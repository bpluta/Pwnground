//
//  ARMDataProcessingFloatingAndSimdInstruction.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

extension ARMInstruction {
    class DataProcessingFloatingAndSimd: ARMInstruction {
        @ARMInstructionComponent(28..<32)
        var dataProcessingFloadingAndSimdOp0: UInt32?
        @ARMInstructionComponent(23..<25)
        var dataProcessingFloadingAndSimdOp1: UInt32?
        @ARMInstructionComponent(19..<23)
        var dataProcessingFloadingAndSimdOp2: UInt32?
        @ARMInstructionComponent(10..<19)
        var dataProcessingFloadingAndSimdOp3: UInt32?
        
        override class func decode(rawInstruction: RawARMInstruction) throws -> ARMInstruction {
            guard Self.self == DataProcessingFloatingAndSimd.self else {
                throw ARMInstructionDecoderError.subclassDecoderUnsupported
            }
            guard let instructionDecoder = try decodeInstructionType(from: rawInstruction) else {
                throw ARMInstructionDecoderError.unrecognizedInstruction
            }
            return try instructionDecoder.init(from: rawInstruction)
        }
        
        private static func decodeInstructionType(from rawInstruction: RawARMInstruction) throws -> DataProcessingFloatingAndSimd.Type? {
            guard
                let op0 = rawInstruction[28..<32],
                let op1 = rawInstruction[23..<25],
                let op2 = rawInstruction[19..<23],
                let op3 = rawInstruction[10..<19]
            else { throw ARMInstructionDecoderError.unableToDecode }
            var decoder: DataProcessingFloatingAndSimd.Type?
            if op0 == 0b0100 && op1 & 0b10 == 0b0 {
                if op2 & 0b0111 == 0b0101 && op3 & 0b110000011 == 0b000000010 {
                    // Cryptographic AES
                    decoder = CryptographicAES.self
                }
            }
            if op0 & 0b1101 == 0b0101 {
                if op0 == 0b0101 && op1 & 0b10 == 0b0 {
                    if op2 & 0b0100 == 0b0 && op3 & 0b000100011 == 0b0 {
                        // Cryptographic three-register SHA
                        decoder = CryptographicThreeRegisterSHA.self
                    }
                    if op2 & 0b0111 == 0b0101 && op3 & 0b110000011 == 0b000000010 {
                        // Cryptographic two-register SHA
                        decoder = CryptographicTwoRegisterSHA.self
                    }
                }
                if op1 & 0b10 == 0b0 {
                    if op1 == 0b0 && op2 & 0b1100 == 0b0 && op3 & 0b000100001 == 0b000000001 {
                        // Advanced SIMD scalar copy
                        decoder = AdvancedSIMDScalarCopy.self
                    }
                    if op2 & 0b1100 == 0b1000 && op3 & 0b000110001 == 0b000000001 {
                        // Advanced SIMD scalar three same FP16
                        decoder = AdvancedSIMDScalarThreeSameFP16.self
                    }
                    if op2 == 0b1111 && op3 & 0b110000011 == 0b000000010 {
                        // Advanced SIMD scalar two-register miscellaneous FP16
                        decoder = AdvancedSIMDScalarTwoRegisterMiscellaneousFP16.self
                    }
                    if op2 & 0b0100 == 0b0 && op3 & 0b000100001 == 0b000100001 {
                        // Advanced SIMD scalar three same extra
                        decoder = AdvancedSIMDScalarThreeSameExtra.self
                    }
                    if op3 & 0b110000011 == 0b000000010 {
                        if op2 & 0b0111 == 0b0100 {
                            // Advanced SIMD scalar two-register miscellaneous
                            decoder = AdvancedSIMDScalarTwoRegisterMiscellaneous.self
                        }
                        if op2 & 0b0111 == 0b0110 {
                            // Advanced SIMD scalar pairwise
                            decoder = AdvancedSIMDScalarPairwise.self
                        }
                    }
                    if op2 & 0b0100 == 0b0100 {
                        if op3 & 0b000000011 == 0b0 {
                            // Advanced SIMD scalar three different
                            decoder = AdvancedSIMDScalarThreeDifferent.self
                        }
                        if op3 & 0b000000001 == 0b1 {
                            // Advanced SIMD scalar three same
                            decoder = AdvancedSIMDScalarThreeSame.self
                        }
                    }
                }
                if op1 == 0b10 && op3 & 0b000000001 == 0b1 {
                    // Advanced SIMD scalar shift by immediate
                    decoder = AdvancedSIMDScalarShiftByImmediate.self
                }
                if op1 & 0b10 == 0b10 && op3 & 0b000000001 == 0b0 {
                    // Advanced SIMD scalar x indexed element
                    decoder = AdvancedSIMDScalarXIndexedElement.self
                }
            }
            if op0 & 0b1011 == 0b0 && op1 & 0b10 == 0b0 && op2 & 0b0100 == 0b0 {
                if op3 & 0b000100011 == 0b0 {
                    // Advanced SIMD table lookup
                    decoder = AdvancedSIMDTableLookup.self
                }
                if op3 & 0b000100011 == 0b000000010 {
                    // Advanced SIMD permute
                    decoder = AdvancedSIMDPermute.self
                }
            }
            if op0 & 0b1011 == 0b0010 && op1 & 0b10 == 0b0 && op2 & 0b0100 == 0b0 && op3 & 0b000100001 == 0b0 {
                // Advanced SIMD extract
                decoder = AdvancedSIMDExtract.self
            }
            if op0 & 0b1011 == 0b0 {
                if op1 & 0b10 == 0b0 {
                    if op1 == 0b00 && op2 & 0b1100 == 0b0 && op3 & 0b000100001 == 0b1 {
                        // Advanced SIMD copy
                        decoder = AdvancedSIMDCopy.self
                    }
                    if op2 & 0b1100 == 0b1000 && op3 & 0b000110001 == 0b1 {
                        // Advanced SIMD three same (FP16)
                        decoder = AdvancedSIMDThreeSameFP16.self
                    }
                    if op2 == 0b1111 && op3 & 0b110000011 == 0b10 {
                        // Advanced SIMD two-register miscellaneous (FP16)
                        decoder = AdvancedSIMDTwoRegisterMiscellaneousFP16.self
                    }
                    if op2 & 0b0100 == 0b0 && op3 & 0b000100001 == 0b000100001 {
                        // Advanced SIMD three-register extension
                        decoder = AdvancedSIMDThreeRegisterExtension.self
                    }
                    if op3 & 0b110000011 == 0b10 {
                        if op2 & 0b0111 == 0b0100 {
                            // Advanced SIMD two-register miscellaneous
                            decoder = AdvancedSIMDTwoRegisterMiscellaneous.self
                        }
                        if op2 & 0b0111 == 0b0110 {
                            // Advanced SIMD across lanes
                            decoder = AdvancedSIMDAcrossLanes.self
                        }
                    }
                    if op2 & 0b0100 == 0b0100 {
                        if op3 & 0b000000011 == 0b0 {
                            // Advanced SIMD three different
                            decoder = AdvancedSIMDThreeDifferent.self
                        }
                        if op3 &  0b000000001 == 0b1 {
                            // Advanced SIMD three same
                            decoder = AdvancedSIMDThreeSame.self
                        }
                    }
                }
                if op1 == 0b10 && op2 == 0b0 && op3 & 0b000000001 == 0b1 {
                    // Advanced SIMD modified immediate
                    decoder = AdvancedSIMDModifiedImmediate.self
                }
                if op1 == 0b10 && op2 != 0b0 && op3 & 0b000000001 == 0b1 {
                    // Advanced SIMD shift by immediate
                    decoder = AdvancedSIMDShiftByImmediate.self
                }
                if op1 & 0b10 == 0b10 && op3 & 0b000000001 == 0b0 {
                    // Advanced SIMD vector x indexed element
                    decoder = AdvancedSIMDVectorXIndexedElement.self
                }
            }
            if op0 == 0b1100 {
                if op1 == 0b0 {
                    if op2 & 0b1100 == 0b1000 && op3 & 0b000110000 == 0b000100000 {
                        // Cryptographic three-register, imm2
                        decoder = CryptographicThreeRegisterImm2.self
                    }
                    if op2 & 0b1100 == 0b1100 && op3 & 0b000101100 == 0b000100000 {
                        // Cryptographic three-register SHA 512
                        decoder = CryptographicThreeRegisterSHA512.self
                    }
                    if op3 & 0b000100000 == 0b0 {
                        // Cryptographic four-register
                        decoder = CryptographicFourRegister.self
                    }
                }
                if op1 == 0b1 {
                    if op2 & 0b1100 == 0b0 {
                        // XAR
                        decoder = XAR.self
                    }
                    if op2 == 0b1000 && op3 & 0b111111100 == 0b000100000 {
                        // Cryptographic two-register SHA 512
                        decoder = CryptographicTwoRegisterSHA512.self
                    }
                }
            }
            if op0 & 0b0101 == 0b1 {
                if op1 & 0b10 == 0b00 {
                    if op2 & 0b0100 == 0b0000 {
                        // Conversion between floating-point and fixed-point
                        decoder = ConversionBetweenFloatingPointAndFixedPoint.self
                    }
                    if op2 & 0b0100 == 0b0100 {
                        if op3 & 0b000111111 == 0b0 {
                            // Conversion between floating-point and integer
                            decoder = ConversionBetweenFloatingPointAndInteger.self
                        }
                        if op3 & 0b000011111 == 0b000010000 {
                            // Floating-point data-processing (1 source)
                            decoder = FloatingPointDataProcessing1Source.self
                        }
                        if op3 & 0b000001111 == 0b000001000 {
                            // Floating-point compare
                            decoder = FloatingPointCompare.self
                        }
                        if op3 & 0b000000111 == 0b000000100 {
                            // Floating-point immediate
                            decoder = FloatingPointImmediate.self
                        }
                        if op3 & 0b000000011 == 0b000000001 {
                            // Floating-point conditional compare
                            decoder = FloatingPointConditionalCompare.self
                        }
                        if op3 & 0b000000011 == 0b000000010 {
                           // Floating-point data-processing (2 source)
                            decoder = FloatingPointDataProcessing2Source.self
                        }
                        if op3 & 0b000000011 == 0b000000011 {
                            // Floating-point conditional select
                            decoder = FloatingPointConditionalSelect.self
                        }
                    }
                }
                if op1 & 0b10 == 0b10 {
                    // Floating-point data-processing (3 source)
                    decoder = FloatingPointDataProcessing3source.self
                }
            }
            return decoder
        }
    }
}

extension ARMInstruction.DataProcessingFloatingAndSimd {
    
    // Cryptographic AES
    class CryptographicAES: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Cryptographic three-register SHA
    class CryptographicThreeRegisterSHA: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Cryptographic two-register SHA
    class CryptographicTwoRegisterSHA: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD scalar copy
    class AdvancedSIMDScalarCopy: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD scalar three same FP16
    class AdvancedSIMDScalarThreeSameFP16: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD scalar two-register miscellaneous FP16
    class AdvancedSIMDScalarTwoRegisterMiscellaneousFP16: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD scalar three same extra
    class AdvancedSIMDScalarThreeSameExtra: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD scalar two-register miscellaneous
    class AdvancedSIMDScalarTwoRegisterMiscellaneous: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD scalar pairwise
    class AdvancedSIMDScalarPairwise: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD scalar three different
    class AdvancedSIMDScalarThreeDifferent: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD scalar three same
    class AdvancedSIMDScalarThreeSame: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD scalar shift by immediate
    class AdvancedSIMDScalarShiftByImmediate: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD scalar x indexed element
    class AdvancedSIMDScalarXIndexedElement: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD table lookup
    class AdvancedSIMDTableLookup: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD permute
    class AdvancedSIMDPermute: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD extract
    class AdvancedSIMDExtract: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD copy
    class AdvancedSIMDCopy: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD three same (FP16)
    class AdvancedSIMDThreeSameFP16: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD two-register miscellaneous (FP16)
    class AdvancedSIMDTwoRegisterMiscellaneousFP16: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD three-register extension
    class AdvancedSIMDThreeRegisterExtension: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD two-register miscellaneous
    class AdvancedSIMDTwoRegisterMiscellaneous: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD across lanes
    class AdvancedSIMDAcrossLanes: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD three different
    class AdvancedSIMDThreeDifferent: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD three same
    class AdvancedSIMDThreeSame: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD modified immediate
    class AdvancedSIMDModifiedImmediate: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD shift by immediate
    class AdvancedSIMDShiftByImmediate: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Advanced SIMD vector x indexed element
    class AdvancedSIMDVectorXIndexedElement: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Cryptographic three-register, imm2
    class CryptographicThreeRegisterImm2: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Cryptographic three-register SHA 512
    class CryptographicThreeRegisterSHA512: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Cryptographic four-register
    class CryptographicFourRegister: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // XAR
    class XAR: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Cryptographic two-register SHA 512
    class CryptographicTwoRegisterSHA512: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Conversion between floating-point and fixed-point
    class ConversionBetweenFloatingPointAndFixedPoint: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Conversion between floating-point and integer
    class ConversionBetweenFloatingPointAndInteger: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Floating-point data-processing (1 source)
    class FloatingPointDataProcessing1Source: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Floating-point compare
    class FloatingPointCompare: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Floating-point immediate
    class FloatingPointImmediate: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Floating-point conditional compare
    class FloatingPointConditionalCompare: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Floating-point data-processing (2 source)
    class FloatingPointDataProcessing2Source: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Floating-point conditional select
    class FloatingPointConditionalSelect: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
    
    // Floating-point data-processing (3 source)
    class FloatingPointDataProcessing3source: DataProcessingFloatingAndSimd {
        override class func getMnemonic(for rawInstruction: RawARMInstruction) throws -> ARMMnemonic {
            throw ARMInstructionDecoderError.unsupportedMnemonic
        }
    }
}
