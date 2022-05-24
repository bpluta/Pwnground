//
//  StaticLinker.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

struct StaticLinkedDataObject {
    let name: String
    let address: Address
}

struct StaticLinkerStringObject {
    let name: String
    let label: String
}

struct StaticLinkerCodeObject {
    let name: String
    var instructionBuilders: [ARMInstructionBuilder.Instruction] = []
}

class StaticLinker {
    private var currentOffset: Int64 = 0
    private var symbols: [String: Int64] = [:]
    
    func link(stringSections: [StaticLinkerStringObject]) -> Data? {
        var data = Data()
        for section in stringSections {
            guard var stringData = section.label.data(using: .utf8) else {
                assertionFailure("Could not convert string to data")
                return nil
            }
            stringData.append(0)
            let bytesToAlign = 4 - (stringData.count % 4)
            for _ in 0..<bytesToAlign {
                stringData.append(0)
            }
            symbols[section.name] = currentOffset
            data.append(stringData)
            currentOffset += Int64(stringData.count)
        }
        return data
    }
    
    func link(codeSections: [StaticLinkerCodeObject]) -> Data? {
        var instructions = [ARMInstruction]()
        updateSymbols(from: codeSections)
        
        for section in codeSections {
            for instruction in section.instructionBuilders {
                guard let instruction = instruction.build() else {
                    assertionFailure("Instruction could not be built")
                    continue
                }
                instructions.append(instruction)
                currentOffset += 4
            }
        }
        
        var rawData = Data()
        for instruction in instructions {
            guard let encodedInstruction = try? instruction.encode() else {
                assertionFailure("Instruction encoding failed")
                return nil
            }
            let rawInstruction = Data(from: encodedInstruction)
            rawData.append(rawInstruction)
        }
        return rawData
    }
    
    private func updateSymbols(from codeSections: [StaticLinkerCodeObject]) {
        var currentOffset: Int64 = self.currentOffset
        for section in codeSections {
            symbols[section.name] = currentOffset
            currentOffset += Int64(4 * section.instructionBuilders.count)
        }
    }
    
    func resolveSymbolOffset<Type: FixedWidthInteger>(for name: String) -> Type? {
        guard let symbol = symbols[name] else {
            assertionFailure("Missing symbol \(name)")
            return nil
        }
        return Type(truncatingIfNeeded: symbol - currentOffset)
    }
    
    func getResolver<Type: FixedWidthInteger>(offset: Int) -> ((String) -> Type?) {
        { [unowned self] name in
            guard let symbol = self.symbols[name] else {
                assertionFailure("Missing symbol \(name)")
                return nil
            }
            if offset > 0 {
                return Type(truncatingIfNeeded: symbol - currentOffset) + Type(truncatingIfNeeded: offset)
            } else {
                return Type(truncatingIfNeeded: symbol - currentOffset) - Type(truncatingIfNeeded: offset)
            }
        }
    }
}
