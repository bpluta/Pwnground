//
//  ARMRegister.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

enum IndexingMode: Int {
    case pre = 0b01
    case offset = 0b11
    case post = 0b10
}

enum CPUMode: Int {
    case w32 = 0b0
    case x64 = 0b1
}

enum InstructionMode {
    case stackPointer
    case zero
}

protocol ARMRegister {
    static func getRegister(from value: UInt32, in mode: CPUMode, for instructionMode: InstructionMode?) -> ARMRegister?
    static func decode(from value: UInt32) -> ARMRegister?
    
    var description: String? { get }
    var value: UInt8? { get }
    var width: Int? { get }
    var mode: CPUMode? { get }
    var constantValue: UInt64? { get }
}

extension ARMRegister {
    static func getRegister(from value: UInt32, in mode: CPUMode, for instructionMode: InstructionMode?) -> ARMRegister? { nil }
    static func decode(from value: UInt32) -> ARMRegister? { nil }
    var description: String? { nil }
    var value: UInt8? { nil }
    var width: Int? { nil }
    var mode: CPUMode? { nil }
    var constantValue: UInt64? { nil }
}

extension ARMRegister where Self: CaseIterable {
    static func decode(from value: UInt32) -> ARMRegister? {
        guard
            value < Self.allCases.count,
            let index = Int(value) as? Self.AllCases.Index
        else { return nil }
        return Self.allCases[index]
    }
}

enum ARMGeneralPurposeRegister: ARMRegister {
    static func getRegister(from value: UInt32, in mode: CPUMode, for instructionMode: InstructionMode? = .stackPointer) -> ARMRegister? {
        guard value < 32 else { return nil }
        if let instructionMode = instructionMode, value == 0b11111 {
            switch mode {
            case .w32:
                return instructionMode == .stackPointer ? GP32.sp : GP32.wzr
            case .x64:
                return instructionMode == .stackPointer ? GP64.sp : GP64.xzr
            }
        }
        switch mode {
        case .w32:
            return GP32.decode(from: value)
        case .x64:
            return GP64.decode(from: value)
        }
    }
    
    enum GP64: String, CaseIterable, Hashable, Identifiable, Codable, ARMRegister {
        case x0
        case x1
        case x2
        case x3
        case x4
        case x5
        case x6
        case x7
        case x8
        case x9
        case x10
        case x11
        case x12
        case x13
        case x14
        case x15
        case x16
        case x17
        case x18
        case x19
        case x20
        case x21
        case x22
        case x23
        case x24
        case x25
        case x26
        case x27
        case x28
        case x29
        case x30
        case xzr
        case sp
        
        var mode: CPUMode? { .x64 }
        var width: Int? { 64 }
        var id: String { rawValue }
        var description: String? { rawValue }
        var constantValue: UInt64? { self == .xzr ? 0 : nil }
        var value: UInt8? {
            switch self {
            case .xzr, .sp: return 0b11111
            default:
                guard let index = Self.allCases.firstIndex(of: self) else { return nil }
                return UInt8(index)
            }
        }
        
        init?(from register: ARMRegister) {
            guard
                let value = register.value,
                let gp64register = Self.allCases.first(where: { $0.value == value })
            else { return nil }
            self = gp64register
        }
    }
    
    enum GP32: String, CaseIterable, Identifiable, ARMRegister {
        static var width: UInt8?
        
        case w0
        case w1
        case w2
        case w3
        case w4
        case w5
        case w6
        case w7
        case w8
        case w9
        case w10
        case w11
        case w12
        case w13
        case w14
        case w15
        case w16
        case w17
        case w18
        case w19
        case w20
        case w21
        case w22
        case w23
        case w24
        case w25
        case w26
        case w27
        case w28
        case w29
        case w30
        case wzr
        case sp
        
        var mode: CPUMode? { .w32 }
        var width: Int? { 32 }
        var id: String { rawValue }
        var description: String? { rawValue }
        var constantValue: UInt64? { self == .wzr ? 0 : nil }
        var value: UInt8? {
            switch self {
            case .wzr, .sp: return 0b11111
            default:
                guard let index = Self.allCases.firstIndex(of: self) else { return nil }
                return UInt8(index)
            }
        }
    }
}
