//
//  ARMInstructionComponent.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

protocol ARMRawInstructionComponent {
    var rawValue: RawARMInstruction? { get set }
    var bitRange: Range<Int> { get }
    func merge(with rawInstruction: RawARMInstruction) throws -> RawARMInstruction
}

@propertyWrapper
class ARMInstructionComponent<InstructionComponent>: ARMRawInstructionComponent {
    typealias ComponentDecoder = ((RawARMInstruction?) -> InstructionComponent?)
    typealias ComponentEncoder = ((InstructionComponent?) -> RawARMInstruction?)
    
    var isValuePreserved: Bool = false
    var projectedValue: RawARMInstruction?
    var wrappedValue: InstructionComponent? {
        get { (customDecoder ?? decode(value:))(projectedValue) }
        set {
            guard !isValuePreserved else { return }
            projectedValue = (customEncoder ?? encode(value:))(newValue)
        }
    }
    var rawValue: RawARMInstruction? {
        get { projectedValue }
        set {
            guard !isValuePreserved else { return }
            projectedValue = newValue
        }
    }
    
    var customDecoder: ((RawARMInstruction?) -> InstructionComponent?)?
    var customEncoder: ((InstructionComponent?) -> RawARMInstruction?)?
    
    var bitRange: Range<Int>
    
    init(_ bitRange: Range<Int>, enforced: RawARMInstruction? = nil) {
        self.bitRange = bitRange
        if let enforcedRawValue = enforced {
            projectedValue = enforcedRawValue
            isValuePreserved = true
        }
    }
}

extension ARMInstructionComponent {
    func merge(with rawInstruction: RawARMInstruction) throws -> RawARMInstruction {
        guard let value = rawValue else { return rawInstruction }
        guard
            bitRange.lowerBound >= 0, bitRange.lowerBound <= bitRange.upperBound,
            bitRange.upperBound <= rawInstruction.bitWidth, bitRange.upperBound <= value.bitWidth
        else {
            throw ARMInstructionEncoderError.bitfieldRangeMismatch
        }
        return rawInstruction.masked(excluding: bitRange) | (value &<< bitRange)
    }
}

// MARK: - Default coders
extension ARMInstructionComponent {
    func decode(value: RawARMInstruction?) -> InstructionComponent? { nil }
    func encode(value: InstructionComponent?) -> RawARMInstruction? { nil }
}

extension ARMInstructionComponent where InstructionComponent: ARMRegister {
    func decode(value: RawARMInstruction?) -> InstructionComponent? {
        guard let value = value else { return nil }
        return ARMGeneralPurposeRegister.getRegister(from: value, in: .x64, for: .stackPointer) as? InstructionComponent
    }

    func encode(value: InstructionComponent?) -> RawARMInstruction? {
        guard let register = value, let value = register.value else { return nil }
        return RawARMInstruction(clamping: value)
    }
}

extension ARMInstructionComponent where InstructionComponent: FixedWidthInteger {
    func decode(value: RawARMInstruction?) -> InstructionComponent? {
        guard let value = value else { return nil }
        return InstructionComponent(clamping: value)
    }
    
    func encode(value: InstructionComponent?) -> RawARMInstruction? {
        guard let value = value else { return nil }
        return RawARMInstruction(clamping: value)
    }
}

extension ARMInstructionComponent where InstructionComponent == CPUMode {
    func decode(value: RawARMInstruction?) -> InstructionComponent? {
        guard let value = value else { return nil }
        return CPUMode(rawValue: Int(value & 1))
    }

    func encode(value: InstructionComponent?) -> RawARMInstruction? {
        guard let value = value else { return nil }
        return RawARMInstruction(clamping: value.rawValue)
    }
}
