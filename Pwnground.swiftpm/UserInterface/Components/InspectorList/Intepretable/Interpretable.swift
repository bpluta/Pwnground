//
//  Interpretable.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

enum InterpretableDisplayMode {
    case normal
    case edited
    case error
}

protocol Interpretable: AnyObject {
    associatedtype Value
    associatedtype Key: Hashable
    
    var key: Key { get }
    var value: Value? { get set }
    
    var presentedValue: String { get }
    var presentedKey: String { get }
    
    var displayMode: InterpretableDisplayMode { get set }
    
    var suggestedPresentationTypes: [ValueInterpretationType] { get }
    var presentationType: ValueInterpretationType { get set }
    var interpreter: InterpretationStrategy.Type { get }
    
    init(key: Key, value: Value?)
    init(from oldObject: Self, updatedTo newValue: Value?)
}

extension Interpretable {
    var suggestedPresentationTypes: [ValueInterpretationType] {
        ValueInterpretationType.allCases
    }
    
    var presentedValue: String {
        guard let value = value as? UInt64 else { return "" }
        return interpreter.interpret(value: value)
    }
    
    var interpreter: InterpretationStrategy.Type {
        switch presentationType {
        case .hexadecimal:
            return HexadecimalInterpreter.self
        case .decimal:
            return DecimalInterpreter.self
        case .boolean:
            return BooleanInterpreter.self
        case .string:
            return ASCIIStringInterpreter.self
        case .instruction:
            return ARNInstructionInterpreter.self
        }
    }
}

extension Interpretable where Value == Bool {
    var presentedValue: String {
        guard let value = value else { return "" }
        return interpreter.interpret(value: UInt64(value))
    }
}

enum ValueInterpretationType: String, CaseIterable {
    case hexadecimal = "Hexadecimal"
    case decimal = "Decimal"
    case boolean = "Boolean"
    case string = "String"
    case instruction = "Instruction"
    
    var description: String { rawValue }
}
