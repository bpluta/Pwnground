//
//  ARMInstructionStringBuilder.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

protocol ARMInstructionStringBuilderItem {
    func buildItem() throws -> String?
}

enum BuilderRule<T> {
    case required(_ type: T?)
    case optional(_ type: T?)
    
    func unwrapValue() throws -> T? {
        switch self {
        case .optional(let value):
            return value
        case .required(let value):
            guard let value = value else {
                throw BuilderError.RequiredElementNotFound
            }
            return value
        }
    }
}

enum BuilderError: Error {
    case RequiredElementNotFound
}

// MARK: - Root Builder
class ARMInstructionStringBuilder {
    private(set) var mnemonic: ARMInstructionStringBuilderItem?
    private(set) var arguments = [ARMInstructionStringBuilderItem?]()
    
    init() { }
    
    convenience init(mnemonic: ARMMnemonicBuilder, arguments: [ARMInstructionStringBuilderItem] = []) {
        self.init()
        self.mnemonic = mnemonic
        self.arguments = arguments
    }
    
    func build() throws -> String {
        guard let mnemonic = try mnemonic?.buildItem() else { return "" }
        let arguments = try self.arguments.compactMap({ try $0?.buildItem() }).joined(separator: ", ")
        return [mnemonic, arguments].filter({ !$0.isEmpty }).joined(separator: " ")
    }
    
    private func unwrapValue<T>(from rule: BuilderRule<T>) throws -> T? {
        switch rule {
        case .optional(let value):
            return value
        case .required(let value):
            guard let value = value else {
                throw BuilderError.RequiredElementNotFound
            }
            return value
        }
    }
    
    func addArgument(builder: ARMInstructionStringBuilderItem) {
        arguments.append(builder)
    }
    
    func addArguments(builders: [ARMInstructionStringBuilderItem]) {
        arguments.append(contentsOf: arguments)
    }
}

// MARK: - Register
struct ARMRegisterBuilder: ARMInstructionStringBuilderItem {
    let register: BuilderRule<ARMRegister>
    
    func buildItem() throws -> String? {
        let register: ARMRegister? = try self.register.unwrapValue()
        return register?.description
    }
}

// MARK: - Mnemonic
struct ARMMnemonicBuilder: ARMInstructionStringBuilderItem {
    let mnemonicBase: BuilderRule<ARMMnemonic>
    let suffix: BuilderRule<ARMMnemonic.Suffix>
    
    init(mnemonicBase: BuilderRule<ARMMnemonic>, suffix: BuilderRule<ARMMnemonic.Suffix> = .optional(.none)) {
        self.mnemonicBase = mnemonicBase
        self.suffix = suffix
    }
    
    func buildItem() throws -> String? {
        let mnemonicBase = try self.mnemonicBase.unwrapValue()
        let suffix = try self.suffix.unwrapValue()
        
        let mnemonicComponents = [mnemonicBase?.rawValue, suffix?.rawValue].compactMap({ $0 })
        return mnemonicComponents.joined(separator: mnemonicBase?.suffixSeparator ?? ARMMnemonic.defaultSeparator)
    }
}

// MARK: - Target
struct ARMTargetBuilder: ARMInstructionStringBuilderItem {
    let target: BuilderRule<ARMMnemonic.IndirectionTarget>
    
    func buildItem() throws -> String? {
        let target: ARMMnemonic.IndirectionTarget? = try self.target.unwrapValue()
        return target?.rawValue
    }
}

// MARK: - Immediate
struct ARMImmediateBuilder<IntegerType: FixedWidthInteger>: ARMInstructionStringBuilderItem {
    let immediate: BuilderRule<IntegerType>
    
    func buildItem() throws -> String? {
        guard let immediate = try self.immediate.unwrapValue() else { return nil }
        return "#\(immediate)"
    }
}

// MARK: - Shift
struct ARMShiftBuilder<IntegerType: FixedWidthInteger>: ARMInstructionStringBuilderItem {
    let mnemonic: BuilderRule<ARMMnemonic.Shift>
    let immediate: BuilderRule<IntegerType>
    
    func buildItem() throws -> String? {
        guard
            let rawMnemonic = try self.mnemonic.unwrapValue()?.rawValue,
            let immediateValue = try self.immediate.unwrapValue(),
            immediateValue != 0
        else { return nil }
        
        let mnemonic = ARMMnemonicBuilder(mnemonicBase: .required(ARMMnemonic(rawValue: rawMnemonic)))
        let immediate = ARMImmediateBuilder(immediate: .required(immediateValue))
        
        let builder = ARMInstructionStringBuilder(mnemonic: mnemonic, arguments: [immediate])
        return try builder.build()
    }
}

// MARK: - Extension
struct ARMExtensionBuilder<IntegerType: FixedWidthInteger>: ARMInstructionStringBuilderItem {
    let mnemonic: BuilderRule<ARMMnemonic.Extension>
    let immediate: BuilderRule<IntegerType>
    
    func buildItem() throws -> String? {
        guard
            let rawMnemonic = try self.mnemonic.unwrapValue()?.rawValue,
            let immediateValue = try self.immediate.unwrapValue()
        else { return nil }
        
        let mnemonic = ARMMnemonicBuilder(mnemonicBase: .required(ARMMnemonic(rawValue: rawMnemonic)))
        let immediate = ARMImmediateBuilder(immediate: .required(immediateValue))
        
        let builder = ARMInstructionStringBuilder(mnemonic: mnemonic, arguments: [immediate])
        return try builder.build()
    }
}

// MARK: - Address
struct ARMAddresBuilder<IntegerType: FixedWidthInteger>: ARMInstructionStringBuilderItem {
    let arguments: [ARMInstructionStringBuilderItem]
    let indexingMode: IndexingMode
    
    // MARK: Addressing with shift
    init(
        baseRegister: BuilderRule<ARMRegister>,
        indexRegister: BuilderRule<ARMRegister> = .optional(.none),
        offsetImmediate: BuilderRule<IntegerType> = .optional(.none),
        shift: BuilderRule<ARMMnemonic.Shift> = .optional(.none),
        shiftImmediate: BuilderRule<IntegerType> = .optional(.none),
        indexingMode: IndexingMode = .post
    ) {
        self.indexingMode = indexingMode
        self.arguments = [
            ARMRegisterBuilder(register: baseRegister),
            ARMRegisterBuilder(register: indexRegister),
            ARMImmediateBuilder(immediate: offsetImmediate),
            ARMShiftBuilder(mnemonic: shift, immediate: shiftImmediate)
        ]
    }
    
    // MARK: Addressing with extension
    @_disfavoredOverload
    init(
        baseRegister: BuilderRule<ARMRegister>,
        indexRegister: BuilderRule<ARMRegister> = .optional(.none),
        offsetImmediate: BuilderRule<IntegerType> = .optional(.none),
        extension: BuilderRule<ARMMnemonic.Extension> = .optional(.none),
        extensionImmediate: BuilderRule<IntegerType> = .optional(.none),
        indexingMode: IndexingMode = .post
    ) {
        self.indexingMode = indexingMode
        self.arguments = [
            ARMRegisterBuilder(register: baseRegister),
            ARMRegisterBuilder(register: indexRegister),
            ARMImmediateBuilder(immediate: offsetImmediate),
            ARMExtensionBuilder(mnemonic: `extension`, immediate: extensionImmediate)
        ]
    }
    
    func buildItem() throws -> String? {
        let arguments = try self.arguments.compactMap({ try $0.buildItem() }).joined(separator: ", ")
        guard !arguments.isEmpty else { return nil }
        let suffix = indexingMode == .pre ? "!" : ""
        return "[\(arguments)]\(suffix)"
    }
}

// MARK: - Label
struct ARMLabelBuilder: ARMInstructionStringBuilderItem {
    let label: BuilderRule<String>
    
    init(label: BuilderRule<String>) {
        self.label = label
    }
    
    init(imm1: Int, imm2: Int) {
        let addressLabel = "\(imm1.hexString):\(imm2.hexString)"
        self.label = .required(addressLabel)
    }
    
    func buildItem() throws -> String? {
        let label = try self.label.unwrapValue()
        return label
    }
}
