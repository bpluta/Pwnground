//
//  BinaryAssembler.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

class BinaryAssembler {
    static func decodeBinary(from rawData: Data) throws -> MachOFile {
        return try MachOFile(from: rawData)
    }
    
    static func encodeBinary(from machOFile: MachOFile) -> Data {
        var data = Data()
        data.append(machOFile.header.encode())
        machOFile.loadCommands.forEach {
            data.append($0.encode())
        }
        data.append(machOFile.data)
        return data
    }
}
