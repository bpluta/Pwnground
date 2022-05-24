//
//  VirtualMemory.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

typealias Address = UInt64

enum VirtualMemoryError: Error {
    case SegmentationFault(address: Address)
    case MemorySegmentNameCollision
    case PageFault(address: Address)
    case InvalidMemoryPageAddress
    case FreeNotAallocatedPointer
    case ReallocNotAllocatedPointer
    case AllocAlreadyAllocatedSpace
    case NotEnoughSpaceWithinPage
}

enum VMOperationType: UInt32 {
    case read = 0b001
    case write = 0b010
    case execute = 0b100
}

enum MemoryAccessMode {
    case user
    case kernel
    
    private static let userSpaceRange: Range<Address> = 0x0 ..< 0x8000_0000_0000
    private static let kernelMinAddress: Range<Address> = 0xffff800000000000 ..< 0xffffffffffffffff
    
    var range: Range<Address> {
        switch self {
        case .user: return Self.userSpaceRange
        case .kernel: return Self.kernelMinAddress
        }
    }
    
    func contains(range: Range<Address>) -> Bool {
        self.range.contains(range.lowerBound) && self.range.contains(range.upperBound - 1)
    }
}

protocol InstructionExecutionDelegate: AnyObject {
    func decode(rawInstruction: RawARMInstruction)
}

class VirtualMemory {
    private var headPage: VirtualMemoryPage?
    private var tailPage: VirtualMemoryPage?
    
    private var mappedSegments: [VirtualMemoryMappedSegment]?
    weak var executionDelegate: InstructionExecutionDelegate?
    
    static let defaultStackSize: UInt64 = (8 << 10) * (1 << 10)
    
    // MARK: - Virtual memory mapping
    func map(segment: VirtualMemoryMappedSegment, as accesser: MemoryAccessMode = .user) throws {
        guard accesser == .kernel || accesser.contains(range: segment.range) else {
            throw VirtualMemoryError.SegmentationFault(address: segment.startAddress)
        }
        guard !(mappedSegments?.contains(where: { $0.name == segment.name }) ?? false) else {
            throw VirtualMemoryError.MemorySegmentNameCollision
        }
        if let mappedSegments = mappedSegments {
            guard !mappedSegments.contains(where: { $0.range.overlaps(segment.range) }) else {
                throw VirtualMemoryError.SegmentationFault(address: segment.startAddress)
            }
            self.mappedSegments?.append(segment)
        } else {
            mappedSegments = [segment]
        }
    }
    
    func unmap(address: Address) throws {
        guard let page = getPage(where: { $0.startAddress == address }) else {
            throw VirtualMemoryError.PageFault(address: address)
        }
        page.next?.previous = page.previous
        page.previous?.next = page.next
        if page === headPage {
            headPage = page.next
        }
        if page === tailPage {
            tailPage = page.previous
        }
    }
    
    // MARK: - Dynamic memory allocation
    func alloc(count: Int) throws -> Address {
        guard let heap = mappedSegments?.first(where: { $0.name == UserControlledMemorySegment.Heap.rawValue }) else {
            throw VirtualMemoryError.PageFault(address: Address(bitPattern: -1))
        }
        let pages = getAllPages(where: { heap.range.contains($0.startAddress) })
        for page in pages {
            if let address = try? page.alloc(size: UInt64(count)) {
                return address
            }
        }
        throw VirtualMemoryError.NotEnoughSpaceWithinPage
    }
 
    func free(address: Address) throws {
        guard let page = getPage(where: { $0.range.contains(address) }) else {
            throw VirtualMemoryError.FreeNotAallocatedPointer
        }
        try page.free(address: address)
    }
    
    // MARK: - Memory operations
    func read(at address: Address, count: Int, as accesser: MemoryAccessMode = .user) throws -> Data {
        do {
            let page = try getPageForOperation(at: address, count: count, operationType: .read, as: accesser)
            return try page.read(at: address, count: count)
        } catch (let error) {
            throw error
        }
    }
    
    func write(at address: Address, value: Data, as accesser: MemoryAccessMode = .user) throws {
        let page = try getPageForOperation(at: address, count: value.count, operationType: .write, as: accesser)
        try page.write(at: address, to: value)
    }
    
    func fetch(at address: Address, as accesser: MemoryAccessMode = .user) throws -> RawARMInstruction {
        let count = RawARMInstruction.bitWidth >> 3
        let page = try getPageForOperation(at: address, count: count, operationType: .execute, as: accesser)
        let rawData = Data(try page.read(at: address, count: count))[0..<4]
        guard let instruction = rawData.to(type: RawARMInstruction.self) else {
            throw VirtualMemoryError.SegmentationFault(address: address)
        }
        return instruction
    }
}

// MARK: - Helpers
extension VirtualMemory {
    private func getPageForOperation(at address: Address, count: Int, operationType: VMOperationType, as accesser: MemoryAccessMode) throws -> VirtualMemoryPage {
        guard accesser == .kernel || accesser.range.contains(address) else {
            throw VirtualMemoryError.SegmentationFault(address: address)
        }
        let pageAddress = address - address % VirtualMemoryPage.pageSize
        guard let page = getPage(where: { $0.startAddress == pageAddress }) else {
            return try createPageIfMemoryIsMapped(address: address, operationType: operationType)
        }
        guard checkPagePermissions(in: page, for: [operationType]) else {
            throw VirtualMemoryError.SegmentationFault(address: address)
        }
        return page
    }
    
    private func createPageIfMemoryIsMapped(address: Address, operationType: VMOperationType) throws -> VirtualMemoryPage {
        let pageAddress = address - address % VirtualMemoryPage.pageSize
        guard let mappedSegment = mappedSegments?.first(where:  { $0.range.contains(pageAddress) }),
              checkSegmentPermissions(in: mappedSegment, for: [operationType]) else {
            throw VirtualMemoryError.SegmentationFault(address: address)
        }
        switch operationType {
        case .write, .execute:
            try addPage(at: pageAddress, with: mappedSegment.protection)
            guard let page = getPage(where: { $0.startAddress == pageAddress }) else {
                throw VirtualMemoryError.SegmentationFault(address: address)
            }
            return page
        case .read:
            let page = try getEmptyPage(address: pageAddress)
            return page
        }
    }
    
    private func getEmptyPage(address: Address) throws -> VirtualMemoryPage {
        try VirtualMemoryPage(address: address)
    }
    
    private func isPageMapped(for address: Address, for accesser: MemoryAccessMode) -> Bool {
        guard let mappedSegments = mappedSegments else { return false }
        guard accesser == .kernel || accesser.range.contains(address) else {
            return false
        }
        let pageAddress = address - address % VirtualMemoryPage.pageSize
        let isPageMapped = mappedSegments.contains(where: { segment in
            segment.range.contains(pageAddress)
        })
        return isPageMapped
    }
    
    
    private func checkPagePermissions(in page: VirtualMemoryPage, for operations: [VMOperationType]) -> Bool {
        guard !operations.isEmpty else { return false }
        for operation in operations {
            guard (operation.rawValue & page.protectionType.rawValue).asBool else {
                return false
            }
        }
        return true
    }

    private func checkSegmentPermissions(in sgement: VirtualMemoryMappedSegment, for operations: [VMOperationType]) -> Bool {
        guard !operations.isEmpty else { return false }
        for operation in operations {
            guard (operation.rawValue & sgement.protection.rawValue).asBool else {
                return false
            }
        }
        return true
    }
    
    private func getPage(where predicate: (VirtualMemoryPage) throws -> Bool) rethrows -> VirtualMemoryPage? {
        var page = headPage
        while let currentPage = page {
            if try predicate(currentPage) {
                return currentPage
            }
            page = currentPage.next
        }
        return nil
    }
    
    private func getAllPages(where predicate: (VirtualMemoryPage) throws -> Bool) rethrows -> [VirtualMemoryPage] {
        var page = headPage
        var matchingPages = [VirtualMemoryPage]()
        while let currentPage = page {
            if try predicate(currentPage) {
                matchingPages.append(currentPage)
            }
            page = currentPage.next
        }
        return matchingPages
    }
    
    @discardableResult
    private func addPage(at address: Address, with protection: VirtualMemoryProtectionType? = nil) throws -> Address {
        guard address % VirtualMemoryPage.pageSize == 0 else {
            throw VirtualMemoryError.InvalidMemoryPageAddress
        }
        guard getPage(where: { $0.range.contains(address) }) == nil else {
            throw VirtualMemoryError.PageFault(address: address)
        }
        let newPage = try VirtualMemoryPage(address: address, protection: protection)
        if let _ = headPage, let space = try findSpace(for: newPage) {
            space.previous.next = newPage
            space.next?.previous = newPage
        } else {
            headPage = newPage
            tailPage = newPage
        }
        return address
    }
    
    private func findSpace(for page: VirtualMemoryPage) throws -> (previous: VirtualMemoryPage, next: VirtualMemoryPage?)? {
        guard headPage != nil else { return nil }
        guard let pageWithFollowingSpace = getPage(where: { currentPage in
            guard let nextPage = currentPage.next else {
                return page.startAddress >= currentPage.startAddress + VirtualMemoryPage.pageSize
            }
            return page.startAddress >= currentPage.startAddress + VirtualMemoryPage.pageSize && currentPage.startAddress < nextPage.startAddress
        }) else {
            return nil
        }
        return (pageWithFollowingSpace, pageWithFollowingSpace.next)
    }
}
