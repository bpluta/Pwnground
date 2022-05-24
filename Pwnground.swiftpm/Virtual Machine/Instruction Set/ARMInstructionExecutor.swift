//
//  ARMInstructionExecutor.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

enum ARMInstructionExecutorError: Error {
    case unsupportedInstruction
    case missingValue
    case unsupportedShiftValue
    case wrongRegister
}

enum ARMConditionFlag: Int, Hashable, CaseIterable {
    case negative
    case zero
    case carry
    case overflow
    
    static var flags: [ARMConditionFlag: Bool] {
        var flags = [ARMConditionFlag: Bool]()
        for flag in allCases {
            flags[flag] = false
        }
        return flags
    }
    
    var description: String {
        switch self {
        case .negative:
            return "Negative"
        case .zero:
            return "Zero"
        case .carry:
            return "Carry"
        case .overflow:
            return "Overflow"
        }
    }
}

// MARK: - ALU
extension ARMInstructionExecutor {
    struct ALU {
        var delegate: ARMInstructionExecutorDelegate?

        func addWithCarry<IntegerType: FixedWidthInteger>(value1: IntegerType?, value2: IntegerType?, carryInBit: Bool) throws -> (IntegerType, [ARMConditionFlag: Bool]) {
            guard let value1 = value1, let value2 = value2 else { throw ARMInstructionExecutorError.missingValue }
            let result = value1 &+ value2 &+ (carryInBit ? 1 : 0)
            let lastBit = result.bitWidth-1
            let negativeFlag = result[lastBit] ?? false
            let zeroFlag = result == 0
            let carryFlag = value1[lastBit] != value2[lastBit] && result[lastBit] == false
            let overflowFlag = value1[lastBit] == value2[lastBit] && result[lastBit] != value1[lastBit]
            let flags = flagDict(n: negativeFlag, z: zeroFlag, c: carryFlag, v: overflowFlag)
            return (result,flags)
        }
        
        func negate<IntegerType: FixedWidthInteger>(value: IntegerType) -> IntegerType {
            ~value
        }
        
        func shift<ArgumentType: FixedWidthInteger, ShiftType: FixedWidthInteger, ReturnedType: FixedWidthInteger>(_ shift: ARMMnemonic.Shift?, value: ArgumentType?, shiftValue: ShiftType, conditionBit: Bool? = true) throws -> ReturnedType {
            guard let value = value else { throw ARMInstructionExecutorError.missingValue }
            let convertedValue = ReturnedType(truncatingIfNeeded: value)
            guard conditionBit ?? false else { return convertedValue }
            switch shift {
            case .LSL:
                return convertedValue << shiftValue
            case .LSR:
                return convertedValue >> shiftValue
            case .ASR:
                return (convertedValue >> shiftValue) | (convertedValue[ReturnedType.bitWidth-1] ?? false ? ReturnedType.ones.masked(including: ReturnedType.bitWidth-1..<ReturnedType.bitWidth) : 0)
            case .ROR:
                return (convertedValue >> shiftValue) | (convertedValue << (ReturnedType.bitWidth - Int(shiftValue)))
            default: throw ARMInstructionExecutorError.missingValue
            }
        }
        
        func merge<ArgumentType: FixedWidthInteger, ShiftType: FixedWidthInteger, ReturnedType: FixedWidthInteger>(value: ReturnedType?, with maskedValue: ArgumentType?, range: Range<Int>?, shiftedBy shiftValue: ShiftType? = nil) throws -> ReturnedType {
            guard let value = value, let maskedValue = maskedValue else { throw ARMInstructionExecutorError.missingValue }
            
            let rangeStartIndex = (range?.startIndex ?? 0) + Int(shiftValue ?? 0)
            let rangeEndIndex = (range?.endIndex ?? ReturnedType.bitWidth) + Int(shiftValue ?? 0)
            let maskRange = rangeStartIndex..<rangeEndIndex
            
            return value.masked(excluding: maskRange) | (ReturnedType(maskedValue) &<< maskRange)
        }
        
        func or<IntegerType: FixedWidthInteger>(value1: IntegerType?, value2: IntegerType?) throws -> (IntegerType, [ARMConditionFlag: Bool]) {
            guard let value1 = value1, let value2 = value2 else { throw ARMInstructionExecutorError.missingValue }
            let result = value1 | value2
            
            let negativeFlag = result[IntegerType.bitWidth-1] ?? false
            let zeroFlag = result == 0
            let flags = flagDict(n: negativeFlag, z: zeroFlag, c: false, v: false)
            return (result, flags)
        }
        
        func and<IntegerType: FixedWidthInteger>(value1: IntegerType?, value2: IntegerType?) throws -> (IntegerType, [ARMConditionFlag: Bool]) {
            guard let value1 = value1, let value2 = value2 else { throw ARMInstructionExecutorError.missingValue }
            let result = value1 & value2
            
            let negativeFlag = result[IntegerType.bitWidth-1] ?? false
            let zeroFlag = result == 0
            let flags = flagDict(n: negativeFlag, z: zeroFlag, c: false, v: false)
            return (result, flags)
        }
        
        func eor<IntegerType: FixedWidthInteger>(value1: IntegerType?, value2: IntegerType?) throws -> (IntegerType, [ARMConditionFlag: Bool]) {
            guard let value1 = value1, let value2 = value2 else { throw ARMInstructionExecutorError.missingValue }
            let result = value1 ^ value2
            
            let negativeFlag = result[IntegerType.bitWidth-1] ?? false
            let zeroFlag = result == 0
            let flags = flagDict(n: negativeFlag, z: zeroFlag, c: false, v: false)
            return (result, flags)
        }
        
        func check(condition: ARMMnemonic.Condition) -> Bool {
            guard let cpu = delegate else { return false }
            let flags = cpu.getFlags()
            let negative = flags[.negative] ?? false
            let zero = flags[.zero] ?? false
            let carry = flags[.carry] ?? false
            let overflow = flags[.overflow] ?? false
            
            switch condition {
            case .EQ:
                return zero
            case .NE:
                return !zero
            case .CS:
                return carry
            case .CC:
                return !carry
            case .MI:
                return negative
            case .PL:
                return !negative
            case .VS:
                return overflow
            case .VC:
                return !overflow
            case .HI:
                return (carry && !zero)
            case .LS:
                return (!carry || zero)
            case .GE:
                return (negative == overflow)
            case .LT:
                return (negative != overflow)
            case .GT:
                return (negative == overflow && !zero)
            case .LE:
                return (negative != overflow || zero)
            case .AL:
                return true
            case .NV:
                return false
            }
        }
        
        private func flagDict(n: Bool? = nil, z: Bool? = nil, c: Bool? = nil, v: Bool? = nil) -> [ARMConditionFlag: Bool] {
            [.negative: n,
             .zero: z,
             .carry: c,
             .overflow: v
            ].compactMapValues({ $0 })
        }
    }
}


protocol ARMInstructionExecutorDelegate: AnyObject {
    func read(at address: Address) throws -> UInt32
    func read(at address: Address) throws -> UInt64
    func write(value: UInt32, to address: Address) throws
    func write(value: UInt64, to address: Address) throws
    func store(value: UInt32, at register: ARMGeneralPurposeRegister.GP32) throws
    func store(value: UInt64, at register: ARMGeneralPurposeRegister.GP64) throws
    func getValue(from register: ARMGeneralPurposeRegister.GP32) throws -> UInt32
    func getValue(from register: ARMGeneralPurposeRegister.GP64) throws -> UInt64
    func getInstructionPointer() -> Address
    func updateInstructionPointer(to value: Address)
    func getFlag(flag: ARMConditionFlag) -> Bool
    func setFlag(flag: ARMConditionFlag, to value: Bool)
    func updateFlags(flags: [ARMConditionFlag:Bool])
    func getFlags() -> [ARMConditionFlag:Bool]
    func triggerSystemCall(syscallValue: UInt32?) throws
}

struct ARMInstructionExecutor {
    private var alu = ALU()
    weak var delegate: ARMInstructionExecutorDelegate? {
        didSet { alu.delegate = delegate }
    }
    
    func execute(instruction: ARMInstruction) throws {
        if let instruction = instruction as? ARMInstruction.DataProcessingImmediate {
            try executeDataProcessingImmediate(instruction: instruction)
        }
        else if let instruction = instruction as? ARMInstruction.BranchesExceptionAndSystem {
            try executeBranchesExceptionAndSystem(instruction: instruction)
        }
        else if let instruction = instruction as? ARMInstruction.LoadsAndStores {
            try executeLoadsAndStores(instruction: instruction)
        }
        else if let instruction = instruction as? ARMInstruction.DataProcessingRegister {
            try executeDataProcessingRegister(instruction: instruction)
        }
        else if let instruction = instruction as? ARMInstruction.DataProcessingFloatingAndSimd {
            try executeDataProcessingFloatingAndSimd(instruction: instruction)
        }
        else {
            throw ARMInstructionExecutorError.unsupportedInstruction
        }
    }
    
    private func executeDataProcessingImmediate(instruction: ARMInstruction.DataProcessingImmediate) throws {
        typealias InstructionType = ARMInstruction.DataProcessingImmediate
        if let instruction = instruction as? InstructionType.PCRelAddressing {
            try executePCRelAddressing(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AddSubtractImmediate {
            try executeAddSubtractImmediate(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AddSubtractImmediateWithTags {
            try executeAddSubtractImmediateWithTags(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.LogicalImmediate {
            try executeLogicalImmediate(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.MoveWideImmediate {
            try executeMoveWideImmediate(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.Bitfield {
            try executeBitfield(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.Extract {
            try executeExtract(instruction: instruction)
        } else {
            throw ARMInstructionExecutorError.unsupportedInstruction
        }
    }
    
    private func executeBranchesExceptionAndSystem(instruction: ARMInstruction.BranchesExceptionAndSystem) throws {
        typealias InstructionType = ARMInstruction.BranchesExceptionAndSystem
        if let instruction = instruction as? InstructionType.ConditionalBranchImmediate {
            try executeConditionalBranchImmediate(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.ExceptionGeneration {
            try executeExceptionGeneration(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.SystemInsturctionsWithRegister {
            try executeSystemInsturctionsWithRegister(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.Hints {
            try executeHints(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.Barriers {
            try executeBarriers(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.PSTATE {
            try executePSTATE(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.SystemInstruction {
            try executeSystemInstruction(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.SystemRegisterMove {
            try executeSystemRegisterMove(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.UnconditionalBranchRegister {
            try executeUnconditionalBranchRegister(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.UnconditionalBranchImmediate {
            try executeUnconditionalBranchImmediate(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.CompareAndBranchImmediate {
            try executeCompareAndBranchImmediate(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.TestAndBranchImmediate {
            try executeTestAndBranchImmediate(instruction: instruction)
        }
        else {
            throw ARMInstructionExecutorError.unsupportedInstruction
        }
    }
    
    private func executeLoadsAndStores(instruction: ARMInstruction.LoadsAndStores) throws {
        typealias InstructionType = ARMInstruction.LoadsAndStores
        if let instruction = instruction as? InstructionType.AdvancedSIMDLoadStoreMultipleStructures {
            try executeAdvancedSIMDLoadStoreMultipleStructures(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDLoadStoreMultipleStructuresPostIndexed {
            try executeAdvancedSIMDLoadStoreMultipleStructuresPostIndexed(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDLoadStoreSingleStructure {
            try executeAdvancedSIMDLoadStoreSingleStructure(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDLoadStoreSingleStructuresPostIndexed {
            try executeAdvancedSIMDLoadStoreSingleStructuresPostIndexed(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.LoadStoreMemoryTags {
            try executeLoadStoreMemoryTags(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.LoadStoreExclusive {
            try executeLoadStoreExclusive(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.LDAPRSTLR {
            try executeLDAPRSTLR(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.LoadRegisterLiteral {
            try executeLoadRegisterLiteral(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.LoadStoreNoAllocatePairOffset {
            try executeLoadStoreNoAllocatePairOffset(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.LoadStoreRegisterPairPostIndexed {
            try executeLoadStoreRegisterPairPostIndexed(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.LoadStoreRegisterPairOffset {
            try executeLoadStoreRegisterPairOffset(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.LoadStoreRegisterPairPreIndexed {
            try executeLoadStoreRegisterPairPreIndexed(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.LoadStoreRegisterUnscaledImmediate {
            try executeLoadStoreRegisterUnscaledImmediate(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.LoadStoreRegisterImmediatePostIndexed {
            try executeLoadStoreRegisterImmediatePostIndexed(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.LoadStoreRegisterUnprivileged {
            try executeLoadStoreRegisterUnprivileged(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.LoadStoreRegisterImmediatePreIndexed {
            try executeLoadStoreRegisterImmediatePreIndexed(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AtomicMemoryOperations {
            try executeAtomicMemoryOperations(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.LoadStoreRegisterRegisterOffset {
            try executeLoadStoreRegisterRegisterOffset(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.LoadStoreRegisterPAC {
            try executeLoadStoreRegisterPAC(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.LoadStoreRegisterUnsignedImmediate {
            try executeLoadStoreRegisterUnsignedImmediate(instruction: instruction)
        }
        else {
            throw ARMInstructionExecutorError.unsupportedInstruction
        }
    }
    
    private func executeDataProcessingRegister(instruction: ARMInstruction.DataProcessingRegister) throws {
        typealias InstructionType = ARMInstruction.DataProcessingRegister
        if let instruction = instruction as? InstructionType.DataProcesssing2Source {
            try executeDataProcesssing2Source(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.DataProcessing1Source {
            try executeDataProcessing1Source(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AddSubtractWithCarry {
            try executeAddSubtractWithCarry(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.RotateRightIntoFlags {
            try executeRotateRightIntoFlags(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.EvaluateIntoFlags {
            try executeEvaluateIntoFlags(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.ConditionalCompareRegister {
            try executeConditionalCompareRegister(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.ConditionalCompareImmediate {
            try executeConditionalCompareImmediate(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.ConditionalSelect {
            try executeConditionalSelect(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.DataProcessing3Source {
            try executeDataProcessing3Source(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.LogicalShiftedRegister {
            try executeLogicalShiftedRegister(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AddSubtractShiftedRegister {
            try executeAddSubtractShiftedRegister(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AddSubtractExtendedRegister {
            try executeAddSubtractExtendedRegister(instruction: instruction)
        }
        else {
            throw ARMInstructionExecutorError.unsupportedInstruction
        }
    }
    
    private func executeDataProcessingFloatingAndSimd(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        typealias InstructionType = ARMInstruction.DataProcessingFloatingAndSimd
        if let instruction = instruction as? InstructionType.CryptographicAES {
            try executeCryptographicAES(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.CryptographicThreeRegisterSHA {
            try executeCryptographicThreeRegisterSHA(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.CryptographicTwoRegisterSHA {
            try executeCryptographicTwoRegisterSHA(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDScalarCopy {
            try executeAdvancedSIMDScalarCopy(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDScalarThreeSameFP16 {
            try executeAdvancedSIMDScalarThreeSameFP16(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDScalarTwoRegisterMiscellaneousFP16 {
            try executeAdvancedSIMDScalarTwoRegisterMiscellaneousFP16(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDScalarThreeSameExtra {
            try executeAdvancedSIMDScalarThreeSameExtra(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDScalarTwoRegisterMiscellaneous {
            try executeAdvancedSIMDScalarTwoRegisterMiscellaneous(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDScalarPairwise {
            try executeAdvancedSIMDScalarPairwise(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDScalarThreeDifferent {
            try executeAdvancedSIMDScalarThreeDifferent(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDScalarThreeSame {
            try executeAdvancedSIMDScalarThreeSame(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDScalarShiftByImmediate {
            try executeAdvancedSIMDScalarShiftByImmediate(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDScalarXIndexedElement {
            try executeAdvancedSIMDScalarXIndexedElement(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDTableLookup {
            try executeAdvancedSIMDTableLookup(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDPermute {
            try executeAdvancedSIMDPermute(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDExtract {
            try executeAdvancedSIMDExtract(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDCopy {
            try executeAdvancedSIMDCopy(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDThreeSameFP16 {
            try executeAdvancedSIMDThreeSameFP16(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDTwoRegisterMiscellaneousFP16 {
            try executeAdvancedSIMDTwoRegisterMiscellaneousFP16(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDThreeRegisterExtension {
            try executeAdvancedSIMDThreeRegisterExtension(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDTwoRegisterMiscellaneous {
            try executeAdvancedSIMDTwoRegisterMiscellaneous(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDAcrossLanes {
            try executeAdvancedSIMDAcrossLanes(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDThreeDifferent {
            try executeAdvancedSIMDThreeDifferent(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDThreeSame {
            try executeAdvancedSIMDThreeSame(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDModifiedImmediate {
            try executeAdvancedSIMDModifiedImmediate(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDShiftByImmediate {
            try executeAdvancedSIMDShiftByImmediate(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.AdvancedSIMDVectorXIndexedElement {
            try executeAdvancedSIMDVectorXIndexedElement(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.CryptographicThreeRegisterImm2 {
            try executeCryptographicThreeRegisterImm2(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.CryptographicThreeRegisterSHA512 {
            try executeCryptographicThreeRegisterSHA512(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.CryptographicFourRegister {
            try executeCryptographicFourRegister(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.XAR {
            try executeXAR(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.CryptographicTwoRegisterSHA512 {
            try executeCryptographicTwoRegisterSHA512(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.ConversionBetweenFloatingPointAndFixedPoint {
            try executeConversionBetweenFloatingPointAndFixedPoint(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.ConversionBetweenFloatingPointAndInteger {
            try executeConversionBetweenFloatingPointAndInteger(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.FloatingPointDataProcessing1Source {
            try executeFloatingPointDataProcessing1Source(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.FloatingPointCompare {
            try executeFloatingPointCompare(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.FloatingPointImmediate {
            try executeFloatingPointImmediate(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.FloatingPointConditionalCompare {
            try executeFloatingPointConditionalCompare(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.FloatingPointDataProcessing2Source {
            try executeFloatingPointDataProcessing2Source(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.FloatingPointConditionalSelect {
            try executeFloatingPointConditionalSelect(instruction: instruction)
        }
        else if let instruction = instruction as? InstructionType.FloatingPointDataProcessing3source {
            try executeFloatingPointDataProcessing3source(instruction: instruction)
        }
        else {
            throw ARMInstructionExecutorError.unsupportedInstruction
        }
    }
}

// MARK: - DataProcessingImmediate
extension ARMInstructionExecutor {
    func executePCRelAddressing(instruction: ARMInstruction.DataProcessingImmediate.PCRelAddressing) throws {
        guard let cpu = delegate else { return }
        guard let destination = instruction.rd as? ARMGeneralPurposeRegister.GP64 else {
            throw ARMInstructionExecutorError.missingValue
        }
        switch instruction.mnemonic {
        case .ADR:
            let ip = cpu.getInstructionPointer()
            let addressOffset = instruction.address ?? 0
            let newValue = addressOffset >= 0 ? ip + UInt64(addressOffset) : ip - UInt64(-addressOffset)
            try cpu.store(value: newValue, at: destination)
        case .ADRP:
            let ip = cpu.getInstructionPointer()
            let pageAddress: UInt64 = (ip &>> 12) &<< 12
            let addressOffset = instruction.address ?? 0
            let newValue = addressOffset >= 0 ? pageAddress + UInt64(addressOffset) : pageAddress - UInt64(-addressOffset)
            try cpu.store(value: newValue, at: destination)
        default: throw ARMInstructionExecutorError.unsupportedInstruction
        }
    }
    func executeAddSubtractImmediate(instruction: ARMInstruction.DataProcessingImmediate.AddSubtractImmediate) throws {
        guard let cpu = delegate else { return }
        switch instruction.mode {
        case .x64:
            guard
                let register = instruction.rn as? ARMGeneralPurposeRegister.GP64,
                let destination = instruction.rd as? ARMGeneralPurposeRegister.GP64
            else {
                throw ARMInstructionExecutorError.wrongRegister
            }
            let value1: UInt64 = try cpu.getValue(from: register)
            let value2: UInt64 = try alu.shift(.LSL, value: instruction.imm12, shiftValue: 12, conditionBit: instruction.sh?.asBool)
            switch instruction.mnemonic {
            case .ADD, .MOV:
                let (result,_) = try alu.addWithCarry(value1: value1, value2: value2, carryInBit: false)
                try cpu.store(value: result, at: destination)
            case .SUB:
                let negativeValue2 = alu.negate(value: value2)
                let (result,_) = try alu.addWithCarry(value1: value1, value2: negativeValue2, carryInBit: true)
                try cpu.store(value: result, at: destination)
            case .ADDS:
                let (result,flags) = try alu.addWithCarry(value1: value1, value2: value2, carryInBit: false)
                cpu.updateFlags(flags: flags)
                guard destination.value != ARMGeneralPurposeRegister.GP64.xzr.value else { return }
                try cpu.store(value: result, at: destination)
            case .SUBS:
                let negativeValue2 = alu.negate(value: value2)
                let (result,flags) = try alu.addWithCarry(value1: value1, value2: negativeValue2, carryInBit: true)
                cpu.updateFlags(flags: flags)
                guard destination.value != ARMGeneralPurposeRegister.GP64.xzr.value else { return }
                try cpu.store(value: result, at: destination)
            case .CMN:
                let (_,flags) = try alu.addWithCarry(value1: value1, value2: value2, carryInBit: false)
                cpu.updateFlags(flags: flags)
            case .CMP:
                let negativeValue2 = alu.negate(value: value2)
                let (_,flags) = try alu.addWithCarry(value1: value1, value2: negativeValue2, carryInBit: true)
                cpu.updateFlags(flags: flags)
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
        case .w32:
            guard
                let register = instruction.rn as? ARMGeneralPurposeRegister.GP32,
                let destination = instruction.rd as? ARMGeneralPurposeRegister.GP32
            else {
                throw ARMInstructionExecutorError.wrongRegister
            }
            let value1: UInt32 = try cpu.getValue(from: register)
            let value2: UInt32 = try alu.shift(.LSL, value: instruction.imm12, shiftValue: 12, conditionBit: instruction.sh?.asBool)
            switch instruction.mnemonic {
            case .ADD, .MOV:
                let (result,_) = try alu.addWithCarry(value1: value1, value2: value2, carryInBit: false)
                try cpu.store(value: result, at: destination)
            case .SUB:
                let negativeValue2 = alu.negate(value: value2)
                let (result,_) = try alu.addWithCarry(value1: value1, value2: negativeValue2, carryInBit: true)
                try cpu.store(value: result, at: destination)
            case .ADDS:
                let (result,flags) = try alu.addWithCarry(value1: value1, value2: value2, carryInBit: false)
                cpu.updateFlags(flags: flags)
                guard destination.value != ARMGeneralPurposeRegister.GP64.xzr.value else { return }
                try cpu.store(value: result, at:
                                destination)
            case .SUBS:
                let negativeValue2 = alu.negate(value: value2)
                let (result,flags) = try alu.addWithCarry(value1: value1, value2: negativeValue2, carryInBit: true)
                cpu.updateFlags(flags: flags)
                guard destination.value != ARMGeneralPurposeRegister.GP64.xzr.value else { return }
                try cpu.store(value: result, at: destination)
            case .CMN:
                let (_,flags) = try alu.addWithCarry(value1: value1, value2: value2, carryInBit: false)
                cpu.updateFlags(flags: flags)
            case .CMP:
                let negativeValue2 = alu.negate(value: value2)
                let (_,flags) = try alu.addWithCarry(value1: value1, value2: negativeValue2, carryInBit: true)
                cpu.updateFlags(flags: flags)
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
        default: throw ARMInstructionExecutorError.missingValue
        }
    }
    func executeAddSubtractImmediateWithTags(instruction: ARMInstruction.DataProcessingImmediate.AddSubtractImmediateWithTags) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeLogicalImmediate(instruction: ARMInstruction.DataProcessingImmediate.LogicalImmediate) throws {
        guard let cpu = delegate else { return }
        switch instruction.mode {
        case .x64:
            guard
                let source = instruction.rn as? ARMGeneralPurposeRegister.GP64,
                let destination = instruction.rd as? ARMGeneralPurposeRegister.GP64,
                let immediate = instruction.immediate
            else { throw ARMInstructionExecutorError.missingValue }
            switch instruction.mnemonic {
            case .ORR:
                let value1 = try cpu.getValue(from: source)
                let (newValue,_) = try alu.or(value1: value1, value2: immediate)
                try cpu.store(value: newValue, at: destination)
            case .MOV:
                try cpu.store(value: immediate, at: destination)
            case .EOR:
                let value1 = try cpu.getValue(from: source)
                let (newValue,_) = try alu.eor(value1: value1, value2: immediate)
                try cpu.store(value: newValue, at: destination)
            case .AND:
                let value1 = try cpu.getValue(from: source)
                let (newValue,_) = try alu.and(value1: value1, value2: immediate)
                try cpu.store(value: newValue, at: destination)
            case .ANDS:
                let value1 = try cpu.getValue(from: source)
                let (newValue,flags) = try alu.and(value1: value1, value2: immediate)
                cpu.updateFlags(flags: flags)
                try cpu.store(value: newValue, at: destination)
            case .TST:
                let value1 = try cpu.getValue(from: source)
                let (_,flags) = try alu.and(value1: value1, value2: immediate)
                cpu.updateFlags(flags: flags)
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
        case .w32:
            guard
                let source = instruction.rn as? ARMGeneralPurposeRegister.GP32,
                let destination = instruction.rd as? ARMGeneralPurposeRegister.GP32,
                let immediate = instruction.immediate
            else { throw ARMInstructionExecutorError.missingValue }
            switch instruction.mnemonic {
            case .ORR:
                let value1 = try cpu.getValue(from: source)
                let (newValue,_) = try alu.or(value1: value1, value2: UInt32(immediate))
                try cpu.store(value: newValue, at: destination)
            case .MOV:
                let newValue = UInt32(instruction.immediate ?? 0)
                try cpu.store(value: newValue, at: destination)
            case .EOR:
                let value1 = try cpu.getValue(from: source)
                let (newValue,_) = try alu.eor(value1: value1, value2: UInt32(immediate))
                try cpu.store(value: newValue, at: destination)
            case .AND:
                let value1 = try cpu.getValue(from: source)
                let (newValue,_) = try alu.and(value1: value1, value2: UInt32(immediate))
                try cpu.store(value: newValue, at: destination)
            case .ANDS:
                let value1 = try cpu.getValue(from: source)
                let (newValue,flags) = try alu.and(value1: value1, value2: UInt32(immediate))
                cpu.updateFlags(flags: flags)
                try cpu.store(value: newValue, at: destination)
            case .TST:
                let value1 = try cpu.getValue(from: source)
                let (_,flags) = try alu.and(value1: value1, value2: UInt32(immediate))
                cpu.updateFlags(flags: flags)
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
        default: throw ARMInstructionExecutorError.missingValue
        }
    }
    func executeMoveWideImmediate(instruction: ARMInstruction.DataProcessingImmediate.MoveWideImmediate) throws {
        guard let cpu = delegate else { return }
        guard instruction.hw ?? 0 <= 48, (instruction.hw ?? 0) % 16 == 0 else { throw ARMInstructionExecutorError.unsupportedShiftValue }
        switch instruction.mode {
        case .x64:
            guard let destinationRegister = instruction.rd as? ARMGeneralPurposeRegister.GP64 else {
                throw ARMInstructionExecutorError.wrongRegister
            }
            switch instruction.mnemonic {
            case .MOVZ:
                let shiftedValue: UInt64 = try alu.shift(.LSL, value: instruction.imm16, shiftValue: instruction.hw ?? 0)
                try cpu.store(value: shiftedValue, at: destinationRegister)
            case .MOV:
                let shiftedValue: UInt64 = try alu.shift(.LSL, value: instruction.immediate, shiftValue: 0)
                try cpu.store(value: shiftedValue, at: destinationRegister)
            case .MOVK:
                let registerValue = try cpu.getValue(from: destinationRegister)
                let newValue: UInt64 = try alu.merge(value: registerValue, with: instruction.imm16, range: 0..<16, shiftedBy: instruction.hw)
                try cpu.store(value: newValue, at: destinationRegister)
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
        case .w32:
            guard let destinationRegister = instruction.rd as? ARMGeneralPurposeRegister.GP32 else {
                throw ARMInstructionExecutorError.wrongRegister
            }
            switch instruction.mnemonic {
            case .MOVZ:
                let shiftedValue: UInt32 = try alu.shift(.LSL, value: instruction.imm16, shiftValue: instruction.hw ?? 0)
                try cpu.store(value: shiftedValue, at: destinationRegister)
            case .MOV:
                let shiftedValue: UInt32 = try alu.shift(.LSL, value: instruction.immediate, shiftValue: 0)
                try cpu.store(value: shiftedValue, at: destinationRegister)
            case .MOVK:
                let registerValue = try cpu.getValue(from: destinationRegister)
                let newValue: UInt32 = try alu.merge(value: registerValue, with: instruction.imm16, range: 0..<16, shiftedBy: instruction.hw)
                try cpu.store(value: newValue, at: destinationRegister)
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
        default: throw ARMInstructionExecutorError.missingValue
        }
    }
    func executeBitfield(instruction: ARMInstruction.DataProcessingImmediate.Bitfield) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeExtract(instruction: ARMInstruction.DataProcessingImmediate.Extract) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
}

// MARK: - BranchesExceptionAndSystem
extension ARMInstructionExecutor {
    func executeConditionalBranchImmediate(instruction: ARMInstruction.BranchesExceptionAndSystem.ConditionalBranchImmediate) throws {
        guard let cpu = delegate else { return }
        switch instruction.mnemonic {
        case .B:
            let condition = instruction.cond ?? .EQ
            if alu.check(condition: condition) {
                let ip = cpu.getInstructionPointer()
                let offset = instruction.address ?? 0
                let convertedOffset = UInt64(abs(offset))
                let address = offset > 0 ? ip + convertedOffset : ip - convertedOffset
                cpu.updateInstructionPointer(to: address)
            }
        default: throw ARMInstructionExecutorError.unsupportedInstruction
        }
    }
    func executeExceptionGeneration(instruction: ARMInstruction.BranchesExceptionAndSystem.ExceptionGeneration) throws {
        guard let cpu = delegate else { return }
        switch instruction.mnemonic {
        case .SVC:
            let syscallNumebr = try cpu.getValue(from: .x16)
            try cpu.triggerSystemCall(syscallValue: UInt32(syscallNumebr))
        default: throw ARMInstructionExecutorError.unsupportedInstruction
        }
    }
    func executeSystemInsturctionsWithRegister(instruction: ARMInstruction.BranchesExceptionAndSystem.SystemInsturctionsWithRegister) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeHints(instruction: ARMInstruction.BranchesExceptionAndSystem.Hints) throws {
        switch instruction.mnemonic {
        case .NOP: return
        default: throw ARMInstructionExecutorError.unsupportedInstruction
        }
    }
    func executeBarriers(instruction: ARMInstruction.BranchesExceptionAndSystem.Barriers) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executePSTATE(instruction: ARMInstruction.BranchesExceptionAndSystem.PSTATE) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeSystemInstruction(instruction: ARMInstruction.BranchesExceptionAndSystem.SystemInstruction) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeSystemRegisterMove(instruction: ARMInstruction.BranchesExceptionAndSystem.SystemRegisterMove) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeUnconditionalBranchRegister(instruction: ARMInstruction.BranchesExceptionAndSystem.UnconditionalBranchRegister) throws {
        guard let cpu = delegate else { return }
        switch instruction.mnemonic {
        case .RET:
            let register = instruction.rn as? ARMGeneralPurposeRegister.GP64 ?? .x30
            let address = try cpu.getValue(from: register)
            cpu.updateInstructionPointer(to: address)
        default: throw ARMInstructionExecutorError.unsupportedInstruction
        }
    }
    func executeUnconditionalBranchImmediate(instruction: ARMInstruction.BranchesExceptionAndSystem.UnconditionalBranchImmediate) throws {
        guard let cpu = delegate else { return }
        switch instruction.mnemonic {
        case .BL:
            let ip = cpu.getInstructionPointer()
            let offset = instruction.address ?? 0
            let convertedOffset = UInt64(abs(offset))
            let address = offset > 0 ? ip + convertedOffset : ip - convertedOffset
            try cpu.store(value: ip + 4, at: .x30)
            cpu.updateInstructionPointer(to: address)
        case .B:
            let ip = cpu.getInstructionPointer()
            let offset = instruction.address ?? 0
            let convertedOffset = UInt64(abs(offset))
            let address = offset > 0 ? ip + convertedOffset : ip - convertedOffset
            cpu.updateInstructionPointer(to: address)
        default: throw ARMInstructionExecutorError.unsupportedInstruction
        }
    }
    func executeCompareAndBranchImmediate(instruction: ARMInstruction.BranchesExceptionAndSystem.CompareAndBranchImmediate) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeTestAndBranchImmediate(instruction: ARMInstruction.BranchesExceptionAndSystem.TestAndBranchImmediate) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
}

// MARK: - LoadsAndStores
extension ARMInstructionExecutor {
    func executeAdvancedSIMDLoadStoreMultipleStructures(instruction: ARMInstruction.LoadsAndStores.AdvancedSIMDLoadStoreMultipleStructures) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDLoadStoreMultipleStructuresPostIndexed(instruction: ARMInstruction.LoadsAndStores.AdvancedSIMDLoadStoreMultipleStructuresPostIndexed) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDLoadStoreSingleStructure(instruction: ARMInstruction.LoadsAndStores.AdvancedSIMDLoadStoreSingleStructure) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDLoadStoreSingleStructuresPostIndexed(instruction: ARMInstruction.LoadsAndStores.AdvancedSIMDLoadStoreSingleStructuresPostIndexed) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeLoadStoreMemoryTags(instruction: ARMInstruction.LoadsAndStores.LoadStoreMemoryTags) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeLoadStoreExclusive(instruction: ARMInstruction.LoadsAndStores.LoadStoreExclusive) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeLDAPRSTLR(instruction: ARMInstruction.LoadsAndStores.LDAPRSTLR) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeLoadRegisterLiteral(instruction: ARMInstruction.LoadsAndStores.LoadRegisterLiteral) throws {
        guard let cpu = delegate else { return }
        switch instruction.mode {
        case .x64:
            guard let register = instruction.rt as? ARMGeneralPurposeRegister.GP64 else { throw ARMInstructionExecutorError.wrongRegister }
            switch instruction.mnemonic {
            case .LDR:
                let ip = cpu.getInstructionPointer()
                let addressOffset = instruction.address ?? 0
                let convertedOffset = UInt64(addressOffset)
                let address = addressOffset >= 0 ? ip + convertedOffset : ip - convertedOffset
                let value: UInt64 = try cpu.read(at: address)
                try cpu.store(value: value, at: register)
                return
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
        case .w32:
            guard let register = instruction.rt as? ARMGeneralPurposeRegister.GP32 else { throw ARMInstructionExecutorError.wrongRegister }
            switch instruction.mnemonic {
            case .LDR:
                let ip = cpu.getInstructionPointer()
                let addressOffset = instruction.address ?? 0
                let convertedOffset = UInt64(addressOffset)
                let address = addressOffset >= 0 ? ip + convertedOffset : ip - convertedOffset
                let value: UInt32 = try cpu.read(at: address)
                try cpu.store(value: value, at: register)
                return
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
        default: throw ARMInstructionExecutorError.missingValue
        }
    }
    func executeLoadStoreNoAllocatePairOffset(instruction: ARMInstruction.LoadsAndStores.LoadStoreNoAllocatePairOffset) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeLoadStoreRegisterPairPostIndexed(instruction: ARMInstruction.LoadsAndStores.LoadStoreRegisterPairPostIndexed) throws {
        guard let cpu = delegate else { return }
        switch instruction.mode {
        case .x64:
            guard
                let destination1 = instruction.rt as? ARMGeneralPurposeRegister.GP64,
                let destination2 = instruction.rt2 as? ARMGeneralPurposeRegister.GP64,
                let source = instruction.rn as? ARMGeneralPurposeRegister.GP64
            else { throw ARMInstructionExecutorError.wrongRegister }
            switch instruction.mnemonic {
            case .LDP:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm7 ?? 0
                let convertedIndex = UInt64(abs(index))
                let newAddressValue = index >= 0 ? address + convertedIndex : address - convertedIndex
                try cpu.store(value: newAddressValue, at: source)
                
                let value1: UInt64 = try cpu.read(at: address)
                try cpu.store(value: value1, at: destination1)
                
                let value2: UInt64 = try cpu.read(at: address + 8)
                try cpu.store(value: value2, at: destination2)
            case .STP:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm7 ?? 0
                let convertedIndex = UInt64(abs(index))
                let newAddressValue = index >= 0 ? address + convertedIndex : address - convertedIndex
                try cpu.store(value: newAddressValue, at: source)
                
                let value1: UInt64 = try cpu.getValue(from: destination1)
                try cpu.write(value: value1, to: address)
                
                let value2: UInt64 = try cpu.getValue(from: destination2)
                try cpu.write(value: value2, to: address + 8)
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
        case .w32:
            guard
                let destination1 = instruction.rt as? ARMGeneralPurposeRegister.GP32,
                let destination2 = instruction.rt2 as? ARMGeneralPurposeRegister.GP32,
                let source = instruction.rn as? ARMGeneralPurposeRegister.GP64
            else { throw ARMInstructionExecutorError.wrongRegister }
            switch instruction.mnemonic {
            case .LDP:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm7 ?? 0
                let convertedIndex = UInt64(abs(index))
                let newAddressValue = index >= 0 ? address + convertedIndex : address - convertedIndex
                try cpu.store(value: newAddressValue, at: source)
                
                let value1: UInt32 = try cpu.read(at: address)
                try cpu.store(value: value1, at: destination1)
                
                let value2: UInt32 = try cpu.read(at: address + 4)
                try cpu.store(value: value2, at: destination2)
            case .STP:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm7 ?? 0
                let convertedIndex = UInt64(abs(index))
                let newAddressValue = index >= 0 ? address + convertedIndex : address - convertedIndex
                try cpu.store(value: newAddressValue, at: source)
                
                let value1: UInt32 = try cpu.getValue(from: destination1)
                try cpu.write(value: value1, to: address)
                
                let value2: UInt32 = try cpu.getValue(from: destination2)
                try cpu.write(value: value2, to: address + 4)
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
        default: throw ARMInstructionExecutorError.missingValue
        }
    }
    func executeLoadStoreRegisterPairOffset(instruction: ARMInstruction.LoadsAndStores.LoadStoreRegisterPairOffset) throws {
        guard let cpu = delegate else { return }
        switch instruction.mode {
        case .x64:
            guard
                let destination1 = instruction.rt as? ARMGeneralPurposeRegister.GP64,
                let destination2 = instruction.rt2 as? ARMGeneralPurposeRegister.GP64,
                let source = instruction.rn as? ARMGeneralPurposeRegister.GP64
            else { throw ARMInstructionExecutorError.wrongRegister }
            switch instruction.mnemonic {
            case .LDP:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm7 ?? 0
                let convertedIndex = UInt64(abs(index))
                let newAddressValue = index >= 0 ? address + convertedIndex : address - convertedIndex
                
                let value1: UInt64 = try cpu.read(at: newAddressValue)
                try cpu.store(value: value1, at: destination1)
                let value2: UInt64 = try cpu.read(at: newAddressValue + 8)
                try cpu.store(value: value2, at: destination2)
            case .STP:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm7 ?? 0
                let convertedIndex = UInt64(abs(index))
                let newAddressValue = index >= 0 ? address + convertedIndex : address - convertedIndex
                
                let value1: UInt64 = try cpu.getValue(from: destination1)
                try cpu.write(value: value1, to: newAddressValue)
                let value2: UInt64 = try cpu.getValue(from: destination2)
                try cpu.write(value: value2, to: newAddressValue + 8)
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
        case .w32:
            guard
                let destination1 = instruction.rt as? ARMGeneralPurposeRegister.GP32,
                let destination2 = instruction.rt2 as? ARMGeneralPurposeRegister.GP32,
                let source = instruction.rn as? ARMGeneralPurposeRegister.GP64
            else { throw ARMInstructionExecutorError.wrongRegister }
            switch instruction.mnemonic {
            case .LDP:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm7 ?? 0
                let convertedIndex = UInt64(abs(index))
                let newAddressValue = index >= 0 ? address + convertedIndex : address - convertedIndex
                
                let value1: UInt32 = try cpu.read(at: newAddressValue)
                try cpu.store(value: value1, at: destination1)
                let value2: UInt32 = try cpu.read(at: newAddressValue + 4)
                try cpu.store(value: value2, at: destination2)
            case .STP:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm7 ?? 0
                let convertedIndex = UInt64(abs(index))
                let newAddressValue = index >= 0 ? address + convertedIndex : address - convertedIndex
                
                let value1: UInt32 = try cpu.getValue(from: destination1)
                try cpu.write(value: value1, to: newAddressValue)
                let value2: UInt32 = try cpu.getValue(from: destination2)
                try cpu.write(value: value2, to: newAddressValue + 4)
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
        default: throw ARMInstructionExecutorError.missingValue
        }
    }
    func executeLoadStoreRegisterPairPreIndexed(instruction: ARMInstruction.LoadsAndStores.LoadStoreRegisterPairPreIndexed) throws {
        guard let cpu = delegate else { return }
        switch instruction.mode {
        case .x64:
            guard
                let destination1 = instruction.rt as? ARMGeneralPurposeRegister.GP64,
                let destination2 = instruction.rt2 as? ARMGeneralPurposeRegister.GP64,
                let source = instruction.rn as? ARMGeneralPurposeRegister.GP64
            else { throw ARMInstructionExecutorError.wrongRegister }
            switch instruction.mnemonic {
            case .LDP:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm7 ?? 0
                let convertedIndex = UInt64(abs(index))
                let newAddressValue = index >= 0 ? address &+ convertedIndex : address &- convertedIndex
                try cpu.store(value: newAddressValue, at: source)
                
                let value1: UInt64 = try cpu.read(at: newAddressValue)
                try cpu.store(value: value1, at: destination1)
                
                let value2: UInt64 = try cpu.read(at: newAddressValue + 8)
                try cpu.store(value: value2, at: destination2)
            case .STP:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm7 ?? 0
                let convertedIndex = UInt64(abs(index))
                let newAddressValue = index >= 0 ? address &+ convertedIndex : address &- convertedIndex
                try cpu.store(value: newAddressValue, at: source)
                
                let value1: UInt64 = try cpu.getValue(from: destination1)
                try cpu.write(value: value1, to: newAddressValue)
                
                let value2: UInt64 = try cpu.getValue(from: destination2)
                try cpu.write(value: value2, to: newAddressValue + 8)
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
        case .w32:
            guard
                let destination1 = instruction.rt as? ARMGeneralPurposeRegister.GP32,
                let destination2 = instruction.rt2 as? ARMGeneralPurposeRegister.GP32,
                let source = instruction.rn as? ARMGeneralPurposeRegister.GP64
            else { throw ARMInstructionExecutorError.wrongRegister }
            switch instruction.mnemonic {
            case .LDP:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm7 ?? 0
                let convertedIndex = UInt64(abs(index))
                let newAddressValue = index >= 0 ? address &+ convertedIndex : address &- convertedIndex
                try cpu.store(value: newAddressValue, at: source)
                
                let value1: UInt32 = try cpu.read(at: newAddressValue)
                try cpu.store(value: value1, at: destination1)
                
                let value2: UInt32 = try cpu.read(at: newAddressValue + 4)
                try cpu.store(value: value2, at: destination2)
            case .STP:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm7 ?? 0
                let convertedIndex = UInt64(abs(index))
                let newAddressValue = index >= 0 ? address &+ convertedIndex : address &- convertedIndex
                try cpu.store(value: newAddressValue, at: source)
                
                let value1: UInt32 = try cpu.getValue(from: destination1)
                try cpu.write(value: value1, to: newAddressValue)
                
                let value2: UInt32 = try cpu.getValue(from: destination2)
                try cpu.write(value: value2, to: newAddressValue + 4)
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
        default: throw ARMInstructionExecutorError.missingValue
        }
    }
    func executeLoadStoreRegisterUnscaledImmediate(instruction: ARMInstruction.LoadsAndStores.LoadStoreRegisterUnscaledImmediate) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeLoadStoreRegisterImmediatePostIndexed(instruction: ARMInstruction.LoadsAndStores.LoadStoreRegisterImmediatePostIndexed) throws {
        guard let cpu = delegate else { return }
        switch instruction.mode {
        case .x64:
            guard
                let destination = instruction.rt as? ARMGeneralPurposeRegister.GP64,
                let source = instruction.rn as? ARMGeneralPurposeRegister.GP64
            else { throw ARMInstructionExecutorError.wrongRegister }
            switch instruction.mnemonic {
            case .LDR:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm9 ?? 0
                let convertedIndex = UInt64(abs(index))
                let newAddressValue = index >= 0 ? address + convertedIndex : address - convertedIndex
                try cpu.store(value: newAddressValue, at: source)
                let value: UInt64 = try cpu.read(at: address)
                try cpu.store(value: value, at: destination)
            case .STR:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm9 ?? 0
                let convertedIndex = UInt64(abs(index))
                let newAddressValue = index >= 0 ? address + convertedIndex : address - convertedIndex
                try cpu.store(value: newAddressValue, at: source)
                let value: UInt64 = try cpu.getValue(from: destination)
                try cpu.write(value: value, to: address)
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
            break
        case .w32:
            guard
                let destination = instruction.rt as? ARMGeneralPurposeRegister.GP32,
                let source = instruction.rn as? ARMGeneralPurposeRegister.GP64
            else { throw ARMInstructionExecutorError.wrongRegister }
            switch instruction.mnemonic {
            case .LDR:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm9 ?? 0
                let convertedIndex = UInt64(abs(index))
                let newAddressValue = index >= 0 ? address + convertedIndex : address - convertedIndex
                try cpu.store(value: newAddressValue, at: source)
                let value: UInt32 = try cpu.read(at: address)
                try cpu.store(value: value, at: destination)
            case .STR:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm9 ?? 0
                let convertedIndex = UInt64(abs(index))
                let newAddressValue = index >= 0 ? address + convertedIndex : address - convertedIndex
                try cpu.store(value: newAddressValue, at: source)
                let value: UInt32 = try cpu.getValue(from: destination)
                try cpu.write(value: value, to: address)
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
            break
        default: throw ARMInstructionExecutorError.missingValue
        }
    }
    func executeLoadStoreRegisterUnprivileged(instruction: ARMInstruction.LoadsAndStores.LoadStoreRegisterUnprivileged) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeLoadStoreRegisterImmediatePreIndexed(instruction: ARMInstruction.LoadsAndStores.LoadStoreRegisterImmediatePreIndexed) throws {
        guard let cpu = delegate else { return }
        switch instruction.mode {
        case .x64:
            guard
                let destination = instruction.rt as? ARMGeneralPurposeRegister.GP64,
                let source = instruction.rn as? ARMGeneralPurposeRegister.GP64
            else { throw ARMInstructionExecutorError.wrongRegister }
            switch instruction.mnemonic {
            case .LDR:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm9 ?? 0
                let convertedIndex = UInt64(abs(index))
                let newAddressValue = index >= 0 ? address + convertedIndex : address - convertedIndex
                try cpu.store(value: newAddressValue, at: source)
                let value: UInt64 = try cpu.read(at: newAddressValue)
                try cpu.store(value: value, at: destination)
            case .STR:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm9 ?? 0
                let convertedIndex = UInt64(abs(index))
                let newAddressValue = index >= 0 ? address + convertedIndex : address - convertedIndex
                try cpu.store(value: newAddressValue, at: source)
                let value: UInt64 = try cpu.getValue(from: destination)
                try cpu.write(value: value, to: newAddressValue)
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
            break
        case .w32:
            guard
                let destination = instruction.rt as? ARMGeneralPurposeRegister.GP32,
                let source = instruction.rn as? ARMGeneralPurposeRegister.GP64
            else { throw ARMInstructionExecutorError.wrongRegister }
            switch instruction.mnemonic {
            case .LDR:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm9 ?? 0
                let convertedIndex = UInt64(abs(index))
                let newAddressValue = index >= 0 ? address + convertedIndex : address - convertedIndex
                try cpu.store(value: newAddressValue, at: source)
                let value: UInt32 = try cpu.read(at: newAddressValue)
                try cpu.store(value: value, at: destination)
            case .STR:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm9 ?? 0
                let convertedIndex = UInt64(abs(index))
                let newAddressValue = index >= 0 ? address + convertedIndex : address - convertedIndex
                try cpu.store(value: newAddressValue, at: source)
                let value: UInt32 = try cpu.getValue(from: destination)
                try cpu.write(value: value, to: newAddressValue)
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
            break
        default: throw ARMInstructionExecutorError.missingValue
        }
    }
    func executeAtomicMemoryOperations(instruction: ARMInstruction.LoadsAndStores.AtomicMemoryOperations) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeLoadStoreRegisterRegisterOffset(instruction: ARMInstruction.LoadsAndStores.LoadStoreRegisterRegisterOffset) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeLoadStoreRegisterPAC(instruction: ARMInstruction.LoadsAndStores.LoadStoreRegisterPAC) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeLoadStoreRegisterUnsignedImmediate(instruction: ARMInstruction.LoadsAndStores.LoadStoreRegisterUnsignedImmediate) throws {
        guard let cpu = delegate else { return }
        switch instruction.mode {
        case .x64:
            guard
                let destination = instruction.rt as? ARMGeneralPurposeRegister.GP64,
                let source = instruction.rn as? ARMGeneralPurposeRegister.GP64
            else { throw ARMInstructionExecutorError.wrongRegister }
            switch instruction.mnemonic {
            case .LDR:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm12 ?? 0
                let convertedIndex = UInt64(index)
                let newAddressValue = address + convertedIndex
                let value: UInt64 = try cpu.read(at: newAddressValue)
                try cpu.store(value: value, at: destination)
            case .STR:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm12 ?? 0
                let convertedIndex = UInt64(index)
                let newAddressValue = address + convertedIndex
                let value: UInt64 = try cpu.getValue(from: destination)
                try cpu.write(value: value, to: newAddressValue)
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
            break
        case .w32:
            guard
                let destination = instruction.rt as? ARMGeneralPurposeRegister.GP32,
                let source = instruction.rn as? ARMGeneralPurposeRegister.GP64
            else { throw ARMInstructionExecutorError.wrongRegister }
            switch instruction.mnemonic {
            case .LDR:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm12 ?? 0
                let convertedIndex = UInt64(index)
                let newAddressValue = address + convertedIndex
                let value: UInt32 = try cpu.read(at: newAddressValue)
                try cpu.store(value: value, at: destination)
            case .STR:
                let address = try cpu.getValue(from: source)
                let index = instruction.imm12 ?? 0
                let convertedIndex = UInt64(index)
                let newAddressValue = address + convertedIndex
                let value: UInt32 = try cpu.getValue(from: destination)
                try cpu.write(value: value, to: newAddressValue)
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
            break
        default: throw ARMInstructionExecutorError.missingValue
        }
    }
}

// MARK: - DataProcessingRegister
extension ARMInstructionExecutor {
    func executeDataProcesssing2Source(instruction: ARMInstruction.DataProcessingRegister.DataProcesssing2Source) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeDataProcessing1Source(instruction: ARMInstruction.DataProcessingRegister.DataProcessing1Source) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAddSubtractWithCarry(instruction: ARMInstruction.DataProcessingRegister.AddSubtractWithCarry) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeRotateRightIntoFlags(instruction: ARMInstruction.DataProcessingRegister.RotateRightIntoFlags) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeEvaluateIntoFlags(instruction: ARMInstruction.DataProcessingRegister.EvaluateIntoFlags) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeConditionalCompareRegister(instruction: ARMInstruction.DataProcessingRegister.ConditionalCompareRegister) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeConditionalCompareImmediate(instruction: ARMInstruction.DataProcessingRegister.ConditionalCompareImmediate) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeConditionalSelect(instruction: ARMInstruction.DataProcessingRegister.ConditionalSelect) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeDataProcessing3Source(instruction: ARMInstruction.DataProcessingRegister.DataProcessing3Source) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeLogicalShiftedRegister(instruction: ARMInstruction.DataProcessingRegister.LogicalShiftedRegister) throws {
        guard let cpu = delegate else { return }
        let shiftType = ARMMnemonic.Shift(value: Int(instruction.shift ?? 0))
        let shiftValue = instruction.imm6 ?? 0
        let shiftCondition = shiftType?.value ?? 0 != 0
        switch instruction.mode {
        case .x64:
            guard
                let firstSource = instruction.rn as? ARMGeneralPurposeRegister.GP64,
                let secondSource = instruction.rm as? ARMGeneralPurposeRegister.GP64,
                let destination = instruction.rd as? ARMGeneralPurposeRegister.GP64
            else { throw ARMInstructionExecutorError.missingValue }
            switch instruction.mnemonic {
            case .ORR:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt64 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let (newValue,_) = try alu.or(value1: firstValue, value2: shiftedValue)
                try cpu.store(value: newValue, at: destination)
                return
            case .MOV:
                let firstValue = try cpu.getValue(from: secondSource)
                try cpu.store(value: firstValue, at: destination)
                return
            case .EOR:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt64 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let (newValue,_) = try alu.eor(value1: firstValue, value2: shiftedValue)
                try cpu.store(value: newValue, at: destination)
                return
            case .AND:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt64 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let (newValue,_) = try alu.and(value1: firstValue, value2: shiftedValue)
                try cpu.store(value: newValue, at: destination)
                return
            case .ANDS:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt64 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let (newValue,flags) = try alu.and(value1: firstValue, value2: shiftedValue)
                cpu.updateFlags(flags: flags)
                try cpu.store(value: newValue, at: destination)
                return
            case .TST:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt64 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let (_,flags) = try alu.and(value1: firstValue, value2: shiftedValue)
                cpu.updateFlags(flags: flags)
                return
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
        case .w32:
            guard
                let firstSource = instruction.rn as? ARMGeneralPurposeRegister.GP32,
                let secondSource = instruction.rm as? ARMGeneralPurposeRegister.GP32,
                let destination = instruction.rd as? ARMGeneralPurposeRegister.GP32
            else { throw ARMInstructionExecutorError.missingValue }
            switch instruction.mnemonic {
            case .ORR:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt32 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let (newValue,_) = try alu.or(value1: firstValue, value2: shiftedValue)
                try cpu.store(value: newValue, at: destination)
                return
            case .MOV:
                let firstValue = try cpu.getValue(from: secondSource)
                try cpu.store(value: firstValue, at: destination)
                return
            case .EOR:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt32 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let (newValue,_) = try alu.eor(value1: firstValue, value2: shiftedValue)
                try cpu.store(value: newValue, at: destination)
                return
            case .AND:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt32 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let (newValue,_) = try alu.and(value1: firstValue, value2: shiftedValue)
                try cpu.store(value: newValue, at: destination)
                return
            case .ANDS:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt32 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let (newValue,flags) = try alu.and(value1: firstValue, value2: shiftedValue)
                cpu.updateFlags(flags: flags)
                try cpu.store(value: newValue, at: destination)
                return
            case .TST:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt32 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let (_,flags) = try alu.and(value1: firstValue, value2: shiftedValue)
                cpu.updateFlags(flags: flags)
                return
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
        default: throw ARMInstructionExecutorError.missingValue
        }
    }
    func executeAddSubtractShiftedRegister(instruction: ARMInstruction.DataProcessingRegister.AddSubtractShiftedRegister) throws {
        guard let cpu = delegate else { return }
        let shiftType = ARMMnemonic.Shift(value: Int(instruction.shift ?? 0))
        guard shiftType != .ROR else { throw ARMInstructionExecutorError.unsupportedShiftValue }
        let shiftValue = instruction.imm6 ?? 0
        let shiftCondition = shiftType?.value ?? 0 != 0
        
        switch instruction.mode {
        case .x64:
            guard
                let firstSource = instruction.rn as? ARMGeneralPurposeRegister.GP64,
                let secondSource = instruction.rm as? ARMGeneralPurposeRegister.GP64,
                let destination = instruction.rd as? ARMGeneralPurposeRegister.GP64
            else { throw ARMInstructionExecutorError.missingValue }
            switch instruction.mnemonic {
            case .ADD:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt64 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let (newValue,_) = try alu.addWithCarry(value1: firstValue, value2: shiftedValue, carryInBit: false)
                try cpu.store(value: newValue, at: destination)
            case .ADDS:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt64 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let (newValue,flags) = try alu.addWithCarry(value1: firstValue, value2: shiftedValue, carryInBit: false)
                cpu.updateFlags(flags: flags)
                try cpu.store(value: newValue, at: destination)
            case .CMN:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt64 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let (_,flags) = try alu.addWithCarry(value1: firstValue, value2: shiftedValue, carryInBit: false)
                cpu.updateFlags(flags: flags)
            case .SUB:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt64 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let negatedValue = alu.negate(value: shiftedValue)
                let (newValue,_) = try alu.addWithCarry(value1: firstValue, value2: negatedValue, carryInBit: true)
                try cpu.store(value: newValue, at: destination)
            case .NEG:
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt64 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let negatedValue = alu.negate(value: shiftedValue)
                try cpu.store(value: negatedValue, at: destination)
            case .SUBS:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt64 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let negatedValue = alu.negate(value: shiftedValue)
                let (newValue,flags) = try alu.addWithCarry(value1: firstValue, value2: negatedValue, carryInBit: true)
                cpu.updateFlags(flags: flags)
                try cpu.store(value: newValue, at: destination)
            case .NEGS:
                let firstValue = UInt64(0)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt64 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let negatedValue = alu.negate(value: shiftedValue)
                let (newValue,flags) = try alu.addWithCarry(value1: firstValue, value2: negatedValue, carryInBit: true)
                cpu.updateFlags(flags: flags)
                try cpu.store(value: newValue, at: destination)
            case .CMP:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt64 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let negatedValue = alu.negate(value: shiftedValue)
                let (_,flags) = try alu.addWithCarry(value1: firstValue, value2: negatedValue, carryInBit: true)
                cpu.updateFlags(flags: flags)
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
        case .w32:
            guard
                let firstSource = instruction.rn as? ARMGeneralPurposeRegister.GP32,
                let secondSource = instruction.rm as? ARMGeneralPurposeRegister.GP32,
                let destination = instruction.rd as? ARMGeneralPurposeRegister.GP32
            else { throw ARMInstructionExecutorError.missingValue }
            switch instruction.mnemonic {
            case .ADD:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt32 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let (newValue,_) = try alu.addWithCarry(value1: firstValue, value2: shiftedValue, carryInBit: false)
                try cpu.store(value: newValue, at: destination)
            case .ADDS:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt32 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let (newValue,flags) = try alu.addWithCarry(value1: firstValue, value2: shiftedValue, carryInBit: false)
                cpu.updateFlags(flags: flags)
                try cpu.store(value: newValue, at: destination)
            case .CMN:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt32 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let (_,flags) = try alu.addWithCarry(value1: firstValue, value2: shiftedValue, carryInBit: false)
                cpu.updateFlags(flags: flags)
            case .SUB:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt32 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let negatedValue = alu.negate(value: shiftedValue)
                let (newValue,_) = try alu.addWithCarry(value1: firstValue, value2: negatedValue, carryInBit: true)
                try cpu.store(value: newValue, at: destination)
            case .NEG:
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt32 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let negatedValue = alu.negate(value: shiftedValue)
                try cpu.store(value: negatedValue, at: destination)
            case .SUBS:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt32 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let negatedValue = alu.negate(value: shiftedValue)
                let (newValue,flags) = try alu.addWithCarry(value1: firstValue, value2: negatedValue, carryInBit: true)
                cpu.updateFlags(flags: flags)
                try cpu.store(value: newValue, at: destination)
            case .NEGS:
                let firstValue = UInt32(0)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt32 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let negatedValue = alu.negate(value: shiftedValue)
                let (newValue,flags) = try alu.addWithCarry(value1: firstValue, value2: negatedValue, carryInBit: true)
                cpu.updateFlags(flags: flags)
                try cpu.store(value: newValue, at: destination)
            case .CMP:
                let firstValue = try cpu.getValue(from: firstSource)
                let secondValue = try cpu.getValue(from: secondSource)
                let shiftedValue: UInt32 = try alu.shift(shiftType, value: secondValue, shiftValue: shiftValue, conditionBit: shiftCondition)
                let negatedValue = alu.negate(value: shiftedValue)
                let (_,flags) = try alu.addWithCarry(value1: firstValue, value2: negatedValue, carryInBit: true)
                cpu.updateFlags(flags: flags)
            default: throw ARMInstructionExecutorError.unsupportedInstruction
            }
        default: break
        }
    }
    func executeAddSubtractExtendedRegister(instruction: ARMInstruction.DataProcessingRegister.AddSubtractExtendedRegister) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
}

// MARK: - DataProcessingFloatingAndSimd
extension ARMInstructionExecutor {
    func executeCryptographicAES(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeCryptographicThreeRegisterSHA(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeCryptographicTwoRegisterSHA(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDScalarCopy(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDScalarThreeSameFP16(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDScalarTwoRegisterMiscellaneousFP16(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDScalarThreeSameExtra(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDScalarTwoRegisterMiscellaneous(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDScalarPairwise(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDScalarThreeDifferent(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDScalarThreeSame(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDScalarShiftByImmediate(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDScalarXIndexedElement(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDTableLookup(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDPermute(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDExtract(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDCopy(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDThreeSameFP16(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDTwoRegisterMiscellaneousFP16(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDThreeRegisterExtension(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDTwoRegisterMiscellaneous(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDAcrossLanes(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDThreeDifferent(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDThreeSame(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDModifiedImmediate(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDShiftByImmediate(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeAdvancedSIMDVectorXIndexedElement(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeCryptographicThreeRegisterImm2(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeCryptographicThreeRegisterSHA512(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeCryptographicFourRegister(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeXAR(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeCryptographicTwoRegisterSHA512(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeConversionBetweenFloatingPointAndFixedPoint(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeConversionBetweenFloatingPointAndInteger(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeFloatingPointDataProcessing1Source(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeFloatingPointCompare(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeFloatingPointImmediate(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeFloatingPointConditionalCompare(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeFloatingPointDataProcessing2Source(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeFloatingPointConditionalSelect(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
    func executeFloatingPointDataProcessing3source(instruction: ARMInstruction.DataProcessingFloatingAndSimd) throws {
        throw ARMInstructionExecutorError.unsupportedInstruction
    }
}
