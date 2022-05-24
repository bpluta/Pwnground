//
//  DynamicLinker.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

enum DynamicLinkerError: Error {
    case couldNotDecodeLoadCommand
    case entryPointMissing
    case loadCommandsMissing
}

class DynamicLinker {
    weak var linkedProcess: SystemProcess?
    
    var entry: Address?
    var stackSize: UInt64?
    var loadSegmentCommands: [MachOLoadSegmentCommand]?
    
    static func parseMachOFile(from rawData: Data) throws -> MachOFile {
        try MachOFile(from: rawData)
    }
    
    func loadBinary(_ rawData: Data) throws {
        let machOFile = try MachOFile(from: rawData)
        for decodedCommand in machOFile.loadCommands {
            try load(command: decodedCommand)
        }
        try loadDataIntoProcess(rawData)
    }
}

// MARK: - Process interaction
extension DynamicLinker {
    private func loadDataIntoProcess(_ binary: Data) throws {
        try loadMainData()
        try loadVirtualMemory(binary)
    }
    
    private func loadMainData() throws {
        let stackSize = self.stackSize ?? VirtualMemory.defaultStackSize
        guard let entryPoint = entry else {
            throw DynamicLinkerError.entryPointMissing
        }
        linkedProcess?.setupEntry(to: entryPoint)
        linkedProcess?.setupStackSize(to: stackSize)
    }
    
    private func loadVirtualMemory(_ binary: Data) throws {
        guard let loadCommands = loadSegmentCommands else {
            throw DynamicLinkerError.loadCommandsMissing
        }
        let mappedSegments = loadCommands.map({ command in
            VirtualMemoryMappedSegment(
                name: command.segname,
                startAddress: command.vmaddr,
                size: command.vmsize,
                protection: command.initprot
            )
        })
        let virtualMemory = VirtualMemory()
        for segment in mappedSegments {
            try virtualMemory.map(segment: segment, as: .user)
        }
        try generateStack(in: virtualMemory)
        try loadData(from: binary, into: virtualMemory)
        linkedProcess?.stackAddress = MemoryAccessMode.user.range.upperBound
        linkedProcess?.setupVirtualMemory(to: virtualMemory)
    }
    
    private func loadData(from binary: Data, into virtualMemory: VirtualMemory) throws {
        guard let loadCommands = loadSegmentCommands else {
            throw DynamicLinkerError.loadCommandsMissing
        }
        for command in loadCommands {
            guard command.fileoff > 0, command.fileoff + command.filesize <= binary.count else { continue }
            let dataToLoad = Data(binary[command.fileoff..<command.fileoff + command.filesize])
            try virtualMemory.write(at: command.vmaddr, value: dataToLoad)
        }
    }
    
    private func generateStack(in virtualMemory: VirtualMemory) throws {
        let size = (stackSize ?? VirtualMemory.defaultStackSize)
        let endAddress = MemoryAccessMode.user.range.upperBound
        let startAddress = endAddress - size
        let stackSegment = VirtualMemoryMappedSegment(
            name: UserControlledMemorySegment.Stack.rawValue,
            startAddress: startAddress,
            size: size,
            protection: .all
        )
        try virtualMemory.map(segment: stackSegment, as: .user)
    }
}

// MARK: - Command loading
extension DynamicLinker {
    private func load(command: MachOLoadCommand) throws {
        switch command.cmd {
        case .main:
            try loadMainCommand(command)
        case .segment64:
            try loadLoadSegmentCommand(command)
        }
    }
    
    private func loadMainCommand(_ command: MachOLoadCommand) throws {
        guard let mainCommand = command as? MachOLoadMainCommand else {
            throw DynamicLinkerError.couldNotDecodeLoadCommand
        }
        entry = mainCommand.entry
        stackSize = mainCommand.stackSize
    }
    
    private func loadLoadSegmentCommand(_ command: MachOLoadCommand) throws {
        guard let segmentCommand = command as? MachOLoadSegmentCommand else {
            throw DynamicLinkerError.couldNotDecodeLoadCommand
        }
        guard let _ = loadSegmentCommands else {
            self.loadSegmentCommands = [segmentCommand]
            return
        }
        loadSegmentCommands?.append(segmentCommand)
    }
}
