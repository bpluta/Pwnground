//
//  MachOLoadMainCommand.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

class MachOLoadMainCommand: MachOLoadCommand {
    var entry: UInt64
    var stackSize: UInt64
    
    static let size = 24
    
    init(entryPoint: Address, stackSize: UInt64) {
        self.entry = entryPoint
        self.stackSize = stackSize
        super.init(cmd: .main, cmdSize: UInt32(MachOLoadMainCommand.size))
    }
    
    override init(from rawData: Data) throws {
        guard rawData.count >= MachOLoadMainCommand.size,
              let entry = rawData[8..<16].to(type: UInt64.self),
              let stackSize = rawData[16..<24].to(type: UInt64.self)
        else {
            throw MachOHeaderError.InvalidData
        }
        self.entry = entry
        self.stackSize = stackSize
        try super.init(from: rawData)
    }
    
    override func encode() -> Data {
        var data = super.encode()
        data.append(Data(from: entry))
        data.append(Data(from: stackSize))
        return data
    }
}
