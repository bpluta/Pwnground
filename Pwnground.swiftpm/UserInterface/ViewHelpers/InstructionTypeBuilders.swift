//
//  InstructionTypeBuilders.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI
import Combine

protocol ArgumentProtocol: ObservableObject, Codable, Identifiable {
    var mutability: InstructionCell.ArgumentMutability { get }
    var role: InstructionCell.ArgumentRole { get }
    var valueDescription: String? { get }
}

enum InstructionCell {
    class BasicArgument: ArgumentProtocol {
        var mutability: InstructionCell.ArgumentMutability
        var role: InstructionCell.ArgumentRole
        var valueDescription: String? { nil }
        
        init(mutability: InstructionCell.ArgumentMutability, role: InstructionCell.ArgumentRole) {
            self.mutability = mutability
            self.role = role
        }
        
        private enum CodingKeys: String, CodingKey {
            case mutability
            case role
        }
        
        required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            mutability = try container.decode(InstructionCell.ArgumentMutability.self, forKey: .mutability)
            role = try container.decode(InstructionCell.ArgumentRole.self, forKey: .role)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(mutability, forKey: .mutability)
            try container.encode(role, forKey: .role)
        }
    }
    
    class RegisterArgument: BasicArgument {
        let supportedRegisters: [ARMGeneralPurposeRegister.GP64]
        @Published var selectedRegister: ARMGeneralPurposeRegister.GP64?
        
        override var valueDescription: String? {
            guard let selectedRegister = selectedRegister else { return nil }
            let register = supportedRegisters.first(where: { $0 == selectedRegister })
            return register?.rawValue
        }
        
        init(mutability: InstructionCell.ArgumentMutability, role: InstructionCell.ArgumentRole, supportedRegisters: [ARMGeneralPurposeRegister.GP64]) {
            self.supportedRegisters = supportedRegisters
            super.init(mutability: mutability, role: role)
        }
        
        private enum CodingKeys: String, CodingKey {
            case supportedRegisters
            case selectedRegister
        }
        
        required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            supportedRegisters = try container.decode([ARMGeneralPurposeRegister.GP64].self, forKey: .supportedRegisters)
            selectedRegister = try container.decode(ARMGeneralPurposeRegister.GP64?.self, forKey: .selectedRegister)
            try super.init(from: decoder)
        }
        
        override func encode(to encoder: Encoder) throws {
            try super.encode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(supportedRegisters, forKey: .supportedRegisters)
            try container.encode(selectedRegister, forKey: .selectedRegister)
        }
    }
    
    class ImmediateArgument: BasicArgument {
        @Published var value: Int?
        @Published var mode: NumberValueKeyboardMode
        
        override var valueDescription: String? {
            switch mode {
            case .decimal:
                return value?.description
            case .hexadecimal:
                return value?.dynamicWidthHexString
            }
        }
        
        init(mutability: InstructionCell.ArgumentMutability, role: InstructionCell.ArgumentRole, mode: NumberValueKeyboardMode) {
            self.mode = mode
            super.init(mutability: mutability, role: role)
        }
        
        private enum CodingKeys: String, CodingKey {
            case value
            case mode
        }
        
        required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try container.decode(Int?.self, forKey: .value)
            mode = try container.decode(NumberValueKeyboardMode.self, forKey: .mode)
            try super.init(from: decoder)
        }
        
        override func encode(to encoder: Encoder) throws {
            try super.encode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(value, forKey: .value)
            try container.encode(mode, forKey: .mode)
        }
    }
    
    class ImmediateRangeArgument: ImmediateArgument {
        var range: ClosedRange<Int>
        
        override var valueDescription: String? {
            switch mode {
            case .decimal:
                return value?.description
            case .hexadecimal:
                return value?.dynamicWidthHexString
            }
        }
        
        init(mutability: InstructionCell.ArgumentMutability, role: InstructionCell.ArgumentRole, range: ClosedRange<Int>, mode: NumberValueKeyboardMode) {
            self.range = range
            super.init(mutability: mutability, role: role, mode: mode)
        }
        
        private enum CodingKeys: String, CodingKey {
            case range
        }
        
        required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            range = try container.decode(ClosedRange<Int>.self, forKey: .range)
            try super.init(from: decoder)
        }
        
        override func encode(to encoder: Encoder) throws {
            try super.encode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(range, forKey: .range)
        }
    }
    
    class ImmediateSelectedArgument: ImmediateArgument {
        var selectedValues: [Int]
        
        init(mutability: InstructionCell.ArgumentMutability, role: InstructionCell.ArgumentRole, selectedValues: [Int], mode: NumberValueKeyboardMode) {
            self.selectedValues = selectedValues
            super.init(mutability: mutability, role: role, mode: mode)
        }
        
        private enum CodingKeys: String, CodingKey {
            case selectedValues
        }
        
        required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            selectedValues = try container.decode([Int].self, forKey: .selectedValues)
            try super.init(from: decoder)
        }
        
        override func encode(to encoder: Encoder) throws {
            try super.encode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(selectedValues, forKey: .selectedValues)
        }
    }
    
    class AddressArgument: BasicArgument {
        @PublishedArray var arguments: [BasicArgument]
        
        private var cancelBag = CancelBag()
        
        init(mutability: InstructionCell.ArgumentMutability, role: InstructionCell.ArgumentRole, arguments: [BasicArgument]) {
            self.arguments = arguments
            super.init(mutability: mutability, role: role)
            $arguments.register(observableObject: self).store(in: cancelBag)
        }
        
        required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            arguments = try container.decode([BasicArgument].self, forKey: .arguments)
            try super.init(from: decoder)
        }
        
        override func encode(to encoder: Encoder) throws {
            try super.encode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(arguments, forKey: .arguments)
        }
        
        private enum CodingKeys: String, CodingKey {
            case arguments
        }
    }
    
    class ShiftArgument: BasicArgument {
        @Published var value: ARMMnemonic.Shift?
        
        override var valueDescription: String? {
            value?.rawValue
        }
        
        private enum CodingKeys: String, CodingKey {
            case value
        }
        
        required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try container.decode(ARMMnemonic.Shift?.self, forKey: .value)
            try super.init(from: decoder)
        }
        
        override func encode(to encoder: Encoder) throws {
            try super.encode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(value, forKey: .value)
        }
    }
    
    
    enum InstructionType: Int, CaseIterable, Codable {
        case movkImmediateWithShift
        case movImmediate
        case movRegister
        case strPreIndexedAddress
        case strOffsetIndexedAddress
        case strPostIndexedAddress
        case addImmediate
        case addRegisters
        case svcImmediate
        
        var arguments: [Argument] {
            switch self {
            case .movkImmediateWithShift:
                return [
                    Argument(type: .register(role: .destiationRegister, values: ArgumentType.allNumberBasedRegisters)),
                    Argument(type: .immediateRange(role: .value, range: 0...65535)),
                    Argument(type: .shift(role: .shiftType, values: [.LSL]), argumentValue: ARMMnemonic.Shift.LSL.value, mutability: .immutable),
                    Argument(type: .immediateSelected(role: .shiftValue, values: [0,16,32,48]))
                ]
            case .movImmediate:
                return [
                    Argument(type: .register(role: .destiationRegister, values: ArgumentType.allNumberBasedRegisters)),
                    Argument(type: .immediateRange(role: .value, range: 0...65535))
                ]
            case .movRegister:
                return [
                    Argument(type: .register(role: .destiationRegister, values: ArgumentType.allNumberBasedRegisters)),
                    Argument(type: .register(role: .sourceRegister, values: ArgumentType.allRegisters))
                ]
            case .strPreIndexedAddress:
                return [
                    Argument(type: .register(role: .sourceRegister, values: ArgumentType.allNumberBasedRegisters)),
                    Argument(type: .preIndexedAddress(role: .address, arguments: [
                        Argument(type: .register(role: .baseRegister, values: ArgumentType.allNumberBasedRegistersWithStackPointer)),
                        Argument(type: .immediateRange(role: .offset, range: -256...255))
                    ]))
                ]
            case .strOffsetIndexedAddress:
                return [
                    Argument(type: .register(role: .sourceRegister, values: ArgumentType.allNumberBasedRegisters)),
                    Argument(type: .postIndexedAddress(role: .address, arguments: [
                        Argument(type: .register(role: .baseRegister, values: ArgumentType.allNumberBasedRegistersWithStackPointer)),
                        Argument(type: .immediateRange(role: .offset, range: -256...255))
                    ]))
                ]
            case .strPostIndexedAddress:
                return [
                    Argument(type: .register(role: .sourceRegister, values: ArgumentType.allNumberBasedRegisters)),
                    Argument(type: .postIndexedAddress(role: .address, arguments: [
                        Argument(type: .register(role: .baseRegister, values: ArgumentType.allNumberBasedRegistersWithStackPointer))
                    ])),
                    Argument(type: .immediateRange(role: .offset, range: -256...255))
                ]
            case .addImmediate:
                return [
                    Argument(type: .register(role: .destiationRegister, values: ArgumentType.allNumberBasedRegistersWithStackPointer)),
                    Argument(type: .register(role: .sourceRegister, values: ArgumentType.allNumberBasedRegisters)),
                    Argument(type: .immediateRange(role: .value, range: 0...8191))
                ]
            case .addRegisters:
                return [
                    Argument(type: .register(role: .destiationRegister, values: ArgumentType.allNumberBasedRegistersWithStackPointer)),
                    Argument(type: .register(role: .firstSourceRegister, values: ArgumentType.allNumberBasedRegistersWithStackPointer)),
                    Argument(type: .register(role: .secondSourceRegister, values: ArgumentType.allNumberBasedRegistersWithStackPointer)),
                ]
            case .svcImmediate:
                return [
                    Argument(type: .immediateRange(role: .value, range: 0...65535))
                ]
            }
        }
        
        static func getFilledArguments(with instruction: ARMInstruction) -> [Argument]? {
            guard let instructionType = getInstructionType(of: instruction) else { return nil }
            let arguments = instructionType.arguments
            switch instructionType {
            case .movkImmediateWithShift:
                guard let instruction = instruction as? ARMInstruction.DataProcessingImmediate.MoveWideImmediate
                else { return nil }
                setRegister(role: .destiationRegister, in: arguments, to: instruction.rd)
                setImmediate(role: .shiftValue, in: arguments, to: instruction.hw)
                setImmediate(role: .value, in: arguments, to: instruction.imm16)
            case .movImmediate:
                guard let instruction = instruction as? ARMInstruction.DataProcessingImmediate.MoveWideImmediate
                else { return nil }
                setRegister(role: .destiationRegister, in: arguments, to: instruction.rd)
                setImmediate(role: .value, in: arguments, to: instruction.immediate)
            case .movRegister:
                if let instruction = instruction as? ARMInstruction.DataProcessingImmediate.AddSubtractImmediate {
                    setRegister(role: .destiationRegister, in: arguments, to: instruction.rd)
                    setRegister(role: .sourceRegister, in: arguments, to: instruction.rn)
                } else if let instruction = instruction as? ARMInstruction.DataProcessingRegister.LogicalShiftedRegister {
                    setRegister(role: .destiationRegister, in: arguments, to: instruction.rd)
                    setRegister(role: .sourceRegister, in: arguments, to: instruction.rn)
                } else { return nil }
            case .strPreIndexedAddress:
                guard let instruction = instruction as? ARMInstruction.LoadsAndStores.LoadStoreRegisterImmediatePreIndexed,
                      let subarguments = getSubarguments(from: arguments)
                else { return nil }
                setRegister(role: .sourceRegister, in: arguments, to: instruction.rt)
                setRegister(role: .baseRegister, in: subarguments, to: instruction.rn)
                setImmediate(role: .offset, in: subarguments, to: instruction.imm9)
            case .strOffsetIndexedAddress:
                guard
                    let instruction = instruction as? ARMInstruction.LoadsAndStores.LoadStoreRegisterPairOffset,
                    let subarguments = getSubarguments(from: arguments)
                else { return nil }
                setRegister(role: .sourceRegister, in: arguments, to: instruction.rt)
                setRegister(role: .baseRegister, in: subarguments, to: instruction.rn)
                setImmediate(role: .offset, in: subarguments, to: instruction.imm7)
            case .strPostIndexedAddress:
                guard let instruction = instruction as? ARMInstruction.LoadsAndStores.LoadStoreRegisterImmediatePostIndexed,
                      let subarguments = getSubarguments(from: arguments)
                else { return nil }
                setRegister(role: .sourceRegister, in: arguments, to: instruction.rt)
                setRegister(role: .baseRegister, in: subarguments, to: instruction.rn)
                setImmediate(role: .offset, in: arguments, to: instruction.imm9)
            case .addImmediate:
                guard let instruction = instruction as? ARMInstruction.DataProcessingImmediate.AddSubtractImmediate
                else { return nil }
                setRegister(role: .destiationRegister, in: arguments, to: instruction.rd)
                setRegister(role: .sourceRegister, in: arguments, to: instruction.rn)
                setImmediate(role: .value, in: arguments, to: instruction.imm12)
            case .addRegisters:
                guard let instruction = instruction as? ARMInstruction.DataProcessingRegister.AddSubtractShiftedRegister
                else { return nil }
                setRegister(role: .destiationRegister, in: arguments, to: instruction.rd)
                setRegister(role: .firstSourceRegister, in: arguments, to: instruction.rn)
                setRegister(role: .secondSourceRegister, in: arguments, to: instruction.rm)
            case .svcImmediate:
                guard let instruction = instruction as? ARMInstruction.BranchesExceptionAndSystem.ExceptionGeneration
                else { return nil }
                setImmediate(role: .value, in: arguments, to: instruction.imm16)
            }
            return arguments
        }
        
        static func getInstructionType(of instruction: ARMInstruction) -> Self? {
            switch instruction.mnemonic {
            case .MOVK:
                if instruction is ARMInstruction.DataProcessingImmediate.MoveWideImmediate {
                    return .movkImmediateWithShift
                }
            case .MOV:
                if instruction is ARMInstruction.DataProcessingImmediate.MoveWideImmediate {
                    return .movImmediate
                } else if instruction is ARMInstruction.DataProcessingRegister.LogicalShiftedRegister {
                    return .movRegister
                }
            case .STR:
                if instruction is ARMInstruction.LoadsAndStores.LoadStoreRegisterImmediatePreIndexed {
                    return .strPreIndexedAddress
                } else if instruction is ARMInstruction.LoadsAndStores.LoadStoreRegisterImmediatePostIndexed {
                    return .strPostIndexedAddress
                } else if instruction is ARMInstruction.LoadsAndStores.LoadStoreRegisterPairOffset {
                    return .strOffsetIndexedAddress
                }
                break
            case .ADD:
                if instruction is ARMInstruction.DataProcessingImmediate.AddSubtractImmediate {
                    return .addImmediate
                } else if instruction is ARMInstruction.DataProcessingRegister.AddSubtractShiftedRegister {
                    return .addRegisters
                }
            case .SVC:
                if instruction is ARMInstruction.BranchesExceptionAndSystem.ExceptionGeneration {
                    return .svcImmediate
                }
            default: return nil
            }
            return nil
        }
        
        func getSubarguments(from arguments: [Argument]) -> [Argument]? {
            Self.getSubarguments(from: arguments)
        }
        
        static func getSubarguments(from arguments: [Argument]) -> [Argument]? {
            guard let argument = arguments.first(where: { !$0.subarguments.isEmpty }) else { return nil }
            return argument.subarguments
        }
        
        func getRegister(role: ArgumentRole, from arguments: [Argument]) -> ARMGeneralPurposeRegister.GP64? {
            guard let argument = arguments.first(where: { $0.role == role }) else { return nil }
            switch argument.argumentType {
            case .register(role: _, values: let values):
                return values.first(where: { $0 == argument.registerValue })
            default: return nil
            }
        }
        
        static func setRegister(role: ArgumentRole, in arguments: [Argument], to register: ARMRegister?) {
            guard let argument = arguments.first(where: { $0.role == role }) else { return }
            guard case .register(_, let values) = argument.argumentType,
                  let register = register as? ARMGeneralPurposeRegister.GP64,
                  values.contains(where: { $0 == register })
            else {
                argument.registerValue = nil
                return
            }
            argument.registerValue = register
        }
        
        func getImmediate<Type: FixedWidthInteger>(role: ArgumentRole, from arguments: [Argument]) -> Type? {
            guard let argument = arguments.first(where: { $0.role == role }),
                  let value = argument.value
            else { return nil }
            return Type(truncatingIfNeeded: value)
        }
        
        static func setImmediate<Type: FixedWidthInteger>(role: ArgumentRole, in arguments: [Argument], to value: Type?) {
            guard let argument = arguments.first(where: { $0.role == role }) else { return }
            guard let value = value else {
                argument.value = nil
                return
            }
            argument.value = Int(value)
        }
        
        func build(with arguments: [Argument]) -> ARMInstruction? {
            switch self {
            case .movkImmediateWithShift:
                guard
                    let register = getRegister(role: .destiationRegister, from: arguments),
                    let immediate: UInt32 = getImmediate(role: .value, from: arguments),
                    let shiftValue: UInt8 = getImmediate(role: .shiftValue, from: arguments)
                else { return nil }
                return ARMInstructionBuilder.movk(register: register, immediate: immediate, shift: shiftValue)
            case .movImmediate:
                guard
                    let register = getRegister(role: .destiationRegister, from: arguments),
                    let immediate: UInt32 = getImmediate(role: .value, from: arguments)
                else { return nil }
                return ARMInstructionBuilder.mov(register: register, immediate: immediate)
            case .movRegister:
                guard
                    let destinationRegister = getRegister(role: .destiationRegister, from: arguments),
                    let sourceRegister = getRegister(role: .sourceRegister, from: arguments)
                else { return nil }
                return ARMInstructionBuilder.mov(destinationRegister: destinationRegister, sourceRegister: sourceRegister)
            case .strPreIndexedAddress:
                guard
                    let subarguments = getSubarguments(from: arguments),
                    let sourceRegister = getRegister(role: .sourceRegister, from: arguments),
                    let baseRegister = getRegister(role: .baseRegister, from: subarguments),
                    let index: Int16 = getImmediate(role: .offset, from: subarguments)
                else { return nil }
                return ARMInstructionBuilder.str(source: sourceRegister, addressRegister: baseRegister, index: index, indexingMode: .pre)
            case .strOffsetIndexedAddress:
                guard
                    let subarguments = getSubarguments(from: arguments),
                    let sourceRegister = getRegister(role: .sourceRegister, from: arguments),
                    let baseRegister = getRegister(role: .baseRegister, from: subarguments),
                    let index: Int16 = getImmediate(role: .offset, from: subarguments)
                else { return nil }
                return ARMInstructionBuilder.str(source: sourceRegister, addressRegister: baseRegister, index: index, indexingMode: .offset)
            case .strPostIndexedAddress:
                guard
                    let subarguments = getSubarguments(from: arguments),
                    let sourceRegister = getRegister(role: .sourceRegister, from: arguments),
                    let baseRegister = getRegister(role: .baseRegister, from: subarguments),
                    let index: Int16 = getImmediate(role: .offset, from: arguments)
                else { return nil }
                return ARMInstructionBuilder.str(source: sourceRegister, addressRegister: baseRegister, index: index, indexingMode: .post)
            case .addImmediate:
                guard
                    let destinationRegister = getRegister(role: .destiationRegister, from: arguments),
                    let sourceRegister = getRegister(role: .sourceRegister, from: arguments),
                    let immediate: UInt16 = getImmediate(role: .value, from: arguments)
                else { return nil }
                return ARMInstructionBuilder.add(destination: destinationRegister, source: sourceRegister, immediate: immediate)
            case .addRegisters:
                guard
                    let destinationRegister = getRegister(role: .destiationRegister, from: arguments),
                    let firstSourceRegister = getRegister(role: .firstSourceRegister, from: arguments),
                    let secondSourceRegister = getRegister(role: .secondSourceRegister, from: arguments)
                else { return nil }
                return ARMInstructionBuilder.add(destination: destinationRegister, firstSource: firstSourceRegister, secondSource: secondSourceRegister)
            case .svcImmediate:
                guard
                    let immediate: UInt16 = getImmediate(role: .value, from: arguments)
                else { return nil }
                return ARMInstructionBuilder.svc(immediate: immediate)
            }
        }
        
        var mnemonic: ARMMnemonic {
            switch self {
            case .movkImmediateWithShift:
                return .MOVK
            case .movImmediate, .movRegister:
                return .MOV
            case .strPreIndexedAddress, .strOffsetIndexedAddress, .strPostIndexedAddress:
                return .STR
            case .addImmediate, .addRegisters:
                return .ADD
            case .svcImmediate:
                return .SVC
            }
        }
        
        var behaviorDescription: String {
            switch self {
            case .movkImmediateWithShift:
                return "Logical shifts left immediate value by the shift value and then stores the shifted 16-bit value into the destination register keeping other bits unchanged"
            case .movImmediate:
                return "Stores the immediate value into the destination register"
            case .movRegister:
                return "Stores value from the source register into the detination register"
            case .strPreIndexedAddress:
                return "Pre indexed store - adds the offset value to a value in the base register, then stores value from the source register in memory address pointed by the updated base register"
            case .strOffsetIndexedAddress:
                return "Offset store - stores the value from the source register into memory address calculated by adding offset value to the address from the base register"
            case .strPostIndexedAddress:
                return "Post indexed store - stores the value from the source register into memory address from the base register and after that adds the offset value to the base register"
            case .addImmediate:
                return "Adds the immediate value to a value stored in the source register and puts the result into the destination register"
            case .addRegisters:
                return "Adds values from both of the source registers and puts the result into the destination register"
            case .svcImmediate:
                return "Requests supervisor (operating system) to execute subroutine of number stored in X16 register with arguments passed from registers X0 to X8 (instruction argument value is ignored)"
            }
        }
    }
    
    class Argument: ObservableObject, Identifiable, Codable {
        let id = UUID()
        let mutability: ArgumentMutability
        let argumentType: ArgumentType
        let role: ArgumentRole
        
        @PublishedArray var subarguments: [Argument]
        
        @Published var displayMode: ArgumentDisplayMode = .decimal
        @Published var value: Int?
        @Published var registerValue: ARMGeneralPurposeRegister.GP64?
        @Published var validationResult = ValidatorResult(isValid: true)
        
        private var cancelBag = CancelBag()
        
        init(type: ArgumentType, argumentValue: Int? = nil, mutability: ArgumentMutability = .mutable) {
            self.mutability = mutability
            self.argumentType = type
            
            var addressArguments: [Argument]?
            switch type {
            case .register(role: let argumentRole, values: let values):
                role = argumentRole
                displayMode = .register(supported: values)
            case .immediateRange(role: let argumentRole, range: _), .immediateSelected(role: let argumentRole, values: _):
                role = argumentRole
                displayMode = .decimal
            case
                .postIndexedAddress(role: let argumentRole, arguments: let arguments),
                .preIndexedAddress(role: let argumentRole, arguments: let arguments),
                .offsetIndexedAddress(role: let argumentRole, arguments: let arguments):
                role = argumentRole
                addressArguments = arguments
                displayMode = .address
            case .shift(role: let argumentRole, values: _):
                role = argumentRole
                displayMode = .shift
            }
            self.subarguments = addressArguments ?? []
            self.value = argumentValue
            self.setup()
        }
        
        private func setup() {
            setupValueObservations()
            setupValidators()
        }
        
        private func setupValueObservations() {
            $subarguments.register(observableObject: self).store(in: cancelBag)
        }
        
        private func setupValidators() {
            var validators = [Validator]()
            switch argumentType {
            case .immediateRange(role: _, range: let range):
                validators = [RangeValidator(range: range)]
            case .immediateSelected(role: _, values: let values):
                validators = [DiscreteRangeNumberValidator(discreteSet: values)]
            case .register(role: _, values: _), .postIndexedAddress(role: _, arguments: _), .offsetIndexedAddress(role: _, arguments: _), .preIndexedAddress(role: _, arguments: _), .shift(role: _, values: _):
                validators = []
            }
            $value
                .flatMap { value in
                    Publishers.MergeMany(validators.map { $0.validate(value) })
                        .collect()
                }.map { results in
                    results.filter { !$0.isValid }
                }.sink { [weak self] results in
                    guard !results.isEmpty else {
                        self?.validationResult = ValidatorResult(isValid: true)
                        return
                    }
                    if let descriptionResult = results.first(where: { !($0.validatorMessage?.isEmpty ?? true) }) {
                        self?.validationResult = descriptionResult
                    } else {
                        self?.validationResult = ValidatorResult(isValid: false)
                    }
                }.store(in: cancelBag)
        }
        
        var valueDescription: String? {
            var description: String?
            switch displayMode {
            case .register(let supportedRegisters):
                let register = supportedRegisters.first(where: { $0 == registerValue })
                description = register?.rawValue
            case .shift:
                guard let value = value else { break }
                let shift = ARMMnemonic.Shift(value: value)
                description = shift?.rawValue
            case .decimal:
                description = value?.description
            case .hex:
                description = value?.dynamicWidthHexString
            case .address:
                break
            }
            return description
        }
        
        enum CodingKeys: String, CodingKey {
            case mutability
            case argumentType
            case subarguments
            case role
            case displayMode
            case value
            case registerValue
        }
        
        required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            mutability = try container.decode(ArgumentMutability.self, forKey: .mutability)
            argumentType = try container.decode(ArgumentType.self, forKey: .argumentType)
            subarguments = try container.decode([Argument].self, forKey: .subarguments)
            role = try container.decode(ArgumentRole.self, forKey: .role)
            displayMode = try container.decode(ArgumentDisplayMode.self, forKey: .displayMode)
            value = try container.decode(Int?.self, forKey: .value)
            registerValue = try container.decode(ARMGeneralPurposeRegister.GP64?.self, forKey: .value)
            
            setup()
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(mutability, forKey: .mutability)
            try container.encode(argumentType, forKey: .argumentType)
            try container.encode(subarguments, forKey: .subarguments)
            try container.encode(role, forKey: .role)
            try container.encode(displayMode, forKey: .displayMode)
            try container.encode(value, forKey: .value)
            try container.encode(registerValue, forKey: .registerValue)
        }
    }
    
    enum ArgumentMutability: Codable {
        case mutable
        case immutable
    }
    
    enum ArgumentRole: String, Codable {
        case sourceRegister = "Source"
        case destiationRegister = "Destination"
        case firstSourceRegister = "First source"
        case secondSourceRegister = "Second source"
        case shiftType = "Shift type"
        case shiftValue = "Shift value"
        case value = "Value"
        case address = "Address"
        case baseRegister = "Base"
        case offset = "Offset"
        
        var description: String {
            rawValue
        }
        
        func formattedDescription(argument: String) -> String {
            var result: String
            switch self {
            case .sourceRegister:
                result = "\(description) \(argument)"
            case .destiationRegister:
                result = "\(description) \(argument)"
            case .firstSourceRegister:
                result = "\(description) \(argument)"
            case .secondSourceRegister:
                result = "\(description) \(argument)"
            case .shiftType:
                result = "\(description)"
            case .shiftValue:
                result = "\(description)"
            case .value:
                result = "\(argument) \(description)"
            case .address:
                result = "\(argument) \(description)"
            case .baseRegister:
                result = "\(description) \(argument)"
            case .offset:
                result = "\(description) \(argument)"
            }
            return result.lowercased().capitalizingFirstLetter
        }
    }
    
    enum ArgumentType: Codable {
        case register(role: ArgumentRole, values: [ARMGeneralPurposeRegister.GP64])
        case immediateRange(role: ArgumentRole, range: ClosedRange<Int>)
        case immediateSelected(role: ArgumentRole, values: [Int])
        case postIndexedAddress(role: ArgumentRole, arguments: [Argument])
        case offsetIndexedAddress(role: ArgumentRole, arguments: [Argument])
        case preIndexedAddress(role: ArgumentRole, arguments: [Argument])
        case shift(role: ArgumentRole, values: [ARMMnemonic.Shift])
        
        var description: String {
            switch self {
            case .register(_, _):
                return "Register"
            case .immediateRange(_, _), .immediateSelected(_, _):
                return "Value"
            case .postIndexedAddress(_, _), .preIndexedAddress(_, _), .offsetIndexedAddress(_, _):
                return "Address"
            case .shift(_, _):
                return "Shift"
            }
        }
        
        var purposeDescription: String {
            switch self {
            case .register(let role, _):
                return role.description
            case .immediateRange(let role, _):
                return role.description
            case .immediateSelected(let role, _):
                return role.description
            case .postIndexedAddress(let role, _):
                return role.description
            case .preIndexedAddress(let role, _):
                return role.description
            case .offsetIndexedAddress(let role, _):
                return role.description
            case .shift(let role, _):
                return role.description
            }
        }
        
        var purposeLongDescription: String {
            switch self {
            case .register(let role, _):
                return role.formattedDescription(argument: "Register")
            case .immediateRange(let role, _):
                return role.formattedDescription(argument: "Immediate")
            case .immediateSelected(let role, _):
                return role.formattedDescription(argument: "Immediate")
            case .postIndexedAddress(let role, _):
                return role.formattedDescription(argument: "Post-indexed")
            case .preIndexedAddress(let role, _):
                return role.formattedDescription(argument: "Pre-indexed")
            case .offsetIndexedAddress(let role, _):
                return role.formattedDescription(argument: "Offset-indexed")
            case .shift(let role, _):
                return role.formattedDescription(argument: "Shift")
            }
        }
        
        static var allNumberBasedRegisters: [ARMGeneralPurposeRegister.GP64] {
            ARMGeneralPurposeRegister.GP64.allCases.filter({ ($0.value ?? 0) < 31 })
        }
        
        static var allNumberBasedRegistersWithStackPointer: [ARMGeneralPurposeRegister.GP64] {
            [[.sp],allNumberBasedRegisters].flatMap({$0})
        }
        
        static var allRegisters: [ARMGeneralPurposeRegister.GP64] {
            [[.xzr, .sp],allNumberBasedRegisters].flatMap({$0})
        }
        
        enum CodingKeys: CodingKey {
            case register
            case immediateRange
            case immediateSelected
            case postIndexedAddress
            case preIndexedAddress
            case offsetIndexedAddress
            case shift
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .register(let role, let values):
                var nestedContainer = container.nestedUnkeyedContainer(forKey: .register)
                try nestedContainer.encode(role)
                try nestedContainer.encode(values)
            case .immediateRange(let role, let range):
                var nestedContainer = container.nestedUnkeyedContainer(forKey: .immediateRange)
                try nestedContainer.encode(role)
                try nestedContainer.encode(range)
            case .immediateSelected(let role, let values):
                var nestedContainer = container.nestedUnkeyedContainer(forKey: .immediateSelected)
                try nestedContainer.encode(role)
                try nestedContainer.encode(values)
            case .postIndexedAddress(let role, let arguments):
                var nestedContainer = container.nestedUnkeyedContainer(forKey: .postIndexedAddress)
                try nestedContainer.encode(role)
                try nestedContainer.encode(arguments)
            case .preIndexedAddress(let role, let arguments):
                var nestedContainer = container.nestedUnkeyedContainer(forKey: .preIndexedAddress)
                try nestedContainer.encode(role)
                try nestedContainer.encode(arguments)
            case .offsetIndexedAddress(let role, let arguments):
                var nestedContainer = container.nestedUnkeyedContainer(forKey: .offsetIndexedAddress)
                try nestedContainer.encode(role)
                try nestedContainer.encode(arguments)
            case .shift(let role, let values):
                var nestedContainer = container.nestedUnkeyedContainer(forKey: .shift)
                try nestedContainer.encode(role)
                try nestedContainer.encode(values)
            }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let key = container.allKeys.first
            switch key {
            case .register:
                var nestedContainer = try container.nestedUnkeyedContainer(forKey: .register)
                let role = try nestedContainer.decode(InstructionCell.ArgumentRole.self)
                let values = try nestedContainer.decode([ARMGeneralPurposeRegister.GP64].self)
                self = .register(role: role, values: values)
            case .immediateRange:
                var nestedContainer = try container.nestedUnkeyedContainer(forKey: .immediateRange)
                let role = try nestedContainer.decode(InstructionCell.ArgumentRole.self)
                let range = try nestedContainer.decode(ClosedRange<Int>.self)
                self = .immediateRange(role: role, range: range)
            case .immediateSelected:
                var nestedContainer = try container.nestedUnkeyedContainer(forKey: .immediateSelected)
                let role = try nestedContainer.decode(InstructionCell.ArgumentRole.self)
                let values = try nestedContainer.decode([Int].self)
                self = .immediateSelected(role: role, values: values)
            case .postIndexedAddress:
                var nestedContainer = try container.nestedUnkeyedContainer(forKey: .postIndexedAddress)
                let role = try nestedContainer.decode(InstructionCell.ArgumentRole.self)
                let arguments = try nestedContainer.decode([InstructionCell.Argument].self)
                self = .postIndexedAddress(role: role, arguments: arguments)
            case .preIndexedAddress:
                var nestedContainer = try container.nestedUnkeyedContainer(forKey: .preIndexedAddress)
                let role = try nestedContainer.decode(InstructionCell.ArgumentRole.self)
                let arguments = try nestedContainer.decode([InstructionCell.Argument].self)
                self = .preIndexedAddress(role: role, arguments: arguments)
            case .offsetIndexedAddress:
                var nestedContainer = try container.nestedUnkeyedContainer(forKey: .offsetIndexedAddress)
                let role = try nestedContainer.decode(InstructionCell.ArgumentRole.self)
                let arguments = try nestedContainer.decode([InstructionCell.Argument].self)
                self = .offsetIndexedAddress(role: role, arguments: arguments)
            case .shift:
                var nestedContainer = try container.nestedUnkeyedContainer(forKey: .shift)
                let role = try nestedContainer.decode(InstructionCell.ArgumentRole.self)
                let values = try nestedContainer.decode([ARMMnemonic.Shift].self)
                self = .shift(role: role, values: values)
            default:
                let error = DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unabled to decode enum."
                )
                throw DecodingError.dataCorrupted(error)
            }
        }
    }
    
    enum ArgumentDisplayMode: Equatable, Codable {
        case register(supported: [ARMGeneralPurposeRegister.GP64])
        case shift
        case decimal
        case hex
        case address
        
        enum CodingKeys: CodingKey {
            case register, shift, decimal, hex, address
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self {
            case .register(let supportedRegisters):
                try container.encode(supportedRegisters, forKey: .register)
            case .shift:
                try container.encode(true, forKey: .shift)
            case .decimal:
                try container.encode(true, forKey: .decimal)
            case .hex:
                try container.encode(true, forKey: .hex)
            case .address:
                try container.encode(true, forKey: .address)
            }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let key = container.allKeys.first
            switch key {
            case .register:
                let supportedRegisters = try container.decode([ARMGeneralPurposeRegister.GP64].self, forKey: .register)
                self = .register(supported: supportedRegisters)
            case .shift:
                self = .shift
            case .decimal:
                self = .decimal
            case .hex:
                self = .hex
            case .address:
                self = .address
            default:
                let error = DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unabled to decode enum."
                )
                throw DecodingError.dataCorrupted(error)
            }
        }
    }
}
