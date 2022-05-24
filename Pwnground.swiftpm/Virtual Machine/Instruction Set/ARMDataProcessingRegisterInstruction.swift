//
//  ARMDataProcessingRegisterInstruction.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

extension ARMInstruction {
    class DataProcessingRegister: ARMInstruction {
        @ARMInstructionComponent(30..<31)
        var dataProcessingRegisterOp0: UInt32?
        @ARMInstructionComponent(28..<29)
        var dataProcessingRegisterOp1: UInt32?
        @ARMInstructionComponent(21..<25)
        var dataProcessingRegisterOp2: UInt32?
        @ARMInstructionComponent(10..<16)
        var dataProcessingRegisterOp3: UInt32?
        
        override class func decode(rawInstruction: RawARMInstruction) throws -> ARMInstruction {
            guard Self.self == DataProcessingRegister.self else {
                throw ARMInstructionDecoderError.subclassDecoderUnsupported
            }
            guard let instructionDecoder = try decodeInstructionType(from: rawInstruction) else {
                throw ARMInstructionDecoderError.unrecognizedInstruction
            }
            return try instructionDecoder.init(from: rawInstruction)
        }
        
        private static func decodeInstructionType(from rawInstruction: RawARMInstruction) throws -> DataProcessingRegister.Type? {
            guard
                let op0 = rawInstruction[30..<31],
                let op1 = rawInstruction[28..<29],
                let op2 = rawInstruction[21..<25],
                let op3 = rawInstruction[10..<16]
            else { throw ARMInstructionDecoderError.unableToDecode }
            var decoder: DataProcessingRegister.Type?
            if op1 == 0b1 {
                if op0 == 0b0 && op2 == 0b0110 {
                    // Data-processing (2 source)
                    decoder = DataProcesssing2Source.self
                }
                if op0 == 0b1 && op2 == 0b0110 {
                    // Data-processing (1 source)
                    decoder = DataProcessing1Source.self
                }
                if op2 == 0b0000 {
                    if op3 == 0b000000 {
                        // Add/subtract (with carry)
                        decoder = AddSubtractWithCarry.self
                    }
                    if op3 & 0b011111 == 0b000001 {
                        // Rotate right into flags
                        decoder = RotateRightIntoFlags.self
                    }
                    if op3 & 0b001111 == 0b000010 {
                        // Evaluate into flags
                        decoder = EvaluateIntoFlags.self
                    }
                }
                if op2 == 0b0010 {
                    if op3 & 0b000010 == 0b000000 {
                        // Conditional compare (register)
                        decoder = ConditionalCompareRegister.self
                    }
                    if op3 & 0b000010 == 0b000010 {
                        // Conditional compare (immediate)
                        decoder = ConditionalCompareImmediate.self
                    }
                }
                if op2 == 0b0100 {
                    // Conditional select
                    decoder = ConditionalSelect.self
                }
                if op2 & 0b1000 == 0b1000 {
                    // Data-processing (3 source)
                    decoder = DataProcessing3Source.self
                }
            }
            if op1 == 0b0 {
                if op2 & 0b1000 == 0b0 {
                    // Logical (shifted register)
                    decoder = LogicalShiftedRegister.self
                }
                if op2 & 0b1001 == 0b1000 {
                    // Add/subtract (shifted register)
                    decoder = AddSubtractShiftedRegister.self
                }
                if op2 & 0b1001 == 0b1001 {
                    // Add/subtract (extended register)
                    decoder = AddSubtractExtendedRegister.self
                }
            }
            return decoder
        }
    }
}

extension ARMInstruction.DataProcessingRegister {
    // Data-processing (2 source)
    class DataProcesssing2Source: DataProcessingRegister {
        override class var supportedMnemonics: [ARMMnemonic] {[.UDIV, .SDIV, .LSLV, .LSRV, .ASRV, .RORV, .CRC32B, .CRC32H, .CRC32W, .CRC32X, .CRC32CB, .CRC32CH, .CRC32CW, .CRC32CX, .SUBP, .IRG, .GMI, .PACGA, .SUBPS]}
        
        @ARMInstructionComponent(30..<31, enforced: 0b0)
        var const1: UInt8?
        @ARMInstructionComponent(21..<29, enforced: 0b11010110)
        var const2: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var sf: UInt8?
        @ARMInstructionComponent(29..<30)
        var s: UInt8?
        @ARMInstructionComponent(16..<21)
        var rm: ARMRegister?
        @ARMInstructionComponent(10..<16)
        var opcode: UInt8?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rd: ARMRegister?
        
        override var mode: CPUMode? {
            switch mnemonic {
            case .UDIV, .SDIV, .LSLV, .LSRV, .ASRV, .RORV:
                switch sf {
                case 0b0: return .w32
                case 0b1: return .x64
                default: return nil
                }
            case .CRC32B, .CRC32H, .CRC32W, .CRC32X, .CRC32CB, .CRC32CH, .CRC32CW, .CRC32CX:
                return .w32
            case .SUBP, .IRG, .GMI, .PACGA, .SUBPS:
                return .x64
            default: return nil
            }
        }
        
        override func setupCustomCoders() {
            switch mnemonic {
            case .CRC32X, .CRC32CX:
                _rm.customDecoder = getEnforcedCPUModeRegisterDecoder(for: .x64)
            default: break
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {[
            ARMRegisterBuilder(register: .required(rd)),
            ARMRegisterBuilder(register: .required(rn)),
            ARMRegisterBuilder(register: .required(rm))
        ]}
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32?)?
            switch mnemonic {
            case .UDIV: data = (nil, 0b0, 0b000010)
            case .SDIV: data = (nil, 0b0, 0b000011)
            case .LSLV: data = (nil, 0b0, 0b001000)
            case .LSRV: data = (nil, 0b0, 0b001001)
            case .ASRV: data = (nil, 0b0, 0b001010)
            case .RORV: data = (nil, 0b0, 0b001011)
            case .CRC32B: data = (0b0, 0b0, 0b010000)
            case .CRC32H: data = (0b0, 0b0, 0b010001)
            case .CRC32W: data = (0b0, 0b0, 0b010010)
            case .CRC32CB: data = (0b0, 0b0, 0b010100)
            case .CRC32CH: data = (0b0, 0b0, 0b010101)
            case .CRC32CW: data = (0b0, 0b0, 0b010110)
            case .SUBP: data = (0b1, 0b0, 0b000000)
            case .IRG: data = (0b1, 0b0, 0b000100)
            case .GMI: data = (0b1, 0b0, 0b000101)
            case .PACGA: data = (0b1, 0b0, 0b001100)
            case .CRC32X: data = (0b1, 0b0, 0b010011)
            case .CRC32CX: data = (0b1, 0b0, 0b010111)
            case .SUBPS: data = (0b1, 0b1, 0b000000)
            default: break
            }
            $sf = data?.0
            $s = data?.1
            $opcode = data?.2
            switch mnemonic {
            case .UDIV, .SDIV, .LSLV, .LSRV, .ASRV, .RORV:
                switch cpuMode {
                case .w32: $sf = 0b0
                case .x64: $sf = 0b1
                default: break
                }
            default: break
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let sf = rawInstruction[31,32],
                let s = rawInstruction[29,30],
                let opcode = rawInstruction[10,16]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (sf, s, opcode) {
            case (0b0, 0b0, 0b000010), (0b1, 0b0, 0b000010): return .UDIV
            case (0b0, 0b0, 0b000011), (0b1, 0b0, 0b000011): return .SDIV
            case (0b0, 0b0, 0b001000), (0b1, 0b0, 0b001000): return .LSLV
            case (0b0, 0b0, 0b001001), (0b1, 0b0, 0b001001): return .LSRV
            case (0b0, 0b0, 0b001010), (0b1, 0b0, 0b001010): return .ASRV
            case (0b0, 0b0, 0b001011), (0b1, 0b0, 0b001011): return .RORV
            case (0b0, 0b0, 0b010000): return .CRC32B
            case (0b0, 0b0, 0b010001): return .CRC32H
            case (0b0, 0b0, 0b010010): return .CRC32W
            case (0b0, 0b0, 0b010100): return .CRC32CB
            case (0b0, 0b0, 0b010101): return .CRC32CH
            case (0b0, 0b0, 0b010110): return .CRC32CW
            case (0b1, 0b0, 0b000000): return .SUBP
            case (0b1, 0b0, 0b000100): return .IRG
            case (0b1, 0b0, 0b000101): return .GMI
            case (0b1, 0b0, 0b001100): return .PACGA
            case (0b1, 0b0, 0b010011): return .CRC32X
            case (0b1, 0b0, 0b010111): return .CRC32CX
            case (0b1, 0b1, 0b000000): return .SUBPS
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Data-processing (1 source)
    class DataProcessing1Source: DataProcessingRegister {
        override class var supportedMnemonics: [ARMMnemonic] { [.RBIT, .REV16, .REV, .CLZ, .CLS, .REV32, .PACIA, .PACIZA, .PACIB, .PACIZB, .PACDA, .PACDZA, .PACDB, .PACDZB, .AUTIA, .AUTIZA, .AUTIB, .AUTIZB, .AUTDA, .AUTDZA, .AUTDB, .AUTDZB, .XPACD, .XPACI
        ]}
        
        @ARMInstructionComponent(30..<31, enforced: 0b1)
        var const1: UInt8?
        @ARMInstructionComponent(21..<29, enforced: 0b11010110)
        var const2: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var sf: UInt8?
        @ARMInstructionComponent(29..<30)
        var s: UInt8?
        @ARMInstructionComponent(16..<21)
        var opcode2: UInt8?
        @ARMInstructionComponent(10..<16)
        var opcode: UInt8?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rd: ARMRegister?
        
        override var mode: CPUMode? {
            switch mnemonic {
            case .RBIT, .REV16, .REV, .CLZ, .CLS:
                switch sf {
                case 0b0: return .w32
                case 0b1: return .x64
                default: return nil
                }
            default:
                guard Self.supportedMnemonics.contains(mnemonic) else { return nil }
                return .x64
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            switch mnemonic {
            case .PACIZA, .PACIZB, .PACDZA, .PACDZB, .AUTIZA, .AUTIZB, .AUTDZA, .AUTDZB, .XPACI, .XPACD: return [
                ARMRegisterBuilder(register: .required(rd)),
            ]
            case .RBIT, .REV16, .REV, .CLZ, .CLS, .PACIA, .PACIB, .PACDA, .PACDB, .AUTIA, .AUTIB, .AUTDA, .AUTDB: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rn))
            ]
            default: return []
            }
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32?,UInt32?,UInt32?)?
            switch mnemonic {
            case .RBIT: data = (nil, 0b0, 0b00000, 0b000000, nil)
            case .REV16: data = (nil, 0b0, 0b00000, 0b000001, nil)
            case .REV: data = (nil, 0b0, 0b00000, 0b000010, nil)
            case .CLZ: data = (nil, 0b0, 0b00000, 0b000100, nil)
            case .CLS: data = (nil, 0b0, 0b00000, 0b000101, nil)
            case .REV32: data = (0b1, 0b0, 0b00000, 0b000010, nil)
            case .PACIA: data = (0b1, 0b0, 0b00001, 0b000000, nil)
            case .PACIB: data = (0b1, 0b0, 0b00001, 0b000001, nil)
            case .PACDA: data = (0b1, 0b0, 0b00001, 0b000010, nil)
            case .PACDB: data = (0b1, 0b0, 0b00001, 0b000011, nil)
            case .AUTIA: data = (0b1, 0b0, 0b00001, 0b000100, nil)
            case .AUTIB: data = (0b1, 0b0, 0b00001, 0b000101, nil)
            case .AUTDA: data = (0b1, 0b0, 0b00001, 0b000110, nil)
            case .AUTDB: data = (0b1, 0b0, 0b00001, 0b000111, nil)
            case .PACIZA: data = (0b1, 0b0, 0b00001, 0b001000, 0b11111)
            case .PACIZB: data = (0b1, 0b0, 0b00001, 0b001001, 0b11111)
            case .PACDZA: data = (0b1, 0b0, 0b00001, 0b001010, 0b11111)
            case .PACDZB: data = (0b1, 0b0, 0b00001, 0b001011, 0b11111)
            case .AUTIZA: data = (0b1, 0b0, 0b00001, 0b001100, 0b11111)
            case .AUTIZB: data = (0b1, 0b0, 0b00001, 0b001101, 0b11111)
            case .AUTDZA: data = (0b1, 0b0, 0b00001, 0b001110, 0b11111)
            case .AUTDZB: data = (0b1, 0b0, 0b00001, 0b001111, 0b11111)
            case .XPACI: data = (0b1, 0b0, 0b00001, 0b010000, 0b11111)
            case .XPACD: data = (0b1, 0b0, 0b00001, 0b010001, 0b11111)
            default: break
            }
            $sf = data?.0
            $s = data?.1
            $opcode2 = data?.2
            $opcode = data?.3
            $rn = data?.4
            switch mnemonic {
            case .RBIT, .REV16, .REV, .CLZ, .CLS:
                switch cpuMode {
                case .w32: $sf = 0b0
                case .x64: $sf = 0b1
                default: break
                }
            default: break
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let sf = rawInstruction[31,32],
                let s = rawInstruction[29,30],
                let opcode2 = rawInstruction[16,21],
                let opcode = rawInstruction[10,16],
                let rn = rawInstruction[5,10]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (sf, s, opcode2, opcode, rn) {
            case (0b0, 0b0, 0b00000, 0b000000, _), (0b1, 0b0, 0b00000, 0b000000, _): return .RBIT
            case (0b0, 0b0, 0b00000, 0b000001, _), (0b1, 0b0, 0b00000, 0b000001, _): return .REV16
            case (0b0, 0b0, 0b00000, 0b000010, _), (0b1, 0b0, 0b00000, 0b000011, _): return .REV
            case (0b0, 0b0, 0b00000, 0b000100, _), (0b1, 0b0, 0b00000, 0b000100, _): return .CLZ
            case (0b0, 0b0, 0b00000, 0b000101, _), (0b1, 0b0, 0b00000, 0b000101, _): return .CLS
            case (0b1, 0b0, 0b00000, 0b000010, _): return .REV32
                
            case (0b1, 0b0, 0b00001, 0b000000, _): return .PACIA
            case (0b1, 0b0, 0b00001, 0b000001, _): return .PACIB
            case (0b1, 0b0, 0b00001, 0b000010, _): return .PACDA
            case (0b1, 0b0, 0b00001, 0b000011, _): return .PACDB
            case (0b1, 0b0, 0b00001, 0b000100, _): return .AUTIA
            case (0b1, 0b0, 0b00001, 0b000101, _): return .AUTIB
            case (0b1, 0b0, 0b00001, 0b000110, _): return .AUTDA
            case (0b1, 0b0, 0b00001, 0b000111, _): return .AUTDB
                
            case (0b1, 0b0, 0b00001, 0b001000, 0b11111): return .PACIZA
            case (0b1, 0b0, 0b00001, 0b001001, 0b11111): return .PACIZB
            case (0b1, 0b0, 0b00001, 0b001010, 0b11111): return .PACDZA
            case (0b1, 0b0, 0b00001, 0b001011, 0b11111): return .PACDZB
            case (0b1, 0b0, 0b00001, 0b001100, 0b11111): return .AUTIZA
            case (0b1, 0b0, 0b00001, 0b001101, 0b11111): return .AUTIZB
            case (0b1, 0b0, 0b00001, 0b001110, 0b11111): return .AUTDZA
            case (0b1, 0b0, 0b00001, 0b001111, 0b11111): return .AUTDZB
                
            case (0b1, 0b0, 0b00001, 0b010000, 0b11111): return .XPACI
            case (0b1, 0b0, 0b00001, 0b010001, 0b11111): return .XPACD
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Add/subtract (with carry)
    class AddSubtractWithCarry: DataProcessingRegister {
        override class var supportedMnemonics: [ARMMnemonic] { [.ADC, .ADCS, .SBC, .SBCS, .NGC, .NGCS]}
        
        @ARMInstructionComponent(21..<29, enforced: 0b11010000)
        var const1: UInt8?
        @ARMInstructionComponent(10..<16, enforced: 0b000000)
        var const2: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var sf: UInt8?
        @ARMInstructionComponent(30..<31)
        var op: UInt8?
        @ARMInstructionComponent(29..<30)
        var s: UInt8?
        @ARMInstructionComponent(16..<21)
        var rm: ARMRegister?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rd: ARMRegister?
        
        override var mode: CPUMode? {
            switch sf {
            case 0b0: return .w32
            case 0b1: return .x64
            default: return nil
            }
        }
        
        override func describe() throws -> String {
            switch mnemonic {
            case .SBC:
                if rn?.value == 0b11111 {
                    return try buildString(for: .NGC) // NGC
                }
            case .SBCS:
                if rn?.value == 0b11111 {
                    return try buildString(for: .NGCS) // NGCS
                }
            default: break
            }
            return try buildString(for: mnemonic)
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            switch mnemonic {
            case .ADC, .ADCS, .SBC, .SBCS: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rn)),
                ARMRegisterBuilder(register: .required(rm))
            ]
            case .NGC, .NGCS: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rm))
            ]
            default: return []
            }
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32?)?
            switch mnemonic {
            case .ADC: data = (0b0, 0b0, nil)
            case .ADCS: data = (0b0, 0b1, nil)
            case .SBC: data = (0b1, 0b0, nil)
            case .SBCS: data = (0b1, 0b1, nil)
            case .NGC: data = (0b1, 0b0, 0b11111)
            case .NGCS: data = (0b1, 0b1, 0b11111)
            default: break
            }
            $op = data?.0
            $s = data?.1
            $rn = data?.2
            $sf = cpuMode?.rawValue.asUInt32
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let op = rawInstruction[30,31],
                let s = rawInstruction[29,30]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (op, s) {
            case (0b0, 0b0): return .ADC
            case (0b0, 0b1): return .ADCS
            case (0b1, 0b0): return .SBC
            case (0b1, 0b1): return .SBCS
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Rotate right into flags
    class RotateRightIntoFlags: DataProcessingRegister {
        override class var supportedMnemonics: [ARMMnemonic] { [.RMIF] }
        
        @ARMInstructionComponent(21..<29, enforced: 0b11010000)
        var const1: UInt8?
        @ARMInstructionComponent(10..<15, enforced: 0b00001)
        var const2: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var sf: UInt8?
        @ARMInstructionComponent(30..<31)
        var op: UInt8?
        @ARMInstructionComponent(29..<30)
        var s: UInt8?
        @ARMInstructionComponent(15..<21)
        var imm6: UInt8?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(4..<5)
        var o2: UInt8?
        @ARMInstructionComponent(0..<4)
        var mask: UInt8?
        
        override var mode: CPUMode? { .x64 }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {[
            ARMRegisterBuilder(register: .required(rn)),
            ARMImmediateBuilder(immediate: .required(imm6)),
            ARMImmediateBuilder(immediate: .required(mask))
        ]}
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            $sf = 0b1
            $op = 0b0
            $s = 0b1
            $o2 = 0b0
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let sf = rawInstruction[31,32],
                let op = rawInstruction[30,31],
                let s = rawInstruction[29,30],
                let o2 = rawInstruction[4,5]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (sf,op,s,o2) {
            case (0b1, 0b0, 0b1, 0b0): return .RMIF
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Evaluate into flags
    class EvaluateIntoFlags: DataProcessingRegister {
        override class var supportedMnemonics: [ARMMnemonic] { [.SETF8, .SETF16] }
        
        @ARMInstructionComponent(21..<29, enforced: 0b11010000)
        var const1: UInt8?
        @ARMInstructionComponent(10..<14, enforced: 0b0010)
        var const2: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var sf: UInt8?
        @ARMInstructionComponent(30..<31)
        var op: UInt8?
        @ARMInstructionComponent(29..<30)
        var s: UInt8?
        @ARMInstructionComponent(15..<21)
        var opcode2: UInt8?
        @ARMInstructionComponent(14..<15)
        var sz: UInt8?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(4..<5)
        var o3: UInt8?
        @ARMInstructionComponent(0..<4)
        var mask: UInt8?
        
        override var mode: CPUMode? { .w32 }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {[
            ARMRegisterBuilder(register: .required(rn))
        ]}
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32?,UInt32?,UInt32?,UInt32?,UInt32?)?
            switch mnemonic {
            case .SETF8: data = (0b0, 0b0, 0b1, 0b000000, 0b0, 0b0, 0b1101)
            case .SETF16: data = (0b0, 0b0, 0b1, 0b000000, 0b1, 0b0, 0b1101)
            default: break
            }
            $sf = data?.0
            $op = data?.1
            $s = data?.2
            $opcode2 = data?.3
            $sz = data?.4
            $o3 = data?.5
            $mask = data?.6
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let sf = rawInstruction[31,32],
                let op = rawInstruction[30,31],
                let s = rawInstruction[29,30],
                let opcode2 = rawInstruction[15,21],
                let sz = rawInstruction[14,15],
                let o3 = rawInstruction[4,5],
                let mask = rawInstruction[0,4]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (sf,op,s,opcode2,sz,o3,mask) {
            case (0b0, 0b0, 0b1, 0b000000, 0b0, 0b0, 0b1101): return .SETF8
            case (0b0, 0b0, 0b1, 0b000000, 0b1, 0b0, 0b1101): return .SETF16
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Conditional compare (register)
    class ConditionalCompareRegister: DataProcessingRegister {
        override class var supportedMnemonics: [ARMMnemonic] { [.CCMN, .CCMP] }
        
        @ARMInstructionComponent(21..<29, enforced: 0b11010010)
        var const1: UInt8?
        @ARMInstructionComponent(11..<12, enforced: 0b0)
        var const2: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var sf: UInt8?
        @ARMInstructionComponent(30..<31)
        var op: UInt8?
        @ARMInstructionComponent(29..<30)
        var s: UInt8?
        @ARMInstructionComponent(16..<21)
        var rm: ARMRegister?
        @ARMInstructionComponent(12..<16)
        var cond: UInt8?
        @ARMInstructionComponent(10..<11)
        var o2: UInt8?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(4..<5)
        var o3: UInt8?
        @ARMInstructionComponent(0..<4)
        var nzcv: UInt8?
        
        override var mode: CPUMode? {
            switch sf {
            case 0b0: return .w32
            case 0b1: return .x64
            default: return nil
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {[
            ARMRegisterBuilder(register: .required(rn)),
            ARMRegisterBuilder(register: .required(rm)),
            ARMImmediateBuilder(immediate: .required(nzcv)),
            ARMLabelBuilder(label: .required(ARMMnemonic.Condition(rawValue: Int(cond ?? 0b1110))?.suffix?.rawValue))
        ]}
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32?,UInt32?)?
            switch mnemonic {
            case .CCMN: data = (0b0, 0b1, 0b0, 0b0)
            case .CCMP: data = (0b1, 0b1, 0b0, 0b0)
            default: break
            }
            $sf = cpuMode?.rawValue.asUInt32
            $op = data?.0
            $s = data?.1
            $o2 = data?.2
            $o3 = data?.3
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let sf = rawInstruction[31,32],
                let op = rawInstruction[30,31],
                let s = rawInstruction[29,30],
                let o2 = rawInstruction[10,11],
                let o3 = rawInstruction[4,5]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (sf,op,s,o2,o3) {
            case (0b0, 0b0, 0b1, 0b0, 0b0), (0b1, 0b0, 0b1, 0b0, 0b0): return .CCMN
            case (0b0, 0b1, 0b1, 0b0, 0b0), (0b1, 0b1, 0b1, 0b0, 0b0): return .CCMP
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Conditional compare (immediate)
    class ConditionalCompareImmediate: DataProcessingRegister {
        override class var supportedMnemonics: [ARMMnemonic] { [.CCMN, .CCMP] }
        
        @ARMInstructionComponent(21..<29, enforced: 0b11010010)
        var const1: UInt8?
        @ARMInstructionComponent(11..<12, enforced: 0b1)
        var const2: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var sf: UInt8?
        @ARMInstructionComponent(30..<31)
        var op: UInt8?
        @ARMInstructionComponent(29..<30)
        var s: UInt8?
        @ARMInstructionComponent(16..<21)
        var imm5: UInt8?
        @ARMInstructionComponent(12..<16)
        var cond: UInt8?
        @ARMInstructionComponent(10..<11)
        var o2: UInt8?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(4..<5)
        var o3: UInt8?
        @ARMInstructionComponent(0..<4)
        var nzcv: UInt8?
        
        override var mode: CPUMode? {
            switch sf {
            case 0b0: return .w32
            case 0b1: return .x64
            default: return nil
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {[
            ARMRegisterBuilder(register: .required(rn)),
            ARMImmediateBuilder(immediate: .required(imm5)),
            ARMImmediateBuilder(immediate: .required(nzcv)),
            ARMLabelBuilder(label: .required(ARMMnemonic.Condition(rawValue: Int(cond ?? 0b1110))?.suffix?.rawValue))
        ]}
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32?,UInt32?)?
            switch mnemonic {
            case .CCMN: data = (0b0, 0b1, 0b0, 0b0)
            case .CCMP: data = (0b1, 0b1, 0b0, 0b0)
            default: break
            }
            $sf = cpuMode?.rawValue.asUInt32
            $op = data?.0
            $s = data?.1
            $o2 = data?.2
            $o3 = data?.3
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let sf = rawInstruction[31,32],
                let op = rawInstruction[30,31],
                let s = rawInstruction[29,30],
                let o2 = rawInstruction[10,11],
                let o3 = rawInstruction[4,5]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (sf,op,s,o2,o3) {
            case (0b0, 0b0, 0b1, 0b0, 0b0), (0b1, 0b0, 0b1, 0b0, 0b0): return .CCMN
            case (0b0, 0b1, 0b1, 0b0, 0b0), (0b1, 0b1, 0b1, 0b0, 0b0): return .CCMP
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Conditional select
    class ConditionalSelect: DataProcessingRegister {
        override class var supportedMnemonics: [ARMMnemonic] { [.CSEL,. CSINC,. CSINV,. CSNEG, .CINC, .CSET, .CINV, .CSETM, .CNEG] }
        
        @ARMInstructionComponent(21..<29, enforced: 0b11010100)
        var const1: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var sf: UInt8?
        @ARMInstructionComponent(30..<31)
        var op: UInt8?
        @ARMInstructionComponent(29..<30)
        var s: UInt8?
        @ARMInstructionComponent(16..<21)
        var rm: ARMRegister?
        @ARMInstructionComponent(12..<16)
        var cond: UInt8?
        @ARMInstructionComponent(10..<12)
        var op2: UInt8?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rd: ARMRegister?
        
        override var mode: CPUMode? {
            switch sf {
            case 0b0: return .w32
            case 0b1: return .x64
            default: return nil
            }
        }
        
        override func describe() throws -> String {
            switch mnemonic {
            case .CSINC:
                if let rm = rm, let rn = rn, let cond = cond,
                   rm.value != 0b11111 && (cond & 0b1110) != 0b1110 && rn.value != 0b11111 && rn.value == rm.value {
                    return try buildString(for: .CINC) // CINC
                } else if let rm = rm, let rn = rn, let cond = cond,
                    rm.value == 0b11111 && (cond & 0b1110) != 0b1110 && rn.value == 0b11111 {
                    return try buildString(for: .CSET) // CSET
                }
            case .CSINV:
                if let rm = rm, let rn = rn, let cond = cond,
                   rm.value != 0b11111 && (cond & 0b1110) != 0b1110 && rn.value != 0b11111 && rn.value == rm.value {
                    return try buildString(for: .CINV) // CINV
                } else if let rm = rm, let rn = rn, let cond = cond,
                    rm.value == 0b11111 && (cond & 0b1110) != 0b1110 && rn.value == 0b11111 {
                    return try buildString(for: .CSETM) // CSETM
                }
            case .CSNEG:
                if let cond = cond, let rn = rn, (cond & 0b1110) != 0b1110 && rn.value == rm?.value {
                    return try buildString(for: .CNEG) // CNEG
                }
            default: break
            }
            return try buildString(for: mnemonic)
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            let condition = ARMMnemonic.Condition(rawValue: Int(cond ?? 0b1110))
            switch mnemonic {
            case .CSEL,. CSINC,. CSINV,. CSNEG: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rn)),
                ARMRegisterBuilder(register: .required(rm)),
                ARMLabelBuilder(label: .required(condition?.suffix?.rawValue))
            ]
            case .CINC, .CINV, .CNEG: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rn)),
                ARMLabelBuilder(label: .required(condition?.inverted?.suffix?.rawValue))
            ]
            case .CSET, .CSETM: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMLabelBuilder(label: .required(condition?.inverted?.suffix?.rawValue))
            ]
            default: return []
            }
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32?,UInt32?)?
            switch mnemonic {
            case .CSEL: data = (0b0, 0b0, 0b00, nil)
            case .CSINC: data = (0b0, 0b0, 0b01, nil)
            case .CSINV: data = (0b1, 0b0, 0b00, nil)
            case .CSNEG: data = (0b1, 0b0, 0b01, nil)
            case .CINC: data = (0b0, 0b0, 0b01, nil)
            case .CSET: data = (0b0, 0b0, 0b01, 0b11111)
            case .CINV: data = (0b1, 0b0, 0b00, nil)
            case .CSETM: data = (0b1, 0b0, 0b00, 0b11111)
            case .CNEG: data = (0b1, 0b0, 0b01, nil)
            default: break
            }
            $sf = cpuMode?.rawValue.asUInt32
            $op = data?.0
            $s = data?.1
            $op2 = data?.2
            $rn = data?.3
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let sf = rawInstruction[31,32],
                let op = rawInstruction[30,31],
                let s = rawInstruction[29,30],
                let op2 = rawInstruction[10,12]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (sf,op,s,op2) {
            case (0b0, 0b0, 0b0, 0b00), (0b1, 0b0, 0b0, 0b00): return .CSEL
            case (0b0, 0b0, 0b0, 0b01), (0b1, 0b0, 0b0, 0b01): return .CSINC
            case (0b0, 0b1, 0b0, 0b00), (0b1, 0b1, 0b0, 0b00): return .CSINV
            case (0b0, 0b1, 0b0, 0b01), (0b1, 0b1, 0b0, 0b01): return .CSNEG
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Data-processing (3 source)
    class DataProcessing3Source: DataProcessingRegister {
        override class var supportedMnemonics: [ARMMnemonic] { [.MADD, .MSUB, .SMADDL, .SMSUBL, .SMULH, .UMADDL, .UMSUBL, .UMULH, .MUL, .MNEG, .SMULL, .SMNEGL, .UMULL, .UMNEGL] }
        
        @ARMInstructionComponent(24..<29, enforced: 0b11011)
        var const1: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var sf: UInt8?
        @ARMInstructionComponent(29..<31)
        var op54: UInt8?
        @ARMInstructionComponent(21..<24)
        var op31: UInt8?
        @ARMInstructionComponent(16..<21)
        var rm: ARMRegister?
        @ARMInstructionComponent(15..<16)
        var o0: UInt8?
        @ARMInstructionComponent(10..<15)
        var ra: ARMRegister?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rd: ARMRegister?
        
        override var mode: CPUMode? {
            switch mnemonic {
            case .MADD, .MSUB:
                switch sf {
                case 0b0: return .w32
                case 0b1: return .x64
                default: return nil
                }
            default:
                guard Self.supportedMnemonics.contains(mnemonic) else { return nil }
                return .x64
            }
        }
        
        override func setupCustomCoders() {
            switch mnemonic {
            case .SMADDL, .SMSUBL, .UMADDL, .UMSUBL:
                _rn.customDecoder = getEnforcedCPUModeRegisterDecoder(for: .w32)
                _rm.customDecoder = getEnforcedCPUModeRegisterDecoder(for: .w32)
            default: break
            }
        }
        
        override func describe() throws -> String {
            switch mnemonic {
            case .MADD:
                if ra?.value == 0b11111 {
                    return try buildString(for: .MUL) // MUL
                }
            case .MSUB:
                if ra?.value == 0b11111 {
                    return try buildString(for: .MNEG) // MNEG
                }
            case .SMADDL:
                if ra?.value == 0b11111 {
                    return try buildString(for: .SMULL) // SMULL
                }
            case .SMSUBL:
                if ra?.value == 0b11111 {
                    return try buildString(for: .SMNEGL) // SMNEGL
                }
            case .UMADDL:
                if ra?.value == 0b11111 {
                    return try buildString(for: .UMULL) // UMULL
                }
            case .UMSUBL:
                if ra?.value == 0b11111 {
                    return try buildString(for: .UMNEGL) // UMNEGL
                }
            default: break
            }
            return try buildString(for: mnemonic)
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            switch mnemonic {
            case .MADD, .MSUB, .SMADDL, .SMSUBL, .UMADDL, .UMSUBL: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rn)),
                ARMRegisterBuilder(register: .required(rm)),
                ARMRegisterBuilder(register: .required(ra))
            ]
            case .SMULH, .UMULH, .MUL, .MNEG, .SMULL, .SMNEGL, .UMULL, .UMNEGL: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rn)),
                ARMRegisterBuilder(register: .required(rm))
            ]
            default: return []
            }
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32?,UInt32?,UInt32?)?
            switch mnemonic {
            case .MADD: data = (nil, 0b00, 0b000, 0b0, nil)
            case .MSUB: data = (nil, 0b00, 0b000, 0b1, nil)
            case .SMADDL: data = (0b1, 0b00, 0b001, 0b0, nil)
            case .SMSUBL: data = (0b1, 0b00, 0b001, 0b1, nil)
            case .SMULH: data = (0b1, 0b00, 0b010, 0b1, nil)
            case .UMADDL: data = (0b1, 0b00, 0b101, 0b0, nil)
            case .UMSUBL: data = (0b1, 0b00, 0b101, 0b1, nil)
            case .UMULH: data = (0b1, 0b00, 0b110, 0b0, nil)
            case .MUL: data = (0b1, 0b00, 0b000, 0b0, 0b11111)
            case .MNEG: data = (0b1, 0b00, 0b000, 0b1, 0b11111)
            case .SMULL: data = (0b1, 0b00, 0b001, 0b0, 0b11111)
            case .SMNEGL: data = (0b1, 0b00, 0b001, 0b1, 0b11111)
            case .UMULL: data = (0b1, 0b00, 0b101, 0b1, 0b11111)
            case .UMNEGL: data = (0b1, 0b00, 0b110, 0b0, 0b11111)
            default: break
            }
            $sf = data?.0
            $op54 = data?.1
            $op31 = data?.2
            $o0 = data?.3
            $ra = data?.4
            switch mnemonic {
            case .MADD, .MSUB:
                switch cpuMode {
                case .w32: $sf = 0b0
                case .x64: $sf = 0b1
                default: break
                }
            default: break
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let sf = rawInstruction[31,32],
                let op54 = rawInstruction[29,31],
                let op31 = rawInstruction[21,24],
                let o0 = rawInstruction[15,16]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (sf,op54,op31,o0) {
            case (0b0, 0b00, 0b000, 0b0), (0b1, 0b00, 0b000, 0b0): return .MADD
            case (0b0, 0b00, 0b000, 0b1), (0b1, 0b00, 0b000, 0b1): return .MSUB
            case (0b1, 0b00, 0b001, 0b0): return .SMADDL
            case (0b1, 0b00, 0b001, 0b1): return .SMSUBL
            case (0b1, 0b00, 0b010, 0b1): return .SMULH
            case (0b1, 0b00, 0b101, 0b0): return .UMADDL
            case (0b1, 0b00, 0b101, 0b1): return .UMSUBL
            case (0b1, 0b00, 0b110, 0b0): return .UMULH
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Logical (shifted register)
    class LogicalShiftedRegister: DataProcessingRegister {
        override class var supportedMnemonics: [ARMMnemonic] { [.AND, .BIC, .ORR, .ORN, .EOR, .EON, .ANDS, .BICS, .MOV, .MVN, .TST] }
        
        @ARMInstructionComponent(24..<29, enforced: 0b01010)
        var const1: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var sf: UInt8?
        @ARMInstructionComponent(29..<31)
        var opc: UInt8?
        @ARMInstructionComponent(22..<24)
        var shift: UInt8?
        @ARMInstructionComponent(21..<22)
        var n: UInt8?
        @ARMInstructionComponent(16..<21)
        var rm: ARMRegister?
        @ARMInstructionComponent(10..<16)
        var imm6: UInt8?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rd: ARMRegister?
        
        override var mode: CPUMode? {
            switch sf {
            case 0b0: return .w32
            case 0b1: return .x64
            default: return nil
            }
        }
        
        override func describe() throws -> String {
            switch mnemonic {
            case .ORR:
                if shift == 0b00 && imm6 == 0b000000 && rn?.value == 0b11111 {
                    return try buildString(for: .MOV) // MOV (register)
                }
            case .ORN:
                if rn?.value == 0b11111 {
                    return try buildString(for: .MVN) // MVN
                }
            case .ANDS:
                if rd?.value == 0b11111 {
                    return try buildString(for: .TST) // TST (shifted register)
                }
            default: break
            }
            return try buildString(for: mnemonic)
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            let shiftMnemonic = shift != nil ? ARMMnemonic.Shift(value: Int(shift ?? 0)) : nil
            switch mnemonic {
            case .AND, .BIC, .ORR, .ORN, .EOR, .EON, .ANDS, .BICS: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rn)),
                ARMRegisterBuilder(register: .required(rm)),
                ARMShiftBuilder(mnemonic: .optional(shiftMnemonic), immediate: .optional(imm6))
            ]
            case .MOV: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rm))
            ]
            case .MVN: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rm)),
                ARMShiftBuilder(mnemonic: .optional(shiftMnemonic), immediate: .optional(imm6))
            ]
            case .TST: return [
                ARMRegisterBuilder(register: .required(rn)),
                ARMRegisterBuilder(register: .required(rm)),
                ARMShiftBuilder(mnemonic: .optional(shiftMnemonic), immediate: .optional(imm6))
            ]
            default: return []
            }
        }
        
        override func setupCustomCoders() {
            _rm.customDecoder = getModeSensitiveRegisterDecoder(for: .zero)
            _rn.customDecoder = getModeSensitiveRegisterDecoder(for: .zero)
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32?,UInt32?,UInt32?,UInt32?)?
            switch mnemonic {
            case .AND: data = (0b00, 0b0, nil, nil, nil, nil)
            case .BIC: data = (0b00, 0b1, nil, nil, nil, nil)
            case .ORR: data = (0b01, 0b0, nil, nil, nil, nil)
            case .ORN: data = (0b01, 0b1, nil, nil, nil, nil)
            case .EOR: data = (0b10, 0b0, nil, nil, nil, nil)
            case .EON: data = (0b10, 0b1, nil, nil, nil, nil)
            case .ANDS: data = (0b11, 0b0, nil, nil, nil, nil)
            case .BICS: data = (0b11, 0b1, nil, nil, nil, nil)
            case .MOV: data = (0b01, 0b0, 0b00, 0b000000, 0b11111, nil)
            case .MVN: data = (0b01, 0b1, nil, nil, 0b11111, nil)
            case .TST: data = (0b11, 0b0, nil, nil, nil, 0b11111)
            default: break
            }
            $sf = cpuMode?.rawValue.asUInt32
            $opc = data?.0
            $n = data?.1
            $shift = data?.2
            $imm6 = data?.3
            $rn = data?.4
            $rd = data?.5
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let sf = rawInstruction[31,32],
                let opc = rawInstruction[29,31],
                let n = rawInstruction[21,22],
                let imm6 = rawInstruction[10,16]
            else { throw ARMInstructionDecoderError.unableToDecode }
            if sf == 0 && (imm6 & 0b100000) == 0b100000 {
                throw ARMInstructionDecoderError.unrecognizedInstruction
            }
            switch (opc,n) {
            case (0b00, 0b0): return .AND
            case (0b00, 0b1): return .BIC
            case (0b01, 0b0): return .ORR
            case (0b01, 0b1): return .ORN
            case (0b10, 0b0): return .EOR
            case (0b10, 0b1): return .EON
            case (0b11, 0b0): return .ANDS
            case (0b11, 0b1): return .BICS
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Add/subtract (shifted register)
    class AddSubtractShiftedRegister: DataProcessingRegister {
        override class var supportedMnemonics: [ARMMnemonic] { [.ADD, .ADDS, .SUB, .SUBS, .CMN, .NEG, .CMP, .NEGS] }
        
        @ARMInstructionComponent(24..<29, enforced: 0b01011)
        var const1: UInt8?
        @ARMInstructionComponent(21..<22, enforced: 0b0)
        var const2: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var sf: UInt8?
        @ARMInstructionComponent(30..<31)
        var op: UInt8?
        @ARMInstructionComponent(29..<30)
        var s: UInt8?
        @ARMInstructionComponent(22..<24)
        var shift: UInt8?
        @ARMInstructionComponent(16..<21)
        var rm: ARMRegister?
        @ARMInstructionComponent(10..<16)
        var imm6: UInt8?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rd: ARMRegister?
        
        override var mode: CPUMode? {
            switch sf {
            case 0b0: return .w32
            case 0b1: return .x64
            default: return nil
            }
        }
        
        override func describe() throws -> String {
            switch mnemonic {
            case .ADDS:
                if rd?.value == 0b11111 {
                    return try buildString(for: .CMN) // CMN (shifted register)
                }
            case .SUB:
                if rn?.value == 0b11111 {
                    return try buildString(for: .NEG) // NEG (shifted register)
                }
            case .SUBS:
                if rd?.value == 0b11111 {
                    return try buildString(for: .CMP) // CMP (shifted register)
                } else if let rd = rd, rn?.value == 0b11111 && rd.value != 0b11111 {
                    return try buildString(for: .NEGS) // NEGS
                }
            default: break
            }
            return try buildString(for: mnemonic)
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            let shiftMnemonic = shift != nil ? ARMMnemonic.Shift(value: Int(shift ?? 0)) : nil
            switch mnemonic {
            case .ADD, .ADDS, .SUB, .SUBS: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rn)),
                ARMRegisterBuilder(register: .required(rm)),
                ARMShiftBuilder(mnemonic: .optional(shiftMnemonic), immediate: .optional(imm6))
            ]
            case .CMN, .CMP: return [
                ARMRegisterBuilder(register: .required(rn)),
                ARMRegisterBuilder(register: .required(rm)),
                ARMShiftBuilder(mnemonic: .optional(shiftMnemonic), immediate: .optional(imm6))
            ]
            case .NEG, .NEGS: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rm)),
                ARMShiftBuilder(mnemonic: .optional(shiftMnemonic), immediate: .optional(imm6))
            ]
            default: return []
            }
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32?,UInt32?)?
            switch mnemonic {
            case .ADD: data = (0b0, 0b0, nil, nil)
            case .ADDS: data = (0b0, 0b1, nil, nil)
            case .SUB: data = (0b1, 0b0, nil, nil)
            case .SUBS: data = (0b1, 0b1, nil, nil)
            case .CMN: data = (0b0, 0b1, 0b11111, nil)
            case .NEG: data = (0b1, 0b0, nil, 0b11111)
            case .CMP: data = (0b1, 0b1, 0b11111, nil)
            case .NEGS: data = (0b1, 0b1, nil, 0b11111)
            default: break
            }
            $sf = cpuMode?.rawValue.asUInt32
            $op = data?.0
            $s = data?.1
            $rd = data?.2
            $rn = data?.3
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let sf = rawInstruction[31,32],
                let op = rawInstruction[30,31],
                let s = rawInstruction[29,30],
                let shift = rawInstruction[22,24],
                let imm6 = rawInstruction[10,16]
            else { throw ARMInstructionDecoderError.unableToDecode }
            if (sf == 0 && (imm6 & 0b100000) == 0b100000) || shift == 0b11 {
                throw ARMInstructionDecoderError.unrecognizedInstruction
            }
            switch (op,s) {
            case (0b0, 0b0): return .ADD
            case (0b0, 0b1): return .ADDS
            case (0b1, 0b0): return .SUB
            case (0b1, 0b1): return .SUBS
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Add/subtract (extended register)
    class AddSubtractExtendedRegister: DataProcessingRegister {
        override class var supportedMnemonics: [ARMMnemonic] { [.ADD, .ADDS, .SUB, .SUBS, .CMN, .CMP] }
        
        @ARMInstructionComponent(24..<29, enforced: 0b01011)
        var const1: UInt8?
        @ARMInstructionComponent(21..<22, enforced: 0b1)
        var const2: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var sf: UInt8?
        @ARMInstructionComponent(30..<31)
        var op: UInt8?
        @ARMInstructionComponent(29..<30)
        var s: UInt8?
        @ARMInstructionComponent(22..<24)
        var opt: UInt8?
        @ARMInstructionComponent(16..<21)
        var rm: ARMRegister?
        @ARMInstructionComponent(13..<16)
        var option: UInt8?
        @ARMInstructionComponent(10..<13)
        var imm3: UInt8?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rd: ARMRegister?
        
        override var mode: CPUMode? {
            switch sf {
            case 0b0: return .w32
            case 0b1: return .x64
            default: return nil
            }
        }
        
        override func describe() throws -> String {
            switch mnemonic {
            case .ADDS:
                if rd?.value == 0b11111 {
                    return try buildString(for: .CMN) // CMN (extended register)
                }
            case .SUBS:
                if rd?.value == 0b11111 {
                    return try buildString(for: .CMP) // CMP (extended register)
                }
            default: break
            }
            return try buildString(for: mnemonic)
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            let extensionMnemonic = option != nil ? ARMMnemonic.Extension(value: Int(option ?? 0), mode: mode ?? .x64) : nil
            switch mnemonic {
            case .ADD, .ADDS, .SUB, .SUBS: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rn)),
                ARMRegisterBuilder(register: .required(rm)),
                ARMExtensionBuilder(mnemonic: .optional(extensionMnemonic), immediate: .optional(imm3))
            ]
            case .CMN, .CMP: return [
                ARMRegisterBuilder(register: .required(rn)),
                ARMRegisterBuilder(register: .required(rm)),
                ARMExtensionBuilder(mnemonic: .optional(extensionMnemonic), immediate: .optional(imm3))
            ]
            default: return []
            }
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32?,UInt32?)?
            switch mnemonic {
            case .ADD: data = (0b0, 0b0, 0b00, nil)
            case .ADDS: data = (0b0, 0b1, 0b00, nil)
            case .SUB: data = (0b1, 0b0, 0b00, nil)
            case .SUBS: data = (0b1, 0b1, 0b00, nil)
            case .CMN: data = (0b0, 0b1, 0b00, 0b11111)
            case .CMP: data = (0b1, 0b1, 0b00, 0b11111)
            default: break
            }
            $sf = cpuMode?.rawValue.asUInt32
            $op = data?.0
            $s = data?.1
            $opt = data?.2
            $rd = data?.3
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let op = rawInstruction[30,31],
                let s = rawInstruction[29,30],
                let opt = rawInstruction[22,24],
                let imm3 = rawInstruction[10,13]
            else { throw ARMInstructionDecoderError.unableToDecode }
            if (imm3 & 0b101 == 0b101) || (imm3 & 0b110 == 0b110) {
                throw ARMInstructionDecoderError.unrecognizedInstruction
            }
            switch (op,s, opt) {
            case (0b0, 0b0, 0b00): return .ADD
            case (0b0, 0b1, 0b00): return .ADDS
            case (0b1, 0b0, 0b00): return .SUB
            case (0b1, 0b1, 0b00): return .SUBS
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
}
