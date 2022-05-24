//
//  MachOSegmentCommand.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

enum MachOLoadSegmentCommandError: Error {
    case InvalidVirtualMemoryProtecionType
}

class MachOLoadSegmentCommand: MachOLoadCommand {
    var segname: String     /* segment name */
    var vmaddr: UInt64    /* memory address of this segment */
    var vmsize: UInt64    /* memory size of this segment */
    var fileoff: UInt32    /* file offset of this segment */
    var filesize: UInt32    /* amount to map from the file */
    var maxprot: VirtualMemoryProtectionType    /* maximum VM protection */
    var initprot: VirtualMemoryProtectionType    /* initial VM protection */
    var nsects: UInt32    /* number of sections in segment */
    var flags: UInt32    /* flags */
    
    let sections: [MachOSegmentSection]
    
    private var segnameData: Data {
        let segnameSize = 16
        var data = Data(self.segname.utf8)
        if data.count < segnameSize {
            let padding = Data(count: segnameSize - data.count)
            data.append(padding)
            return data
        } else if data.count > segnameSize {
            return data[0..<segnameSize]
        }
        return data
    }
    
    static let size = 64
    
    init(segname: String, address: Address, vmsize: UInt64, fileOffset: UInt32 = 0, fileSize: UInt32) {
        self.segname = segname
        self.vmaddr = address
        self.vmsize = vmsize
        self.fileoff = fileOffset
        self.filesize = fileSize
        self.maxprot = .all
        self.initprot = .all
        self.nsects = 0
        self.flags = 0
        self.sections = [MachOSegmentSection]()
        let cmdSize = MachOLoadSegmentCommand.size + Int(nsects) * MachOSegmentSection.size
        super.init(cmd: .segment64, cmdSize: UInt32(cmdSize))
    }
    
    override init(from rawData: Data) throws {
        guard rawData.count >= MachOLoadSegmentCommand.size else {
            throw MachOHeaderError.InvalidData
        }
        guard
            let segname = String(data: Data(rawData[8..<24]), encoding: .utf8),
            let vmaddr = Data(rawData[24..<32]).to(type: UInt64.self),
            let vmsize = Data(rawData[32..<40]).to(type: UInt64.self),
            let fileoff = Data(rawData[40..<44]).to(type: UInt32.self),
            let filesize = Data(rawData[44..<48]).to(type: UInt32.self),
            let maxprotRawValue = Data(rawData[48..<52]).to(type: UInt32.self),
            let initprotRawValue = Data(rawData[52..<56]).to(type: UInt32.self),
            let nsects = Data(rawData[56..<60]).to(type: UInt32.self),
            let flags = Data(rawData[60..<64]).to(type: UInt32.self)
        else {
            throw MachOHeaderError.InvalidData
        }
        guard let maxprotValue = VirtualMemoryProtectionType(rawValue: maxprotRawValue),
              let initprotValue = VirtualMemoryProtectionType(rawValue: initprotRawValue)
        else {
            throw MachOLoadSegmentCommandError.InvalidVirtualMemoryProtecionType
        }
        self.segname = segname
        self.vmaddr = vmaddr
        self.vmsize = vmsize
        self.fileoff = fileoff
        self.filesize = filesize
        self.maxprot = maxprotValue
        self.initprot = initprotValue
        self.nsects = nsects
        self.flags = flags
        self.sections = try Self.decodeSections(from: rawData, nsects: nsects)
        try super.init(from: rawData)
    }
    
    override func encode() -> Data {
        var data = super.encode()
        data.append(segnameData)
        data.append(Data(from: vmaddr))
        data.append(Data(from: vmsize))
        data.append(Data(from: fileoff))
        data.append(Data(from: filesize))
        data.append(Data(from: maxprot.rawValue))
        data.append(Data(from: initprot.rawValue))
        data.append(Data(from: nsects))
        data.append(Data(from: flags))
        return data
    }
    
    private static func decodeSections(from data: Data, nsects: UInt32) throws -> [MachOSegmentSection] {
        var sections = [MachOSegmentSection]()
        
        var sectionStartIndex = MachOLoadSegmentCommand.size
        var sectionEndIndex = sectionStartIndex + MachOSegmentSection.size
        
        for _ in 0 ..< nsects {
            let rawSectionData = data[sectionStartIndex..<sectionEndIndex]
            let decoddedSection = try MachOSegmentSection(from: rawSectionData)
            sections.append(decoddedSection)
            sectionStartIndex += MachOSegmentSection.size
            sectionEndIndex += MachOSegmentSection.size
        }
        return sections
    }
}
