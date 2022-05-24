//
//  MachOHeader.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

enum CPUType: UInt32 {
    case arm64 = 0x010000c
    
    enum SubType {
        case arm64_v8
        
        init?(rawValue: UInt32, cpuType: CPUType) {
            var cpuSubTypes: [SubType]?
            switch cpuType {
            case .arm64:
                cpuSubTypes = [SubType.arm64_v8]
            }
            guard let subType = cpuSubTypes?.first(where: { $0.rawValue == rawValue }) else {
                return nil
            }
            self = subType
        }
        
        var rawValue: UInt32? {
            switch self {
            case .arm64_v8: return 1
            }
        }
        
        var cpuType: CPUType {
            switch self {
            case .arm64_v8: return .arm64
            }
        }
    }
}

enum MachOHeaderError: Error {
    case InvalidData
    case UnknownLoadCommand
    case IncorrectMagicBytes
    case UnknownFileType
    case UnknownCpuType
    case UnknowneCpuSubType
}

enum MachOFileType: UInt32 {
    case executable = 0x2
}

enum MachOHeaderFlag: UInt32, CaseIterable {
    case allowStackExecution = 0x20000
    
    static func isSet(flag: MachOHeaderFlag, in rawValue: UInt32) -> Bool {
        (rawValue & flag.rawValue) != 0
    }
    
    static func decodeFlags(from rawValue: UInt32) -> [MachOHeaderFlag] {
        allCases.filter({ flag in
            (rawValue & flag.rawValue) != 0
        })
    }
}

struct MachOHeader {
    let magic: UInt32
    let cpuType: CPUType
    let cpuSubtype: CPUType.SubType
    let fileType: MachOFileType
    let ncmds: UInt32
    let flags: [MachOHeaderFlag]
    let reserved: UInt32
    
    static let headerSize = 28
    static let machMagic64: UInt32 = 0xfeedfacf
    
    init(cpuSubtype: CPUType.SubType, fileType: MachOFileType, ncmds: UInt32, flags: [MachOHeaderFlag]) {
        self.magic = MachOHeader.machMagic64
        self.cpuType = cpuSubtype.cpuType
        self.cpuSubtype = cpuSubtype
        self.fileType = fileType
        self.ncmds = ncmds
        self.flags = flags
        self.reserved = 0
    }
    
    init(from rawData: Data) throws {
        guard rawData.count >= MachOHeader.headerSize else {
            throw MachOHeaderError.InvalidData
        }
        guard let magicBytes = Data(rawData[0..<4]).to(type: UInt32.self),
              magicBytes == MachOHeader.machMagic64,
              let ncmds = Data(rawData[16..<20]).to(type: UInt32.self),
              let rawFlags = Data(rawData[20..<24]).to(type: UInt32.self),
              let reserved = Data(rawData[24..<28]).to(type: UInt32.self)
        else {
            throw MachOHeaderError.InvalidData
        }
        let flags = MachOHeaderFlag.decodeFlags(from: rawFlags)
        guard let cpuTypeRawValue = Data(rawData[4..<8]).to(type: UInt32.self),
              let cpuTypeValue = CPUType(rawValue: cpuTypeRawValue) else {
            throw MachOHeaderError.UnknownCpuType
        }
        guard let cpuSubtypeRawValue = Data(rawData[8..<12]).to(type: UInt32.self),
              let cpuSubtypeValue = CPUType.SubType(rawValue: cpuSubtypeRawValue, cpuType: cpuTypeValue) else {
            throw MachOHeaderError.UnknowneCpuSubType
        }
        guard let fileTypeRawValue = Data(rawData[12..<16]).to(type: UInt32.self),
              let fileTypeValue = MachOFileType(rawValue: fileTypeRawValue) else {
            throw MachOHeaderError.UnknownFileType
        }
        self.magic = magicBytes
        self.cpuType = cpuTypeValue
        self.cpuSubtype = cpuSubtypeValue
        self.fileType = fileTypeValue
        self.ncmds = ncmds
        self.flags = flags
        self.reserved = reserved
    }
    
    func encode() -> Data {
        var data = Data()
        data.append(Data(from: magic)[0..<4])
        data.append(Data(from: cpuType.rawValue)[0..<4])
        data.append(Data(from: cpuSubtype.rawValue)[0..<4])
        data.append(Data(from: fileType.rawValue)[0..<4])
        data.append(Data(from: ncmds)[0..<4])
        data.append(Data(from: flags.rawValue)[0..<4])
        data.append(Data(from: reserved)[0..<4])
        return data
    }
}


fileprivate extension Array where Element == MachOHeaderFlag {
    var rawValue: UInt32 {
        reduce(0, { $0 | $1.rawValue })
    }
}
