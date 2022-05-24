//
//  ARMBranchesExceptionAndSystemInstruction.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

extension ARMInstruction {
    class BranchesExceptionAndSystem: ARMInstruction {
        @ARMInstructionComponent(29..<32)
        var branchesExceptionAndSystemOp0: UInt32?
        @ARMInstructionComponent(12..<26)
        var branchesExceptionAndSystemOp1: UInt32?
        @ARMInstructionComponent(0..<5)
        var branchesExceptionAndSystemOp2: UInt32?
        
        override class func decode(rawInstruction: RawARMInstruction) throws -> ARMInstruction {
            guard Self.self == BranchesExceptionAndSystem.self else {
                throw ARMInstructionDecoderError.subclassDecoderUnsupported
            }
            guard let instructionDecoder = try decodeInstructionType(from: rawInstruction) else {
                throw ARMInstructionDecoderError.unrecognizedInstruction
            }
            return try instructionDecoder.init(from: rawInstruction)
        }
        
        private static func decodeInstructionType(from rawInstruction: RawARMInstruction) throws -> BranchesExceptionAndSystem.Type? {
            guard
                let op0 = rawInstruction[29..<32],
                let op1 = rawInstruction[12..<26],
                let op2 = rawInstruction[0..<5]
            else { throw ARMInstructionDecoderError.unableToDecode }
            var decoder: BranchesExceptionAndSystem.Type?
            if op0 == 0b010 {
                if op1 & 0b10000000000000 == 0b0 {
                    // Conditional branch (immediate)
                    decoder = ConditionalBranchImmediate.self
                }
            }
            if op0 == 0b110 {
                if op1 & 0b11000000000000 == 0b0 {
                    // Exception generation
                    decoder = ExceptionGeneration.self
                }
                if op1 == 0b01000000110001 {
                    // System instructions with register argument
                    decoder = SystemInsturctionsWithRegister.self
                }
                if op1 == 0b01000000110010 && op2 == 0b11111 {
                    // Hints
                    decoder = Hints.self
                }
                if op1 == 0b01000000110011 {
                    // Barriers
                    decoder = Barriers.self
                }
                if op1 & 0b11111110001111 == 0b01000000000100 {
                    // PSTATE
                    decoder = PSTATE.self
                }
                if op1 & 0b11110110000000 == 0b01000010000000 {
                    // System instructions
                    decoder = SystemInstruction.self
                }
                if op1 & 0b11110100000000 == 0b01000100000000 {
                    // System register move
                    decoder = SystemRegisterMove.self
                }
                if op1 & 0b10000000000000 == 0b10000000000000 {
                    // Unconditional branch (register)
                    decoder = UnconditionalBranchRegister.self
                }
            }
            if op0 & 0b011 == 0b0 {
                // Unconditional branch (immediate)
                decoder = UnconditionalBranchImmediate.self
            }
            if op0 & 0b11 == 0b01 {
                if op1 & 0b10000000000000 == 0b0 {
                    // Compare and branch (immediate)
                    decoder = CompareAndBranchImmediate.self
                }
                if op1 & 0b10000000000000 == 0b10000000000000 {
                    // Test and branch (immediate)
                    decoder = TestAndBranchImmediate.self
                }
            }
            return decoder
        }
    }
}

extension ARMInstruction.BranchesExceptionAndSystem {
    // Conditional branch (immediate)
    class ConditionalBranchImmediate: BranchesExceptionAndSystem {
        override class var supportedMnemonics: [ARMMnemonic] { [.B] }
        
        @ARMInstructionComponent(25..<32, enforced: 0b0101010)
        var const1: UInt8?
        
        @ARMInstructionComponent(24..<25)
        var o1: UInt8?
        @ARMInstructionComponent(5..<24)
        var imm19: UInt32?
        @ARMInstructionComponent(4..<5)
        var o0: UInt8?
        @ARMInstructionComponent(0..<4)
        var cond: ARMMnemonic.Condition?
        
        var address: Int32? {
            get {
                guard let value = imm19 else { return nil }
                let mask = value[18..<19] == 0b1 ? Int32(bitPattern: UInt32.max.masked(including: 21..<Int32.bitWidth)) : 0
                return (Int32(bitPattern: value) &<< 2) | mask
            }
            set {
                guard let value = newValue else { imm19 = nil; return }
                let mask = UInt32.max.masked(including: 0..<19)
                imm19 = UInt32(bitPattern: value &>> 2) & mask
            }
        }
        
        override var mnemonicSuffix: ARMMnemonic.Suffix? { cond?.suffix }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {[
            ARMImmediateBuilder(immediate: .required(address))
        ]}
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            $o1 = 0b00
            $o0 = 0b0
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let o1 = rawInstruction[24,25],
                let o0 = rawInstruction[4,5]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (o1,o0) {
            case (0,0): return .B
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Exception generation
    class ExceptionGeneration: BranchesExceptionAndSystem {
        override class var supportedMnemonics: [ARMMnemonic] { [.SVC, .HVC, .SMC, .BRK, .HLT, .DCPS1, .DCPS2, .DCPS3] }
        
        @ARMInstructionComponent(24..<32, enforced: 0b11010100)
        var const1: UInt8?
        
        @ARMInstructionComponent(21..<24)
        var opc: UInt8?
        @ARMInstructionComponent(5..<21)
        var imm16: UInt16?
        @ARMInstructionComponent(2..<5)
        var op2: UInt8?
        @ARMInstructionComponent(0..<2)
        var ll: UInt8?
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {[
            ARMImmediateBuilder(immediate: .required(imm16))
        ]}
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?, UInt32?, UInt32)?
            switch mnemonic {
            case .SVC: data = (0b000, 0b000, 0b01)
            case .HVC: data = (0b000, 0b000, 0b10)
            case .SMC: data = (0b000, 0b000, 0b11)
            case .BRK: data = (0b001, 0b000, 0b00)
            case .HLT: data = (0b010, 0b000, 0b00)
            case .DCPS1: data = (0b101, 0b000, 0b01)
            case .DCPS2: data = (0b101, 0b000, 0b10)
            case .DCPS3: data = (0b101, 0b000, 0b11)
            default: break
            }
            $opc = data?.0
            $op2 = data?.1
            $ll = data?.2
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let opc = rawInstruction[21,24],
                let op2 = rawInstruction[2,5],
                let ll = rawInstruction[0,2]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (opc, op2, ll) {
            case (0b000, 0b000, 0b01): return .SVC
            case (0b000, 0b000, 0b10): return .HVC
            case (0b000, 0b000, 0b11): return .SMC
            case (0b001, 0b000, 0b00): return .BRK
            case (0b010, 0b000, 0b00): return .HLT
            case (0b101, 0b000, 0b01): return .DCPS1
            case (0b101, 0b000, 0b10): return .DCPS2
            case (0b101, 0b000, 0b11): return .DCPS3
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // System instructions with register argument
    class SystemInsturctionsWithRegister: BranchesExceptionAndSystem {
        override class var supportedMnemonics: [ARMMnemonic] { [.WFET, .WFIT] }
        
        @ARMInstructionComponent(12..<32, enforced: 0b1101_0101_0000_0011_0001)
        var const1: UInt8?
        
        @ARMInstructionComponent(8..<12)
        var crm: UInt8?
        @ARMInstructionComponent(5..<8)
        var op2: UInt8?
        @ARMInstructionComponent(0..<5)
        var rd: ARMRegister?
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {[
            ARMRegisterBuilder(register: .required(rd))
        ]}
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?, UInt32?)?
            switch mnemonic {
            case .WFET: data = (0b0000, 0b000)
            case .WFIT: data = (0b0000, 0b001)
            default: break
            }
            $crm = data?.0
            $op2 = data?.1
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let crm = rawInstruction[8,12],
                let op2 = rawInstruction[5,8]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (crm, op2) {
            case (0b0000, 0b000): return .WFET
            case (0b0000, 0b001): return .WFIT
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Hints
    class Hints: BranchesExceptionAndSystem {
        override class var supportedMnemonics: [ARMMnemonic] {[
            .HINT, .NOP, .YIELD, .WFE, .WFI, .SEV, .SEVL, .DGH, .XPACD, .XPACI, .XPACLRI, .PACIA, .PACIA1716, .PACIASP, .PACIAZ, .PACIZA, .PACIB, .PACIB1716, .PACIBSP, .PACIBZ, .PACIZB, .AUTIA, .AUTIA1716, .AUTIASP, .AUTIAZ, .AUTIZA, .AUTIB, .AUTIB1716, .AUTIBSP, .AUTIBZ, .AUTIZB, .ESB, .PSB_CSYNC, .TSB_CSYNC, .CSDB, .BTI
        ]}
        
        @ARMInstructionComponent(12..<32, enforced: 0b1101_0101_0000_0011_0010)
        var const1: UInt8?
        
        @ARMInstructionComponent(8..<12)
        var crm: UInt8?
        @ARMInstructionComponent(10..<11)
        var d: UInt8?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5, enforced: 0b11111)
        var rd: ARMRegister?
        @ARMInstructionComponent(5..<8)
        var op2: ARMMnemonic.IndirectionTarget?
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            switch mnemonic {
            case .NOP, .YIELD, .WFE, .WFI, .SEV, .SEVL, .DGH, .PACIA1716, .PACIASP, .PACIAZ, .PACIB1716, .PACIBSP, .PACIBZ, .AUTIA1716, .AUTIASP, .AUTIAZ, .AUTIB1716, .AUTIBSP, .AUTIBZ, .ESB, .PSB_CSYNC, .TSB_CSYNC, .CSDB: return []
            case .XPACD, .XPACI, .XPACLRI, .PACIZA, .PACIZB, .AUTIZA, .AUTIZB: return [
                ARMRegisterBuilder(register: .required(rd))
            ]
            case .PACIA, .PACIB, .AUTIA, .AUTIB: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rn))
            ]
            case .BTI: return [
                ARMTargetBuilder(target: .required(op2))
            ]
            default: return nil
            }
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?, UInt32?, UInt32?)?
            switch mnemonic {
            case .NOP: data = (0b0000, 0b000, nil)
            case .YIELD: data = (0b0000, 0b001, nil)
            case .WFE: data = (0b0000, 0b010, nil)
            case .WFI: data = (0b0000, 0b011, nil)
            case .SEV: data = (0b0000, 0b100, nil)
            case .SEVL: data = (0b0000, 0b101, nil)
            case .DGH: data = (0b0000, 0b110, nil)
            case .PACIA1716: data = (0b0001, 0b000, nil)
            case .PACIB1716: data = (0b0001, 0b010, nil)
            case .AUTIA1716: data = (0b0001, 0b100, nil)
            case .AUTIB1716: data = (0b0001, 0b110, nil)
            case .ESB: data = (0b0010, 0b000, nil)
            case .PSB_CSYNC: data = (0b0010, 0b001, nil)
            case .TSB_CSYNC: data = (0b0010, 0b010, nil)
            case .CSDB: data = (0b0010, 0b100, nil)
            case .PACIAZ: data = (0b0011, 0b000, nil)
            case .PACIASP: data = (0b0011, 0b001, nil)
            case .PACIBZ: data = (0b0011, 0b010, nil)
            case .PACIBSP: data = (0b0011, 0b011, nil)
            case .AUTIAZ: data = (0b0011, 0b100, nil)
            case .AUTIASP: data = (0b0011, 0b101, nil)
            case .AUTIBZ: data = (0b0011, 0b110, nil)
            case .AUTIBSP: data = (0b0011, 0b111, nil)
            case .XPACD: data = (0b0000, 0b111, 0b1)
            case .XPACI: data = (0b0000, 0b111, 0b0)
            case .BTI: data = (0b0100, 0b000, nil)
            case .HINT: break
            default: break
            }
            $crm = data?.0
            $op2 = data?.1
            $d = data?.2
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let crm = rawInstruction[8,12],
                let op2 = rawInstruction[5,8],
                let d = rawInstruction[10,11]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (crm, op2) {
            case (0b0000, 0b000): return .NOP
            case (0b0000, 0b001): return .YIELD
            case (0b0000, 0b010): return .WFE
            case (0b0000, 0b011): return .WFI
            case (0b0000, 0b100): return .SEV
            case (0b0000, 0b101): return .SEVL
            case (0b0000, 0b110): return .DGH
            case (0b0001, 0b000): return .PACIA1716
            case (0b0001, 0b010): return .PACIB1716
            case (0b0001, 0b100): return .AUTIA1716
            case (0b0001, 0b110): return .AUTIB1716
            case (0b0010, 0b000): return .ESB
            case (0b0010, 0b001): return .PSB_CSYNC
            case (0b0010, 0b010): return .TSB_CSYNC
            case (0b0010, 0b100): return .CSDB
            case (0b0011, 0b000): return .PACIAZ
            case (0b0011, 0b001): return .PACIASP
            case (0b0011, 0b010): return .PACIBZ
            case (0b0011, 0b011): return .PACIBSP
            case (0b0011, 0b100): return .AUTIAZ
            case (0b0011, 0b101): return .AUTIASP
            case (0b0011, 0b110): return .AUTIBZ
            case (0b0011, 0b111): return .AUTIBSP
            case (0b0000, 0b111):
                if d == 0b1 {
                    return .XPACD
                } else if d == 0b0 {
                    return .XPACI
                }
            case (0b0100, _):
                if op2 & 0b001 == 0 {
                    return .BTI
                }
            default: return .HINT
            }
            throw ARMInstructionDecoderError.unrecognizedInstruction
        }
    }
    
    // Barriers
    class Barriers: BranchesExceptionAndSystem {
        override class var supportedMnemonics: [ARMMnemonic] { [.CLREX, .DMB, .ISB, .SB, .DSB, .SSBB, .PSSBB] }
        
        @ARMInstructionComponent(12..<32, enforced: 0b1101_0101_0000_0011_0011)
        var const1: UInt8?
        
        @ARMInstructionComponent(8..<12)
        var crm: UInt8?
        @ARMInstructionComponent(10..<12)
        var imm2: UInt8?
        @ARMInstructionComponent(5..<8)
        var op2: UInt8?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            switch mnemonic {
            case .SB, .SSBB, .PSSBB: return [
                ARMImmediateBuilder(immediate: mnemonic == .DSB ? .required(imm2) : .optional(imm2))
            ]
            default: return []
            }
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?, UInt32?)?
            switch mnemonic {
            case .DSB: data = (0b001, 0b10)
            case .SSBB: data = (0b100, 0b0)
            case .PSSBB: data = (0b100, 0b100)
            case .DMB: data = (0b101, nil)
            case .ISB: data = (0b110, nil)
            case .SB: data = (0b111, nil)
            default: break
            }
            $op2 = data?.0
            $crm = data?.1
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let crm = rawInstruction[8,12],
                let op2 = rawInstruction[5,8]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch op2 {
            case 0b001:
                if crm & 0b11 == 0b10 {
                    return .DSB
                }
            case 0b100:
                if crm & 0b100 != 0b0 {
                    return .DSB
                } else if crm == 0b0 {
                    return .SSBB
                } else if crm == 0b100 {
                    return .PSSBB
                }
            case 0b101: return .DMB
            case 0b110: return .ISB
            case 0b111: return .SB
            default: break
            }
            throw ARMInstructionDecoderError.unrecognizedInstruction
        }
        
        override func setupCustomCoders() {
            _imm2.customDecoder = customImmediateDecoder()
            _imm2.customEncoder = customImmediateEncoder()
        }
        
        private func customImmediateDecoder<Type: FixedWidthInteger>() -> ((RawARMInstruction?) -> Type?) {
            { value in
                switch value {
                case 0b00: return 16
                case 0b01: return 20
                case 0b10: return 24
                case 0b11: return 28
                default: return nil
                }
            }
        }
        
        private func customImmediateEncoder<Type: FixedWidthInteger>() -> ((Type?) -> RawARMInstruction?) {
            { value in
                switch value {
                case 16: return RawARMInstruction(0b00)
                case 20: return RawARMInstruction(0b01)
                case 24: return RawARMInstruction(0b10)
                case 28: return RawARMInstruction(0b11)
                default: return nil
                }
            }
        }
    }
    
    // PSTATE
    class PSTATE: BranchesExceptionAndSystem {
        override class var supportedMnemonics: [ARMMnemonic] { [.MSR, .CFINV, .XAFLAG, .AXFLAG] }
        
        @ARMInstructionComponent(19..<32, enforced: 0b1101_0101_0000_0)
        var const1: UInt8?
        @ARMInstructionComponent(12..<16, enforced: 0b0100)
        var const2: UInt8?
        
        @ARMInstructionComponent(16..<19)
        var op1: UInt8?
        @ARMInstructionComponent(8..<12)
        var crm: UInt8?
        @ARMInstructionComponent(5..<8)
        var op2: UInt8?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        var pstate: ARMMnemonic.PSTATE? {
            get { getPSTATE() }
            set { setPSTATE(to: newValue) }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            switch mnemonic {
            case .MSR: return [
                ARMLabelBuilder(label: .required(pstate?.rawValue)),
                ARMImmediateBuilder(immediate: .required(crm))
            ]
            default: return []
            }
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32)?
            switch mnemonic {
            case .CFINV: data = (0b000, 0b000, 0b11111)
            case .XAFLAG: data = (0b000, 0b001, 0b11111)
            case .AXFLAG: data = (0b000, 0b010, 0b11111)
            case .MSR: data = (nil, nil, 0b11111)
            default: break
            }
            $op1 = data?.0
            $op2 = data?.1
            $rt = data?.2
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let op1 = rawInstruction[16,19],
                let op2 = rawInstruction[5,8],
                let rt = rawInstruction[0,5]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (op1, op2, rt) {
            case (0b000, 0b000, 0b11111): return .CFINV
            case (0b000, 0b001, 0b11111): return .XAFLAG
            case (0b000, 0b010, 0b11111): return .AXFLAG
            case (_, _, 0b11111): return .MSR
            default: break
            }
            throw ARMInstructionDecoderError.unrecognizedInstruction
        }
        
        func getPSTATE() -> ARMMnemonic.PSTATE? {
            guard let op1 = op1, let op2 = op2 else { return nil }
            switch (op1, op2) {
            case (0b000, 0b101): return .SPSel
            case (0b011, 0b110): return .DAIFSet
            case (0b011, 0b111): return .DAIFClr
            case (0b000, 0b011): return .UAO
            case (0b000, 0b100): return .PAN
            case (0b011, 0b001): return .SSBS
            case (0b011, 0b010): return .DIT
            case (0b011, 0b100): return .TCO
            default: return nil
            }
        }
        
        func setPSTATE(to value: ARMMnemonic.PSTATE?) {
            switch value {
            case .SPSel: op1 = 0b000; op2 = 0b101
            case .DAIFSet: op1 = 0b011; op2 = 0b110
            case .DAIFClr: op1 = 0b011; op2 = 0b111
            case .UAO: op1 = 0b000; op2 = 0b011
            case .PAN: op1 = 0b000; op2 = 0b100
            case .SSBS: op1 = 0b011; op2 = 0b001
            case .DIT: op1 = 0b011; op2 = 0b010
            case .TCO: op1 = 0b011; op2 = 0b100
            default: op1 = nil; op2 = nil; return
            }
        }
    }
    
    // System instructions
    class SystemInstruction: BranchesExceptionAndSystem {
        override class var supportedMnemonics: [ARMMnemonic] { [.SYS, .SYSL, .CFP, .CPP, .DVP, .AT, .DC, .IC, .TLBI] }
        
        @ARMInstructionComponent(22..<32, enforced: 0b1101_0101_00)
        var const1: UInt8?
        @ARMInstructionComponent(19..<21, enforced: 0b01)
        var const2: UInt8?
        
        @ARMInstructionComponent(21..<22)
        var l: UInt8?
        @ARMInstructionComponent(16..<19)
        var op1: UInt8?
        @ARMInstructionComponent(12..<16)
        var crn: UInt8?
        @ARMInstructionComponent(8..<12)
        var crm: UInt8?
        @ARMInstructionComponent(5..<8)
        var op2: UInt8?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            switch mnemonic {
            case .SYS: return [
                    ARMImmediateBuilder(immediate: .required(op1)),
                    ARMLabelBuilder(label: .required(getCname(from: crn))),
                    ARMLabelBuilder(label: .required(getCname(from: crm))),
                    ARMImmediateBuilder(immediate: .required(op2)),
                    ARMRegisterBuilder(register: .optional(rt?.value != 0b11111 ? rt : nil))
                ]
            case .SYSL: return [
                    ARMRegisterBuilder(register: .required(rt)),
                    ARMImmediateBuilder(immediate: .required(op1)),
                    ARMLabelBuilder(label: .required(getCname(from: crn))),
                    ARMLabelBuilder(label: .required(getCname(from: crm))),
                    ARMImmediateBuilder(immediate: .required(op2)),
                ]
            case .CFP, .CPP, .DVP: return [
                ARMLabelBuilder(label: .required(ARMMnemonic.PredictionRestriction.RCTX.rawValue)),
                ARMRegisterBuilder(register: .required(rt))
            ]
            case .AT: return [
                ARMLabelBuilder(label: .required(ARMMnemonic.ATInstruction(op1: op1, crm: crm, op2: op2)?.rawValue)),
                ARMRegisterBuilder(register: .required(rt))
            ]
            case .DC: return [
                ARMLabelBuilder(label: .required(ARMMnemonic.DCInstruction(op1: op1, crm: crm, op2: op2)?.rawValue)),
                ARMRegisterBuilder(register: .required(rt))
            ]
            case .IC: return [
                ARMLabelBuilder(label: .required(ARMMnemonic.ICInstruction(op1: op1, crm: crm, op2: op2)?.rawValue)),
                ARMRegisterBuilder(register: .optional(rt))
            ]
            case .TLBI: return [
                ARMLabelBuilder(label: .required(ARMMnemonic.TLBIInstruction(op1: op1, crm: crm, op2: op2)?.rawValue)),
                ARMRegisterBuilder(register: .optional(rt))
            ]
            default: return []
            }
        }
        
        override func describe() throws -> String {
            guard mnemonic == .SYS else {
                return try buildString(for: mnemonic)
            }
            let sysOp = ARMMnemonic.SysOp(op1: op1, crn: crn, crm: crm, op2: op2)
            if op1 == 0b011 && crn == 0b0111 && crm == 0b0011 {
                switch op2 {
                case 0b100:
                    return try buildString(for: .CFP) // CFP
                case 0b111:
                    return try buildString(for: .CPP) // CPP
                case 0b101:
                    return try buildString(for: .DVP) // DVP
                default: break
                }
            } else if (crn == 0b0111) && (crm ?? 0 & 0b1110 == 0b1000) && (sysOp == .AT) {
                return try buildString(for: .AT) // AT
            } else if crn == 0b0111 {
                if sysOp == .DC {
                    return try buildString(for: .DC) // DC
                } else if sysOp == .IC {
                    return try buildString(for: .IC) // IC
                }
            } else if crn == 0b1000 && sysOp == .TLBI {
                return try buildString(for: .TLBI) // TLBI
            }
            return try buildString(for: mnemonic)
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32?,UInt32?,UInt32?)?
            switch mnemonic {
            case .SYS: data = (0b0, nil, nil, nil, nil)
            case .SYSL: data = (0b1, nil, nil, nil, nil)
            case .CFP: data = (0b0, 0b011, 0b0111, 0b0011, 0b100)
            case .CPP: data = (0b0, 0b011, 0b0111, 0b0011, 0b111)
            case .DVP: data = (0b0, 0b011, 0b0111, 0b0011, 0b101)
            case .AT: data = (0b0, nil, 0b0111, 0b1000, nil)
            case .DC: data = (0b0, nil, 0b0111, nil, nil)
            case .IC: data = (0b0, nil, 0b0111, nil, nil)
            case .TLBI: data = (0b0, nil, 0b1000, nil, nil)
            default: break
            }
            $l = data?.0
            $op1 = data?.1
            $crn = data?.2
            $crm = data?.3
            $op2 = data?.4
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard let l = rawInstruction[21,22] else { throw ARMInstructionDecoderError.unableToDecode }
            switch l {
            case 0b0: return .SYS
            case 0b1: return .SYSL
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
        
        private func getCname(from value: UInt8?) -> String? {
            guard let value = value else { return nil }
            return "C\(value)"
        }
    }
    
    // System register move
    class SystemRegisterMove: BranchesExceptionAndSystem {
        override class var supportedMnemonics: [ARMMnemonic] { [.MSR, .MRS] }
        
        @ARMInstructionComponent(22..<32, enforced: 0b1101_0101_00)
        var const1: UInt8?
        @ARMInstructionComponent(20..<21, enforced: 0b1)
        var const2: UInt8?
        
        @ARMInstructionComponent(21..<22)
        var l: UInt8?
        @ARMInstructionComponent(19..<20)
        var o0: UInt8?
        @ARMInstructionComponent(16..<19)
        var op1: UInt8?
        @ARMInstructionComponent(12..<16)
        var crn: UInt8?
        @ARMInstructionComponent(8..<12)
        var crm: UInt8?
        @ARMInstructionComponent(5..<8)
        var op2: UInt8?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        private var systemReg: String? {
            guard
                let op1 = op1,
                let op2 = op2,
                let crn = getCname(from: crn),
                let crm = getCname(from: crm),
                let o0 = o0
            else { return nil }
            return "S_\(o0)_\(op1)_\(crn)_\(crm)_\(op2)"
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            switch mnemonic {
            case .MSR: return [
                ARMLabelBuilder(label: .required(systemReg)),
                ARMRegisterBuilder(register: .required(rt))
            ]
            case .MRS: return [
                ARMRegisterBuilder(register: .required(rt)),
                ARMLabelBuilder(label: .required(systemReg))
            ]
            default: return []
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard let l = rawInstruction[21,22] else { throw ARMInstructionDecoderError.unableToDecode }
            switch l {
            case 0b0: return .MSR
            case 0b1: return .MRS
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var l: UInt32?
            switch mnemonic {
            case .MSR: l = 0b0
            case .MRS: l = 0b1
            default: break
            }
            $l = l
        }
        
        override func setupCustomCoders() {
            _o0.customDecoder = getPostProcessedImmedaiteDecoder({ $0 == 0b0 ? 2 : 3 })
            _o0.customEncoder = getPreProcessedImmedaiteEncoder({ $0 == 2 ? 0 : $0 == 3 ? 1 : nil })
        }
        
        private func getCname(from value: UInt8?) -> String? {
            guard let value = value else { return nil }
            return "C\(value)"
        }
    }
    
    // Unconditional branch (register)
    class UnconditionalBranchRegister: BranchesExceptionAndSystem {
        override class var supportedMnemonics: [ARMMnemonic] {
            [.BR, .BRAA, .BRAAZ, .BRAB, .BRABZ, .BLR, .RET, .RETAA, .RETAB, .ERET, .ERETAA, .ERETAB, .DRPS]
        }
        
        @ARMInstructionComponent(25..<32, enforced: 0b1101_011)
        var const1: UInt8?
        
        @ARMInstructionComponent(21..<25)
        var opc: UInt8?
        @ARMInstructionComponent(16..<21)
        var op2: UInt8?
        @ARMInstructionComponent(10..<16)
        var op3: UInt8?
        @ARMInstructionComponent(5..<10)
        var rn : ARMRegister?
        @ARMInstructionComponent(0..<5)
        var op4: ARMRegister?
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            switch mnemonic {
            case .BR, .BRAAZ, .BRABZ, .BLRAAZ, .BLRABZ, .BLR: return [
                ARMRegisterBuilder(register: .required(rn))
            ]
            case .BRAA, .BRAB, .BLRAA, .BLRAB: return [
                ARMRegisterBuilder(register: .required(rn)),
                ARMRegisterBuilder(register: .required(op4))
            ]
            case .RET: return [
                ARMRegisterBuilder(register: .optional(rn as? ARMGeneralPurposeRegister.GP64 == .x30 ? nil : rn))
            ]
            default: return []
            }
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32?,UInt32?,UInt32?)?
            switch mnemonic {
            case .BR: data = (0b0000, 0b11111, 0b000000, nil, 0b00000)
            case .BRAAZ: data = (0b0000, 0b11111, 0b000010, nil, 0b11111)
            case .BLRAAZ: data = (0b0001, 0b11111, 0b000010, nil, 0b11111)
            case .BRABZ: data = (0b0000, 0b11111, 0b000011, nil, 0b11111)
            case .BLRABZ: data = (0b0001, 0b11111, 0b000011, nil, 0b11111)
            case .RET: data = (0b0010, 0b11111, 0b000000, nil, 0b00000)
            case .RETAA: data = (0b0010, 0b11111, 0b000010, 0b11111, 0b11111)
            case .RETAB: data = (0b0010, 0b11111, 0b000011, 0b11111, 0b11111)
            case .ERET: data = (0b0100, 0b11111, 0b000000, 0b11111, 0b00000)
            case .ERETAA: data = (0b0100, 0b11111, 0b000010, 0b11111, 0b11111)
            case .ERETAB: data = (0b0100, 0b11111, 0b000011, 0b11111, 0b11111)
            case .DRPS: data = (0b0101, 0b11111, 0b000000, 0b11111, 0b00000)
            case .BRAA: data = (0b1000, 0b11111, 0b000010, nil, nil)
            case .BLRAA: data = (0b1001, 0b11111, 0b000010, nil, nil)
            case .BRAB: data = (0b1000, 0b11111, 0b000011, nil, nil)
            case .BLRAB: data = (0b1001, 0b11111, 0b000011, nil, nil)
            default: break
            }
            $opc = data?.0
            $op2 = data?.1
            $op3 = data?.2
            $rn = data?.3
            $op4 = data?.4
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let opc = rawInstruction[21,25],
                let op2 = rawInstruction[16,21],
                let op3 = rawInstruction[10,16],
                let rn = rawInstruction[5,10],
                let op4 = rawInstruction[0,5]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (opc,op2,op3,rn,op4) {
            case (0b0000, 0b11111, 0b000000, _, 0b00000): return .BR
            case (0b0000, 0b11111, 0b000010, _, 0b11111): return .BRAAZ
            case (0b0001, 0b11111, 0b000010, _, 0b11111): return .BLRAAZ
            case (0b0000, 0b11111, 0b000011, _, 0b11111): return .BRABZ
            case (0b0001, 0b11111, 0b000011, _, 0b11111): return .BLRABZ
            case (0b0010, 0b11111, 0b000000, _, 0b00000): return .RET
            case (0b0010, 0b11111, 0b000010, 0b11111, 0b11111): return .RETAA
            case (0b0010, 0b11111, 0b000011, 0b11111, 0b11111): return .RETAB
            case (0b0100, 0b11111, 0b000000, 0b11111, 0b00000): return .ERET
            case (0b0100, 0b11111, 0b000010, 0b11111, 0b11111): return .ERETAA
            case (0b0100, 0b11111, 0b000011, 0b11111, 0b11111): return .ERETAB
            case (0b0101, 0b11111, 0b000000, 0b11111, 0b00000): return .DRPS
            case (0b1000, 0b11111, 0b000010, _, _): return .BRAA
            case (0b1001, 0b11111, 0b000010, _, _): return .BLRAA
            case (0b1000, 0b11111, 0b000011, _, _): return .BRAB
            case (0b1001, 0b11111, 0b000011, _, _): return .BLRAB
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Unconditional branch (immediate)
    class UnconditionalBranchImmediate: BranchesExceptionAndSystem {
        override class var supportedMnemonics: [ARMMnemonic] {[.B, .BL]}
        
        @ARMInstructionComponent(26..<31, enforced: 0b00101)
        var const1: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var op: UInt8?
        @ARMInstructionComponent(0..<26)
        var imm26: UInt32?
        
        var address: Int32? {
            get {
                guard let value = imm26 else { return nil }
                let mask = value[25..<26] == 0b1 ? Int32(bitPattern: UInt32.max.masked(including: 28..<32)) : 0
                return (Int32(bitPattern: value) &<< 2) | mask
            }
            set {
                guard let value = newValue else { imm26 = nil; return }
                let mask = UInt32.max.masked(including: 0..<26)
                imm26 = UInt32(bitPattern: value &>> 2) & mask
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {[
            ARMImmediateBuilder(immediate: .required(address))
        ]}
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            switch mnemonic {
            case .B: op = 0b0
            case .BL: op = 0b1
            default: break
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard let op = rawInstruction[31,32] else { throw ARMInstructionDecoderError.unableToDecode }
            switch op {
            case 0b0: return .B
            case 0b1: return .BL
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Compare and branch (immediate)
    class CompareAndBranchImmediate: BranchesExceptionAndSystem {
        override class var supportedMnemonics: [ARMMnemonic] {[.CBZ, .CBNZ]}
        
        @ARMInstructionComponent(25..<31, enforced: 0b011010)
        var const1: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var sf: UInt8?
        @ARMInstructionComponent(24..<25)
        var op: UInt8?
        @ARMInstructionComponent(5..<24)
        var imm19: UInt32?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        override var mode: CPUMode? {
            get {
                guard let sf = sf else { return nil }
                return CPUMode(rawValue: Int(sf))
            }
        }
        
        var address: UInt64? {
            get {
                guard let value = imm19 else { return nil }
                return UInt64(clamping: value) &<< 2
            }
            set {
                guard let value = imm19 else { imm19 = nil; return }
                imm19 = UInt32(clamping: value &>> 2)
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {[
            ARMRegisterBuilder(register: .required(rt)),
            ARMImmediateBuilder(immediate: .required(address))
        ]}
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            switch mnemonic {
            case .CBZ: op = 0b0
            case .CBNZ: op = 0b1
            default: break
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard let op = rawInstruction[24,25] else { throw ARMInstructionDecoderError.unableToDecode }
            switch op {
            case 0b0: return .CBZ
            case 0b1: return .CBNZ
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Test and branch (immediate)
    class TestAndBranchImmediate: BranchesExceptionAndSystem {
        override class var supportedMnemonics: [ARMMnemonic] {[.TBZ, .TBNZ]}
        
        @ARMInstructionComponent(25..<31, enforced: 0b011011)
        var const1: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var b5: UInt8?
        @ARMInstructionComponent(24..<25)
        var op: UInt8?
        @ARMInstructionComponent(19..<24)
        var b40: UInt8?
        @ARMInstructionComponent(5..<19)
        var imm14: UInt16?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        override var mode: CPUMode? {
            get {
                guard let b5 = b5 else { return nil }
                return CPUMode(rawValue: Int(b5))
            }
        }
        
        var immediate: UInt8? {
            get { mergeImmediates(from: [_b5, _b40]) }
            set { try? divideImmediates(from: newValue, into: [_b5, _b40]) }
        }
        
        var address: UInt64? {
            get {
                guard let value = imm14 else { return nil }
                return UInt64(clamping: value) &<< 2
            }
            set {
                guard let value = imm14 else { imm14 = nil; return }
                imm14 = UInt16(clamping: value &>> 2)
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {[
            ARMRegisterBuilder(register: .required(rt)),
            ARMImmediateBuilder(immediate: .required(immediate)),
            ARMImmediateBuilder(immediate: .required(address))
        ]}
        
        override func setupCustomCoders() {
            _rt.customDecoder = getModeSensitiveRegisterDecoder(for: .zero)
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            switch mnemonic {
            case .TBZ: op = 0b0
            case .TBNZ: op = 0b1
            default: break
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard let op = rawInstruction[24,25] else { throw ARMInstructionDecoderError.unableToDecode }
            switch op {
            case 0b0: return .TBZ
            case 0b1: return .TBNZ
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
}
