//
//  MachOFile.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

class MachOFile {
    let header: MachOHeader
    let loadCommands: [MachOLoadCommand]
    let data: Data
    
    init(header: MachOHeader, loadCommands: [MachOLoadCommand], data: Data) {
        self.header = header
        self.loadCommands = loadCommands
        self.data = data
    }
    
    init(from rawData: Data) throws {
        self.header = try MachOHeader(from: rawData)
        self.loadCommands = try MachOLoadCommand.decodeLoadCommands(from: rawData, ncmds: header.ncmds)
        let dataOffset = loadCommands.reduce(MachOHeader.headerSize, { $0 + Int($1.cmdsize) })
        self.data = rawData[dataOffset...]
    }
}
