//
//  MachOLoadCommand.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

enum MachOLoadCommandType: UInt32 {
    case segment64 = 0x19
    case main = 0x80000028
}

class MachOLoadCommand {
    let cmd: MachOLoadCommandType
    var cmdsize: UInt32
    
    private static let size = 8
    
    init(cmd: MachOLoadCommandType, cmdSize: UInt32 = UInt32(MachOLoadCommand.size)) {
        self.cmd = cmd
        self.cmdsize = cmdSize
    }
    
    init(from rawData: Data) throws {
        guard
            rawData.count >= MachOLoadCommand.size,
            let rawCmdType = Data(rawData[0..<4]).to(type: UInt32.self),
            let cmdSize = Data(rawData[4..<8]).to(type: UInt32.self)
        else {
            throw MachOHeaderError.InvalidData
        }
        guard let cmdType = MachOLoadCommandType(rawValue: rawCmdType) else {
            throw MachOHeaderError.UnknownLoadCommand
        }
        self.cmd = cmdType
        self.cmdsize = cmdSize
    }
    
    func encode() -> Data {
        var data = Data()
        data.append(Data(from: cmd.rawValue))
        data.append(Data(from: cmdsize))
        return data
    }
    
    func execute() { }
    
    static func decodeLoadCommands(from data: Data, ncmds: UInt32) throws -> [MachOLoadCommand] {
        var commands = [MachOLoadCommand]()
        var commandStartIndex = MachOHeader.headerSize
        var commandEndIndex = commandStartIndex
        
        for _ in 0 ..< ncmds {
            commandEndIndex = commandStartIndex + MachOLoadCommand.size
            
            let generalCommandData = Data(data[commandStartIndex..<commandEndIndex])
            let command = try MachOLoadCommand(from: generalCommandData)
            
            commandEndIndex = commandStartIndex + Int(command.cmdsize)
            let commandData = Data(data[commandStartIndex..<commandEndIndex])
            
            var targetCommand: MachOLoadCommand?
            switch command.cmd {
            case .main: targetCommand = try MachOLoadMainCommand(from: commandData)
            case .segment64: targetCommand = try MachOLoadSegmentCommand(from: commandData)
            }
            guard let decodedTargetCommand = targetCommand else {
                throw MachOHeaderError.InvalidData
            }
            commands.append(decodedTargetCommand)
            commandStartIndex = commandEndIndex
        }
        return commands
    }
}
