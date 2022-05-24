//
//  ARMLoadsAndStoresInstruction.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

extension ARMInstruction {
    class LoadsAndStores: ARMInstruction {
        @ARMInstructionComponent(28..<32)
        var loadsAndStoresOp0: UInt32?
        @ARMInstructionComponent(26..<27)
        var loadsAndStoresOp1: UInt32?
        @ARMInstructionComponent(23..<25)
        var loadsAndStoresOp2: UInt32?
        @ARMInstructionComponent(16..<22)
        var loadsAndStoresOp3: UInt32?
        @ARMInstructionComponent(10..<12)
        var loadsAndStoresOp4: UInt32?
        
        override class func decode(rawInstruction: RawARMInstruction) throws -> ARMInstruction {
            guard Self.self == LoadsAndStores.self else {
                throw ARMInstructionDecoderError.subclassDecoderUnsupported
            }
            guard let instructionDecoder = try decodeInstructionType(from: rawInstruction) else {
                throw ARMInstructionDecoderError.unrecognizedInstruction
            }
            return try instructionDecoder.init(from: rawInstruction)
        }
        
        private static func decodeInstructionType(from rawInstruction: RawARMInstruction) throws -> LoadsAndStores.Type? {
            guard
                let op0 = rawInstruction[28..<32],
                let op1 = rawInstruction[26..<27],
                let op2 = rawInstruction[23..<25],
                let op3 = rawInstruction[16..<22],
                let op4 = rawInstruction[10..<12]
            else { throw ARMInstructionDecoderError.unableToDecode }
            var decoder: LoadsAndStores.Type?
            if op0 & 0b1011 == 0b0 && op1 == 0b1 {
                if op2 == 0b0 && op3 == 0b0 {
                    // Advanced SIMD load/store multiple structures
                    decoder = AdvancedSIMDLoadStoreMultipleStructures.self
                }
                if op2 == 0b01 && op3 & 0b100000 == 0b0 {
                    // Advanced SIMD load/store multiple structures (post-indexed)
                    decoder = AdvancedSIMDLoadStoreMultipleStructuresPostIndexed.self
                }
                if op2 == 0b10 && op3 & 0b011111 == 0b0 {
                    // Advanced SIMD load/store single structure
                    decoder = AdvancedSIMDLoadStoreSingleStructure.self
                }
                if op2 == 0b11 {
                    // Advanced SIMD load/store single structure (post-indexed)
                    decoder = AdvancedSIMDLoadStoreSingleStructuresPostIndexed.self
                }
            }
            if op0 == 0b1101 && op1 == 0b0 {
                if op2 & 0b10 == 0b10 && op3 & 0b100000 == 0b100000 {
                    // Load/store memory tags
                    decoder = LoadStoreMemoryTags.self
                }
            }
            if op0 & 0b0011 == 0b0 && op1 == 0b0 {
                if op2 & 0b10 == 0b0 {
                    // Load/store exclusive
                    decoder = LoadStoreExclusive.self
                }
            }
            if op0 & 0b0011 == 0b0001 && op1 == 0b0 {
                if op2 & 0b10 == 0b10 && op3 & 0b100000 == 0b0 && op4 == 0b0 {
                    // LDAPR/STLR (unscaled immediate)
                    decoder = LDAPRSTLR.self
                }
            }
            if op0 & 0b0011 == 0b0001 && op2 & 0b10 == 0b0 {
                // Load register (literal)
                decoder = LoadRegisterLiteral.self
            }
            if op0 & 0b0011 == 0b0010 {
                if op2 == 0b00 {
                    // Load/store no-allocate pair (offset)
                    decoder = LoadStoreNoAllocatePairOffset.self
                }
                if op2 == 0b01 {
                    // Load/store register pair (post-indexed)
                    decoder = LoadStoreRegisterPairPostIndexed.self
                }
                if op2 == 0b10 {
                    // Load/store register pair (offset)
                    decoder = LoadStoreRegisterPairOffset.self
                }
                if op2 == 0b11 {
                    // Load/store register pair (pre-indexed)
                    decoder = LoadStoreRegisterPairPreIndexed.self
                }
            }
            if op0 & 0b0011 == 0b0011 {
                if op2 & 0b10 == 0 {
                    if op3 & 0b100000 == 0b0 {
                        if op4 == 0b00 {
                            // Load/store register (unscaled immediate)
                            decoder = LoadStoreRegisterUnscaledImmediate.self
                        }
                        if op4 == 0b01 {
                            // Load/store register (immediate post-indexed)
                            decoder = LoadStoreRegisterImmediatePostIndexed.self
                        }
                        if op4 == 0b10 {
                            // Load/store register (unprivileged)
                            decoder = LoadStoreRegisterUnprivileged.self
                        }
                        if op4 == 0b11 {
                            // Load/store register (immediate pre-indexed)
                            decoder = LoadStoreRegisterImmediatePreIndexed.self
                        }
                    }
                    if op3 & 0b100000 == 0b100000 {
                        if op4 == 0b00 {
                            // Atomic memory operations
                            decoder = AtomicMemoryOperations.self
                        }
                        if op4 == 0b10 {
                            // Load/store register (register offset)
                            decoder = LoadStoreRegisterRegisterOffset.self
                        }
                        if op4 & 0b01 == 0b01 {
                            // Load/store register (pac)
                            decoder = LoadStoreRegisterPAC.self
                        }
                    }
                }
                if op2 & 0b10 == 0b10 {
                    // Load/store register (unsigned immediate)
                    decoder = LoadStoreRegisterUnsignedImmediate.self
                }
            }
            return decoder
        }
    }
}

extension ARMInstruction.LoadsAndStores {
    
    // Advanced SIMD load/store multiple structures
    class AdvancedSIMDLoadStoreMultipleStructures: LoadsAndStores {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD load/store multiple structures (post-indexed)
    class AdvancedSIMDLoadStoreMultipleStructuresPostIndexed: LoadsAndStores {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD load/store single structure
    class AdvancedSIMDLoadStoreSingleStructure: LoadsAndStores {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD load/store single structure (post-indexed)
    class AdvancedSIMDLoadStoreSingleStructuresPostIndexed: LoadsAndStores {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Load/store memory tags
    class LoadStoreMemoryTags: LoadsAndStores {
        override class var supportedMnemonics: [ARMMnemonic] { [.STG, .STZGM, .STZG, .LDG, .STGM, .STZ2G, .ST2G, .LDGM] }
        
        @ARMInstructionComponent(22..<24, enforced: 0b11011001)
        var const1: UInt8?
        @ARMInstructionComponent(21..<22, enforced: 0b1)
        var const2: UInt8?
        
        @ARMInstructionComponent(22..<24)
        var opc: UInt8?
        @ARMInstructionComponent(12..<21)
        var imm9: Int16?
        @ARMInstructionComponent(10..<12)
        var op2: UInt8?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            switch mnemonic {
            case .STG, .STZG, .ST2G, .STZ2G:
                switch op2 {
                case 0b01: return [
                    ARMRegisterBuilder(register: .required(rt)),
                    ARMAddresBuilder<Int16>(baseRegister: .required(rn)),
                    ARMImmediateBuilder(immediate: .required(imm9))
                ]
                case 0b11: return [
                    ARMRegisterBuilder(register: .required(rt)),
                    ARMAddresBuilder(baseRegister: .required(rn), offsetImmediate: .required(imm9), indexingMode: .pre)
                ]
                case 0b10: return [
                    ARMRegisterBuilder(register: .required(rt)),
                    ARMAddresBuilder(baseRegister: .required(rn), offsetImmediate: .optional(imm9))
                ]
                default: return []
                }
            case .STZGM,. STGM, .LDGM: return [
                ARMRegisterBuilder(register: .required(rt)),
                ARMAddresBuilder<Int16>(baseRegister: .required(rn)),
            ]
            case .LDG: return [
                ARMRegisterBuilder(register: .required(rt)),
                ARMAddresBuilder(baseRegister: .required(rn), offsetImmediate: .optional(imm9))
            ]
            default: return []
            }
        }
        
        override func setupCustomCoders() {
            _rn.customDecoder = getModeSensitiveRegisterDecoder(cpuMode: .x64)
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32?)?
            switch mnemonic {
            case .STG: data = (0b00, nil, nil)
            case .STZGM: data = (0b0, 0b0, 0b0)
            case .LDG: data = (0b01, nil, 0b00)
            case .STZG: data = (0b01, nil, 0b01)
            case .ST2G: data = (0b10, nil, 0b01)
            case .STGM: data = (0b10, 0b0, 0b0)
            case .STZ2G: data = (0b11, nil, 0b01)
            case .LDGM: data = (0b11, 0b0, 0b0)
            default: break
            }
            $opc = data?.0
            $imm9 = data?.1
            $op2 = data?.2 ?? indexingMode?.rawValue.asUInt32
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let opc = rawInstruction[22,24],
                let imm9 = rawInstruction[12,21],
                let op2 = rawInstruction[10,12]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (opc, imm9, op2) {
            case (0b00, _, 0b01), (0b00, _, 0b10), (0b00, _, 0b11): return .STG
            case (0b0, 0b0, 0b0): return .STZGM
            case (0b01, _, 0b00): return .LDG
            case (0b01, _, 0b01), (0b01, _, 0b10), (0b01, _, 0b11): return .STZG
            case (0b10, _, 0b01), (0b10, _, 0b10), (0b10, _, 0b11): return .ST2G
            case (0b10, 0b0, 0b0): return .STGM
            case (0b11, _, 0b01), (0b11, _, 0b10), (0b11, _, 0b11): return .STZ2G
            case (0b11, 0b0, 0b0): return .LDGM
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Load/store exclusive
    class LoadStoreExclusive: LoadsAndStores {
        override class var supportedMnemonics: [ARMMnemonic] { [ .STXRB, .STLXRB, .CASP, .CASPA, .CASPAL, .CASPL, .LDXRB, .LDAXRB, .STLLRB, .STLRB, .CASB, .CASAB, .CASALB, .CASLB, .LDLARB, .LDARB, .STXRH, .STLXRH, .LDXRH, .LDAXRH, .STLLRH, .STLRH, .CASH, .CASAH, .CASALH, .CASLH, .LDLARH, .LDARH, .STXR, .STLXR, .STXP, .STLXP, .LDXR, .LDAXR, .LDXP, .LDAXP, .STLLR, .STLR, .CAS, .CASA, .CASAL, .CASL, .LDLAR, .LDAR ] }
        
        @ARMInstructionComponent(24..<30, enforced: 0b001000)
        var const1: UInt8?
        
        @ARMInstructionComponent(30..<32)
        var size: UInt8?
        @ARMInstructionComponent(23..<24)
        var o2: UInt8?
        @ARMInstructionComponent(22..<23)
        var l: UInt8?
        @ARMInstructionComponent(21..<22)
        var o1: UInt8?
        @ARMInstructionComponent(16..<21)
        var rs: ARMRegister?
        @ARMInstructionComponent(15..<16)
        var o0: UInt8?
        @ARMInstructionComponent(10..<15)
        var rt2: ARMRegister?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        var rs1: ARMRegister? { getNextRegister(to: rs) }
        var rt1: ARMRegister? { getNextRegister(to: rt) }
        
        override var mode: CPUMode? {
            switch mnemonic {
            case .STXR, .STLXR, .STXP, .STLXP, .LDXR, .LDAXR, .LDXP, .LDAXP, .STLLR, .STLR, .CAS, .CASL, .LDLAR, .LDAR, .CASA, .CASAL:
                switch size {
                case 0b10: return .w32
                case 0b11: return .x64
                default: return nil
                }
            case .CASP, .CASPL, .CASPA, .CASPAL:
                switch size {
                case 0b00: return .w32
                case 0b01: return .x64
                default: return nil
                }
            default: return .x64
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            switch mnemonic {
            case .STXRB, .STLXRB, .STXRH, .STLXRH, .STXR, .STLXR: return [
                ARMRegisterBuilder(register: .required(rs)),
                ARMRegisterBuilder(register: .required(rt)),
                ARMAddresBuilder<UInt8>(baseRegister: .required(rn))
            ]
            case .CASP, .CASPL, .CASPA, .CASPAL: return [
                ARMRegisterBuilder(register: .required(rs)),
                ARMRegisterBuilder(register: .required(rs1)),
                ARMRegisterBuilder(register: .required(rt)),
                ARMRegisterBuilder(register: .required(rt1)),
                ARMAddresBuilder<UInt8>(baseRegister: .required(rn))
            ]
            case .CASAB, .CASALB, .CASB, .CASLB, .CAS, .CASA, .CASAL, .CASL: return [
                ARMRegisterBuilder(register: .required(rs)),
                ARMRegisterBuilder(register: .required(rt)),
                ARMAddresBuilder<UInt8>(baseRegister: .required(rn))
            ]
            case .LDAXR, .LDAXRB, .STLLRB, .STLRB, .LDLARB, .LDARB, .LDXRH, .LDAXRH, .STLLRH, .STLRH, .LDLARH, .LDARH, .LDXR, .STLLR, .STLR, .LDLAR, .LDAR: return [
                ARMRegisterBuilder(register: .required(rt)),
                ARMAddresBuilder<UInt8>(baseRegister: .required(rn))
            ]
            case .STXP, .STLXP: return [
                ARMRegisterBuilder(register: .required(rs)),
                ARMRegisterBuilder(register: .required(rt)),
                ARMRegisterBuilder(register: .required(rt2)),
                ARMAddresBuilder<UInt8>(baseRegister: .required(rn))
            ]
            case .LDXP, .LDAXP: return [
                ARMRegisterBuilder(register: .required(rt)),
                ARMRegisterBuilder(register: .required(rt2)),
                ARMAddresBuilder<UInt8>(baseRegister: .required(rn))
            ]
            default: return []
            }
        }
        
        override func setupCustomCoders() {
            _rn.customDecoder = getModeSensitiveRegisterDecoder(cpuMode: .x64)
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32?,UInt32?,UInt32?,UInt32?)?
            switch mnemonic {
            case .STXRB: data = (0b00,0b0,0b0,0b0,0b0,nil)
            case .STLXRB: data = (0b00,0b0,0b0,0b0,0b1,nil)
            case .CASP: data = (0b00,0b0,0b0,0b1,0b0,0b11111)
            case .CASPL: data = (0b00,0b0,0b0,0b1,0b1,0b11111)
            case .LDXRB: data = (0b00,0b0,0b1,0b0,0b0,nil)
            case .LDAXRB: data = (0b00,0b0,0b1,0b0,0b1,nil)
            case .CASPA: data = (0b00,0b0,0b1,0b1,0b0,0b11111)
            case .CASPAL: data = (0b00,0b0,0b1,0b1,0b1,0b11111)
            case .STLLRB: data = (0b00,0b1,0b0,0b0,0b0,nil)
            case .STLRB: data = (0b00,0b1,0b0,0b0,0b1,nil)
            case .CASB: data = (0b00,0b1,0b0,0b1,0b0,0b11111)
            case .CASLB: data = (0b00,0b1,0b0,0b1,0b1,0b11111)
            case .LDLARB: data = (0b00,0b1,0b1,0b0,0b0,nil)
            case .LDARB: data = (0b00,0b1,0b1,0b0,0b1,nil)
            case .CASAB: data = (0b00,0b1,0b1,0b1,0b0,0b11111)
            case .CASALB: data = (0b00,0b1,0b1,0b1,0b1,0b11111)
                
            case .STXRH: data = (0b01,0b0,0b0,0b0,0b0,nil)
            case .STLXRH: data = (0b01,0b0,0b0,0b0,0b1,nil)
            case .LDXRH: data = (0b01,0b0,0b1,0b0,0b0,nil)
            case .LDAXRH: data = (0b01,0b0,0b1,0b0,0b1,nil)
            case .STLLRH: data = (0b01,0b1,0b0,0b0,0b0,nil)
            case .STLRH: data = (0b01,0b1,0b0,0b0,0b1,nil)
            case .CASH: data = (0b01,0b1,0b0,0b1,0b0,0b11111)
            case .CASLH: data = (0b01,0b1,0b0,0b1,0b1,0b11111)
            case .LDLARH: data = (0b01,0b1,0b1,0b0,0b0,nil)
            case .LDARH: data = (0b01,0b1,0b1,0b0,0b1,nil)
            case .CASAH: data = (0b01,0b1,0b1,0b1,0b0,0b11111)
            case .CASALH: data = (0b01,0b1,0b1,0b1,0b1,0b11111)
                
            case .STXR: data = (0b10,0b0,0b0,0b0,0b0,nil)
            case .STLXR: data = (0b10,0b0,0b0,0b0,0b1,nil)
            case .STXP: data = (0b10,0b0,0b0,0b1,0b0,nil)
            case .STLXP: data = (0b10,0b0,0b0,0b1,0b1,nil)
            case .LDXR: data = (0b10,0b0,0b1,0b0,0b0,nil)
            case .LDAXR: data = (0b10,0b0,0b1,0b0,0b1,nil)
            case .LDXP: data = (0b10,0b0,0b1,0b1,0b0,nil)
            case .LDAXP: data = (0b10,0b0,0b1,0b1,0b1,nil)
            case .STLLR: data = (0b10,0b1,0b0,0b0,0b0,nil)
            case .STLR: data = (0b10,0b1,0b0,0b0,0b1,nil)
            case .CAS: data = (0b10,0b1,0b0,0b1,0b0,0b11111)
            case .CASL: data = (0b10,0b1,0b0,0b1,0b1,0b11111)
            case .LDLAR: data = (0b10,0b1,0b1,0b0,0b0,nil)
            case .LDAR: data = (0b10,0b1,0b1,0b0,0b1,nil)
            case .CASA: data = (0b10,0b1,0b1,0b1,0b0,0b11111)
            case .CASAL: data = (0b10,0b1,0b1,0b1,0b1,0b11111)
            default: break
            }
            $size = data?.0
            $o2 = data?.1
            $l = data?.2
            $o1 = data?.3
            $o0 = data?.4
            $rt2 = data?.5
            switch mnemonic {
            case .STXR, .STLXR, .STXP, .STLXP, .LDXR, .LDAXR, .LDXP, .LDAXP, .STLLR, .STLR, .CAS, .CASL, .LDLAR, .LDAR, .CASA, .CASAL:
                switch mode {
                case .w32: size = 0b10
                case .x64: size = 0b11
                default: break
                }
            case .CASP, .CASPL, .CASPA, .CASPAL:
                switch mode {
                case .w32: size = 0b00
                case .x64: size = 0b01
                default: break
                }
            default: break
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let size = rawInstruction[30,32],
                let o2 = rawInstruction[23,24],
                let l = rawInstruction[22,23],
                let o1 = rawInstruction[21,22],
                let o0 = rawInstruction[15,16],
                let rt2 = rawInstruction[10,15]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (size, o2, l, o1, o0, rt2) {
            case (0b00,0b0,0b0,0b0,0b0,_): return .STXRB
            case (0b00,0b0,0b0,0b0,0b1,_): return .STLXRB
            case (0b00,0b0,0b0,0b1,0b0,0b11111): return .CASP
            case (0b00,0b0,0b0,0b1,0b1,0b11111): return .CASPL
            case (0b00,0b0,0b1,0b0,0b0,_): return .LDXRB
            case (0b00,0b0,0b1,0b0,0b1,_): return .LDAXRB
            case (0b00,0b0,0b1,0b1,0b0,0b11111): return .CASPA
            case (0b00,0b0,0b1,0b1,0b1,0b11111): return .CASPAL
            case (0b00,0b1,0b0,0b0,0b0,_): return .STLLRB
            case (0b00,0b1,0b0,0b0,0b1,_): return .STLRB
            case (0b00,0b1,0b0,0b1,0b0,0b11111): return .CASB
            case (0b00,0b1,0b0,0b1,0b1,0b11111): return .CASLB
            case (0b00,0b1,0b1,0b0,0b0,_): return .LDLARB
            case (0b00,0b1,0b1,0b0,0b1,_): return .LDARB
            case (0b00,0b1,0b1,0b1,0b0,0b11111): return .CASAB
            case (0b00,0b1,0b1,0b1,0b1,0b11111): return .CASALB
                
            case (0b01,0b0,0b0,0b0,0b0,_): return .STXRH
            case (0b01,0b0,0b0,0b0,0b1,_): return .STLXRH
            case (0b01,0b0,0b0,0b1,0b0,0b11111): return .CASP
            case (0b01,0b0,0b0,0b1,0b1,0b11111): return .CASPL
            case (0b01,0b0,0b1,0b0,0b0,_): return .LDXRH
            case (0b01,0b0,0b1,0b0,0b1,_): return .LDAXRH
            case (0b01,0b0,0b1,0b1,0b0,0b11111): return .CASPA
            case (0b01,0b0,0b1,0b1,0b1,0b11111): return .CASPAL
            case (0b01,0b1,0b0,0b0,0b0,_): return .STLLRH
            case (0b01,0b1,0b0,0b0,0b1,_): return .STLRH
            case (0b01,0b1,0b0,0b1,0b0,0b11111): return .CASH
            case (0b01,0b1,0b0,0b1,0b1,0b11111): return .CASLH
            case (0b01,0b1,0b1,0b0,0b0,_): return .LDLARH
            case (0b01,0b1,0b1,0b0,0b1,_): return .LDARH
            case (0b01,0b1,0b1,0b1,0b0,0b11111): return .CASAH
            case (0b01,0b1,0b1,0b1,0b1,0b11111): return .CASALH
                
            case (0b10,0b0,0b0,0b0,0b0,_): return .STXR
            case (0b10,0b0,0b0,0b0,0b1,_): return .STLXR
            case (0b10,0b0,0b0,0b1,0b0,_): return .STXP
            case (0b10,0b0,0b0,0b1,0b1,_): return .STLXP
            case (0b10,0b0,0b1,0b0,0b0,_): return .LDXR
            case (0b10,0b0,0b1,0b0,0b1,_): return .LDAXR
            case (0b10,0b0,0b1,0b1,0b0,_): return .LDXP
            case (0b10,0b0,0b1,0b1,0b1,_): return .LDAXP
            case (0b10,0b1,0b0,0b0,0b0,_): return .STLLR
            case (0b10,0b1,0b0,0b0,0b1,_): return .STLR
            case (0b10,0b1,0b0,0b1,0b0,0b11111): return .CAS
            case (0b10,0b1,0b0,0b1,0b1,0b11111): return .CASL
            case (0b10,0b1,0b1,0b0,0b0,_): return .LDLAR
            case (0b10,0b1,0b1,0b0,0b1,_): return .LDAR
            case (0b10,0b1,0b1,0b1,0b0,0b11111): return .CASA
            case (0b10,0b1,0b1,0b1,0b1,0b11111): return .CASAL
                
            case (0b11,0b0,0b0,0b0,0b0,_): return .STXR
            case (0b11,0b0,0b0,0b0,0b1,_): return .STLXR
            case (0b11,0b0,0b0,0b1,0b0,_): return .STXP
            case (0b11,0b0,0b0,0b1,0b1,_): return .STLXP
            case (0b11,0b0,0b1,0b0,0b0,_): return .LDXR
            case (0b11,0b0,0b1,0b0,0b1,_): return .LDAXR
            case (0b11,0b0,0b1,0b1,0b0,_): return .LDXP
            case (0b11,0b0,0b1,0b1,0b1,_): return .LDAXP
            case (0b11,0b1,0b0,0b0,0b0,_): return .STLLR
            case (0b11,0b1,0b0,0b0,0b1,_): return .STLR
            case (0b11,0b1,0b0,0b1,0b0,0b11111): return .CAS
            case (0b11,0b1,0b0,0b1,0b1,0b11111): return .CASL
            case (0b11,0b1,0b1,0b0,0b0,_): return .LDLAR
            case (0b11,0b1,0b1,0b0,0b1,_): return .LDAR
            case (0b11,0b1,0b1,0b1,0b0,0b11111): return .CASA
            case (0b11,0b1,0b1,0b1,0b1,0b11111): return .CASAL
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
        
        private func getNextRegister(to register: ARMRegister?) -> ARMRegister? {
            guard let registerValue = register?.value else { return nil }
            return ARMGeneralPurposeRegister.getRegister(from: UInt32(registerValue) + 1, in: mode ?? .x64)
        }
    }
    
    // LDAPR/STLR (unscaled immediate)
    class LDAPRSTLR: LoadsAndStores {
        override class var supportedMnemonics: [ARMMnemonic] { [.STLURB, .LDAPURB, .LDAPURSB, .STLURH, .LDAPURH, .LDAPURSH, .STLUR, .LDAPUR, .LDAPURSW] }
        
        @ARMInstructionComponent(24..<30, enforced: 0b011001)
        var const1: UInt8?
        @ARMInstructionComponent(21..<22, enforced: 0b0)
        var const2: UInt8?
        @ARMInstructionComponent(10..<12, enforced: 0b00)
        var const3: UInt8?
        
        @ARMInstructionComponent(30..<32)
        var size: UInt8?
        @ARMInstructionComponent(22..<24)
        var opc: UInt8?
        @ARMInstructionComponent(12..<21)
        var imm9: Int16?
        @ARMInstructionComponent(16..<21)
        var rs: ARMRegister?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        override var mode: CPUMode? {
            switch mnemonic {
            case .LDAPURSB, .LDAPURSH:
                switch opc {
                case 0b10: return .x64
                case 0b11: return .w32
                default: return nil
                }
            case .STLUR, .LDAPUR:
                switch size {
                case 0b10: return .w32
                case 0b11: return .x64
                default: return nil
                }
            default: return .x64
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {[
            ARMRegisterBuilder(register: .required(rt)),
            ARMAddresBuilder(baseRegister: .required(rn), offsetImmediate: .optional(imm9))
        ]}
        
        override func setupCustomCoders() {
            _rn.customDecoder = getModeSensitiveRegisterDecoder(cpuMode: .x64)
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?)?
            switch mnemonic {
            case .STLURB: data = (0b00, 0b00)
            case .LDAPURB: data = (0b00, 0b01)
            case .LDAPURSB: data = (0b00, nil)
            case .STLURH: data = (0b01, 0b00)
            case .LDAPURH: data = (0b01, 0b01)
            case .LDAPURSH: data = (0b01, nil)
            case .STLUR: data = (nil, 0b00)
            case .LDAPUR: data = (nil, 0b01)
            default: break
            }
            $size = data?.0
            $opc = data?.1
            switch mnemonic {
            case .LDAPURSB, .LDAPURSH:
                switch mode {
                case .x64: opc = 0b10
                case .w32: opc = 0b11
                default: break
                }
            case .STLUR, .LDAPUR:
                switch mode {
                case .w32: size = 0b10
                case .x64: size = 0b11
                default: break
                }
            default: break
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let size = rawInstruction[30,32],
                let opc = rawInstruction[22,24]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (size, opc) {
            case (0b00, 0b00): return .STLURB
            case (0b00, 0b01): return .LDAPURB
            case (0b00, 0b10), (0b00, 0b11): return .LDAPURSB
            case (0b01, 0b00): return .STLURH
            case (0b01, 0b01): return .LDAPURH
            case (0b01, 0b10), (0b01, 0b11): return .LDAPURSH
            case (0b10, 0b00), (0b11, 0b00): return .STLUR
            case (0b10, 0b01), (0b11, 0b01): return .LDAPUR
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Load register (literal)
    class LoadRegisterLiteral: LoadsAndStores {
        override class var supportedMnemonics: [ARMMnemonic] { [.LDR, .LDRSW, .PRFM] }
        
        @ARMInstructionComponent(27..<30, enforced: 0b011)
        var const1: UInt8?
        @ARMInstructionComponent(24..<26, enforced: 0b00)
        var const2: UInt8?
        
        @ARMInstructionComponent(30..<32)
        var opc: UInt8?
        @ARMInstructionComponent(26..<27)
        var v: UInt8?
        @ARMInstructionComponent(5..<24)
        var imm19: UInt32?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        override var mode: CPUMode? {
            guard mnemonic == .LDR else { return .x64 }
            switch opc {
            case 0b00: return .w32
            case 0b01: return .x64
            default: return nil
            }
        }
        
        var address: Int32? {
            get {
                guard let value = imm19 else { return nil }
                let mask = value[18..<19] == 0b1 ? Int32(bitPattern: UInt32.max.masked(including: 21..<32)) : 0
                return (Int32(bitPattern: value) &<< 2) | mask
            }
            set {
                guard let value = newValue else { imm19 = nil; return }
                let mask = UInt32.max.masked(including: 0..<19)
                imm19 = UInt32(bitPattern: value &>> 2) & mask
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            switch mnemonic {
            case .PRFM: return [
                ARMImmediateBuilder(immediate: .required($rt)),
                ARMImmediateBuilder(immediate: .required(address))
            ]
            default: return [
                ARMRegisterBuilder(register: .required(rt)),
                ARMImmediateBuilder(immediate: .required(address))
            ]
            }
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?)?
            switch mnemonic {
            case .LDR: data = (nil, 0b0)
            case .LDRSW: data = (0b10, 0b0)
            case .PRFM: data = (0b11, 0b0)
            default: break
            }
            $opc = data?.0
            $v = data?.1
            if mnemonic == .LDR {
                $opc = cpuMode?.rawValue.asUInt32
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let opc = rawInstruction[30,32],
                let v = rawInstruction[26,27]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (opc, v) {
            case (0b00, 0b0), (0b01, 0b0): return .LDR
            case (0b00, 0b1), (0b01, 0b1), (0b10, 0b1): throw ARMInstructionDecoderError.unsupportedMnemonic // LDR (literal, SIMD&FP)
            case (0b10, 0b0): return .LDRSW
            case (0b11, 0b0): return .PRFM
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Load/store no-allocate pair (offset)
    class LoadStoreNoAllocatePairOffset: LoadsAndStores {
        override class var supportedMnemonics: [ARMMnemonic] { [.STNP, .LDNP] }
        
        @ARMInstructionComponent(27..<30, enforced: 0b101)
        var const1: UInt8?
        @ARMInstructionComponent(23..<26, enforced: 0b000)
        var const2: UInt8?
        
        @ARMInstructionComponent(30..<32)
        var opc: UInt8?
        @ARMInstructionComponent(26..<27)
        var v: UInt8?
        @ARMInstructionComponent(22..<23)
        var l: UInt8?
        @ARMInstructionComponent(15..<22)
        var imm7: Int16?
        @ARMInstructionComponent(10..<15)
        var rt2: ARMRegister?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        override var mode: CPUMode? {
            switch opc {
            case 0b00: return .w32
            case 0b10: return .x64
            default: return nil
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {[
            ARMRegisterBuilder(register: .required(rt)),
            ARMRegisterBuilder(register: .required(rt2)),
            ARMAddresBuilder(baseRegister: .required(rn), offsetImmediate: .optional(imm7))
        ]}
        
        override func setupCustomCoders() {
            _rn.customDecoder = getModeSensitiveRegisterDecoder(cpuMode: .x64)
            _imm7.customDecoder = getPostProcessedImmedaiteDecoder({ [weak self] in self?.mode == .x64 ? $0 &<< 3 : $0 &<< 2})
            _imm7.customEncoder = getPreProcessedImmedaiteEncoder({ [weak self] in self?.mode == .x64 ? $0 &>> 3 : $0 &>> 2})
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?)?
            switch mnemonic {
            case .STNP: data = (0b0, 0b0)
            case .LDNP: data = (0b0, 0b1)
            default: break
            }
            $v = data?.0
            $l = data?.1
            $opc = cpuMode?.rawValue.asUInt32
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let opc = rawInstruction[30,32],
                let v = rawInstruction[26,27],
                let l = rawInstruction[22,23]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (opc, v, l) {
            case (0b00, 0b0, 0b0), (0b10, 0b0, 0b0): return .STNP
            case (0b00, 0b0, 0b1), (0b10, 0b0, 0b1): return .LDNP
            case (0b00, 0b1, 0b0), (0b01, 0b1, 0b0), (0b10, 0b1, 0b0): throw ARMInstructionDecoderError.unsupportedMnemonic // STNP (SIMD&FP)
            case (0b00, 0b1, 0b1), (0b01, 0b1, 0b1), (0b10, 0b1, 0b1): throw ARMInstructionDecoderError.unsupportedMnemonic // LDNP (SIMD&FP)
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Load/store register pair (post-indexed)
    class LoadStoreRegisterPairPostIndexed: LoadsAndStores {
        override class var supportedMnemonics: [ARMMnemonic] { [.STP, .LDP, .STGP, .LDPSW] }
        
        @ARMInstructionComponent(27..<30, enforced: 0b101)
        var const1: UInt8?
        @ARMInstructionComponent(23..<26, enforced: 0b001)
        var const2: UInt8?
        
        @ARMInstructionComponent(30..<32)
        var opc: UInt8?
        @ARMInstructionComponent(26..<27)
        var v: UInt8?
        @ARMInstructionComponent(22..<23)
        var l: UInt8?
        @ARMInstructionComponent(15..<22)
        var imm7: Int16?
        @ARMInstructionComponent(10..<15)
        var rt2: ARMRegister?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        override var mode: CPUMode? {
            switch mnemonic {
            case .STP, .LDP:
                switch opc {
                case 0b00: return .w32
                case 0b10: return .x64
                default: return nil
                }
            default: return .x64
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {[
            ARMRegisterBuilder(register: .required(rt)),
            ARMRegisterBuilder(register: .required(rt2)),
            ARMAddresBuilder<Int16>(baseRegister: .required(rn)),
            ARMImmediateBuilder(immediate: .required(imm7))
        ]}
        
        override func setupCustomCoders() {
            _rn.customDecoder = getModeSensitiveRegisterDecoder(cpuMode: .x64)
            _imm7.customDecoder = getPostProcessedSignedImmedaiteDecoder({ [weak self] in self?.mode == .x64 ? $0 &<< 3 : $0 &<< 2}, bitWidth: 7)
            _imm7.customEncoder = getPreProcessedSignedImmedaiteEncoder({ [weak self] in self?.mode == .x64 ? $0 &>> 3 : $0 &>> 2}, bitWidth: 7)
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32?)?
            switch mnemonic {
            case .STP: data = (nil, 0b0, 0b0)
            case .LDP: data = (nil, 0b0, 0b1)
            case .STGP: data = (0b01, 0b0, 0b0)
            case .LDPSW: data = (0b01, 0b0, 0b1)
            default: break
            }
            $opc = data?.0
            $v = data?.1
            $l = data?.2
            switch mnemonic {
            case .STP, .LDP:
                switch cpuMode {
                case .w32: opc = 0b00
                case .x64: opc = 0b10
                default: break
                }
            default: break
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let opc = rawInstruction[30,32],
                let v = rawInstruction[26,27],
                let l = rawInstruction[22,23]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (opc, v, l) {
            case (0b00, 0b0, 0b0), (0b10, 0b0, 0b0): return .STP
            case (0b00, 0b0, 0b1), (0b10, 0b0, 0b1): return .LDP
            case (0b01, 0b0, 0b0): return .STGP
            case (0b01, 0b0, 0b1): return .LDPSW
            case (0b00, 0b1, 0b0), (0b01, 0b1, 0b0), (0b10, 0b1, 0b0): throw ARMInstructionDecoderError.unsupportedMnemonic // STP (SIMD&FP)
            case (0b00, 0b1, 0b1), (0b01, 0b1, 0b1), (0b10, 0b1, 0b1): throw ARMInstructionDecoderError.unsupportedMnemonic // LDP (SIMD&FP)
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Load/store register pair (offset)
    class LoadStoreRegisterPairOffset: LoadsAndStores {
        override class var supportedMnemonics: [ARMMnemonic] { [.STP, .LDP, .STGP, .LDPSW] }
        
        @ARMInstructionComponent(27..<30, enforced: 0b101)
        var const1: UInt8?
        @ARMInstructionComponent(23..<26, enforced: 0b010)
        var const2: UInt8?
        
        @ARMInstructionComponent(30..<32)
        var opc: UInt8?
        @ARMInstructionComponent(26..<27)
        var v: UInt8?
        @ARMInstructionComponent(22..<23)
        var l: UInt8?
        @ARMInstructionComponent(15..<22)
        var imm7: Int16?
        @ARMInstructionComponent(10..<15)
        var rt2: ARMRegister?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        override var mode: CPUMode? {
            switch mnemonic {
            case .STP, .LDP:
                switch opc {
                case 0b00: return .w32
                case 0b10: return .x64
                default: return nil
                }
            default: return .x64
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {[
            ARMRegisterBuilder(register: .required(rt)),
            ARMRegisterBuilder(register: .required(rt2)),
            ARMAddresBuilder(baseRegister: .required(rn), offsetImmediate: .optional(imm7))
        ]}
        
        override func setupCustomCoders() {
            _rn.customDecoder = getModeSensitiveRegisterDecoder(cpuMode: .x64)
            _imm7.customDecoder = getPostProcessedSignedImmedaiteDecoder({ [weak self] in self?.mode == .x64 ? $0 &<< 3 : $0 &<< 2}, bitWidth: 7)
            _imm7.customEncoder = getPreProcessedSignedImmedaiteEncoder({ [weak self] in self?.mode == .x64 ? $0 &>> 3 : $0 &>> 2}, bitWidth: 7)
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32?)?
            switch mnemonic {
            case .STP: data = (nil, 0b0, 0b0)
            case .LDP: data = (nil, 0b0, 0b1)
            case .STGP: data = (0b01, 0b0, 0b0)
            case .LDPSW: data = (0b01, 0b0, 0b1)
            default: break
            }
            $opc = data?.0
            $v = data?.1
            $l = data?.2
            switch mnemonic {
            case .STP, .LDP:
                switch cpuMode {
                case .w32: opc = 0b00
                case .x64: opc = 0b10
                default: break
                }
            default: break
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let opc = rawInstruction[30,32],
                let v = rawInstruction[26,27],
                let l = rawInstruction[22,23]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (opc, v, l) {
            case (0b00, 0b0, 0b0), (0b10, 0b0, 0b0): return .STP
            case (0b00, 0b0, 0b1), (0b10, 0b0, 0b1): return .LDP
            case (0b01, 0b0, 0b0): return .STGP
            case (0b01, 0b0, 0b1): return .LDPSW
            case (0b00, 0b1, 0b0), (0b01, 0b1, 0b0), (0b10, 0b1, 0b0): throw ARMInstructionDecoderError.unsupportedMnemonic // STP (SIMD&FP)
            case (0b00, 0b1, 0b1), (0b01, 0b1, 0b1), (0b10, 0b1, 0b1): throw ARMInstructionDecoderError.unsupportedMnemonic // LDP (SIMD&FP)
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Load/store register pair (pre-indexed)
    class LoadStoreRegisterPairPreIndexed: LoadsAndStores {
        override class var supportedMnemonics: [ARMMnemonic] { [.STP, .LDP, .STGP, .LDPSW] }
        
        @ARMInstructionComponent(27..<30, enforced: 0b101)
        var const1: UInt8?
        @ARMInstructionComponent(23..<26, enforced: 0b011)
        var const2: UInt8?
        
        @ARMInstructionComponent(30..<32)
        var opc: UInt8?
        @ARMInstructionComponent(26..<27)
        var v: UInt8?
        @ARMInstructionComponent(22..<23)
        var l: UInt8?
        @ARMInstructionComponent(15..<22)
        var imm7: Int16?
        @ARMInstructionComponent(10..<15)
        var rt2: ARMRegister?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        override var mode: CPUMode? {
            switch mnemonic {
            case .STP, .LDP:
                switch opc {
                case 0b00: return .w32
                case 0b10: return .x64
                default: return nil
                }
            default: return .x64
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {[
            ARMRegisterBuilder(register: .required(rt)),
            ARMRegisterBuilder(register: .required(rt2)),
            ARMAddresBuilder(baseRegister: .required(rn), offsetImmediate: .required(imm7), indexingMode: .pre)
        ]}
        
        override func setupCustomCoders() {
            _rn.customDecoder = getModeSensitiveRegisterDecoder(cpuMode: .x64)
            _imm7.customDecoder = getPostProcessedSignedImmedaiteDecoder({ [weak self] in self?.mode == .x64 ? $0 &<< 3 : $0 &<< 2}, bitWidth: 7)
            _imm7.customEncoder = getPreProcessedSignedImmedaiteEncoder({ [weak self] in self?.mode == .x64 ? $0 &>> 3 : $0 &>> 2}, bitWidth: 7)
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32?)?
            switch mnemonic {
            case .STP: data = (nil, 0b0, 0b0)
            case .LDP: data = (nil, 0b0, 0b1)
            case .STGP: data = (0b01, 0b0, 0b0)
            case .LDPSW: data = (0b01, 0b0, 0b1)
            default: break
            }
            $opc = data?.0
            $v = data?.1
            $l = data?.2
            switch mnemonic {
            case .STP, .LDP:
                switch cpuMode {
                case .w32: opc = 0b00
                case .x64: opc = 0b10
                default: break
                }
            default: break
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let opc = rawInstruction[30,32],
                let v = rawInstruction[26,27],
                let l = rawInstruction[22,23]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (opc, v, l) {
            case (0b00, 0b0, 0b0), (0b10, 0b0, 0b0): return .STP
            case (0b00, 0b0, 0b1), (0b10, 0b0, 0b1): return .LDP
            case (0b01, 0b0, 0b0): return .STGP
            case (0b01, 0b0, 0b1): return .LDPSW
            case (0b00, 0b1, 0b0), (0b01, 0b1, 0b0), (0b10, 0b1, 0b0): throw ARMInstructionDecoderError.unsupportedMnemonic // STP (SIMD&FP)
            case (0b00, 0b1, 0b1), (0b01, 0b1, 0b1), (0b10, 0b1, 0b1): throw ARMInstructionDecoderError.unsupportedMnemonic // LDP (SIMD&FP)
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Load/store register (unscaled immediate)
    class LoadStoreRegisterUnscaledImmediate: LoadsAndStores {
        override class var supportedMnemonics: [ARMMnemonic] { [.STURB, .LDURB, .LDURSB, .STUR, .LDUR, .STURH, .LDURH, .LDURSH, .LDURSW, .PRFUM] }
        
        @ARMInstructionComponent(27..<30, enforced: 0b111)
        var const1: UInt8?
        @ARMInstructionComponent(24..<26, enforced: 0b00)
        var const2: UInt8?
        @ARMInstructionComponent(21..<22, enforced: 0b0)
        var const3: UInt8?
        @ARMInstructionComponent(10..<12, enforced: 0b00)
        var const4: UInt8?
        
        @ARMInstructionComponent(30..<32)
        var size: UInt8?
        @ARMInstructionComponent(26..<27)
        var v: UInt8?
        @ARMInstructionComponent(22..<24)
        var opc: UInt8?
        @ARMInstructionComponent(12..<21)
        var imm9: Int16?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        override var mode: CPUMode? {
            switch mnemonic {
            case .LDURSB, .LDURSH:
                switch opc {
                case 0b10: return .x64
                case 0b11: return .w32
                default: return nil
                }
            case .STUR, .LDUR:
                switch size {
                case 0b10: return .x64
                case 0b11: return .w32
                default: return nil
                }
            default: return .x64
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            let offsetImmediate = imm9 != 0 ? imm9 : nil
            switch mnemonic {
            case .PRFUM: return [
                ARMImmediateBuilder(immediate: .required($rt)),
                ARMAddresBuilder(baseRegister: .required(rn), offsetImmediate: .optional(offsetImmediate))
            ]
            case .STURB, .LDURB, .LDURSB, .STUR, .LDUR, .STURH, .LDURH, .LDURSH, .LDURSW: return [
                ARMRegisterBuilder(register: .required(rt)),
                ARMAddresBuilder(baseRegister: .required(rn), offsetImmediate: .optional(offsetImmediate))
            ]
            default: return []
            }
        }
        
        override func setupCustomCoders() {
            _rn.customDecoder = getModeSensitiveRegisterDecoder(cpuMode: .x64)
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?, UInt32?, UInt32?)?
            switch mnemonic {
            case .STURB: data = (0b00, 0b0, 0b00)
            case .LDURB: data = (0b00, 0b0, 0b01)
            case .LDURSB: data = (0b00, 0b0, nil)
            case .STURH: data = (0b01, 0b0, 0b00)
            case .LDURH: data = (0b01, 0b0, 0b01)
            case .LDURSH: data = (0b01, 0b0, nil)
            case .STUR: data = (nil, 0b0, 0b00)
            case .LDUR: data = (nil, 0b0, 0b01)
            case .LDURSW: data = (0b10, 0b0, 0b10)
            case .PRFUM: data = (0b11, 0b0, 0b10)
            default: break
            }
            $size = data?.0
            $v = data?.1
            $opc = data?.2
            switch mnemonic {
            case .LDURSB, .LDURSH:
                switch cpuMode {
                case .x64: opc = 0b10
                case .w32: opc = 0b11
                default: break
                }
            case .STUR, .LDUR:
                switch cpuMode {
                case .x64: size = 0b10
                case .w32: size = 0b11
                default: break
                }
            default: break
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let size = rawInstruction[30,32],
                let v = rawInstruction[26,27],
                let opc = rawInstruction[22,24]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (size, v, opc) {
            case (0b00, 0b0, 0b00): return .STURB
            case (0b00, 0b0, 0b01): return .LDURB
            case (0b00, 0b0, 0b10), (0b00, 0b0, 0b11): return .LDURSB
            case (0b00, 0b1, 0b00), (0b00, 0b1, 0b10), (0b01, 0b1, 0b00), (0b10, 0b1, 0b00), (0b11, 0b1, 0b00): throw ARMInstructionDecoderError.unsupportedMnemonic // STUR (SIMD&FP)
            case (0b00, 0b1, 0b01), (0b00, 0b1, 0b11), (0b01, 0b1, 0b01), (0b10, 0b1, 0b01), (0b11, 0b1, 0b01): throw ARMInstructionDecoderError.unsupportedMnemonic // LDUR (SIMD&FP)
            case (0b01, 0b0, 0b00): return .STURH
            case (0b01, 0b0, 0b01): return .LDURH
            case (0b01, 0b0, 0b10), (0b01, 0b0, 0b11): return .LDURSH
            case (0b10, 0b0, 0b00), (0b11, 0b0, 0b00): return .STUR
            case (0b10, 0b0, 0b01), (0b11, 0b0, 0b01): return .LDUR
            case (0b10, 0b0, 0b10): return .LDURSW
            case (0b11, 0b0, 0b10): return .PRFUM
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Load/store register (immediate post-indexed)
    class LoadStoreRegisterImmediatePostIndexed: LoadsAndStores {
        override class var supportedMnemonics: [ARMMnemonic] { [.STRB, .LDRB, .LDRSB, .STR, .LDR, .STRH, .LDRH, .LDRSH] }
        
        @ARMInstructionComponent(27..<30, enforced: 0b111)
        var const1: UInt8?
        @ARMInstructionComponent(24..<26, enforced: 0b00)
        var const2: UInt8?
        @ARMInstructionComponent(21..<22, enforced: 0b0)
        var const3: UInt8?
        @ARMInstructionComponent(10..<12, enforced: 0b01)
        var const4: UInt8?
        
        @ARMInstructionComponent(30..<32)
        var size: UInt8?
        @ARMInstructionComponent(26..<27)
        var v: UInt8?
        @ARMInstructionComponent(22..<24)
        var opc: UInt8?
        @ARMInstructionComponent(12..<21)
        var imm9: Int16?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        override var mode: CPUMode? {
            switch mnemonic {
            case .LDRSB, .LDRSH:
                switch opc {
                case 0b10: return .x64
                case 0b11: return .w32
                default: return nil
                }
            case .STR, .LDR:
                switch size {
                case 0b10: return .x64
                case 0b11: return .w32
                default: return nil
                }
            default: return .x64
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {[
            ARMRegisterBuilder(register: .required(rt)),
            ARMAddresBuilder<Int16>(baseRegister: .required(rn)),
            ARMImmediateBuilder(immediate: .required(imm9))
        ]}
        
        override func setupCustomCoders() {
            _rn.customDecoder = getModeSensitiveRegisterDecoder(cpuMode: .x64)
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?, UInt32?, UInt32?)?
            switch mnemonic {
            case .STRB: data = (0b00, 0b0, 0b00)
            case .LDRB: data = (0b00, 0b0, 0b01)
            case .LDRSB: data = (0b00, 0b0, nil)
            case .STRH: data = (0b01, 0b0, 0b00)
            case .LDRH: data = (0b01, 0b0, 0b01)
            case .LDRSH: data = (0b01, 0b0, nil)
            case .STR: data = (nil, 0b0, 0b00)
            case .LDR: data = (nil, 0b0, 0b01)
            case .LDRSW: data = (0b10, 0b0, 0b10)
            default: break
            }
            $size = data?.0
            $v = data?.1
            $opc = data?.2
            switch mnemonic {
            case .LDRSB, .LDRSH:
                switch cpuMode {
                case .x64: opc = 0b10
                case .w32: opc = 0b11
                default: break
                }
            case .STR, .LDR:
                switch cpuMode {
                case .x64: size = 0b10
                case .w32: size = 0b11
                default: break
                }
            default: break
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let size = rawInstruction[30,32],
                let v = rawInstruction[26,27],
                let opc = rawInstruction[22,24]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (size, v, opc) {
            case (0b00, 0b0, 0b00): return .STRB
            case (0b00, 0b0, 0b01): return .LDRB
            case (0b00, 0b0, 0b10), (0b00, 0b0, 0b11): return .LDRSB
            case (0b00, 0b1, 0b00), (0b00, 0b1, 0b10), (0b01, 0b1, 0b00), (0b10, 0b1, 0b00), (0b11, 0b1, 0b00): throw ARMInstructionDecoderError.unsupportedMnemonic // STR (SIMD&FP)
            case (0b00, 0b1, 0b01), (0b00, 0b1, 0b11), (0b01, 0b1, 0b01), (0b10, 0b1, 0b01), (0b11, 0b1, 0b01): throw ARMInstructionDecoderError.unsupportedMnemonic // LDR (SIMD&FP)
            case (0b01, 0b0, 0b00): return .STRH
            case (0b01, 0b0, 0b01): return .LDRH
            case (0b01, 0b0, 0b10), (0b01, 0b0, 0b11): return .LDRSH
            case (0b10, 0b0, 0b00), (0b11, 0b0, 0b00): return .STR
            case (0b10, 0b0, 0b01), (0b11, 0b0, 0b01): return .LDR
            case (0b10, 0b0, 0b10): return .LDRSW
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Load/store register (unprivileged)
    class LoadStoreRegisterUnprivileged: LoadsAndStores {
        override class var supportedMnemonics: [ARMMnemonic] { [.STTRB, .LDTRB, .LDTRSB, .STTRH, .LDTRH, .LDTRSH, .STTR, .LDTR, .LDTRSW] }
        
        @ARMInstructionComponent(27..<30, enforced: 0b111)
        var const1: UInt8?
        @ARMInstructionComponent(24..<26, enforced: 0b00)
        var const2: UInt8?
        @ARMInstructionComponent(21..<22, enforced: 0b0)
        var const3: UInt8?
        @ARMInstructionComponent(10..<12, enforced: 0b10)
        var const4: UInt8?
        
        @ARMInstructionComponent(30..<32)
        var size: UInt8?
        @ARMInstructionComponent(26..<27)
        var v: UInt8?
        @ARMInstructionComponent(22..<24)
        var opc: UInt8?
        @ARMInstructionComponent(12..<21)
        var imm9: Int16?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        override var mode: CPUMode? {
            switch mnemonic {
            case .LDTRSB, .LDTRSH:
                switch opc {
                case 0b10: return .x64
                case 0b11: return .w32
                default: return nil
                }
            case .STTR, .LDTR:
                switch size {
                case 0b10: return .x64
                case 0b11: return .w32
                default: return nil
                }
            default: return .x64
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {[
            ARMRegisterBuilder(register: .required(rt)),
            ARMAddresBuilder<Int16>(baseRegister: .required(rn), offsetImmediate: .optional(imm9 != 0 ? imm9 : nil))
        ]}
        
        override func setupCustomCoders() {
            _rn.customDecoder = getModeSensitiveRegisterDecoder(cpuMode: .x64)
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?, UInt32?, UInt32?)?
            switch mnemonic {
            case .STTRB: data = (0b00, 0b0, 0b00)
            case .LDTRB: data = (0b00, 0b0, 0b01)
            case .LDTRSB: data = (0b00, 0b0, nil)
            case .STTRH: data = (0b01, 0b0, 0b00)
            case .LDTRH: data = (0b01, 0b0, 0b01)
            case .LDTRSH: data = (0b01, 0b0, nil)
            case .STTR: data = (nil, 0b0, 0b00)
            case .LDTR: data = (nil, 0b0, 0b01)
            case .LDTRSW: data = (0b10, 0b0, 0b10)
            default: break
            }
            $size = data?.0
            $v = data?.1
            $opc = data?.2
            switch mnemonic {
            case .LDTRSB, .LDTRSH:
                switch cpuMode {
                case .x64: opc = 0b10
                case .w32: opc = 0b11
                default: break
                }
            case .STTR, .LDTR:
                switch cpuMode {
                case .x64: size = 0b10
                case .w32: size = 0b11
                default: break
                }
            default: break
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let size = rawInstruction[30,32],
                let v = rawInstruction[26,27],
                let opc = rawInstruction[22,24]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (size, v, opc) {
            case (0b00, 0b0, 0b00): return .STTRB
            case (0b00, 0b0, 0b01): return .LDTRB
            case (0b00, 0b0, 0b10), (0b00, 0b0, 0b11): return .LDTRSB
            case (0b01, 0b0, 0b00): return .STTRH
            case (0b01, 0b0, 0b01): return .LDTRH
            case (0b01, 0b0, 0b10), (0b01, 0b0, 0b11): return .LDTRSH
            case (0b10, 0b0, 0b00), (0b11, 0b0, 0b00): return .STTR
            case (0b10, 0b0, 0b01), (0b11, 0b0, 0b01): return .LDTR
            case (0b10, 0b0, 0b10): return .LDTRSW
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Load/store register (immediate pre-indexed)
    class LoadStoreRegisterImmediatePreIndexed: LoadsAndStores {
        override class var supportedMnemonics: [ARMMnemonic] { [.STRB, .LDRB, .LDRSB, .STR, .LDR, .STRH, .LDRH, .LDRSH, .LDRSW] }
        
        @ARMInstructionComponent(27..<30, enforced: 0b111)
        var const1: UInt8?
        @ARMInstructionComponent(24..<26, enforced: 0b00)
        var const2: UInt8?
        @ARMInstructionComponent(21..<22, enforced: 0b0)
        var const3: UInt8?
        @ARMInstructionComponent(10..<12, enforced: 0b11)
        var const4: UInt8?
        
        @ARMInstructionComponent(30..<32)
        var size: UInt8?
        @ARMInstructionComponent(26..<27)
        var v: UInt8?
        @ARMInstructionComponent(22..<24)
        var opc: UInt8?
        @ARMInstructionComponent(12..<21)
        var imm9: Int16?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        override var mode: CPUMode? {
            switch mnemonic {
            case .LDRSB, .LDRSH:
                switch opc {
                case 0b10: return .x64
                case 0b11: return .w32
                default: return nil
                }
            case .STR, .LDR:
                switch size {
                case 0b10: return .x64
                case 0b11: return .w32
                default: return nil
                }
            default: return .x64
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {[
            ARMRegisterBuilder(register: .required(rt)),
            ARMAddresBuilder(baseRegister: .required(rn), offsetImmediate: .required(imm9), indexingMode: .pre)
        ]}
        
        override func setupCustomCoders() {
            _rn.customDecoder = getModeSensitiveRegisterDecoder(cpuMode: .x64)
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?, UInt32?, UInt32?)?
            switch mnemonic {
            case .STRB: data = (0b00, 0b0, 0b00)
            case .LDRB: data = (0b00, 0b0, 0b01)
            case .LDRSB: data = (0b00, 0b0, nil)
            case .STRH: data = (0b01, 0b0, 0b00)
            case .LDRH: data = (0b01, 0b0, 0b01)
            case .LDRSH: data = (0b01, 0b0, nil)
            case .STR: data = (nil, 0b0, 0b00)
            case .LDR: data = (nil, 0b0, 0b01)
            case .LDRSW: data = (0b10, 0b0, 0b10)
            default: break
            }
            $size = data?.0
            $v = data?.1
            $opc = data?.2
            switch mnemonic {
            case .LDRSB, .LDRSH:
                switch cpuMode {
                case .x64: opc = 0b10
                case .w32: opc = 0b11
                default: break
                }
            case .STR, .LDR:
                switch cpuMode {
                case .x64: size = 0b10
                case .w32: size = 0b11
                default: break
                }
            default: break
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let size = rawInstruction[30,32],
                let v = rawInstruction[26,27],
                let opc = rawInstruction[22,24]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (size, v, opc) {
            case (0b00, 0b0, 0b00): return .STRB
            case (0b00, 0b0, 0b01): return .LDRB
            case (0b00, 0b0, 0b10), (0b00, 0b0, 0b11): return .LDRSB
            case (0b00, 0b1, 0b00), (0b00, 0b1, 0b10), (0b01, 0b1, 0b00), (0b10, 0b1, 0b00), (0b11, 0b1, 0b00): throw ARMInstructionDecoderError.unsupportedMnemonic // STR (immediate, SIMD&FP)
            case (0b00, 0b1, 0b01), (0b00, 0b1, 0b11), (0b01, 0b1, 0b01), (0b10, 0b1, 0b01), (0b11, 0b1, 0b01): throw ARMInstructionDecoderError.unsupportedMnemonic // LDR (immediate, SIMD&FP)
            case (0b01, 0b0, 0b00): return .STRH
            case (0b01, 0b0, 0b01): return .LDRH
            case (0b01, 0b0, 0b10), (0b01, 0b0, 0b11): return .LDRSH
            case (0b10, 0b0, 0b00), (0b11, 0b0, 0b00): return .STR
            case (0b10, 0b0, 0b01), (0b11, 0b0, 0b01): return .LDR
            case (0b10, 0b0, 0b10): return .LDRSW
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Atomic memory operations
    class AtomicMemoryOperations: LoadsAndStores {
        override class var supportedMnemonics: [ARMMnemonic] {[
            .LDADDB, .LDADDAB, .LDADDALB, .LDADDLB,
            .LDCLRB, .LDCLRAB, .LDCLRALB, .LDCLRLB,
            .LDEORB, .LDEORAB, .LDEORALB, .LDEORLB,
            .LDSETB, .LDSETAB, .LDSETALB, .LDSETLB,
            .LDSMAXB, .LDSMAXAB, .LDSMAXALB, .LDSMAXLB,
            .LDSMINB, .LDSMINAB, .LDSMINALB, .LDSMINLB,
            .LDUMAXB, .LDUMAXAB, .LDUMAXALB, .LDUMAXLB,
            .LDUMINB, .LDUMINAB, .LDUMINALB, .LDUMINLB,
            .SWPB, .SWPAB, .SWPALB, .SWPLB,
            .LDAPRB,
            .LDADDH, .LDADDAH, .LDADDALH, .LDADDLH,
            .LDCLRH, .LDCLRAH, .LDCLRALH, .LDCLRLH,
            .LDEORH, .LDEORAH, .LDEORALH, .LDEORLH,
            .LDSETH, .LDSETAH, .LDSETALH, .LDSETLH,
            .LDSMAXH, .LDSMAXAH, .LDSMAXALH, .LDSMAXLH,
            .LDSMINH, .LDSMINAH, .LDSMINALH, .LDSMINLH,
            .LDUMAXH, .LDUMAXAH, .LDUMAXALH, .LDUMAXLH,
            .LDUMINH, .LDUMINAH, .LDUMINALH, .LDUMINLH,
            .SWPH, .SWPAH, .SWPALH, .SWPLH,
            .LDADD, .LDADDA, .LDADDAL, .LDADDL,
            .LDCLR, .LDCLRA, .LDCLRAL, .LDCLRL,
            .LDEOR, .LDEORA, .LDEORAL, .LDEORL,
            .LDSET, .LDSETA, .LDSETAL, .LDSETL,
            .LDSMAX, .LDSMAXA, .LDSMAXAL, .LDSMAXL,
            .LDSMIN, .LDSMINA, .LDSMINAL, .LDSMINL,
            .LDUMAX, .LDUMAXA, .LDUMAXAL, .LDUMAXL,
            .LDUMIN, .LDUMINA, .LDUMINAL, .LDUMINL,
            .SWP, .SWPA, .SWPAL, .SWPL,
            .LDAPR,
            .ST64BV0,
            .ST64BV,
            .ST64B,
            .LD64B,
            .STADDB, .STADDLB,
            .STCLRB, .STCLRLB,
            .STEORB, .STEORLB,
            .STSETB, .STSETLB,
            .STSMAXB, .STSMAXLB,
            .SSTSMINB, .STSMINLB,
            .STUMAXB, .STUMAXLB,
            .STUMINB, .STUMINLB,
            .STADDH, .STADDLH,
            .STCLRH, .STCLRLH,
            .STEORH, .STEORLH,
            .STSETH, .STSETLH,
            .STSMAXH, .STSMAXLH,
            .SSTSMINH, .STSMINLH,
            .STUMAXH, .STUMAXLH,
            .STUMINH, .STUMINLH,
            .STADD, .STADDL,
            .STCLR, .STCLRL,
            .STEOR, .STEORL,
            .STSET, .STSETL,
            .STSMAX, .STSMAXL,
            .SSTSMIN, .STSMINL,
            .STUMAX, .STUMAXL,
            .STUMIN, .STUMINL,
        ]}
        
        @ARMInstructionComponent(27..<30, enforced: 0b111)
        var const1: UInt8?
        @ARMInstructionComponent(24..<26, enforced: 0b00)
        var const2: UInt8?
        @ARMInstructionComponent(21..<22, enforced: 0b1)
        var const3: UInt8?
        @ARMInstructionComponent(10..<12, enforced: 0b00)
        var const4: UInt8?
        
        @ARMInstructionComponent(30..<32)
        var size: UInt8?
        @ARMInstructionComponent(26..<27)
        var v: UInt8?
        @ARMInstructionComponent(23..<24)
        var a: UInt8?
        @ARMInstructionComponent(22..<23)
        var r: UInt8?
        @ARMInstructionComponent(16..<21)
        var rs: ARMRegister?
        @ARMInstructionComponent(15..<16)
        var o3: UInt8?
        @ARMInstructionComponent(12..<15)
        var opc: UInt8?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        override var mode: CPUMode? {
            switch size {
            case 0b00, 0b01, 0b10: return .w32
            case 0b11: return .x64
            default: return nil
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            switch mnemonic {
            case .LDAPRB, .LDAPR, .ST64B, .LD64B: return [
                ARMRegisterBuilder(register: .required(rt)),
                ARMAddresBuilder<UInt8>(baseRegister: .required(rn))
            ]
            case .STADDB, .STADDLB, .STCLRB, .STCLRLB, .STEORB, .STEORLB, .STSETB, .STSETLB, .STSMAXB, .STSMAXLB, .SSTSMINB, .STSMINLB, .STUMAXB, .STUMAXLB, .STUMINB, .STUMINLB, .STADDH, .STADDLH, .STCLRH, .STCLRLH, .STEORH, .STEORLH, .STSETH, .STSETLH, .STSMAXH, .STSMAXLH, .SSTSMINH, .STSMINLH, .STUMAXH, .STUMAXLH, .STUMINH, .STUMINLH, .STADD, .STADDL, .STCLR, .STCLRL, .STEOR, .STEORL, .STSET, .STSETL, .STSMAX, .STSMAXL, .SSTSMIN, .STSMINL, .STUMAX, .STUMAXL, .STUMIN, .STUMINL: return [
                ARMRegisterBuilder(register: .required(rs)),
                ARMAddresBuilder<UInt8>(baseRegister: .required(rn))
            ]
            default:
                if Self.supportedMnemonics.contains(mnemonic) {
                    return [
                        ARMRegisterBuilder(register: .required(rs)),
                        ARMRegisterBuilder(register: .required(rt)),
                        ARMAddresBuilder<UInt8>(baseRegister: .required(rn))
                    ]
                } else { return [] }
            }
        }
        
        override func describe() throws -> String {
            guard a == 0 && rt?.value == 0b11111 else {
                return try buildString(for: mnemonic)
            }
            switch mnemonic {
            case .LDADDB, .LDADDAB:
                return try buildString(for: .STADDB) // STADDB, STADDLB
            case .LDADDALB, .LDADDLB:
                return try buildString(for: .STADDLB)
            case .LDCLRB, .LDCLRAB:
                return try buildString(for: .STCLRB) // STCLRB, STCLRLB
            case .LDCLRALB, .LDCLRLB:
                return try buildString(for: .STCLRLB)
            case .LDEORB, .LDEORAB:
                return try buildString(for: .STEORB) // STEORB, STEORLB
            case .LDEORALB, .LDEORLB:
                return try buildString(for: .STEORLB)
            case .LDSETB, .LDSETAB:
                return try buildString(for: .STSETB) // STSETB, STSETLB
            case .LDSETALB, .LDSETLB:
                return try buildString(for: .STSETLB)
            case .LDSMAXB, .LDSMAXAB:
                return try buildString(for: .STSMAXB) // STSMAXB, STSMAXLB
            case .LDSMAXALB, .LDSMAXLB:
                return try buildString(for: .STSMAXLB)
            case .LDSMINB, .LDSMINAB:
                return try buildString(for: .SSTSMINB) // SSTSMINB, STSMINLB
            case .LDSMINALB, .LDSMINLB:
                return try buildString(for: .STSMINLB)
            case .LDUMAXB, .LDUMAXAB:
                return try buildString(for: .STUMAXB) // STUMAXB, STUMAXLB
            case .LDUMAXALB, .LDUMAXLB:
                return try buildString(for: .STUMAXLB)
            case .LDUMINB, .LDUMINAB:
                return try buildString(for: .STUMINB) // STUMINB, STUMINLB
            case .LDUMINALB, .LDUMINLB:
                return try buildString(for: .STUMINLB)
            
            case .LDADDH, .LDADDAH:
                return try buildString(for: .STADDH) // STADDH, STADDLH
            case .LDADDALH, .LDADDLH:
                return try buildString(for: .STADDLH)
            case .LDCLRH, .LDCLRAH:
                return try buildString(for: .STCLRH) // STCLRH, STCLRLH
            case .LDCLRALH, .LDCLRLH:
                return try buildString(for: .STCLRLH)
            case .LDEORH, .LDEORAH:
                return try buildString(for: .STEORH) // STEORH, STEORLH
            case .LDEORALH, .LDEORLH:
                return try buildString(for: .STEORLH)
            case .LDSETH, .LDSETAH:
                return try buildString(for: .STSETH) // STSETH, STSETLH
            case .LDSETALH, .LDSETLH:
                return try buildString(for: .STSETLH)
            case .LDSMAXH, .LDSMAXAH:
                return try buildString(for: .STSMAXH) // STSMAXH, STSMAXLH
            case .LDSMAXALH, .LDSMAXLH:
                return try buildString(for: .STSMAXLH)
            case .LDSMINH, .LDSMINAH:
                return try buildString(for: .SSTSMINH) // SSTSMINH, STSMINLH
            case .LDSMINALH, .LDSMINLH:
                return try buildString(for: .STSMINLH)
            case .LDUMAXH, .LDUMAXAH:
                return try buildString(for: .STUMAXH) // STUMAXH, STUMAXLH
            case .LDUMAXALH, .LDUMAXLH:
                return try buildString(for: .STUMAXLH)
            case .LDUMINH, .LDUMINAH:
                return try buildString(for: .STUMINH) // STUMINH, STUMINLH
            case .LDUMINALH, .LDUMINLH:
                return try buildString(for: .STUMINLH)
                
            case .LDADD, .LDADDA:
                return try buildString(for: .STADD) // STADD, STADDL
            case .LDADDAL, .LDADDL:
                return try buildString(for: .STADDL)
            case .LDCLR, .LDCLRA:
                return try buildString(for: .STCLR) // STCLR, STCLRL
            case .LDCLRAL, .LDCLRL:
                return try buildString(for: .STCLRL)
            case .LDEOR, .LDEORA:
                return try buildString(for: .STEOR) // STEOR, STEORL
            case .LDEORAL, .LDEORL:
                return try buildString(for: .STEORL)
            case .LDSET, .LDSETA:
                return try buildString(for: .STSET) // STSET, STSETL
            case .LDSETAL, .LDSETL:
                return try buildString(for: .STSETL)
            case .LDSMAX, .LDSMAXA:
                return try buildString(for: .STSMAX) // STSMAX, STSMAXL
            case .LDSMAXAL, .LDSMAXL:
                return try buildString(for: .STSMAXL)
            case .LDSMIN, .LDSMINA:
                return try buildString(for: .SSTSMIN) // SSTSMIN, STSMINL
            case .LDSMINAL, .LDSMINL:
                return try buildString(for: .STSMINL)
            case .LDUMAX, .LDUMAXA:
                return try buildString(for: .STUMAX) // STUMAX, STUMAXL
            case .LDUMAXAL, .LDUMAXL:
                return try buildString(for: .STUMAXL)
            case .LDUMIN, .LDUMINA:
                return try buildString(for: .STUMIN) // STUMIN, STUMINL
            case .LDUMINAL, .LDUMINL:
                return try buildString(for: .STUMINL)
            default: break
            }
            return try buildString(for: mnemonic)
        }
        
        override func setupCustomCoders() {
            _rn.customDecoder = getModeSensitiveRegisterDecoder(cpuMode: .x64)
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let size = rawInstruction[30,32],
                let v = rawInstruction[26,27],
                let a = rawInstruction[23,24],
                let r = rawInstruction[22,23],
                let rs = rawInstruction[16,21],
                let o3 = rawInstruction[15,16],
                let opc = rawInstruction[12,15]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch size {
            case 0b00: return try getBVersionMnemonic(v: v, a: a, r: r, o3: o3, opc: opc)
            case 0b01: return try getHVersionMnemonic(v: v, a: a, r: r, o3: o3, opc: opc)
            case 0b10, 0b11: return try getBaseVersionMnemonic(size: size, v: v, a: a, r: r, rs: rs, o3: o3, opc: opc)
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
        
        private static func getBVersionMnemonic(v: RawARMInstruction, a: RawARMInstruction, r: RawARMInstruction, o3: RawARMInstruction, opc: RawARMInstruction) throws -> ARMMnemonic {
            guard v == 0b0 else { throw ARMInstructionDecoderError.unrecognizedInstruction }
            switch (a,r,o3,opc) {
            case (0b0, 0b0, 0b0, 0b000): return .LDADDB
            case (0b0, 0b0, 0b0, 0b001): return .LDCLRB
            case (0b0, 0b0, 0b0, 0b010): return .LDEORB
            case (0b0, 0b0, 0b0, 0b011): return .LDSETB
            case (0b0, 0b0, 0b0, 0b100): return .LDSMAXB
            case (0b0, 0b0, 0b0, 0b101): return .LDSMINB
            case (0b0, 0b0, 0b0, 0b110): return .LDUMAXB
            case (0b0, 0b0, 0b0, 0b111): return .LDUMINB
            case (0b0, 0b0, 0b1, 0b000): return .SWPB
            case (0b0, 0b1, 0b0, 0b000): return .LDADDLB
            case (0b0, 0b1, 0b0, 0b001): return .LDCLRLB
            case (0b0, 0b1, 0b0, 0b010): return .LDEORLB
            case (0b0, 0b1, 0b0, 0b011): return .LDSETLB
            case (0b0, 0b1, 0b0, 0b100): return .LDSMAXLB
            case (0b0, 0b1, 0b0, 0b101): return .LDSMINLB
            case (0b0, 0b1, 0b0, 0b110): return .LDUMAXLB
            case (0b0, 0b1, 0b0, 0b111): return .LDUMINLB
            case (0b0, 0b1, 0b1, 0b000): return .SWPLB
            case (0b1, 0b0, 0b0, 0b000): return .LDADDAB
            case (0b1, 0b0, 0b0, 0b001): return .LDCLRAB
            case (0b1, 0b0, 0b0, 0b010): return .LDEORAB
            case (0b1, 0b0, 0b0, 0b011): return .LDSETAB
            case (0b1, 0b0, 0b0, 0b100): return .LDSMAXAB
            case (0b1, 0b0, 0b0, 0b101): return .LDSMINAB
            case (0b1, 0b0, 0b0, 0b110): return .LDUMAXAB
            case (0b1, 0b0, 0b0, 0b111): return .LDUMINAB
            case (0b1, 0b0, 0b1, 0b000): return .SWPAB
            case (0b1, 0b0, 0b1, 0b100): return .LDAPRB
            case (0b1, 0b1, 0b0, 0b000): return .LDADDALB
            case (0b1, 0b1, 0b0, 0b001): return .LDCLRALB
            case (0b1, 0b1, 0b0, 0b010): return .LDEORALB
            case (0b1, 0b1, 0b0, 0b011): return .LDSETALB
            case (0b1, 0b1, 0b0, 0b100): return .LDSMAXALB
            case (0b1, 0b1, 0b0, 0b101): return .LDSMINALB
            case (0b1, 0b1, 0b0, 0b110): return .LDUMAXALB
            case (0b1, 0b1, 0b0, 0b111): return .LDUMINALB
            case (0b1, 0b1, 0b1, 0b000): return .SWPALB
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
        
        private static func getHVersionMnemonic(v: RawARMInstruction, a: RawARMInstruction, r: RawARMInstruction, o3: RawARMInstruction, opc: RawARMInstruction) throws -> ARMMnemonic {
            guard v == 0b0 else { throw ARMInstructionDecoderError.unrecognizedInstruction }
            switch (a,r,o3,opc) {
            case (0b0, 0b0, 0b0, 0b000): return .LDADDH
            case (0b0, 0b0, 0b0, 0b001): return .LDCLRH
            case (0b0, 0b0, 0b0, 0b010): return .LDEORH
            case (0b0, 0b0, 0b0, 0b011): return .LDSETH
            case (0b0, 0b0, 0b0, 0b100): return .LDSMAXH
            case (0b0, 0b0, 0b0, 0b101): return .LDSMINH
            case (0b0, 0b0, 0b0, 0b110): return .LDUMAXH
            case (0b0, 0b0, 0b0, 0b111): return .LDUMINH
            case (0b0, 0b0, 0b1, 0b000): return .SWPH
            case (0b0, 0b1, 0b0, 0b000): return .LDADDLH
            case (0b0, 0b1, 0b0, 0b001): return .LDCLRLH
            case (0b0, 0b1, 0b0, 0b010): return .LDEORLH
            case (0b0, 0b1, 0b0, 0b011): return .LDSETLH
            case (0b0, 0b1, 0b0, 0b100): return .LDSMAXLH
            case (0b0, 0b1, 0b0, 0b101): return .LDSMINLH
            case (0b0, 0b1, 0b0, 0b110): return .LDUMAXLH
            case (0b0, 0b1, 0b0, 0b111): return .LDUMINLH
            case (0b0, 0b1, 0b1, 0b000): return .SWPLH
            case (0b1, 0b0, 0b0, 0b000): return .LDADDAH
            case (0b1, 0b0, 0b0, 0b001): return .LDCLRAH
            case (0b1, 0b0, 0b0, 0b010): return .LDEORAH
            case (0b1, 0b0, 0b0, 0b011): return .LDSETAH
            case (0b1, 0b0, 0b0, 0b100): return .LDSMAXAH
            case (0b1, 0b0, 0b0, 0b101): return .LDSMINAH
            case (0b1, 0b0, 0b0, 0b110): return .LDUMAXAH
            case (0b1, 0b0, 0b0, 0b111): return .LDUMINAH
            case (0b1, 0b0, 0b1, 0b000): return .SWPAH
            case (0b1, 0b1, 0b0, 0b000): return .LDADDALH
            case (0b1, 0b1, 0b0, 0b001): return .LDCLRALH
            case (0b1, 0b1, 0b0, 0b010): return .LDEORALH
            case (0b1, 0b1, 0b0, 0b011): return .LDSETALH
            case (0b1, 0b1, 0b0, 0b100): return .LDSMAXALH
            case (0b1, 0b1, 0b0, 0b101): return .LDSMINALH
            case (0b1, 0b1, 0b0, 0b110): return .LDUMAXALH
            case (0b1, 0b1, 0b0, 0b111): return .LDUMINALH
            case (0b1, 0b1, 0b1, 0b000): return .SWPALH
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
        
        private static func getBaseVersionMnemonic(size: RawARMInstruction, v: RawARMInstruction, a: RawARMInstruction, r: RawARMInstruction, rs: RawARMInstruction, o3: RawARMInstruction, opc: RawARMInstruction) throws -> ARMMnemonic {
            guard v == 0b0 else { throw ARMInstructionDecoderError.unrecognizedInstruction }
            switch (a,r,o3,opc) {
            case (0b0, 0b0, 0b0, 0b000): return .LDADD
            case (0b0, 0b0, 0b0, 0b001): return .LDCLR
            case (0b0, 0b0, 0b0, 0b010): return .LDEOR
            case (0b0, 0b0, 0b0, 0b011): return .LDSET
            case (0b0, 0b0, 0b0, 0b100): return .LDSMAX
            case (0b0, 0b0, 0b0, 0b101): return .LDSMIN
            case (0b0, 0b0, 0b0, 0b110): return .LDUMAX
            case (0b0, 0b0, 0b0, 0b111): return .LDUMIN
            case (0b0, 0b0, 0b1, 0b000): return .SWP
            case (0b0, 0b1, 0b0, 0b000): return .LDADDL
            case (0b0, 0b1, 0b0, 0b001): return .LDCLRL
            case (0b0, 0b1, 0b0, 0b010): return .LDEORL
            case (0b0, 0b1, 0b0, 0b011): return .LDSETL
            case (0b0, 0b1, 0b0, 0b100): return .LDSMAXL
            case (0b0, 0b1, 0b0, 0b101): return .LDSMINL
            case (0b0, 0b1, 0b0, 0b110): return .LDUMAXL
            case (0b0, 0b1, 0b0, 0b111): return .LDUMINL
            case (0b0, 0b1, 0b1, 0b000): return .SWPL
            case (0b1, 0b0, 0b0, 0b000): return .LDADDA
            case (0b1, 0b0, 0b0, 0b001): return .LDCLRA
            case (0b1, 0b0, 0b0, 0b010): return .LDEORA
            case (0b1, 0b0, 0b0, 0b011): return .LDSETA
            case (0b1, 0b0, 0b0, 0b100): return .LDSMAXA
            case (0b1, 0b0, 0b0, 0b101): return .LDSMINA
            case (0b1, 0b0, 0b0, 0b110): return .LDUMAXA
            case (0b1, 0b0, 0b0, 0b111): return .LDUMINA
            case (0b1, 0b0, 0b1, 0b000): return .SWPA
            case (0b1, 0b0, 0b1, 0b100): return .LDAPR
            case (0b1, 0b1, 0b0, 0b000): return .LDADDAL
            case (0b1, 0b1, 0b0, 0b001): return .LDCLRAL
            case (0b1, 0b1, 0b0, 0b010): return .LDEORAL
            case (0b1, 0b1, 0b0, 0b011): return .LDSETAL
            case (0b1, 0b1, 0b0, 0b100): return .LDSMAXAL
            case (0b1, 0b1, 0b0, 0b101): return .LDSMINAL
            case (0b1, 0b1, 0b0, 0b110): return .LDUMAXAL
            case (0b1, 0b1, 0b0, 0b111): return .LDUMINAL
            case (0b1, 0b1, 0b1, 0b000): return .SWPAL
            default:
                guard size == 0b11, v == 0, a == 0, r == 0, o3 == 1 else { throw ARMInstructionDecoderError.unrecognizedInstruction }
                switch (rs,opc) {
                case (_, 0b010): return .ST64BV0
                case (_, 0b011): return .ST64BV
                case (0b11111, 0b001): return .ST64B
                case (0b11111, 0b101): return .LD64B
                default: throw ARMInstructionDecoderError.unrecognizedInstruction
                }
            }
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?, UInt32?, UInt32?, UInt32?, UInt32?, UInt32?, UInt32?)?
            var size: UInt32?
            if let cpuMode = cpuMode {
                size = cpuMode.rawValue.asUInt32 | 0b10
            }
            switch mnemonic {
            case .LDADDB: data = (0b00, 0b0, 0b0, 0b0, 0b000, nil, nil)
            case .LDCLRB: data = (0b00, 0b0, 0b0, 0b0, 0b001, nil, nil)
            case .LDEORB: data = (0b00, 0b0, 0b0, 0b0, 0b010, nil, nil)
            case .LDSETB: data = (0b00, 0b0, 0b0, 0b0, 0b011, nil, nil)
            case .LDSMAXB: data = (0b00, 0b0, 0b0, 0b0, 0b100, nil, nil)
            case .LDSMINB: data = (0b00, 0b0, 0b0, 0b0, 0b101, nil, nil)
            case .LDUMAXB: data = (0b00, 0b0, 0b0, 0b0, 0b110, nil, nil)
            case .LDUMINB: data = (0b00, 0b0, 0b0, 0b0, 0b111, nil, nil)
            case .SWPB: data = (0b00, 0b0, 0b0, 0b1, 0b000, nil, nil)
            case .LDADDLB: data = (0b00, 0b0, 0b1, 0b0, 0b000, nil, nil)
            case .LDCLRLB: data = (0b00, 0b0, 0b1, 0b0, 0b001, nil, nil)
            case .LDEORLB: data = (0b00, 0b0, 0b1, 0b0, 0b010, nil, nil)
            case .LDSETLB: data = (0b00, 0b0, 0b1, 0b0, 0b011, nil, nil)
            case .LDSMAXLB: data = (0b00, 0b0, 0b1, 0b0, 0b100, nil, nil)
            case .LDSMINLB: data = (0b00, 0b0, 0b1, 0b0, 0b101, nil, nil)
            case .LDUMAXLB: data = (0b00, 0b0, 0b1, 0b0, 0b110, nil, nil)
            case .LDUMINLB: data = (0b00, 0b0, 0b1, 0b0, 0b111, nil, nil)
            case .SWPLB: data = (0b00, 0b0, 0b1, 0b1, 0b000, nil, nil)
            case .LDADDAB: data = (0b00, 0b1, 0b0, 0b0, 0b000, nil, nil)
            case .LDCLRAB: data = (0b00, 0b1, 0b0, 0b0, 0b001, nil, nil)
            case .LDEORAB: data = (0b00, 0b1, 0b0, 0b0, 0b010, nil, nil)
            case .LDSETAB: data = (0b00, 0b1, 0b0, 0b0, 0b011, nil, nil)
            case .LDSMAXAB: data = (0b00, 0b1, 0b0, 0b0, 0b100, nil, nil)
            case .LDSMINAB: data = (0b00, 0b1, 0b0, 0b0, 0b101, nil, nil)
            case .LDUMAXAB: data = (0b00, 0b1, 0b0, 0b0, 0b110, nil, nil)
            case .LDUMINAB: data = (0b00, 0b1, 0b0, 0b0, 0b111, nil, nil)
            case .SWPAB: data = (0b00, 0b1, 0b0, 0b1, 0b000, nil, nil)
            case .LDAPRB: data = (0b00, 0b1, 0b0, 0b1, 0b100, nil, nil)
            case .LDADDALB: data = (0b00, 0b1, 0b1, 0b0, 0b000, nil, nil)
            case .LDCLRALB: data = (0b00, 0b1, 0b1, 0b0, 0b001, nil, nil)
            case .LDEORALB: data = (0b00, 0b1, 0b1, 0b0, 0b010, nil, nil)
            case .LDSETALB: data = (0b00, 0b1, 0b1, 0b0, 0b011, nil, nil)
            case .LDSMAXALB: data = (0b00, 0b1, 0b1, 0b0, 0b100, nil, nil)
            case .LDSMINALB: data = (0b00, 0b1, 0b1, 0b0, 0b101, nil, nil)
            case .LDUMAXALB: data = (0b00, 0b1, 0b1, 0b0, 0b110, nil, nil)
            case .LDUMINALB: data = (0b00, 0b1, 0b1, 0b0, 0b111, nil, nil)
            case .SWPALB: data = (0b00, 0b1, 0b1, 0b1, 0b000, nil, nil)
                
            case .LDADDH: data = (0b01, 0b0, 0b0, 0b0, 0b000, nil, nil)
            case .LDCLRH: data = (0b01, 0b0, 0b0, 0b0, 0b001, nil, nil)
            case .LDEORH: data = (0b01, 0b0, 0b0, 0b0, 0b010, nil, nil)
            case .LDSETH: data = (0b01, 0b0, 0b0, 0b0, 0b011, nil, nil)
            case .LDSMAXH: data = (0b01, 0b0, 0b0, 0b0, 0b100, nil, nil)
            case .LDSMINH: data = (0b01, 0b0, 0b0, 0b0, 0b101, nil, nil)
            case .LDUMAXH: data = (0b01, 0b0, 0b0, 0b0, 0b110, nil, nil)
            case .LDUMINH: data = (0b01, 0b0, 0b0, 0b0, 0b111, nil, nil)
            case .SWPH: data = (0b01, 0b0, 0b0, 0b1, 0b000, nil, nil)
            case .LDADDLH: data = (0b01, 0b0, 0b1, 0b0, 0b000, nil, nil)
            case .LDCLRLH: data = (0b01, 0b0, 0b1, 0b0, 0b001, nil, nil)
            case .LDEORLH: data = (0b01, 0b0, 0b1, 0b0, 0b010, nil, nil)
            case .LDSETLH: data = (0b01, 0b0, 0b1, 0b0, 0b011, nil, nil)
            case .LDSMAXLH: data = (0b01, 0b0, 0b1, 0b0, 0b100, nil, nil)
            case .LDSMINLH: data = (0b01, 0b0, 0b1, 0b0, 0b101, nil, nil)
            case .LDUMAXLH: data = (0b01, 0b0, 0b1, 0b0, 0b110, nil, nil)
            case .LDUMINLH: data = (0b01, 0b0, 0b1, 0b0, 0b111, nil, nil)
            case .SWPLH: data = (0b01, 0b0, 0b1, 0b1, 0b000, nil, nil)
            case .LDADDAH: data = (0b01, 0b1, 0b0, 0b0, 0b000, nil, nil)
            case .LDCLRAH: data = (0b01, 0b1, 0b0, 0b0, 0b001, nil, nil)
            case .LDEORAH: data = (0b01, 0b1, 0b0, 0b0, 0b010, nil, nil)
            case .LDSETAH: data = (0b01, 0b1, 0b0, 0b0, 0b011, nil, nil)
            case .LDSMAXAH: data = (0b01, 0b1, 0b0, 0b0, 0b100, nil, nil)
            case .LDSMINAH: data = (0b01, 0b1, 0b0, 0b0, 0b101, nil, nil)
            case .LDUMAXAH: data = (0b01, 0b1, 0b0, 0b0, 0b110, nil, nil)
            case .LDUMINAH: data = (0b01, 0b1, 0b0, 0b0, 0b111, nil, nil)
            case .SWPAH: data = (0b01, 0b1, 0b0, 0b1, 0b000, nil, nil)
            case .LDADDALH: data = (0b01, 0b1, 0b1, 0b0, 0b000, nil, nil)
            case .LDCLRALH: data = (0b01, 0b1, 0b1, 0b0, 0b001, nil, nil)
            case .LDEORALH: data = (0b01, 0b1, 0b1, 0b0, 0b010, nil, nil)
            case .LDSETALH: data = (0b01, 0b1, 0b1, 0b0, 0b011, nil, nil)
            case .LDSMAXALH: data = (0b01, 0b1, 0b1, 0b0, 0b100, nil, nil)
            case .LDSMINALH: data = (0b01, 0b1, 0b1, 0b0, 0b101, nil, nil)
            case .LDUMAXALH: data = (0b01, 0b1, 0b1, 0b0, 0b110, nil, nil)
            case .LDUMINALH: data = (0b01, 0b1, 0b1, 0b0, 0b111, nil, nil)
            case .SWPALH: data = (0b01, 0b1, 0b1, 0b1, 0b000, nil, nil)
                
            case .LDADD: data = (size, 0b0, 0b0, 0b0, 0b000, nil, nil)
            case .LDCLR: data = (size, 0b0, 0b0, 0b0, 0b001, nil, nil)
            case .LDEOR: data = (size, 0b0, 0b0, 0b0, 0b010, nil, nil)
            case .LDSET: data = (size, 0b0, 0b0, 0b0, 0b011, nil, nil)
            case .LDSMAX: data = (size, 0b0, 0b0, 0b0, 0b100, nil, nil)
            case .LDSMIN: data = (size, 0b0, 0b0, 0b0, 0b101, nil, nil)
            case .LDUMAX: data = (size, 0b0, 0b0, 0b0, 0b110, nil, nil)
            case .LDUMIN: data = (size, 0b0, 0b0, 0b0, 0b111, nil, nil)
            case .SWP: data = (size, 0b0, 0b0, 0b1, 0b000, nil, nil)
            case .LDADDL: data = (size, 0b0, 0b1, 0b0, 0b000, nil, nil)
            case .LDCLRL: data = (size, 0b0, 0b1, 0b0, 0b001, nil, nil)
            case .LDEORL: data = (size, 0b0, 0b1, 0b0, 0b010, nil, nil)
            case .LDSETL: data = (size, 0b0, 0b1, 0b0, 0b011, nil, nil)
            case .LDSMAXL: data = (size, 0b0, 0b1, 0b0, 0b100, nil, nil)
            case .LDSMINL: data = (size, 0b0, 0b1, 0b0, 0b101, nil, nil)
            case .LDUMAXL: data = (size, 0b0, 0b1, 0b0, 0b110, nil, nil)
            case .LDUMINL: data = (size, 0b0, 0b1, 0b0, 0b111, nil, nil)
            case .SWPL: data = (size, 0b0, 0b1, 0b1, 0b000, nil, nil)
            case .LDADDA: data = (size, 0b1, 0b0, 0b0, 0b000, nil, nil)
            case .LDCLRA: data = (size, 0b1, 0b0, 0b0, 0b001, nil, nil)
            case .LDEORA: data = (size, 0b1, 0b0, 0b0, 0b010, nil, nil)
            case .LDSETA: data = (size, 0b1, 0b0, 0b0, 0b011, nil, nil)
            case .LDSMAXA: data = (size, 0b1, 0b0, 0b0, 0b100, nil, nil)
            case .LDSMINA: data = (size, 0b1, 0b0, 0b0, 0b101, nil, nil)
            case .LDUMAXA: data = (size, 0b1, 0b0, 0b0, 0b110, nil, nil)
            case .LDUMINA: data = (size, 0b1, 0b0, 0b0, 0b111, nil, nil)
            case .SWPA: data = (size, 0b1, 0b0, 0b1, 0b000, nil, nil)
            case .LDAPR: data = (size, 0b1, 0b0, 0b1, 0b100, nil, nil)
            case .LDADDAL: data = (size, 0b1, 0b1, 0b0, 0b000, nil, nil)
            case .LDCLRAL: data = (size, 0b1, 0b1, 0b0, 0b001, nil, nil)
            case .LDEORAL: data = (size, 0b1, 0b1, 0b0, 0b010, nil, nil)
            case .LDSETAL: data = (size, 0b1, 0b1, 0b0, 0b011, nil, nil)
            case .LDSMAXAL: data = (size, 0b1, 0b1, 0b0, 0b100, nil, nil)
            case .LDSMINAL: data = (size, 0b1, 0b1, 0b0, 0b101, nil, nil)
            case .LDUMAXAL: data = (size, 0b1, 0b1, 0b0, 0b110, nil, nil)
            case .LDUMINAL: data = (size, 0b1, 0b1, 0b0, 0b111, nil, nil)
            case .SWPAL: data = (size, 0b1, 0b1, 0b1, 0b000, nil, nil)
                
            case .ST64BV0: data = (0b11, 0b0, 0b0, 0b1, 0b010, nil, nil)
            case .ST64BV: data = (0b11, 0b0, 0b0, 0b1, 0b011, nil, nil)
            case .ST64B: data = (0b11, 0b0, 0b0, 0b1, 0b001, 0b11111, nil)
            case .LD64B: data = (0b11, 0b0, 0b0, 0b1, 0b101, 0b11111, nil)
                
            case .STADDB: data = (0b00, 0b0, 0b0, 0b0, 0b000, nil, nil)
            case .STADDLB: data = (0b00, 0b0, 0b1, 0b0, 0b000, nil, nil)
            case .STCLRB: data = (0b00, 0b0, 0b0, 0b0, 0b001, nil, nil)
            case .STCLRLB: data = (0b00, 0b0, 0b1, 0b0, 0b001, nil, nil)
            case .STEORB: data = (0b00, 0b0, 0b0, 0b0, 0b010, nil, nil)
            case .STEORLB: data = (0b00, 0b0, 0b1, 0b0, 0b010, nil, nil)
            case .STSETB: data = (0b00, 0b0, 0b0, 0b0, 0b011, nil, nil)
            case .STSETLB: data = (0b00, 0b0, 0b1, 0b0, 0b011, nil, nil)
            case .STSMAXB: data = (0b00, 0b0, 0b0, 0b0, 0b100, nil, nil)
            case .STSMAXLB: data = (0b00, 0b0, 0b1, 0b0, 0b100, nil, nil)
            case .SSTSMINB: data = (0b00, 0b0, 0b0, 0b0, 0b101, nil, nil)
            case .STSMINLB: data = (0b00, 0b0, 0b1, 0b0, 0b101, nil, nil)
            case .STUMAXB: data = (0b00, 0b0, 0b0, 0b0, 0b110, nil, nil)
            case .STUMAXLB: data = (0b00, 0b0, 0b1, 0b0, 0b110, nil, nil)
            case .STUMINB: data = (0b00, 0b0, 0b0, 0b0, 0b111, nil, nil)
            case .STUMINLB: data = (0b00, 0b0, 0b1, 0b0, 0b111, nil, nil)
                
            case .STADDH: data = (0b01, 0b0, 0b0, 0b0, 0b000, nil, nil)
            case .STADDLH: data = (0b01, 0b0, 0b1, 0b0, 0b000, nil, nil)
            case .STCLRH: data = (0b01, 0b0, 0b0, 0b0, 0b001, nil, nil)
            case .STCLRLH: data = (0b01, 0b0, 0b1, 0b0, 0b001, nil, nil)
            case .STEORH: data = (0b01, 0b0, 0b0, 0b0, 0b010, nil, nil)
            case .STEORLH: data = (0b01, 0b0, 0b1, 0b0, 0b010, nil, nil)
            case .STSETH: data = (0b01, 0b0, 0b0, 0b0, 0b011, nil, nil)
            case .STSETLH: data = (0b01, 0b0, 0b1, 0b0, 0b011, nil, nil)
            case .STSMAXH: data = (0b01, 0b0, 0b0, 0b0, 0b100, nil, nil)
            case .STSMAXLH: data = (0b01, 0b0, 0b1, 0b0, 0b100, nil, nil)
            case .SSTSMINH: data = (0b01, 0b0, 0b0, 0b0, 0b101, nil, nil)
            case .STSMINLH: data = (0b01, 0b0, 0b1, 0b0, 0b101, nil, nil)
            case .STUMAXH: data = (0b01, 0b0, 0b0, 0b0, 0b110, nil, nil)
            case .STUMAXLH: data = (0b01, 0b0, 0b1, 0b0, 0b110, nil, nil)
            case .STUMINH: data = (0b01, 0b0, 0b0, 0b0, 0b111, nil, nil)
            case .STUMINLH: data = (0b01, 0b0, 0b1, 0b0, 0b111, nil, nil)
                
            case .STADD: data = (size, 0b0, 0b0, 0b0, 0b000, nil, nil)
            case .STADDL: data = (size, 0b0, 0b1, 0b0, 0b000, nil, nil)
            case .STCLR: data = (size, 0b0, 0b0, 0b0, 0b001, nil, nil)
            case .STCLRL: data = (size, 0b0, 0b1, 0b0, 0b001, nil, nil)
            case .STEOR: data = (size, 0b0, 0b0, 0b0, 0b010, nil, nil)
            case .STEORL: data = (size, 0b0, 0b1, 0b0, 0b010, nil, nil)
            case .STSET: data = (size, 0b0, 0b0, 0b0, 0b011, nil, nil)
            case .STSETL: data = (size, 0b0, 0b1, 0b0, 0b011, nil, nil)
            case .STSMAX: data = (size, 0b0, 0b0, 0b0, 0b100, nil, nil)
            case .STSMAXL: data = (size, 0b0, 0b1, 0b0, 0b100, nil, nil)
            case .SSTSMIN: data = (size, 0b0, 0b0, 0b0, 0b101, nil, nil)
            case .STSMINL: data = (size, 0b0, 0b1, 0b0, 0b101, nil, nil)
            case .STUMAX: data = (size, 0b0, 0b0, 0b0, 0b110, nil, nil)
            case .STUMAXL: data = (size, 0b0, 0b1, 0b0, 0b110, nil, nil)
            case .STUMIN: data = (size, 0b0, 0b0, 0b0, 0b111, nil, nil)
            case .STUMINL: data = (size, 0b0, 0b1, 0b0, 0b111, nil, nil)
            default: break
            }
            $size = data?.0
            $a = data?.1
            $r = data?.2
            $o3 = data?.3
            $opc = data?.4
            $rs = data?.5
            $rt = data?.6
        }
    }
    
    // Load/store register (register offset)
    class LoadStoreRegisterRegisterOffset: LoadsAndStores {
        override class var supportedMnemonics: [ARMMnemonic] { [.STRB, .LDRB, .LDRSB, .STR, .LDR, .STRH, .LDRH, .LDRSH, .LDRSW, .PRFM] }
        
        @ARMInstructionComponent(27..<30, enforced: 0b111)
        var const1: UInt8?
        @ARMInstructionComponent(24..<26, enforced: 0b00)
        var const2: UInt8?
        @ARMInstructionComponent(21..<22, enforced: 0b1)
        var const3: UInt8?
        @ARMInstructionComponent(10..<12, enforced: 0b10)
        var const4: UInt8?
        
        @ARMInstructionComponent(30..<32)
        var size: UInt8?
        @ARMInstructionComponent(26..<27)
        var v: UInt8?
        @ARMInstructionComponent(22..<24)
        var opc: UInt8?
        @ARMInstructionComponent(16..<21)
        var rm: ARMRegister?
        @ARMInstructionComponent(13..<16)
        var option: UInt8?
        @ARMInstructionComponent(12..<13)
        var s: UInt8?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        override func setupCustomCoders() {
            _rm.customDecoder = getModeSensitiveRegisterDecoder(cpuMode: .x64)
            _rn.customDecoder = getModeSensitiveRegisterDecoder(cpuMode: .x64)
        }
        
        override var mode: CPUMode? {
            switch mnemonic {
            case .STRB, .LDRB, .STRH, .LDRH:
                return .w32
            case .LDRSB, .LDRSH:
                switch opc {
                case 0b10: return .x64
                case 0b11: return .w32
                default: return nil
                }
            case .STR, .LDR:
                switch size {
                case 0b10: return .w32
                case 0b11: return .x64
                default: return nil
                }
            case .LDRSW, .PRFM:
                return .x64
            default: return nil
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            let extensionMnemonic = ARMMnemonic.Extension(value: Int(option ?? 0), mode: .x64)
            switch mnemonic {
            case .STRB, .LDRB, .LDRSB:
                if option == 0b11 {
                    return [
                        ARMRegisterBuilder(register: .required(rt)),
                        ARMAddresBuilder(baseRegister: .required(rn), indexRegister: .required(rm), extension: .required(extensionMnemonic), extensionImmediate: .optional(s))
                    ]
                } else {
                    return [
                        ARMRegisterBuilder(register: .required(rt)),
                        ARMAddresBuilder(baseRegister: .required(rn), indexRegister: .required(rm), shift: .optional(.LSL), shiftImmediate: .optional(s))
                    ]
                }
            case .STRH, .LDRH, .LDRSH, .STR, .LDR, .LDRSW: return [
                ARMRegisterBuilder(register: .required(rt)),
                ARMAddresBuilder(baseRegister: .required(rn), indexRegister: .required(rm), extension: .required(extensionMnemonic), extensionImmediate: .optional(s))
            ]
            case .PRFM: return [
                ARMImmediateBuilder(immediate: .required($rt)),
                ARMAddresBuilder(baseRegister: .required(rn), indexRegister: .required(rm), extension: .optional(extensionMnemonic), extensionImmediate: .optional(s))
            ]
            default: return []
            }
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32?)?
            switch mnemonic {
            case .STRB: data = (0b00, 0b0, 0b00)
            case .LDRB: data = (0b00, 0b0, 0b01)
            case .LDRSB: data = (0b00, 0b0, nil)
            case .STRH: data = (0b01, 0b0, 0b00)
            case .LDRH: data = (0b01, 0b0, 0b01)
            case .LDRSH: data = (0b01, 0b0, nil)
            case .STR: data = (nil, 0b0, 0b00)
            case .LDR: data = (nil, 0b0, 0b01)
            case .LDRSW: data = (0b10, 0b0, 0b10)
            case .PRFM: data = (0b11, 0b0, 0b10)
            default: break
            }
            $size = data?.0
            $v = data?.1
            $opc = data?.2
            switch mnemonic {
            case .LDRSB, .LDRSH:
                switch cpuMode {
                case .x64: opc = 0b10
                case .w32: opc = 0b11
                default: break
                }
            case .STR, .LDR:
                switch cpuMode {
                case .w32: size = 0b10
                case .x64: size = 0b11
                default: break
                }
            default: break
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let size = rawInstruction[30,32],
                let v = rawInstruction[26,27],
                let opc = rawInstruction[22,24],
                let option = rawInstruction[13,16]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (size,v,opc,option) {
            case (0b00, 0b0, 0b00, _): return .STRB
            case (0b00, 0b0, 0b01, _): return .LDRB
            case (0b00, 0b0, 0b10, _), (0b00, 0b0, 0b11, _): return .LDRSB
            case (0b00, 0b1, 0b00, _), (0b00, 0b1, 0b10, _), (0b01, 0b1, 0b00, _), (0b10, 0b1, 0b00, _), (0b11, 0b1, 0b00, _): throw ARMInstructionDecoderError.unsupportedMnemonic // STR (register, SIMD&FP)
            case (0b00, 0b1, 0b01, _), (0b00, 0b1, 0b11, _), (0b01, 0b1, 0b01, _), (0b10, 0b1, 0b01, _), (0b11, 0b1, 0b01, _): throw ARMInstructionDecoderError.unsupportedMnemonic // LDR (register, SIMD&FP)
            case (0b01, 0b0, 0b00, _): return .STRH
            case (0b01, 0b0, 0b01, _): return .LDRH
            case (0b01, 0b0, 0b10, _), (0b01, 0b0, 0b11, _): return .LDRSH
            case (0b10, 0b0, 0b00, _), (0b11, 0b0, 0b00, _): return .STR
            case (0b10, 0b0, 0b01, _), (0b11, 0b0, 0b01, _): return .LDR
            case (0b10, 0b0, 0b10, _): return .LDRSW
            case (0b11, 0b0, 0b10, _): return .PRFM
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Load/store register (pac)
    class LoadStoreRegisterPAC: LoadsAndStores {
        override class var supportedMnemonics: [ARMMnemonic] { [.LDRAA, .LDRAB] }
        
        @ARMInstructionComponent(27..<30, enforced: 0b111)
        var const1: UInt8?
        @ARMInstructionComponent(24..<26, enforced: 0b00)
        var const2: UInt8?
        @ARMInstructionComponent(21..<22, enforced: 0b1)
        var const3: UInt8?
        @ARMInstructionComponent(10..<11, enforced: 0b1)
        var const4: UInt8?
        
        @ARMInstructionComponent(30..<32)
        var size: UInt8?
        @ARMInstructionComponent(26..<27)
        var v: UInt8?
        @ARMInstructionComponent(23..<24)
        var m: UInt8?
        @ARMInstructionComponent(22..<23)
        var s: UInt8?
        @ARMInstructionComponent(12..<21)
        var imm9: Int16?
        @ARMInstructionComponent(11..<12)
        var w: UInt8?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        override var mode: CPUMode? { .x64 }
        
        override func setupCustomCoders() {
            _imm9.customDecoder = getPostProcessedImmedaiteDecoder({ $0 &<< 3})
            _imm9.customEncoder = getPreProcessedImmedaiteEncoder({ $0 &>> 3})
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            switch w {
            case 0b0: return [
                ARMRegisterBuilder(register: .required(rt)),
                ARMAddresBuilder(baseRegister: .required(rn), offsetImmediate: .required(imm9))
            ]
            case 0b1: return [
                ARMRegisterBuilder(register: .required(rt)),
                ARMAddresBuilder(baseRegister: .required(rn), offsetImmediate: .required(imm9), indexingMode: .pre)
            ]
            default: return []
            }
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?, UInt32?, UInt32?)?
            switch mnemonic {
            case .LDRAA: data = (0b11, 0b0 ,0b0)
            case .LDRAB: data = (0b11, 0b0 ,0b1)
            default: break
            }
            $size = data?.0
            $v = data?.1
            $m = data?.2
            $w = indexingMode == .pre ? 0b1 : 0b0
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let size = rawInstruction[30,32],
                let v = rawInstruction[26,27],
                let m = rawInstruction[23,24],
                let w = rawInstruction[11,12]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (size,v,m,w) {
            case (0b11, 0b0 ,0b0, 0b0), (0b11, 0b0 ,0b0, 0b1): return .LDRAA
            case (0b11, 0b0 ,0b1, 0b0), (0b11, 0b0 ,0b1, 0b1): return .LDRAB
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Load/store register (unsigned immediate)
    class LoadStoreRegisterUnsignedImmediate: LoadsAndStores {
        override class var supportedMnemonics: [ARMMnemonic] { [ .STRB, .LDRB, .LDRSB, .LDR, .STR, .STRH, .LDRH, .LDRSH, .LDRSW, .PRFM] }
            
        @ARMInstructionComponent(27..<30, enforced: 0b111)
        var const1: UInt8?
        @ARMInstructionComponent(24..<26, enforced: 0b01)
        var const2: UInt8?
        
        @ARMInstructionComponent(30..<32)
        var size: UInt8?
        @ARMInstructionComponent(26..<27)
        var v: UInt8?
        @ARMInstructionComponent(22..<24)
        var opc: UInt8?
        @ARMInstructionComponent(10..<22)
        var imm12: UInt16?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rt: ARMRegister?
        
        override func setupCustomCoders() {
            _rn.customDecoder = getModeSensitiveRegisterDecoder(cpuMode: .x64)
            _imm12.customDecoder = getPostProcessedImmedaiteDecoder({ [weak self] in self?.mode == .x64 ? $0 &<< 3 : $0 &<< 2})
            _imm12.customEncoder = getPreProcessedImmedaiteEncoder({ [weak self] in self?.mode == .x64 ? $0 &>> 3 : $0 &>> 2 })
        }
        
        override var mode: CPUMode? {
            switch mnemonic {
            case .STRB, .LDRB, .STRH, .LDRH:
                return .w32
            case .LDRSB, .LDRSH:
                switch opc {
                case 0b10: return .x64
                case 0b11: return .w32
                default: return nil
                }
            case .STR, .LDR:
                switch size {
                case 0b10: return .w32
                case 0b11: return .x64
                default: return nil
                }
            case .LDRSW, .PRFM:
                return .x64
            default: return nil
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            let immediate = imm12 != 0 ? imm12 : nil
            switch mnemonic {
            case .PRFM: return [
                ARMImmediateBuilder(immediate: .required($rt)),
                ARMAddresBuilder(baseRegister: .required(rn), offsetImmediate: .optional(immediate))
            ]
            default:
                guard Self.supportedMnemonics.contains(mnemonic) else { return [] }
                return [
                    ARMRegisterBuilder(register: .required(rt)),
                    ARMAddresBuilder(baseRegister: .required(rn), offsetImmediate: .optional(immediate))
                ]
            }
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?, UInt32?, UInt32?)?
            switch mnemonic {
            case .STRB: data = (0b00, 0b0, 0b00)
            case .LDRB: data = (0b00, 0b0, 0b01)
            case .LDRSB: data = (0b00, 0b0, nil)
            case .STRH: data = (0b01, 0b0, 0b00)
            case .LDRH: data = (0b01, 0b0, 0b01)
            case .LDRSH: data = (0b01, 0b0, nil)
            case .STR: data = (nil, 0b0, 0b00)
            case .LDR: data = (nil, 0b0, 0b01)
            case .LDRSW: data = (0b10, 0b0, 0b10)
            case .PRFM: data = (0b11, 0b0, 0b10)
            default: break
            }
            $size = data?.0
            $v = data?.1
            $opc = data?.2
            switch mnemonic {
            case .LDRSB, .LDRSH:
                switch cpuMode {
                case .x64: opc = 0b10
                case .w32: opc = 0b11
                default: break
                }
            case .STR, .LDR:
                switch cpuMode {
                case .w32: size = 0b10
                case .x64: size = 0b11
                default: break
                }
            default: break
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let size = rawInstruction[30,32],
                let v = rawInstruction[26,27],
                let opc = rawInstruction[22,24]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (size,v,opc) {
            case (0b00, 0b0, 0b00): return .STRB
            case (0b00, 0b0, 0b01): return .LDRB
            case (0b00, 0b0, 0b10), (0b00, 0b0, 0b11): return .LDRSB
            case (0b00, 0b1, 0b00), (0b00, 0b1, 0b10), (0b01, 0b1, 0b00), (0b10, 0b1, 0b00), (0b11, 0b1, 0b00): throw ARMInstructionDecoderError.unsupportedMnemonic // STR (immediate, SIMD&FP)
            case (0b00, 0b1, 0b01), (0b00, 0b1, 0b11), (0b01, 0b1, 0b01), (0b10, 0b1, 0b01), (0b11, 0b1, 0b01): throw ARMInstructionDecoderError.unsupportedMnemonic // LDR (immediate, SIMD&FP)
            case (0b01, 0b0, 0b00): return .STRH
            case (0b01, 0b0, 0b01): return .LDRH
            case (0b01, 0b0, 0b10), (0b01, 0b0, 0b11): return .LDRSH
            case (0b10, 0b0, 0b10): return .LDRSW
            case (0b10, 0b0, 0b00), (0b11, 0b0, 0b00): return .STR
            case (0b10, 0b0, 0b01), (0b11, 0b0, 0b01): return .LDR
            case (0b11, 0b0, 0b10): return .PRFM
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
}
