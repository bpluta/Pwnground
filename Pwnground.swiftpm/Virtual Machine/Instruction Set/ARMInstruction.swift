//
//  ARMInstruction.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

enum ARMInstructionEncoderError: Error {
    case bitfieldRangeMismatch
}

enum ARMInstructionDecoderError: Error {
    case instructionFamilyMismatch
    case unsupportedMnemonic
    case unableToDecode
    case unrecognizedInstruction
    case subclassDecoderUnsupported
}

class ARMInstruction {
    class var supportedMnemonics: [ARMMnemonic] { [ARMMnemonic]() }

    let mnemonic: ARMMnemonic
    var mnemonicSuffix: ARMMnemonic.Suffix? { nil }
    var mode: CPUMode? { nil }
    
    @ARMInstructionComponent(25..<29)
    var rootOp0: UInt32?
    
    required init(_ mnemonic: ARMMnemonic? = nil, cpuMode: CPUMode? = nil, indexingMode: IndexingMode? = nil) throws {
        guard let mnemonic = mnemonic, Self.supportedMnemonics.contains(mnemonic) else {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
        self.mnemonic = mnemonic
        setupDefaultCoders()
        setupCustomCoders()
        setupInstruction(cpuMode: cpuMode, indexingMode: indexingMode)
    }
    
    required init(from rawInstruction: RawARMInstruction) throws {
        mnemonic = try Self.getMnemonic(for: rawInstruction)
        setupDefaultCoders()
        setupCustomCoders()
        try decodeComponents(from: rawInstruction)
    }
    
    // MARK: Static intercae
    class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
        let decodedInstruction = try decode(rawInstruction: rawInstruction)
        guard decodedInstruction.self is Self else {
            throw ARMInstructionDecoderError.instructionFamilyMismatch
        }
        return decodedInstruction.mnemonic
    }
    
    class func decode(rawInstruction: RawARMInstruction) throws -> ARMInstruction {
        guard Self.self == ARMInstruction.self else {
            throw ARMInstructionDecoderError.subclassDecoderUnsupported
        }
        guard let instructionDecoder = try decodeInstructionType(from: rawInstruction) else {
            throw ARMInstructionDecoderError.unrecognizedInstruction
        }
        return try instructionDecoder.decode(rawInstruction: rawInstruction)
    }
    
    // MARK: Setup methods
    func setupCustomCoders() { }
    
    func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) { }
    
    // MARK: Description
    func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? { nil }
    
    func describe() throws -> String {
        try buildString(for: mnemonic)
    }
    
    func buildString(for mnemonic: ARMMnemonic) throws -> String {
        let mnemonicBuilder = ARMMnemonicBuilder(mnemonicBase: .required(mnemonic), suffix: .optional(mnemonicSuffix))
        let argumentBuilders = getArgumentBuilders(for: mnemonic) ?? []
        let builder = ARMInstructionStringBuilder(mnemonic: mnemonicBuilder, arguments: argumentBuilders)
        return try builder.build()
    }
    
}

// MARK: Component coding
extension ARMInstruction {
    func encode() throws -> RawARMInstruction {
        try rawInstructionComponents.reduce(RawARMInstruction(), { try $1.merge(with: $0) })
    }
    
    private static func decodeInstructionType(from rawInstruction: RawARMInstruction) throws -> ARMInstruction.Type? {
        guard let op0 = rawInstruction[25..<29] else { throw ARMInstructionDecoderError.unableToDecode }
        var decoder: ARMInstruction.Type?
        if op0 == 0b0000 {
            // Reserved
        } else if op0 == 0b0010 {
            // SVE Instructions
        } else if op0 & 0b1110 == 0b1000 {
            // Data Processing -- Immediate
            decoder = DataProcessingImmediate.self
        } else if op0 & 0b1110 == 0b1010 {
            // Branches, Exception Generating and System instructions
            decoder = BranchesExceptionAndSystem.self
        } else if op0 & 0b0101 == 0b0100 {
            // Loads and Stores
            decoder = LoadsAndStores.self
        } else if op0 & 0b0111 == 0b101 {
            // Data Processing -- Register
            decoder = DataProcessingRegister.self
        } else if op0 & 0b0111 == 0b111 {
            // Data Processing -- Scalar Floating-Point and Advanced SIMD
            decoder = DataProcessingFloatingAndSimd.self
        }
        return decoder
    }
    
    private func decodeComponents(from rawInstruction: RawARMInstruction) throws {
        for var component in rawInstructionComponents {
            guard let value = rawInstruction[component.bitRange] else {
                throw ARMInstructionDecoderError.unableToDecode
            }
            component.rawValue = value
        }
    }
    
    private var rawInstructionComponents: [ARMRawInstructionComponent] {
        var currentMirror: Mirror? = Mirror(reflecting: self)
        var components = [ARMRawInstructionComponent]()
        
        while currentMirror != nil && currentMirror?.subjectType is ARMInstruction.Type {
            let currentClassComponents = currentMirror?.children.compactMap { _, value in
                guard let value = value as? ARMRawInstructionComponent else { return nil }
                return value
            } ?? [ARMRawInstructionComponent]()
            components = currentClassComponents + components
            currentMirror = currentMirror?.superclassMirror
        }
        return components
    }
    
    // Walkaround for swift issue with type specific exetnsion in property wrappers
    private func setupDefaultCoders() {
        for (_, value) in Mirror(reflecting: self).children {
            if let value = value as? ARMInstructionComponent<UInt64> {
                value.customDecoder = decodeImmediate(value:)
                value.customEncoder = encodeImmediate(value:)
            }
            if let value = value as? ARMInstructionComponent<UInt32> {
                value.customDecoder = decodeImmediate(value:)
                value.customEncoder = encodeImmediate(value:)
            }
            if let value = value as? ARMInstructionComponent<UInt16> {
                value.customDecoder = decodeImmediate(value:)
                value.customEncoder = encodeImmediate(value:)
            }
            if let value = value as? ARMInstructionComponent<UInt8> {
                value.customDecoder = decodeImmediate(value:)
                value.customEncoder = encodeImmediate(value:)
            }
            if let value = value as? ARMInstructionComponent<Int64> {
                value.customDecoder = getSignedImmediateDecoder(bitRange: value.bitRange)
                value.customEncoder = getSignedImmediateEncoder(bitRange: value.bitRange)
            }
            if let value = value as? ARMInstructionComponent<Int32> {
                value.customDecoder = getSignedImmediateDecoder(bitRange: value.bitRange)
                value.customEncoder = getSignedImmediateEncoder(bitRange: value.bitRange)
            }
            if let value = value as? ARMInstructionComponent<Int16> {
                value.customDecoder = getSignedImmediateDecoder(bitRange: value.bitRange)
                value.customEncoder = getSignedImmediateEncoder(bitRange: value.bitRange)
            }
            if let value = value as? ARMInstructionComponent<Int8> {
                value.customDecoder = getSignedImmediateDecoder(bitRange: value.bitRange)
                value.customEncoder = getSignedImmediateEncoder(bitRange: value.bitRange)
            }
            if let value = value as? ARMInstructionComponent<ARMRegister> {
                value.customDecoder = decodeRegister(value:)
                value.customEncoder = encodeRegister(value:)
            }
            if let value = value as? ARMInstructionComponent<CPUMode> {
                value.customDecoder = decodeCPUMode(value:)
                value.customEncoder = encodeCPUMode(value:)
            }
            if let value = value as? ARMInstructionComponent<ARMMnemonic.Condition> {
                value.customDecoder = decodeBranchCondition(value:)
                value.customEncoder = encodeBranchCondition(value:)
            }
            if let value = value as? ARMInstructionComponent<ARMMnemonic.IndirectionTarget> {
                value.customDecoder = decodeIndirectionTarget(value:)
                value.customEncoder = encodeIndirectionTarget(value:)
            }
        }
    }
}

// MARK: Decoder helpers
extension ARMInstruction {
    func shiftImmediate<Type: FixedWidthInteger>(_ immediate: Type?, by value: Int, condition: (() -> Bool)? = nil) -> Type? {
        guard let immediate = immediate else { return nil }
        if let condition = condition {
            if condition() {
                return immediate &<< value
            } else {
                return immediate
            }
        } else {
            return immediate &<< value
        }
    }
    
    func mergeImmediates<Type: FixedWidthInteger>(from immediateComponentWrappers: [ARMRawInstructionComponent]) -> Type? {
        guard immediateComponentWrappers.reduce(true, { $0 && $1.rawValue != nil }) else { return nil }
        var value: Type = 0
        var index = 0
        for component in immediateComponentWrappers {
            value |= Type(component.rawValue ?? 0) &<< index
            index += component.bitRange.count
        }
        return value
    }
    
    func divideImmediates<Type: FixedWidthInteger>(from value: Type?, into immediateComponentWrappers: [ARMRawInstructionComponent]) throws {
        guard let value = value else { return }
        guard immediateComponentWrappers.reduce(true, { isValid, component in
            let bitRange = component.bitRange
            guard
                bitRange.lowerBound > 0, bitRange.lowerBound <= bitRange.upperBound,
                bitRange.upperBound <= value.bitWidth, bitRange.upperBound <= value.bitWidth
            else { return isValid && false }
            return isValid && true
        }) else {
            throw ARMInstructionEncoderError.bitfieldRangeMismatch
        }
        var startIndex = 0
        for var component in immediateComponentWrappers {
            let endIndex = startIndex + component.bitRange.count
            let bitRange = startIndex ..< endIndex
            let newValue = RawARMInstruction(clamping: value.masked(including: bitRange) &>> bitRange)
            component.rawValue = newValue
            startIndex += component.bitRange.count
        }
    }
}

// MARK: - Common custom Encoders / Decoders
extension ARMInstruction {
    func getSignedImmediateDecoder<Type: FixedWidthInteger>(bitRange: Range<Int>) -> ((RawARMInstruction?) -> Type?) {
        { value in
            guard var value = value else { return nil }
            if value[bitRange.count-1] ?? false {
                let mask = RawARMInstruction.ones.masked(excluding: 0..<bitRange.count)
                value = value | mask
            }
            return Type(truncatingIfNeeded: value)
        }
    }
    
    func getSignedImmediateEncoder<Type: FixedWidthInteger>(bitRange: Range<Int>) -> ((Type?) -> RawARMInstruction?) {
        { value in
            guard var value = value else { return nil }
            if value[bitRange.count-1] ?? false {
                let mask = Type.ones.masked(including: 0..<bitRange.count)
                value = value & mask
            }
            return RawARMInstruction(truncatingIfNeeded: value)
        }
    }
    
    func getPreProcessedImmedaiteDecoder<Type: FixedWidthInteger>(_ operation: @escaping ((RawARMInstruction) -> RawARMInstruction?)) -> ((RawARMInstruction?) -> Type?) {
        { value in
            guard let value = value, let processedValue = operation(value) else { return nil }
            return Type(clamping: processedValue)
        }
    }
    
    func getPostProcessedImmedaiteDecoder<Type: FixedWidthInteger>(_ operation: @escaping ((Type) -> Type?)) -> ((RawARMInstruction?) -> Type?) {
        { value in
            guard let value = value else { return nil }
            return operation(Type(truncatingIfNeeded: value))
        }
    }
    
    func getPreProcessedImmedaiteEncoder<Type: FixedWidthInteger>(_ operation: @escaping ((Type) -> Type?)) -> ((Type?) -> RawARMInstruction?) {
        { value in
            guard let value = value, let processedValue = operation(value) else { return nil }
            return RawARMInstruction(truncatingIfNeeded: processedValue)
        }
    }
    
    func getPostProcessedImmedaiteEncoder<Type: FixedWidthInteger>(_ operation: @escaping ((RawARMInstruction) -> RawARMInstruction?)) -> ((Type?) -> RawARMInstruction?) {
        { value in
            guard let value = value else { return nil }
            return operation(RawARMInstruction(truncatingIfNeeded: value))
        }
    }
    
    func getPreProcessedSignedImmedaiteDecoder<Type: FixedWidthInteger>(_ operation: @escaping ((RawARMInstruction) -> RawARMInstruction?), bitWidth: Int) -> ((RawARMInstruction?) -> Type?) {
        { value in
            guard let value = value, let processedValue = operation(value) else { return nil }
            var mask: Type = 0b0
            if value[bitWidth-1..<bitWidth] == 0b1 {
                mask = Type.ones.masked(including: bitWidth..<Type.bitWidth)
            }
            return Type(clamping: processedValue) | mask
        }
    }
    
    func getPostProcessedSignedImmedaiteDecoder<Type: FixedWidthInteger>(_ operation: @escaping ((Type) -> Type?), bitWidth: Int) -> ((RawARMInstruction?) -> Type?) {
        { value in
            guard let value = value else { return nil }
            var mask: Type = 0b0
            if value[bitWidth-1] ?? false {
                mask = Type.ones.masked(including: bitWidth..<Type.bitWidth)
            }
            return operation(Type(truncatingIfNeeded: value) | mask) // operation(Type(clamping: value) | mask)
        }
    }
    
    func getPreProcessedSignedImmedaiteEncoder<Type: FixedWidthInteger>(_ operation: @escaping ((Type) -> Type?), bitWidth: Int) -> ((Type?) -> RawARMInstruction?) {
        { value in
            guard let value = value else { return nil }
            guard var processedValue = operation(value) else { return nil }
            if processedValue[bitWidth-1] ?? false {
                let mask = Type.ones.masked(excluding: 0..<bitWidth)
                processedValue = processedValue | mask
            }
            return RawARMInstruction(truncatingIfNeeded: processedValue)
        }
    }
    
    func getPostProcessedSignedImmedaiteEncoder<Type: FixedWidthInteger>(_ operation: @escaping ((RawARMInstruction) -> RawARMInstruction?), bitWidth: Int) -> ((Type?) -> RawARMInstruction?) {
        { value in
            guard var value = value else { return nil }
            if value < 0 {
                let mask = Type.ones.masked(excluding: bitWidth..<Type.bitWidth)
                value = value & mask
            }
            return operation(RawARMInstruction(clamping: value))
        }
    }
    
    func getModeSensitiveRegisterDecoder(for instructionMode: InstructionMode = .stackPointer, cpuMode: CPUMode? = nil) -> ((RawARMInstruction?) -> ARMRegister?) {
        { [weak self] value in
            guard let value = value, let mode = cpuMode ?? self?.mode else { return nil }
            return ARMGeneralPurposeRegister.getRegister(from: value, in: mode , for: instructionMode)
        }
    }
    
    func getEnforcedCPUModeRegisterDecoder(for mode: CPUMode = .x64) ->
    ((RawARMInstruction?) -> ARMRegister?) {
        { value in
            guard let value = value else { return nil }
            return ARMGeneralPurposeRegister.getRegister(from: value, in: mode)
        }
    }
    
    func getBinaryShiftValueDecoder<Type: FixedWidthInteger>(defaultShiftValue: Type) -> ((RawARMInstruction?) -> Type?) {
        { value in
            guard let value = value else { return nil }
            switch (value & 0b1) {
            case 0b0: return 0
            case 0b1: return defaultShiftValue
            default: return nil
            }
        }
    }
    
    func getBinaryShiftValueEncoder<Type: FixedWidthInteger>() -> ((Type?) -> RawARMInstruction?) {
        { value in
            guard let value = value else { return nil }
            return value != 0 ? 0b1 : 0b0
        }
    }
    
    func decodeRegister(value: RawARMInstruction?) -> ARMRegister? {
        guard let value = value else { return nil }
        return ARMGeneralPurposeRegister.getRegister(from: value, in: mode ?? .x64, for: .stackPointer)
    }
    func encodeRegister(value: ARMRegister?) -> RawARMInstruction? {
        guard let register = value, let rawValue = register.value else { return nil }
        return RawARMInstruction(clamping: rawValue)
    }
    func decodeImmediate<Type: FixedWidthInteger>(value: RawARMInstruction?) -> Type? {
        guard let value = value else { return nil }
        return Type(clamping: value)
    }
    func encodeImmediate<Type: FixedWidthInteger>(value: Type?) -> RawARMInstruction? {
        guard let value = value else { return nil }
        return RawARMInstruction(clamping: value)
    }
    func decodeCPUMode(value: RawARMInstruction?) -> CPUMode? {
        guard let value = value else { return nil }
        return CPUMode(rawValue: Int(value & 1))
    }
    func encodeCPUMode(value: CPUMode?) -> RawARMInstruction? {
        guard let value = value else { return nil }
        return RawARMInstruction(clamping: value.rawValue)
    }
    func decodeBranchCondition(value: RawARMInstruction?) -> ARMMnemonic.Condition? {
        guard let value = value else { return nil }
        return ARMMnemonic.Condition(rawValue: Int(value & 0b1111))
    }
    func encodeBranchCondition(value: ARMMnemonic.Condition?) -> RawARMInstruction? {
        guard let value = value else { return nil }
        return RawARMInstruction(clamping: value.rawValue)
    }
    func decodeIndirectionTarget(value: RawARMInstruction?) -> ARMMnemonic.IndirectionTarget? {
        guard let value = value else { return nil }
        return ARMMnemonic.IndirectionTarget(value: Int(value & 0b11))
    }
    func encodeIndirectionTarget(value: ARMMnemonic.IndirectionTarget?) -> RawARMInstruction? {
        guard let value = value else { return nil }
        return RawARMInstruction(clamping: value.value)
    }
}


class ARMDecoderHelper {
    static func isBFXPreferred<IntegerType: FixedWidthInteger>(sf: Bool, uns: Bool, imms: IntegerType?, immr: IntegerType?) -> Bool {
        let imms = imms ?? 0 & 0b111111
        let immr = immr ?? 0 & 0b111111
        
        guard imms >= immr, imms != (sf &<< 5 | 0b11111) else { return false }
        if immr == 0 {
            if !sf && (imms == 0b000111 || imms == 0b001111) {
                return false
            }
            if ((sf &<< 1 | (uns ? 1 : 0)) == 0b10) && (imms == 0b000111 || imms == 0b001111 || imms == 0b011111) {
                return false
            }
        }
        return true
    }
    
    static func isMoveWidePreferred<IntegerType: FixedWidthInteger>(sf: Bool, n: Bool, imms: IntegerType?, immr: IntegerType?) -> Bool {
        let imms = imms ?? 0 & 0b111111
        let immr = immr ?? 0 & 0b111111
        let s = UInt8(imms)
        let r = UInt8(immr)
        let width = sf ? 64 : 32
        
        guard !(sf && n), !(!sf && (n &<< 6 | imms) & 0b1100000 == 0b0) else {
            return false
        }
        if s < 16 {
            return (-Int(r) % 16) <= (15 - s)
        }
        if s >= width - 15 {
            return (r % 16) <= (Int(s) - (width - 15))
        }
        return false
    }
}
