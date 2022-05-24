//
//  ARMDataProcessingImmediateInstruction.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

extension ARMInstruction {
    class DataProcessingImmediate: ARMInstruction {
        @ARMInstructionComponent(23..<26)
        var dataProcessingImmediateOp0: UInt32?
        
        override class func decode(rawInstruction: RawARMInstruction) throws -> ARMInstruction {
            guard Self.self == DataProcessingImmediate.self else {
                throw ARMInstructionDecoderError.subclassDecoderUnsupported
            }
            guard let instructionDecoder = try decodeInstructionType(from: rawInstruction) else {
                throw ARMInstructionDecoderError.unrecognizedInstruction
            }
            return try instructionDecoder.init(from: rawInstruction)
        }
        
        private static func decodeInstructionType(from rawInstruction: RawARMInstruction) throws -> DataProcessingImmediate.Type? {
            guard let op0 = rawInstruction[23,26] else {
                throw ARMInstructionDecoderError.unableToDecode
            }
            var decoder: DataProcessingImmediate.Type?
            if op0 & 0b110 == 0b000 {
                // PC-rel. addressing
                decoder = PCRelAddressing.self
            } else if op0 == 0b010 {
                // Add/subtract (immediate)
                decoder = AddSubtractImmediate.self
            } else if op0 == 0b011 {
                // Add/subtract (immediate, with tags)
                decoder = AddSubtractImmediateWithTags.self
            } else if op0 == 0b100 {
                // Logical (immediate)
                decoder = LogicalImmediate.self
            } else if op0 == 0b101 {
                // Move wide (immediate)
                decoder = MoveWideImmediate.self
            } else if op0 == 0b110 {
                // Bitfield
                decoder = Bitfield.self
            } else if op0 == 0b111 {
                // Extract
                decoder = Extract.self
            }
            return decoder
        }
    }
}

extension ARMInstruction.DataProcessingImmediate {
    // PC-rel. addressing
    class PCRelAddressing: DataProcessingImmediate {
        override class var supportedMnemonics: [ARMMnemonic] { [.ADR, .ADRP] }
        
        @ARMInstructionComponent(24..<29, enforced: 0b10000)
        var const1: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var op: UInt8?
        @ARMInstructionComponent(29..<31)
        var immlo: UInt32?
        @ARMInstructionComponent(5..<24)
        var immhi: UInt32?
        @ARMInstructionComponent(0..<5)
        var rd: ARMRegister?
        
        var address: Int64? {
            get {
                guard let value: UInt64 = mergeImmediates(from: [_immlo, _immhi]) else { return nil }
                var mask: Int64 = 0
                if value[20..<21] == 0b1 {
                    var range = 21 ..< UInt64.bitWidth
                    if mnemonic == .ADRP {
                        range = range.startIndex + 12 ..< UInt64.bitWidth
                    }
                    mask = Int64(bitPattern: UInt64.max.masked(including: range))
                }
                let convertedValue = Int64(bitPattern: value)
                guard let shiftedValue = shiftImmediate(convertedValue, by: 12, condition: { self.mnemonic == .ADRP }) else {
                    return nil
                }
                return shiftedValue | mask
            }
            set {
                guard let value = newValue else {
                    try? divideImmediates(from: UInt64(0), into: [_immlo,_immhi])
                    return
                }
                let shiftedValue: UInt64 = mnemonic == .ADRP ? UInt64(bitPattern: value) &>> 12 : UInt64(bitPattern: value)
                let mask = UInt64.max.masked(including: 0..<21)
                let maskedValue = shiftedValue & mask
                try? divideImmediates(from: maskedValue, into: [_immlo,_immhi])
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {[
            ARMRegisterBuilder(register: .required(rd)),
            ARMImmediateBuilder(immediate: .required(address))
        ]}
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            switch mnemonic {
            case .ADR: op = 0b0
            case .ADRP: op = 0b1
            default: break
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard let op = rawInstruction[31,32] else { throw ARMInstructionDecoderError.unableToDecode }
            switch op {
            case 0b0: return .ADR
            case 0b1: return .ADRP
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Add/subtract (immediate)
    class AddSubtractImmediate: DataProcessingImmediate {
        override class var supportedMnemonics: [ARMMnemonic] { [.ADD, .ADDS, .SUB, .SUBS, .MOV, .CMN, .CMP] }
        
        @ARMInstructionComponent(23..<29, enforced: 0b100010)
        var const1: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var sf: CPUMode?
        @ARMInstructionComponent(30..<31)
        var op: UInt8?
        @ARMInstructionComponent(29..<30)
        var s: UInt8?
        @ARMInstructionComponent(22..<23)
        var sh: UInt8?
        @ARMInstructionComponent(10..<22)
        var imm12: UInt16?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rd: ARMRegister?
        
        override var mode: CPUMode? { sf }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            switch mnemonic {
            case .ADD, .ADDS, .SUB, .SUBS: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rn)),
                ARMImmediateBuilder(immediate: .required(imm12)),
                ARMShiftBuilder(mnemonic: .optional(.LSL), immediate: .optional(sh))
            ]
            case .MOV: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rn)),
            ]
            case .CMN, .CMP: return [
                ARMRegisterBuilder(register: .required(rn)),
                ARMImmediateBuilder(immediate: .required(imm12)),
                ARMShiftBuilder(mnemonic: .optional(.LSL), immediate: .optional(sh))
            ]
            default: return []
            }
        }
        
        override func describe() throws -> String {
            switch mnemonic {
            case .ADD:
                if sh == 0 && imm12 == 0 && (rd?.value == 0b11111 || rn?.value == 0b11111) {
                    return try buildString(for: .MOV) // MOV (to/from SP)
                }
            case .ADDS:
                if rd?.value == 0b11111 {
                    return try buildString(for: .CMN) // CMN (immediate)
                }
            case .SUBS:
                if rd?.value == 0b11111 {
                    return try buildString(for: .CMP) // CMP (immediate)
                }
            default: break
            }
            return try buildString(for: mnemonic)
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?, UInt32?, UInt32?, UInt32?, UInt32?)?
            switch mnemonic {
            case .ADD: data = (0b0,0b0,nil,nil,nil)
            case .ADDS: data = (0b0,0b1,nil,nil,nil)
            case .SUB: data = (0b1,0b0,nil,nil,nil)
            case .SUBS: data = (0b1,0b1,nil,nil,nil)
            case .MOV: data = (0b0,0b0,0b0,0b0,nil)
            case .CMN: data = (0b0,0b1,nil,nil,0b11111)
            case .CMP: data = (0b1,0b1,nil,nil,0b11111)
            default: break
            }
            $op = data?.0
            $s = data?.1
            $sh = data?.2
            $imm12 = data?.3
            $rd = data?.4
            sf = cpuMode
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let op = rawInstruction[30,31],
                let s = rawInstruction[29,30]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (op,s) {
            case (0b0,0b0): return .ADD
            case (0b0,0b1): return .ADDS
            case (0b1,0b0): return .SUB
            case (0b1,0b1): return .SUBS
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
        
        override func setupCustomCoders() {
            _sh.customDecoder = getBinaryShiftValueDecoder(defaultShiftValue: 12)
            _sh.customEncoder = getBinaryShiftValueEncoder()
        }
    }
    
    // Add/subtract (immediate, with tags)
    class AddSubtractImmediateWithTags: DataProcessingImmediate {
        override class var supportedMnemonics: [ARMMnemonic] { [.ADDG, .SUBG] }
        
        @ARMInstructionComponent(23..<29, enforced: 0b100011)
        var const1: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var sf: UInt8?
        @ARMInstructionComponent(30..<31)
        var op: UInt8?
        @ARMInstructionComponent(29..<30)
        var s: UInt8?
        @ARMInstructionComponent(22..<23)
        var o2: UInt8?
        @ARMInstructionComponent(16..<22)
        var uimm6: UInt8?
        @ARMInstructionComponent(14..<16)
        var op3: UInt8?
        @ARMInstructionComponent(10..<14)
        var uimm4: UInt8?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rd: ARMRegister?
        
        var immediate1: Int?
        var immediate2: Int?
        var sourceRegister: ARMRegister?
        var destinationRegister: ARMRegister?
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {[
            ARMRegisterBuilder(register: .required(rd)),
            ARMRegisterBuilder(register: .required(rn)),
            ARMImmediateBuilder(immediate: .required(uimm6)),
            ARMImmediateBuilder(immediate: .required(uimm4))
        ]}
        
        override func setupCustomCoders() {
            _uimm6.customDecoder = getPostProcessedImmedaiteDecoder({ $0 &<< 4 })
            _uimm6.customEncoder = getPreProcessedImmedaiteEncoder({ $0 &>> 4 })
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32?,UInt32?)?
            switch mnemonic {
            case .ADDG: data = (0b1, 0b0, 0b0, 0b0)
            case .SUBG: data = (0b1, 0b1, 0b0, 0b0)
            default: break
            }
            $sf = data?.0
            $op = data?.1
            $s = data?.2
            $o2 = data?.3
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let sf = rawInstruction[31,32],
                let op = rawInstruction[30,31],
                let s = rawInstruction[29,30],
                let o2 = rawInstruction[22,23]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (sf,op,s,o2) {
            case (0b1, 0b0, 0b0, 0b0): return .ADDG
            case (0b1, 0b1, 0b0, 0b0): return .SUBG
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Logical (immediate)
    class LogicalImmediate: DataProcessingImmediate {
        override class var supportedMnemonics: [ARMMnemonic] { [.AND, .ORR, .EOR, .ANDS, .TST, .MOV] }
        
        @ARMInstructionComponent(23..<29, enforced: 0b100100)
        var const1: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var sf: UInt8?
        @ARMInstructionComponent(29..<31)
        var opc: UInt8?
        @ARMInstructionComponent(22..<23)
        var n: UInt8?
        @ARMInstructionComponent(16..<22)
        var immr: UInt8?
        @ARMInstructionComponent(10..<16)
        var imms: UInt8?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rd: ARMRegister?
        
        var immediate: UInt64? {
            get { mergeImmediates(from: mode == .x64 ? [_immr, _imms, _n] : [_immr, _imms]) }
            set { try? divideImmediates(from: newValue, into: mode == .x64 ? [_immr, _imms, _n] : [_immr, _imms]) }
        }
        
        override var mode: CPUMode? {
            switch (sf, n) {
            case (0b0,0b0): return .w32
            case (0b1,_): return .x64
            default: return nil
            }
        }
        
        override func describe() throws -> String {
            switch mnemonic {
            case .ANDS:
                if rd?.value == 0b11111 {
                    return try buildString(for: .TST) // TST (immediate)
                }
            case .ORR:
                if rd?.value == 0b11111 && !ARMDecoderHelper.isMoveWidePreferred(sf: sf?.asBool ?? false, n: n?.asBool ?? false, imms: imms, immr: immr) {
                    return try buildString(for: .MOV) // MOV (bitmask immediate)
                }
            default: break
            }
            return try buildString(for: mnemonic)
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            switch mnemonic {
            case .AND, .ORR, .EOR, .ANDS: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rn)),
                ARMImmediateBuilder(immediate: .required(immediate)),
            ]
            case .TST: return [
                ARMRegisterBuilder(register: .required(rn)),
                ARMImmediateBuilder(immediate: .required(immediate)),
            ]
            case .MOV: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMImmediateBuilder(immediate: .required(immediate)),
            ]
            default: return []
            }
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?,UInt32?,UInt32?)?
            switch mnemonic {
            case .AND: data = (0b00, 0b0, nil)
            case .ORR: data = (0b01, 0b0, nil)
            case .EOR: data = (0b10, 0b0, nil)
            case .ANDS: data = (0b11, 0b0, nil)
            case .MOV: data = (0b01, 0b0, 0b11111)
            case .TST: data = (0b11, 0b0, 0b11111)
            default: break
            }
            $opc = data?.0
            $n = data?.1
            $rn = data?.2
            sf = cpuMode?.rawValue.asUInt8
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let sf = rawInstruction[31,32],
                let opc = rawInstruction[29,31],
                let n = rawInstruction[22,23]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (sf,opc,n) {
            case (0b0, 0b00, 0b0), (0b1, 0b00, _): return .AND
            case (0b0, 0b01, 0b0), (0b1, 0b01, _): return .ORR
            case (0b0, 0b10, 0b0), (0b1, 0b10, _): return .EOR
            case (0b0, 0b11, 0b0), (0b1, 0b11, _): return .ANDS
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
    
    // Move wide (immediate)
    class MoveWideImmediate: DataProcessingImmediate {
        override class var supportedMnemonics: [ARMMnemonic] { [.MOVN, .MOVZ, .MOVK, .MOV] }
        
        @ARMInstructionComponent(23..<29, enforced: 0b100101)
        var const1: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var sf: UInt8?
        @ARMInstructionComponent(29..<31)
        var opc: UInt8?
        @ARMInstructionComponent(21..<23)
        var hw: UInt8?
        @ARMInstructionComponent(5..<21)
        var imm16: UInt16?
        @ARMInstructionComponent(0..<5)
        var rd: ARMRegister?
        
        override var mode: CPUMode? {
            switch (sf, (($hw ?? 0) & 0b10)) {
            case (0b0,0b0): return .w32
            case (0b1,_): return .x64
            default: return nil
            }
        }
        
        var immediate: UInt32? {
            get { mergeImmediates(from: [_imm16, _hw]) }
            set { try? divideImmediates(from: newValue, into: [_imm16, _hw]) }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            switch mnemonic {
            case .MOVN, .MOVZ, .MOVK: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMImmediateBuilder(immediate: .required(imm16)),
                ARMShiftBuilder(mnemonic: .optional(.LSL), immediate: .optional(hw))
            ]
            case .MOV: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMImmediateBuilder(immediate: .required(immediate))
            ]
            default: return []
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let sf = rawInstruction[31,32],
                let opc = rawInstruction[29,31],
                let hw = rawInstruction[21,23]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (sf,opc,(hw & 0b10)) {
            case (0b0, 0b00, 0b0), (0b1, 0b00, _): return .MOVN
            case (0b0, 0b10, 0b0), (0b1, 0b10, _): return .MOVZ
            case (0b0, 0b11, 0b0), (0b1, 0b11, _): return .MOVK
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
        
        override func describe() throws -> String {
            switch mnemonic {
            case .MOVN:
                if !(imm16 == 0 && hw != 0) {
                    if mode == .w32 && !((imm16 ?? 0) == 0b1111_1111_1111_1111) {
                        return try buildString(for: .MOV) // MOV (inverted wide immediate)
                    } else if mode == .x64 {
                        return try buildString(for: .MOV) // MOV (inverted wide immediate)
                    }
                }
            case .MOVZ:
                if !(imm16 == 0 && hw != 0) {
                    return try buildString(for: .MOV) // MOV (wide immediate)
                }
            default: break
            }
            return try buildString(for: mnemonic)
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var opc: UInt32?
            switch mnemonic {
            case .MOVN: opc = 0b00
            case .MOVZ: opc = 0b10
            case .MOVK: opc = 0b11
            case .MOV: opc = 0b10
            default: break
            }
            $opc = opc
            sf = cpuMode?.rawValue.asUInt8
        }
        
        override func setupCustomCoders() {
            _hw.customDecoder = getPostProcessedImmedaiteDecoder({ $0 &<< 4 })
            _hw.customEncoder = getPreProcessedImmedaiteEncoder({ $0 &>> 4 })
        }
    }
    
    // Bitfield
    class Bitfield: DataProcessingImmediate {
        override class var supportedMnemonics: [ARMMnemonic] { [.SBFM, .BFM, .UBFM, .BFC, .BFI, .BFXIL, .ASR, .SBFIZ, .SBFX, .SXTB, .SXTH, .SXTW, .LSL, .LSR, .UBFIZ, .UBFX, .UXTB, .UXTH] }
        
        @ARMInstructionComponent(23..<29, enforced: 0b100110)
        var const1: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var sf: UInt8?
        @ARMInstructionComponent(29..<31)
        var opc: UInt8?
        @ARMInstructionComponent(22..<23)
        var n: UInt8?
        @ARMInstructionComponent(16..<22)
        var immr: UInt8?
        @ARMInstructionComponent(10..<16)
        var imms: UInt8?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rd: ARMRegister?
        
        override var mode: CPUMode? {
            switch (sf, n) {
            case (0b0,0b0): return .w32
            case (0b1,0b1): return .x64
            default: return nil
            }
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let sf = rawInstruction[31,32],
                let opc = rawInstruction[29,31],
                let n = rawInstruction[22,23]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (sf,opc,n) {
            case (0b0, 0b00,0b0), (0b1, 0b00,0b1): return .SBFM
            case (0b0, 0b01,0b0), (0b1, 0b01,0b1): return .BFM
            case (0b0, 0b10,0b0), (0b1, 0b10,0b1): return .UBFM
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            var data: (UInt32?, UInt32?, UInt32?, UInt32?)?
            switch mnemonic {
            case .SBFM: data = (0b00, nil, nil, nil)
            case .BFM: data = (0b01, nil, nil, nil)
            case .UBFM: data = (0b10, nil, nil, nil)
                
            case .BFC: data = (0b01, 0b11111, nil, nil)
            case .BFI: data = (0b01, nil, nil, nil)
            case .BFXIL: data = (0b01, nil, nil, nil)
                
            case .ASR: data =  (0b00, nil, mode == .x64 ? 0b111111 : nil, mode == .w32 ? 0b011111 : nil)
            case .SBFIZ: data =  (0b00, nil, nil, nil)
            case .SBFX: data =  (0b00, nil, nil, nil)
            case .SXTB: data =  (0b00, nil, 0b0, 0b00111)
            case .SXTH: data =  (0b00, nil, 0b0, 0b01111)
            case .SXTW: data =  (0b00, nil, 0b0, 0b11111)
                
            case .LSL: data = (0b10, nil, nil, nil)
            case .LSR: data = (0b10, nil, nil, mode == .w32 ? 0b011111 : 0b111111)
            case .UBFIZ: data = (0b10, nil, nil, nil)
            case .UBFX: data = (0b10, nil, nil, nil)
            case .UXTB: data = (0b10, nil, 0b0, 0b000111)
            case .UXTH: data = (0b10, nil, 0b0, 0b001111)
            default: break
            }
            $opc = data?.0
            $rd = data?.1
            $immr = data?.2
            $imms = data?.3
            $sf = cpuMode?.rawValue.asUInt32
            $n = cpuMode?.rawValue.asUInt32
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            var lsb: Int16?
            var width: Int16?
            switch mnemonic {
            case .SBFM, .BFM, .UBFM: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rn)),
                ARMImmediateBuilder(immediate: .required(immr)),
                ARMImmediateBuilder(immediate: .required(imms))
            ]
            case .BFC, .BFI, .SBFIZ, .UBFIZ:
                if let immr = immr { lsb = -Int16(immr) }
                if let imms = imms { width = Int16(imms + 1) }
                return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMImmediateBuilder(immediate: .required(lsb)),
                ARMImmediateBuilder(immediate: .required(width))
            ]
            case .BFXIL, .SBFX, .UBFX:
                if let immr = immr {
                    lsb = Int16(immr)
                    if let imms = imms { width = Int16(imms) - Int16(immr) + 1 }
                }
                return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMImmediateBuilder(immediate: .required(lsb)),
                ARMImmediateBuilder(immediate: .required(width))
            ]
            case .ASR, .LSR: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rn)),
                ARMImmediateBuilder(immediate: .required(immr))
            ]
            case .SXTB, .SXTH, .SXTW, .UXTB, .UXTH: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rn))
            ]
            case .LSL:
                if let imms = imms { width = 31 - Int16(imms) }
                return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rn)),
                ARMImmediateBuilder(immediate: .required(width))
            ]
            default: return []
            }
        }
        
        override func describe() throws -> String {
            if mnemonic == .BFM {
                if rd?.value == 0b11111 && imms ?? 0 < immr ?? 0 {
                    return try buildString(for: .BFC) // BFC
                }
                if rd?.value != 0b11111 && imms ?? 0 < immr ?? 0 {
                    return try buildString(for: .BFI) // BFI
                }
                if imms ?? 0 >= immr ?? 0 {
                    return try buildString(for: .BFXIL) // BFXIL
                }
            }
            if mnemonic == .SBFM {
                if mode == .w32 && imms == 0b011111 {
                    return try buildString(for: .ASR) // ASR (immediate)
                }
                if mode == .x64 && immr == 0b111111 {
                    return try buildString(for: .ASR) // ASR (immediate)
                }
                if let imms = imms, let immr = immr, imms < immr {
                    return try buildString(for: .SBFIZ) // SBFIZ
                }
                if ARMDecoderHelper.isBFXPreferred(sf: mode == .x64, uns: mnemonic == .UBFM, imms: imms, immr: immr) {
                    return try buildString(for: .UBFX) // SBFX
                }
                if immr == 0b0 && imms == 0b00111 {
                    return try buildString(for: .SXTB) // SXTB
                }
                if immr == 0b0 && imms == 0b01111 {
                    return try buildString(for: .SXTH) // SXTH
                }
                if immr == 0b0 && imms == 0b11111 {
                    return try buildString(for: .SXTW) // SXTW
                }
            }
            if mnemonic == .UBFM {
                if mode == .w32, let imms = imms, let immr = immr {
                    if imms != 0b011111 && imms + 1 == immr {
                        return try buildString(for: .LSL) // LSL (immediate)
                    }
                    if imms == 0b011111 {
                        return try buildString(for: .LSR) // LSR (immediate)
                    }
                }
                if mode == .x64, let imms = imms, let immr = immr {
                    if imms != 0b111111 && imms + 1 == immr {
                        return try buildString(for: .LSL) // LSL (immediate)
                    }
                    if imms == 0b111111 {
                        return try buildString(for: .LSR) // LSR (immediate)
                    }
                }
                if imms ?? 0 < immr ?? 0 {
                    return try buildString(for: .UBFIZ) // UBFIZ
                }
                if ARMDecoderHelper.isBFXPreferred(sf: mode == .x64, uns: mnemonic == .UBFM, imms: imms, immr: immr) {
                    return try buildString(for: .SBFX) // UBFX
                }
                if immr == 0b0 && imms == 0b000111 {
                    return try buildString(for: .UXTB) // UXTB
                }
                if immr == 0b0 && imms == 0b001111 {
                    return try buildString(for: .UXTB) // UXTH
                }
            }
            return try buildString(for: mnemonic)
        }
    }
    
    // Extract
    class Extract: DataProcessingImmediate {
        override class var supportedMnemonics: [ARMMnemonic] { [.EXTR, .ROR] }
        
        @ARMInstructionComponent(23..<29, enforced: 0b100111)
        var const1: UInt8?
        
        @ARMInstructionComponent(31..<32)
        var sf: UInt8?
        @ARMInstructionComponent(29..<31)
        var op21: UInt8?
        @ARMInstructionComponent(22..<23)
        var n: UInt8?
        @ARMInstructionComponent(21..<22)
        var o0: UInt8?
        @ARMInstructionComponent(16..<21)
        var rm: ARMRegister?
        @ARMInstructionComponent(10..<16)
        var imms: UInt8?
        @ARMInstructionComponent(5..<10)
        var rn: ARMRegister?
        @ARMInstructionComponent(0..<5)
        var rd: ARMRegister?
        
        override var mode: CPUMode? {
            switch (sf, n, (imms ?? 0 & 0b100000)) {
            case (0b0,0b0,0b0): return .w32
            case (0b1,0b1,_): return .x64
            default: return nil
            }
        }
        
        override func getArgumentBuilders(for mnemonic: ARMMnemonic) -> [ARMInstructionStringBuilderItem]? {
            switch mnemonic {
            case .EXTR: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rn)),
                ARMRegisterBuilder(register: .required(rm)),
                ARMImmediateBuilder(immediate: .required(imms))
            ]
            case .ROR: return [
                ARMRegisterBuilder(register: .required(rd)),
                ARMRegisterBuilder(register: .required(rn)),
                ARMImmediateBuilder(immediate: .required(imms))
            ]
            default: return []
            }
        }
        
        override func describe() throws -> String {
            if rn?.value == rm?.value {
                return try buildString(for: .ROR) // ROR (immediate)
            }
            return try buildString(for: mnemonic)
        }
        
        override func setupInstruction(cpuMode: CPUMode?, indexingMode: IndexingMode?) {
            $op21 = 0b00
            $o0 = 0b0
            $sf = cpuMode?.rawValue.asUInt32
            $n = cpuMode?.rawValue.asUInt32
        }
        
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            guard
                let sf = rawInstruction[31,32],
                let op21 = rawInstruction[29,31],
                let n = rawInstruction[22,23],
                let o0 = rawInstruction[21,22],
                let imms = rawInstruction[10,16]
            else { throw ARMInstructionDecoderError.unableToDecode }
            switch (sf, op21, n, o0, (imms & 0b100000)) {
            case (0b0, 0b00, 0b0, 0b0, 0b0), (0b1, 0b00, 0b1, 0b0, _): return .EXTR
            default: throw ARMInstructionDecoderError.unrecognizedInstruction
            }
        }
    }
}
