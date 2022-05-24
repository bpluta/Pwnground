//
//  InterpretationStrategy.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

protocol InterpretationStrategy {
    static func interpret(value: UInt64) -> String
}

class ARNInstructionInterpreter: InterpretationStrategy {
    static func interpret(value: UInt64) -> String {
        var instructions = [String]()
        if let lower = value[0..<32] {
            instructions.append(interpretInstruction(rawInstruction: lower))
        }
        if let upper = value[32..<64] {
            instructions.append(interpretInstruction(rawInstruction: upper))
        }
        return instructions.joined(separator: " | ")
    }
    
    private static func interpretInstruction(rawInstruction: UInt64) -> String {
        guard
            let rawInstruction = UInt32(exactly: rawInstruction),
            let decodedInstruction = try? ARMInstruction.decode(rawInstruction: rawInstruction),
            let instructionDescription = try? decodedInstruction.describe()
        else { return "?" }
        return instructionDescription
    }
}

class ASCIIStringInterpreter: InterpretationStrategy {
    static func interpret(value: UInt64) -> String {
        let rawData = Data(from: value)
        let asciiString = rawData.printableStringRepresentation(as: Unicode.ASCII.self)
        return "\"\(asciiString)\""
    }
}

class BooleanInterpreter: InterpretationStrategy {
    static func interpret(value: UInt64) -> String {
        value.asBool.description
    }
}

class DecimalInterpreter: InterpretationStrategy {
    static func interpret(value: UInt64) -> String {
        value.description
    }
}

class HexadecimalInterpreter: InterpretationStrategy {
    static func interpret(value: UInt64) -> String {
        value.uppercaseDynamicWidthHexString
    }
}
