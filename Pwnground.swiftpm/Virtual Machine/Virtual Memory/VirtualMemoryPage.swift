//
//  VirtualMemoryPage.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

enum VirtualMemoryProtectionType: UInt32 {
    case none = 0b000
    case read = 0b001
    case write = 0b010
    case execute = 0b100
    case `default` = 0b011
    case all = 0b111
}

class VirtualMemoryPage {
    static let pageSize: UInt64 = 4 << 10
    lazy var data: Data = Data(count: Int(VirtualMemoryPage.pageSize))
    
    private var headBlock: VirtualMemoryBlock?
    private var tailBlock: VirtualMemoryBlock?
    
    let startAddress: Address
    let endAddress: Address
    
    var protectionType: VirtualMemoryProtectionType
    
    var next: VirtualMemoryPage?
    weak var previous: VirtualMemoryPage?
    
    var range: Range<Address> {
        startAddress ..< endAddress
    }
    
    init(address: UInt64, protection: VirtualMemoryProtectionType? = nil) throws {
        guard address % VirtualMemoryPage.pageSize == 0 else {
            throw VirtualMemoryError.InvalidMemoryPageAddress
        }
        startAddress = address
        endAddress = address + VirtualMemoryPage.pageSize
        protectionType = protection ?? .default
    }
    
    func alloc(at address: Address? = nil, size: UInt64) throws -> Address {
        if let destinationAddress = address {
            guard let _ = headBlock else {
                let newBlock = VirtualMemoryBlock(address: destinationAddress, size: size)
                headBlock = newBlock
                tailBlock = newBlock
                return destinationAddress
            }
            guard let space = try findSpace(for: destinationAddress) else {
                throw VirtualMemoryError.AllocAlreadyAllocatedSpace
            }
            let newBlock = VirtualMemoryBlock(address: destinationAddress, size: size)
            newBlock.place(between: space.previous, and: space.next)
            return destinationAddress
        }
        guard let _ = headBlock else {
            let newAddress = startAddress
            let newBlock = VirtualMemoryBlock(address: newAddress, size: size)
            headBlock = newBlock
            tailBlock = newBlock
            return newAddress
        }
        guard let space = try findSpace(for: size) else {
            throw VirtualMemoryError.NotEnoughSpaceWithinPage
        }
        let newAddress = space.previous.address + space.previous.size
        let newBlock = VirtualMemoryBlock(address: newAddress, size: size)
        newBlock.place(between: space.previous, and: space.next)
        return newAddress
    }
    
    func realloc(address: Address, to size: UInt64) throws -> Address {
        guard let block = getBlock(where: { $0.contains(address) }), block.address == address else {
            throw VirtualMemoryError.ReallocNotAllocatedPointer
        }
        guard let nextBlock = block.next, nextBlock.address < block.address + size else {
            let newAddress = block.address
            let newBlock = VirtualMemoryBlock(address: newAddress, size: size)
            newBlock.place(between: block.previous, and: block.next)
            return newAddress
        }
        guard let space = try findSpace(for: size) else {
            let newAddress = startAddress
            let newBlock = VirtualMemoryBlock(address: newAddress, size: size)
            headBlock = newBlock
            tailBlock = newBlock
            return newAddress
        }
        let newAddress = space.previous.address + space.previous.size
        let newBlock = VirtualMemoryBlock(address: newAddress, size: size)
        newBlock.place(between: space.previous, and: space.next)
        return newAddress
    }
    
    func free(address: Address) throws {
        guard let block = getBlock(where: { $0.address == address }) else {
            throw VirtualMemoryError.FreeNotAallocatedPointer
        }
        block.next?.previous = block.previous
        block.previous?.next = block.next
        if block === tailBlock {
            tailBlock = block.previous
        }
        if block === headBlock {
            headBlock = block.next
        }
    }
    
    func read(at address: Address, count: Int) throws -> Data {
        guard range.contains(address) && (address + UInt64(count)) <= endAddress else {
            throw VirtualMemoryError.PageFault(address: address)
        }
        let startIndex = Int(address - startAddress)
        let endIndex = startIndex + count
        return Data(data[startIndex..<endIndex])
    }
    
    func write(at address: Address, to value: Data) throws {
        guard range.contains(address) && (address + UInt64(value.count)) <= endAddress else {
            throw VirtualMemoryError.PageFault(address: address)
        }
        let startIndex = Int(address - startAddress)
        let endIndex = startIndex + value.count
        data.replaceSubrange(startIndex..<endIndex, with: value)
    }
}

extension VirtualMemoryPage {
    private func getBlock(where predicate: (VirtualMemoryBlock) throws -> Bool) rethrows -> VirtualMemoryBlock? {
        var block = headBlock
        while let currentBlock = block {
            if try predicate(currentBlock) {
                return currentBlock
            }
            block = currentBlock.next
        }
        return nil
    }
    
    private func findSpace(for size: UInt64) throws -> (previous: VirtualMemoryBlock, next: VirtualMemoryBlock?)? {
        guard size <= VirtualMemoryPage.pageSize else { throw VirtualMemoryError.NotEnoughSpaceWithinPage }
        guard let blockWithFollowingSpace = try getBlock(where: { block in
            guard let nextBlock = block.next else {
                guard (endAddress - block.address + block.size) >= size else {
                    throw VirtualMemoryError.NotEnoughSpaceWithinPage
                }
                return true
            }
            return nextBlock.address - (block.address + block.size) >= size
        }) else { return nil }
        return (blockWithFollowingSpace, blockWithFollowingSpace.next)
    }
    
    private func findSpace(of address: Address) throws -> (previous: VirtualMemoryBlock, next: VirtualMemoryBlock?)? {
        guard address >= startAddress, address < endAddress else {
            throw VirtualMemoryError.PageFault(address: address)
        }
        guard headBlock != nil else { return nil }
        guard let blockWithFollowingSpace = getBlock(where: { block in
            guard let nextBlock = block.next else {
                return address >= block.address + block.size
            }
            return address >= block.address + block.size && address < nextBlock.address
        }) else {
            return nil
        }
        return (blockWithFollowingSpace, blockWithFollowingSpace.next)
    }
}
