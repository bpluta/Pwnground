//
//  InstructionBuilderComponent.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI
import Combine

struct InstructionBuilderEditableComponent: View {
    @State var text: String
    
    var body: some View {
        ZStack {
            HStack {
                Text(text)
                    .foregroundColor(Color.black)
                    .font(.system(size: 15, weight: .regular, design: .default))
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 3)
            .overlay(
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(ThemeColors.diabledGray)
                        .frame(height: 3)
                        .padding(.bottom, 0)
                }
                
            )
            .background(ThemeColors.lighterGray)
            .cornerRadius(5)
        }
    }
}

class ArgumentValue {
    let value: Int? = nil
    let displayMode: InstructionCell.ArgumentDisplayMode
    
    init(displayMode: InstructionCell.ArgumentDisplayMode) {
        self.displayMode = displayMode
    }
    var description: String {
        var description: String?
        switch displayMode {
        case .register(let supportedRegisters):
            let register = supportedRegisters.first(where: { $0.value?.asInt == value })
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
        return description ?? ""
    }
}

class InstructionCellItem: NSObject, ObservableObject, Codable {
    let id = UUID()
    let type: InstructionCell.InstructionType
    
    @PublishedArray var arguments: [InstructionCell.Argument]
    @Published var isSelected: Bool = false
    
    static let dataUTI = "public.item"
    
    private var cancelBag = CancelBag()
    
    init(type: InstructionCell.InstructionType) {
        self.type = type
        self.arguments = type.arguments
        super.init()
        $arguments.register(observableObject: self).store(in: cancelBag)
    }
    
    init?(from instruction: ARMInstruction) {
        guard
            let instructionType = InstructionCell.InstructionType.getInstructionType(of: instruction),
            let filledArguments = InstructionCell.InstructionType.getFilledArguments(with: instruction)
        else { return nil }
        self.type = instructionType
        self.arguments = filledArguments
        super.init()
        $arguments.register(observableObject: self).store(in: cancelBag)
    }

    func updateInstructionArgument(index: Int, to newValue: Int) {
        guard arguments.indices.contains(index) else { return }
        arguments[index].value = newValue
    }
    
    func build() -> ARMInstruction? {
        type.build(with: arguments)
    }
    
    enum CodingKeys: CodingKey {
        case type
        case arguments
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(arguments, forKey: .arguments)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(InstructionCell.InstructionType.self, forKey: .type)
        arguments = try container.decode([InstructionCell.Argument].self, forKey: .arguments)
        super.init()
        $arguments.register(observableObject: self).store(in: cancelBag)
    }
}

extension InstructionCellItem: NSItemProviderWriting, NSItemProviderReading {
    static var writableTypeIdentifiersForItemProvider: [String] { [dataUTI] }
    static var readableTypeIdentifiersForItemProvider: [String] { [dataUTI] }
    
    static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
        let decoder = JSONDecoder()
        return try decoder.decode(Self.self, from: data)
    }
    
    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        let progress = Progress(totalUnitCount: 1)
        DispatchQueue.global(qos: .userInitiated).async {
            progress.completedUnitCount = 1
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                completionHandler(try encoder.encode(self), nil)
            } catch {
                completionHandler(nil, error)
            }
        }
        return progress
    }
}
