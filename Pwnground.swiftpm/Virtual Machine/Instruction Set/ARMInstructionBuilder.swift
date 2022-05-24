//
//  ARMInstructionBuilder.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

enum LinkableSymbol<T: FixedWidthInteger> {
    case resolvable(id: String, resolver: ((String) -> T?))
    case literal(value: T)
    
    func resolve() -> T? {
        switch self {
        case .resolvable(let id, let resolver):
            return resolver(id)
        case .literal(let value):
            return value
        }
    }
}

struct ARMInstructionBuilder {
    
    enum Instruction {
        case movImmediate(register: ARMRegister, immediate: LinkableSymbol<UInt32>)
        case movRegister(destination: ARMRegister, source: ARMRegister)
        case movz(register: ARMRegister, immediate: LinkableSymbol<UInt32>, shift: UInt8 = 0)
        case movk(register: ARMRegister, immediate: LinkableSymbol<UInt32>, shift: UInt8 = 0)
        
        case adr(register: ARMRegister, immediate: LinkableSymbol<Int64>)
        case adrp(register: ARMRegister, immediate: LinkableSymbol<Int64>)
        
        case addImmediate(destination: ARMRegister, source: ARMRegister, immediate: LinkableSymbol<UInt16>, shift: Bool? = nil)
        case addRegister(destination: ARMRegister, firstSource: ARMRegister, secondSource: ARMRegister, shiftValue: UInt8 = 0, shift: ARMMnemonic.Shift? = nil)
        case addsImmediate(destination: ARMRegister, source: ARMRegister, immediate: LinkableSymbol<UInt16>, shift: Bool? = nil)
        case addsRegister(destination: ARMRegister, firstSource: ARMRegister, secondSource: ARMRegister, shiftValue: UInt8 = 0, shift: ARMMnemonic.Shift? = nil)
        
        case subImmediate(destination: ARMRegister, source: ARMRegister, immediate: LinkableSymbol<UInt16>, shift: Bool? = nil)
        case subRegister(destination: ARMRegister, firstSource: ARMRegister, secondSource: ARMRegister, shiftValue: UInt8 = 0, shift: ARMMnemonic.Shift? = nil)
        case subsImmediate(destination: ARMRegister, source: ARMRegister, immediate: LinkableSymbol<UInt16>, shift: Bool? = nil)
        case subsRegister(destination: ARMRegister, firstSource: ARMRegister, secondSource: ARMRegister, shiftValue: UInt8 = 0, shift: ARMMnemonic.Shift? = nil)
        
        case ldrImmediate(register: ARMRegister, address: LinkableSymbol<Int32>)
        case ldrRegister(destination: ARMRegister, addressRegister: ARMRegister, index: Int16? = nil, indexingMode: IndexingMode)
        
        case str(source: ARMRegister, addressRegister: ARMRegister, index: Int16? = nil, indexingMode: IndexingMode)
        
        case bUnconditional(address: LinkableSymbol<Int32>)
        case bConditional(address: LinkableSymbol<Int32>, condition: ARMMnemonic.Condition)
        
        case bl(address: LinkableSymbol<Int32>)
        case svc(immediate:  LinkableSymbol<UInt16>)
        
        case cmpImmediate(register: ARMRegister, immediate: LinkableSymbol<UInt16>, shift: Bool? = nil)
        case cmpRegister(destination: ARMRegister, source: ARMRegister, shiftValue: UInt8 = 0, shift: ARMMnemonic.Shift? = nil)
        case cmnImmediate(register: ARMRegister, immediate: LinkableSymbol<UInt16>, shift: Bool? = nil)
        case cmnRegister(destination: ARMRegister, source: ARMRegister, shiftValue: UInt8 = 0, shift: ARMMnemonic.Shift? = nil)
        
        case eorRegister(destination: ARMRegister, firstSource: ARMRegister, secondSource: ARMRegister, shift: ARMMnemonic.Shift? = nil, shiftValue: UInt8? = nil)
        case eorImmediate(destination: ARMRegister, source: ARMRegister, immediate: LinkableSymbol<UInt64>)
        
        case andRegister(destination: ARMRegister, firstSource: ARMRegister, secondSource: ARMRegister, shift: ARMMnemonic.Shift? = nil, shiftValue: UInt8? = nil)
        case andImmediate(destination: ARMRegister, source: ARMRegister, immediate: LinkableSymbol<UInt64>)
        
        case andsRegister(destination: ARMRegister, firstSource: ARMRegister, secondSource: ARMRegister, shift: ARMMnemonic.Shift? = nil, shiftValue: UInt8? = nil)
        case andsImmediate(destination: ARMRegister, source: ARMRegister, immediate: LinkableSymbol<UInt64>)
        
        case orrRegister(destination: ARMRegister, firstSource: ARMRegister, secondSource: ARMRegister, shift: ARMMnemonic.Shift? = nil, shiftValue: UInt8? = nil)
        case orrImmediate(destination: ARMRegister, source: ARMRegister, immediate: LinkableSymbol<UInt64>)
        
        case tstRegister(destination: ARMRegister, source: ARMRegister, shift: ARMMnemonic.Shift? = nil, shiftValue: UInt8? = nil)
        case tstImmediate(register: ARMRegister, immediate: LinkableSymbol<UInt64>)
        
        case ret(register: ARMRegister = ARMGeneralPurposeRegister.GP64.x30)
        case nop
        
        case ldp(register1: ARMRegister, register2: ARMRegister, addressRegister: ARMRegister, index: LinkableSymbol<Int16>, indexingMode: IndexingMode)
        case stp(register1: ARMRegister, register2: ARMRegister, addressRegister: ARMRegister, index: LinkableSymbol<Int16>, indexingMode: IndexingMode)
    }
    
    func build() { }
    
    // MARK: MOV
    static func mov(register: ARMRegister, immediate: UInt32) -> ARMInstruction? {
        let cpuMode = register.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingImmediate.MoveWideImmediate(.MOV, cpuMode: cpuMode)
        instruction?.rd = register
        instruction?.immediate = immediate
        return instruction
    }
    
    static func mov(destinationRegister: ARMRegister, sourceRegister: ARMRegister) -> ARMInstruction? {
        guard destinationRegister.mode == sourceRegister.mode else { return nil }
        let cpuMode = destinationRegister.mode ?? .x64
        
        let isSourceStackPointer = isStackPointer(sourceRegister)
        let isDestinationStackPointer = isStackPointer(destinationRegister)
        let isAnyRegisterStackPointer = isSourceStackPointer || isDestinationStackPointer
        
        if isAnyRegisterStackPointer {
            let instruction = try? ARMInstruction.DataProcessingImmediate.AddSubtractImmediate(.MOV, cpuMode: cpuMode)
            instruction?.rd = destinationRegister
            instruction?.rn = sourceRegister
            return instruction
        } else {
            let instruction = try? ARMInstruction.DataProcessingRegister.LogicalShiftedRegister(.MOV, cpuMode: cpuMode)
            instruction?.rd = destinationRegister
            instruction?.rm = sourceRegister
            return instruction
        }
    }
    
    // MARK: MOVZ
    static func movz(register: ARMRegister, immediate: UInt32, shift: UInt8 = 0) -> ARMInstruction? {
        let cpuMode = register.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingImmediate.MoveWideImmediate(.MOVZ, cpuMode: cpuMode)
        instruction?.rd = register
        instruction?.immediate = immediate
        instruction?.hw = shift
        return instruction
    }
    
    // MARK: MOVK
    static func movk(register: ARMRegister, immediate: UInt32, shift: UInt8 = 0) -> ARMInstruction? {
        let cpuMode = register.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingImmediate.MoveWideImmediate(.MOVK, cpuMode: cpuMode)
        instruction?.rd = register
        instruction?.immediate = immediate
        instruction?.hw = shift
        return instruction
    }
    
    // MARK: ADR
    static func adr(register: ARMRegister, immediate: Int64) -> ARMInstruction? {
        guard register.mode == .x64 else { return nil }
        let instruction = try? ARMInstruction.DataProcessingImmediate.PCRelAddressing(.ADR)
        instruction?.rd = register
        instruction?.address = immediate
        return instruction
    }
    
    // MARK: ADRP
    static func adrp(register: ARMRegister, immediate: Int64) -> ARMInstruction? {
        guard register.mode == .x64 else { return nil }
        let instruction = try? ARMInstruction.DataProcessingImmediate.PCRelAddressing(.ADRP)
        instruction?.rd = register
        instruction?.address = immediate
        return instruction
    }
    
    // MARK: ADD
    static func add(destination: ARMRegister, source: ARMRegister, immediate: UInt16, shift: Bool? = nil) -> ARMInstruction? {
        guard destination.mode == source.mode else { return nil }
        let cpuMode = destination.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingImmediate.AddSubtractImmediate(.ADD, cpuMode: cpuMode)
        instruction?.rd = destination
        instruction?.rn = source
        instruction?.imm12 = immediate
        instruction?.sh = shift ?? false ? 0b1 : 0b0
        return instruction
    }
    
    static func add(destination: ARMRegister, firstSource: ARMRegister, secondSource: ARMRegister, shiftValue: UInt8 = 0, shift: ARMMnemonic.Shift? = nil) -> ARMInstruction? {
        guard destination.mode == firstSource.mode, firstSource.mode == secondSource.mode else { return nil }
        let cpuMode = destination.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingRegister.AddSubtractShiftedRegister(.ADD, cpuMode: cpuMode)
        instruction?.rd = destination
        instruction?.rn = firstSource
        instruction?.rm = secondSource
        instruction?.imm6 = shiftValue
        instruction?.shift = UInt8(shift?.value ?? 0)
        return instruction
    }
    
    // MARK: ADDS
    static func adds(destination: ARMRegister, source: ARMRegister, immediate: UInt16, shift: Bool? = nil) -> ARMInstruction? {
        guard destination.mode == source.mode else { return nil }
        let cpuMode = destination.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingImmediate.AddSubtractImmediate(.ADDS, cpuMode: cpuMode)
        instruction?.rd = destination
        instruction?.rn = source
        instruction?.imm12 = immediate
        instruction?.sh = shift ?? false ? 0b1 : 0b0
        return instruction
    }
    
    static func adds(destination: ARMRegister, firstSource: ARMRegister, secondSource: ARMRegister, shiftValue: UInt8 = 0, shift: ARMMnemonic.Shift? = nil) -> ARMInstruction? {
        guard destination.mode == firstSource.mode, firstSource.mode == secondSource.mode else { return nil }
        let cpuMode = destination.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingRegister.AddSubtractShiftedRegister(.ADDS, cpuMode: cpuMode)
        instruction?.rd = destination
        instruction?.rn = firstSource
        instruction?.rm = secondSource
        instruction?.imm6 = shiftValue
        instruction?.shift = UInt8(shift?.value ?? 0)
        return instruction
    }
    
    // MARK: SUB
    static func sub(destination: ARMRegister, source: ARMRegister, immediate: UInt16, shift: Bool? = nil) -> ARMInstruction? {
        guard destination.mode == source.mode else { return nil }
        let cpuMode = destination.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingImmediate.AddSubtractImmediate(.SUB, cpuMode: cpuMode)
        instruction?.rd = destination
        instruction?.rn = source
        instruction?.imm12 = immediate
        instruction?.sh = shift ?? false ? 0b1 : 0b0
        return instruction
    }
    
    static func sub(destination: ARMRegister, firstSource: ARMRegister, secondSource: ARMRegister, shiftValue: UInt8 = 0, shift: ARMMnemonic.Shift? = nil) -> ARMInstruction? {
        guard destination.mode == firstSource.mode, firstSource.mode == secondSource.mode else { return nil }
        let cpuMode = destination.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingRegister.AddSubtractShiftedRegister(.SUB, cpuMode: cpuMode)
        instruction?.rd = destination
        instruction?.rn = firstSource
        instruction?.rm = secondSource
        instruction?.imm6 = shiftValue
        instruction?.shift = UInt8(shift?.value ?? 0)
        return instruction
    }
    
    // MARK: SUBS
    static func subs(destination: ARMRegister, source: ARMRegister, immediate: UInt16, shift: Bool? = nil) -> ARMInstruction? {
        guard destination.mode == source.mode else { return nil }
        let cpuMode = destination.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingImmediate.AddSubtractImmediate(.SUBS, cpuMode: cpuMode)
        instruction?.rd = destination
        instruction?.rn = source
        instruction?.imm12 = immediate
        instruction?.sh = shift ?? false ? 0b1 : 0b0
        return instruction
    }
    
    static func subs(destination: ARMRegister, firstSource: ARMRegister, secondSource: ARMRegister, shiftValue: UInt8 = 0, shift: ARMMnemonic.Shift? = nil) -> ARMInstruction? {
        guard destination.mode == firstSource.mode, firstSource.mode == secondSource.mode else { return nil }
        let cpuMode = destination.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingRegister.AddSubtractShiftedRegister(.SUBS, cpuMode: cpuMode)
        instruction?.rd = destination
        instruction?.rn = firstSource
        instruction?.rm = secondSource
        instruction?.imm6 = shiftValue
        instruction?.shift = UInt8(shift?.value ?? 0)
        return instruction
    }
    
    // MARK: LDR
    static func ldr(register: ARMRegister, address: Int32) -> ARMInstruction? {
        guard register.mode == .x64 else { return nil }
        let instruction = try? ARMInstruction.LoadsAndStores.LoadRegisterLiteral(.LDR)
        instruction?.rt = register
        instruction?.address = address
        return instruction
    }
    
    static func ldr(destination: ARMRegister, addressRegister: ARMRegister, index: Int16? = nil, indexingMode: IndexingMode) -> ARMInstruction? {
        let cpuMode = destination.mode ?? .x64
        switch indexingMode {
        case .post:
            let instruction = try? ARMInstruction.LoadsAndStores.LoadStoreRegisterImmediatePostIndexed(.LDR, cpuMode: cpuMode)
            instruction?.rt = destination
            instruction?.rn = addressRegister
            instruction?.imm9 = index
            return instruction
        case .pre:
            let instruction = try? ARMInstruction.LoadsAndStores.LoadStoreRegisterImmediatePreIndexed(.LDR, cpuMode: cpuMode)
            instruction?.rt = destination
            instruction?.rn = addressRegister
            instruction?.imm9 = index
            return instruction
        case .offset:
            let instruction = try? ARMInstruction.LoadsAndStores.LoadStoreRegisterUnsignedImmediate(.LDR, cpuMode: cpuMode)
            instruction?.rt = destination
            instruction?.rn = addressRegister
            instruction?.imm12 = UInt16(index ?? 0)
            return instruction
        }
    }
    
    // MARK: STR
    static func str(source: ARMRegister, addressRegister: ARMRegister, index: Int16? = nil, indexingMode: IndexingMode) -> ARMInstruction? {
        let cpuMode = source.mode ?? .x64
        switch indexingMode {
        case .post:
            let instruction = try? ARMInstruction.LoadsAndStores.LoadStoreRegisterImmediatePostIndexed(.STR, cpuMode: cpuMode)
            instruction?.rt = source
            instruction?.rn = addressRegister
            instruction?.imm9 = index
            return instruction
        case .pre:
            let instruction = try? ARMInstruction.LoadsAndStores.LoadStoreRegisterImmediatePreIndexed(.STR, cpuMode: cpuMode)
            instruction?.rt = source
            instruction?.rn = addressRegister
            instruction?.imm9 = index
            return instruction
        case .offset:
            let instruction = try? ARMInstruction.LoadsAndStores.LoadStoreRegisterUnsignedImmediate(.STR, cpuMode: cpuMode)
            instruction?.rt = source
            instruction?.rn = addressRegister
            instruction?.imm12 = UInt16(bitPattern: index ?? 0)
            return instruction
        }
    }
    
    // MARK: B
    static func b(address: Int32) -> ARMInstruction? {
        let instruction = try? ARMInstruction.BranchesExceptionAndSystem.UnconditionalBranchImmediate(.B)
        instruction?.address = address
        return instruction
    }
    
    static func b(address: Int32, condition: ARMMnemonic.Condition) -> ARMInstruction? {
        let instruction = try? ARMInstruction.BranchesExceptionAndSystem.ConditionalBranchImmediate(.B)
        instruction?.address = address
        instruction?.cond =  condition
        return instruction
    }
    
    // MARK: BL
    static func bl(address: Int32) -> ARMInstruction? {
        let instruction = try? ARMInstruction.BranchesExceptionAndSystem.UnconditionalBranchImmediate(.BL)
        instruction?.address = address
        return instruction
    }
    
    // MARK: SVC
    static func svc(immediate: UInt16) -> ARMInstruction? {
        let instruction = try? ARMInstruction.BranchesExceptionAndSystem.ExceptionGeneration(.SVC)
        instruction?.imm16 = immediate
        return instruction
    }
    
    // MARK: CMP
    static func cmp(register: ARMRegister, immediate: UInt16, shift: Bool? = nil) -> ARMInstruction? {
        let cpuMode = register.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingImmediate.AddSubtractImmediate(.CMP, cpuMode: cpuMode)
        instruction?.rn = register
        instruction?.imm12 = immediate
        instruction?.sh = shift ?? false ? 0b1 : 0b0
        return instruction
    }
    
    static func cmp(destination: ARMRegister, source: ARMRegister, shiftValue: UInt8 = 0, shift: ARMMnemonic.Shift? = nil) -> ARMInstruction? {
        let cpuMode = destination.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingRegister.AddSubtractShiftedRegister(.CMP, cpuMode: cpuMode)
        instruction?.rn = destination
        instruction?.rm = source
        instruction?.imm6 = shiftValue
        instruction?.shift = UInt8(shift?.value ?? 0)
        return instruction
    }
    
    // MARK: CMN
    static func cmn(register: ARMRegister, immediate: UInt16, shift: Bool? = nil) -> ARMInstruction? {
        let cpuMode = register.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingImmediate.AddSubtractImmediate(.CMN, cpuMode: cpuMode)
        instruction?.rn = register
        instruction?.imm12 = immediate
        instruction?.sh = shift ?? false ? 0b1 : 0b0
        return instruction
    }
    
    static func cmn(destination: ARMRegister, source: ARMRegister, shiftValue: UInt8 = 0, shift: ARMMnemonic.Shift? = nil) -> ARMInstruction? {
        let cpuMode = destination.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingRegister.AddSubtractShiftedRegister(.CMN, cpuMode: cpuMode)
        instruction?.rn = destination
        instruction?.rm = source
        instruction?.imm6 = shiftValue
        instruction?.shift = UInt8(shift?.value ?? 0)
        return instruction
    }
    
    // MARK: EOR
    static func eor(destination: ARMRegister, firstSource: ARMRegister, secondSource: ARMRegister, shift: ARMMnemonic.Shift? = nil, shiftValue: UInt8? = nil) -> ARMInstruction? {
        guard destination.mode == firstSource.mode, firstSource.mode == secondSource.mode else { return nil }
        let cpuMode = destination.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingRegister.LogicalShiftedRegister(.EOR, cpuMode: cpuMode)
        instruction?.rd = destination
        instruction?.rn = firstSource
        instruction?.rm = secondSource
        instruction?.shift = shift?.value.asUInt8
        instruction?.imm6 = shiftValue
        return instruction
    }
    
    static func eor(destination: ARMRegister, source: ARMRegister, immediate: UInt64?) -> ARMInstruction? {
        guard destination.mode == source.mode else { return nil }
        let cpuMode = destination.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingImmediate.LogicalImmediate(.EOR, cpuMode: cpuMode)
        instruction?.rd = destination
        instruction?.rn = source
        instruction?.immediate = immediate
        return instruction
    }
    
    // MARK: AND
    static func and(destination: ARMRegister, firstSource: ARMRegister, secondSource: ARMRegister, shift: ARMMnemonic.Shift? = nil, shiftValue: UInt8? = nil) -> ARMInstruction? {
        guard destination.mode == firstSource.mode, firstSource.mode == secondSource.mode else { return nil }
        let cpuMode = destination.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingRegister.LogicalShiftedRegister(.AND, cpuMode: cpuMode)
        instruction?.rd = destination
        instruction?.rn = firstSource
        instruction?.rm = secondSource
        instruction?.shift = shift?.value.asUInt8
        instruction?.imm6 = shiftValue
        return instruction
    }
    
    static func and(destination: ARMRegister, source: ARMRegister, immediate: UInt64?) -> ARMInstruction? {
        guard destination.mode == source.mode else { return nil }
        let cpuMode = destination.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingImmediate.LogicalImmediate(.AND, cpuMode: cpuMode)
        instruction?.rd = destination
        instruction?.rn = source
        instruction?.immediate = immediate
        return instruction
    }
    
    // MARK: ANDS
    static func ands(destination: ARMRegister, source: ARMRegister, immediate: UInt64?) -> ARMInstruction? {
        guard destination.mode == source.mode else { return nil }
        let cpuMode = destination.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingImmediate.LogicalImmediate(.ANDS, cpuMode: cpuMode)
        instruction?.rd = destination
        instruction?.rn = source
        instruction?.immediate = immediate
        return instruction
    }
    
    static func ands(destination: ARMRegister, firstSource: ARMRegister, secondSource: ARMRegister, shift: ARMMnemonic.Shift? = nil, shiftValue: UInt8? = nil) -> ARMInstruction? {
        guard destination.mode == firstSource.mode, firstSource.mode == secondSource.mode else { return nil }
        let cpuMode = destination.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingRegister.LogicalShiftedRegister(.ANDS, cpuMode: cpuMode)
        instruction?.rd = destination
        instruction?.rn = firstSource
        instruction?.rm = secondSource
        instruction?.shift = shift?.value.asUInt8
        instruction?.imm6 = shiftValue
        return instruction
    }
    
    // MARK: ORR
    static func orr(destination: ARMRegister, firstSource: ARMRegister, secondSource: ARMRegister, shift: ARMMnemonic.Shift? = nil, shiftValue: UInt8? = nil) -> ARMInstruction? {
        guard destination.mode == firstSource.mode, firstSource.mode == secondSource.mode else { return nil }
        let cpuMode = destination.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingRegister.LogicalShiftedRegister(.ORR, cpuMode: cpuMode)
        instruction?.rd = destination
        instruction?.rn = firstSource
        instruction?.rm = secondSource
        instruction?.shift = shift?.value.asUInt8
        instruction?.imm6 = shiftValue
        return instruction
    }
    
    static func orr(destination: ARMRegister, source: ARMRegister, immediate: UInt64?) -> ARMInstruction? {
        guard destination.mode == source.mode else { return nil }
        let cpuMode = destination.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingImmediate.LogicalImmediate(.ORR, cpuMode: cpuMode)
        instruction?.rd = destination
        instruction?.rn = source
        instruction?.immediate = immediate
        return instruction
    }
    
    // MARK: TST
    static func tst(destination: ARMRegister, source: ARMRegister, shift: ARMMnemonic.Shift? = nil, shiftValue: UInt8? = nil) -> ARMInstruction? {
        guard destination.mode == source.mode else { return nil }
        let cpuMode = destination.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingRegister.LogicalShiftedRegister(.TST, cpuMode: cpuMode)
        instruction?.rn = destination
        instruction?.rm = source
        instruction?.shift = shift?.value.asUInt8
        instruction?.imm6 = shiftValue
        return instruction
    }
    
    static func tst(register: ARMRegister, immediate: UInt64?) -> ARMInstruction? {
        let cpuMode = register.mode ?? .x64
        let instruction = try? ARMInstruction.DataProcessingImmediate.LogicalImmediate(.TST, cpuMode: cpuMode)
        instruction?.rn = register
        instruction?.immediate = immediate
        return instruction
    }
    
    // MARK: RET
    static func ret(register: ARMRegister = ARMGeneralPurposeRegister.GP64.x30) -> ARMInstruction? {
        guard register.mode == .x64 else { return nil }
        let instruction = try? ARMInstruction.BranchesExceptionAndSystem.UnconditionalBranchRegister(.RET)
        instruction?.rn = register
        return instruction
    }
    
    // MARK: NOP
    static func nop() -> ARMInstruction? {
        try? ARMInstruction.BranchesExceptionAndSystem.Hints(.NOP)
    }
    
    // MARK: LDP
    static func ldp(register1: ARMRegister, register2: ARMRegister, addressRegister: ARMRegister, index: Int16, indexingMode: IndexingMode) -> ARMInstruction? {
        guard register1.mode == register2.mode else { return nil }
        let cpuMode = register1.mode ?? .x64
        switch indexingMode {
        case .post:
            let instruction = try? ARMInstruction.LoadsAndStores.LoadStoreRegisterPairPostIndexed(.LDP, cpuMode: cpuMode)
            instruction?.rn = addressRegister
            instruction?.rt = register1
            instruction?.rt2 = register2
            instruction?.imm7 = index
            return instruction
        case .pre:
            let instruction = try? ARMInstruction.LoadsAndStores.LoadStoreRegisterPairPreIndexed(.LDP, cpuMode: cpuMode)
            instruction?.rn = addressRegister
            instruction?.rt = register1
            instruction?.rt2 = register2
            instruction?.imm7 = index
            return instruction
        case .offset:
            let instruction = try? ARMInstruction.LoadsAndStores.LoadStoreRegisterPairOffset(.LDP, cpuMode: cpuMode)
            instruction?.rn = addressRegister
            instruction?.rt = register1
            instruction?.rt2 = register2
            instruction?.imm7 = index
            return instruction
        }
    }
    
    // MARK: STP
    static func stp(register1: ARMRegister, register2: ARMRegister, addressRegister: ARMRegister, index: Int16, indexingMode: IndexingMode) -> ARMInstruction? {
        guard register1.mode == register2.mode else { return nil }
        let cpuMode = register1.mode ?? .x64
        switch indexingMode {
        case .post:
            let instruction = try? ARMInstruction.LoadsAndStores.LoadStoreRegisterPairPostIndexed(.STP, cpuMode: cpuMode)
            instruction?.rn = addressRegister
            instruction?.rt = register1
            instruction?.rt2 = register2
            instruction?.imm7 = index
            return instruction
        case .pre:
            let instruction = try? ARMInstruction.LoadsAndStores.LoadStoreRegisterPairPreIndexed(.STP, cpuMode: cpuMode)
            instruction?.rn = addressRegister
            instruction?.rt = register1
            instruction?.rt2 = register2
            instruction?.imm7 = index
            return instruction
        case .offset:
            let instruction = try? ARMInstruction.LoadsAndStores.LoadStoreRegisterPairOffset(.STP, cpuMode: cpuMode)
            instruction?.rn = addressRegister
            instruction?.rt = register1
            instruction?.rt2 = register2
            instruction?.imm7 = index
            return instruction
        }
    }
}

extension ARMInstructionBuilder {
    private static func isStackPointer(_ register: ARMRegister) -> Bool {
        if let gp64register = register as? ARMGeneralPurposeRegister.GP64 {
            return gp64register == .sp
        } else if let gp32register = register as? ARMGeneralPurposeRegister.GP32 {
            return gp32register == .sp
        } else {
            return false
        }
    }
}

extension ARMInstructionBuilder.Instruction {
    func build() -> ARMInstruction? {
        switch self {
        case .movImmediate(let register, let immediate):
            return ARMInstructionBuilder.mov(register: register, immediate: immediate.resolve() ?? 0)
        case .movRegister(let destination, let source):
            return ARMInstructionBuilder.mov(destinationRegister: destination, sourceRegister: source)
        case .movz(let register, let immediate, let shift):
            return ARMInstructionBuilder.movz(register: register, immediate: immediate.resolve() ?? 0, shift: shift)
        case .movk(let register, let immediate, let shift):
            return ARMInstructionBuilder.movk(register: register, immediate: immediate.resolve() ?? 0, shift: shift)
            
        case .adr(let register, let immediate):
            return ARMInstructionBuilder.adr(register: register, immediate: immediate.resolve() ?? 0)
        case .adrp(let register, let immediate):
            return ARMInstructionBuilder.adrp(register: register, immediate: immediate.resolve() ?? 0)
            
        case .addImmediate(let destination, let source, let immediate, let shift):
            return ARMInstructionBuilder.add(destination: destination, source: source, immediate: immediate.resolve() ?? 0, shift: shift)
        case .addRegister(let destination, let firstSource, let secondSource, let shiftValue, let shift):
            return ARMInstructionBuilder.add(destination: destination, firstSource: firstSource, secondSource: secondSource, shiftValue: shiftValue, shift: shift)
        case .addsImmediate(let destination, let source, let immediate, let shift):
            return ARMInstructionBuilder.adds(destination: destination, source: source, immediate: immediate.resolve() ?? 0, shift: shift)
        case .addsRegister(let destination, let firstSource, let secondSource, let shiftValue, let shift):
            return ARMInstructionBuilder.adds(destination: destination, firstSource: firstSource, secondSource: secondSource, shiftValue: shiftValue, shift: shift)
        
        case .subImmediate(let destination, let source, let immediate, let shift):
            return ARMInstructionBuilder.sub(destination: destination, source: source, immediate: immediate.resolve() ?? 0, shift: shift)
        case .subRegister(let destination, let firstSource, let secondSource, let shiftValue, let shift):
            return ARMInstructionBuilder.sub(destination: destination, firstSource: firstSource, secondSource: secondSource, shiftValue: shiftValue, shift: shift)
        case .subsImmediate(let destination, let source, let immediate, let shift):
            return ARMInstructionBuilder.subs(destination: destination, source: source, immediate: immediate.resolve() ?? 0, shift: shift)
        case .subsRegister(let destination, let firstSource, let secondSource, let shiftValue, let shift):
            return ARMInstructionBuilder.subs(destination: destination, firstSource: firstSource, secondSource: secondSource, shiftValue: shiftValue, shift: shift)
        
        case .ldrImmediate(let register, let address):
            return ARMInstructionBuilder.ldr(register: register, address: address.resolve() ?? 0)
        case .ldrRegister(let destination, let addressRegister, let index, let indexingMode):
            return ARMInstructionBuilder.ldr(destination: destination, addressRegister: addressRegister, index: index, indexingMode: indexingMode)
        
        case .str(let source, let addressRegister, let index, let indexingMode):
            return ARMInstructionBuilder.str(source: source, addressRegister: addressRegister, index: index, indexingMode: indexingMode)
        
        case .bUnconditional(let address):
            return ARMInstructionBuilder.b(address: address.resolve() ?? 0)
        case .bConditional(let address, let condition):
            return ARMInstructionBuilder.b(address: address.resolve() ?? 0, condition: condition)
        
        case .bl(let address):
            return ARMInstructionBuilder.bl(address: address.resolve() ?? 0)
        case .svc(let immediate):
            return ARMInstructionBuilder.svc(immediate: immediate.resolve() ?? 0)
        
        case .cmpImmediate(let register, let immediate, let shift):
            return ARMInstructionBuilder.cmp(register: register, immediate: immediate.resolve() ?? 0, shift: shift)
        case .cmpRegister(let destination, let source, let shiftValue, let shift):
            return ARMInstructionBuilder.cmp(destination: destination, source: source, shiftValue: shiftValue, shift: shift)
        case .cmnImmediate(let register, let immediate, let shift):
            return ARMInstructionBuilder.cmn(register: register, immediate: immediate.resolve() ?? 0, shift: shift)
        case .cmnRegister(let destination, let source, let shiftValue, let shift):
            return ARMInstructionBuilder.cmn(destination: destination, source: source, shiftValue: shiftValue, shift: shift)
        
        case .eorRegister(let destination, let firstSource, let secondSource, let shift, let shiftValue):
            return ARMInstructionBuilder.eor(destination: destination, firstSource: firstSource, secondSource: secondSource, shift: shift, shiftValue: shiftValue)
        case .eorImmediate(let destination, let source, let immediate):
            return ARMInstructionBuilder.eor(destination: destination, source: source, immediate: immediate.resolve() ?? 0)
        
        case .andRegister(let destination, let firstSource, let secondSource, let shift, let shiftValue):
            return ARMInstructionBuilder.and(destination: destination, firstSource: firstSource, secondSource: secondSource, shift: shift, shiftValue: shiftValue)
        case .andImmediate(let destination, let source, let immediate):
            return ARMInstructionBuilder.and(destination: destination, source: source, immediate: immediate.resolve() ?? 0)
        
        case .andsRegister(let destination, let firstSource, let secondSource, let shift, let shiftValue):
            return ARMInstructionBuilder.ands(destination: destination, firstSource: firstSource, secondSource: secondSource, shift: shift, shiftValue: shiftValue)
        case .andsImmediate(let destination, let source, let immediate):
            return ARMInstructionBuilder.ands(destination: destination, source: source, immediate: immediate.resolve() ?? 0)
        
        case .orrRegister(let destination, let firstSource, let secondSource, let shift, let shiftValue):
            return ARMInstructionBuilder.orr(destination: destination, firstSource: firstSource, secondSource: secondSource, shift: shift, shiftValue: shiftValue)
        case .orrImmediate(let destination, let source, let immediate):
            return ARMInstructionBuilder.orr(destination: destination, source: source, immediate: immediate.resolve() ?? 0)
        
        case .tstRegister(let destination, let source, let shift, let shiftValue):
            return ARMInstructionBuilder.tst(destination: destination, source: source, shift: shift, shiftValue: shiftValue)
        case .tstImmediate(let register, let immediate):
            return ARMInstructionBuilder.tst(register: register, immediate: immediate.resolve() ?? 0)
        
        case .ret(let register):
            return ARMInstructionBuilder.ret(register: register)
        case .nop:
            return ARMInstructionBuilder.nop()
        
        case .ldp(let register1, let register2, let addressRegister, let index, let indexingMode):
            return ARMInstructionBuilder.ldp(register1: register1, register2: register2, addressRegister: addressRegister, index: index.resolve() ?? 0, indexingMode: indexingMode)
        case .stp(let register1, let register2, let addressRegister, let index, let indexingMode):
            return ARMInstructionBuilder.stp(register1: register1, register2: register2, addressRegister: addressRegister, index: index.resolve() ?? 0, indexingMode: indexingMode)
        }
    }
}
