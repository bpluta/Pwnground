//
//  InstructionBuilderArgumentPickers.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI
import Combine

struct InstructionBuilderArgumentView: View {
    @ObservedObject var argument: InstructionCell.Argument
    
    let title: String
    let isSelected: Bool
    
    private var strokeColor: Color {
        guard isSelected else { return Color.clear }
        return argument.validationResult.isValid ? Color.blue : Color.red
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            CellContent()
            ValidationMessage()
        }
        .padding(.vertical, 10)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func CellContent() -> some View {
        HStack {
            Text(title)
                .foregroundColor(.gray)
            Spacer()
            Text(argument.valueDescription ?? "None")
                .frame(minWidth: 50, alignment: .center)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(strokeColor, lineWidth: 3)
                )
        }
    }
    
    @ViewBuilder
    private func ValidationMessage() -> some View {
        if let validationMessage = argument.validationResult.validatorMessage {
            Text(validationMessage)
                .font(.system(size: 12))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(Color.red)

        }
    }
}

struct ArgumentValuePicker: View {
    class ViewModel: ObservableObject {
        @Published var numericKeyboardMode: NumberValueKeyboardMode = .decimal
        
        var keyboardModeCancellable: AnyCancellable?
    }
    @ObservedObject var object: InstructionCell.Argument
    @StateObject var viewModel = ViewModel()
    
    var body: some View {
        ArgumentPickerComponent()
    }
    
    @ViewBuilder
    func ArgumentPickerComponent() -> some View {
        switch object.argumentType {
        case .register(_, let allowedValues):
            RegisterInstruction(values: allowedValues)
        case .immediateRange(_, _):
            ImmediateRangeInstruction()
        case .immediateSelected(_, let allowedValues):
            ImmediateSetectedInstruction(values: allowedValues)
        case .shift(_, let allowedShifts):
            ShiftInstruction(shifts: allowedShifts)
        case .postIndexedAddress(_, _), .preIndexedAddress(_, _), .offsetIndexedAddress:
            EmptyView()
        }
    }
    
    @ViewBuilder
    func RegisterInstruction(values: [ARMGeneralPurposeRegister.GP64]) -> some View {
        WheelPicker(title: "Register", values: values, tagKey: Int.self, selection: $object.registerValue) { value in
            Text(value.rawValue.uppercased())
                .tag(value as ARMGeneralPurposeRegister.GP64?)
        }
    }
    
    @ViewBuilder
    func ImmediateRangeInstruction() -> some View {
        SignedNumberKeyboard(mode: $viewModel.numericKeyboardMode, value: $object.value)
            .onAppear(perform: setupKeyboardPipeline)
    }
    
    @ViewBuilder
    func ImmediateSetectedInstruction(values: [Int]) -> some View {
        WheelPicker(title: "Val", values: values, tagKey: Int.self, selection: $object.value) { value in
            Text(object.displayMode == .hex ? value.dynamicWidthHexString : value.description)
                .tag(value as Int?)
        }
    }
    
    @ViewBuilder
    func ShiftInstruction(shifts: [ARMMnemonic.Shift]) -> some View {
        WheelPicker(title: "Shift", values: shifts, tagKey: ARMMnemonic.Shift.self, selection: $object.value) { value in
            Text(value.rawValue.uppercased())
                .tag(value as ARMMnemonic.Shift?)
        }
    }
    
    @ViewBuilder
    private func WheelPicker<Content: View, PickerItem: Hashable, SelectionValue: Hashable, TagKey: Hashable>(title: String, values: [PickerItem], tagKey: TagKey.Type, selection: Binding<SelectionValue?>, @ViewBuilder content: @escaping (PickerItem) -> Content) -> some View {
        Picker(title, selection: selection) {
            Text("None").tag(nil as TagKey?)
            ForEach(values, id: \.self) { value in
                content(value)
            }
        }.pickerStyle(.wheel)
    }
    
    private func setupKeyboardPipeline() {
        viewModel.numericKeyboardMode = NumberValueKeyboardMode(from: object.displayMode) ?? .decimal
        viewModel.keyboardModeCancellable = viewModel.$numericKeyboardMode
            .dropFirst()
            .map { item in
                switch item {
                case .decimal:
                    return .decimal
                case .hexadecimal:
                    return .hex
                }
            }.sink { value in
                object.displayMode = value
            }
    }
}

struct PickerView: View {
    class ViewModel: ObservableObject {
        @Published var selectedArgument: InstructionCell.Argument?
    }
    
    @StateObject var viewModel = ViewModel()
    @ObservedObject var instructionInfo: InstructionCellItem
    
    var deleteAction: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Toolbar()
            Description()
            Separator()
            ArgumentCells()
            Separator()
            SelectedPickerItem()
        }
    }
    
    @ViewBuilder
    private func Toolbar() -> some View {
        HStack {
            Button(action: {
                instructionInfo.isSelected = false
                deleteAction()
            }) {
                Image(systemName: "trash")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20)
                    .foregroundColor(Color.red)
            }.buttonStyle(.plain)
            Spacer()
            Button(action: {
                instructionInfo.isSelected = false
            }) {
                Image(systemName: "xmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15)
                    .foregroundColor(Color.gray) 
            }.buttonStyle(.plain)
        }.padding(.vertical, 15)
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func Description() -> some View {
        Text(instructionInfo.type.behaviorDescription)
            .multilineTextAlignment(.center)
            .font(.system(size: 13))
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .foregroundColor(Color.gray)
            .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private func Separator() -> some View {
        Divider()
            .padding(.horizontal, 10)
    }
    
    @ViewBuilder
    private func ArgumentCells() -> some View {
        ForEach(instructionInfo.arguments) { argument in
            ArgumentCells(from: argument)
        }
    }
    
    @ViewBuilder
    private func ArgumentCells(from argument: InstructionCell.Argument) -> some View {
        if argument.mutability == .mutable {
            let subarguments = argument.subarguments.filter { $0.mutability == .mutable }
            if !subarguments.isEmpty {
                ForEach(subarguments) { argument in
                    Argument(for: argument)
                }
            } else {
                Argument(for: argument)
            }
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func Argument(for argument: InstructionCell.Argument) -> some View {
        Group {
            switch argument.argumentType {
            case .register(let role, _), .immediateRange(let role, _), .immediateSelected(let role, _), .shift(let role, _):
                InstructionBuilderArgumentView(
                    argument: argument,
                    title: role.description,
                    isSelected: argument === viewModel.selectedArgument
                )
            case .postIndexedAddress(_, _), .preIndexedAddress(_, _), .offsetIndexedAddress(_,_):
                EmptyView()
            }
        }.onTapGesture { select(argument: argument) }
    }
    
    @ViewBuilder
    private func SelectedPickerItem() -> some View {
        if let selectedArgument = viewModel.selectedArgument {
            ArgumentValuePicker(object: selectedArgument)
        } else {
            Text("Select argument")
                .frame(height: 200, alignment: .center)
        }
    }
}

extension PickerView {
    private func select(argument: InstructionCell.Argument) {
        viewModel.selectedArgument = argument
    }
}

#if DEBUG
struct InstructionBuilderArgumentPreview: PreviewProvider {
    
    static let instructionCellItem = InstructionCellItem(type: .movImmediate)
    
    static var previews: some View {
        Group {
            PickerView(instructionInfo: instructionCellItem, deleteAction: {})
        }
    }
}
#endif
