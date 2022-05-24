//
//  NumberKeyboard.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI

struct NumberKeyboardButton<Content: View>: View {
    let content: () -> Content
    let action: () -> Void
    
    @State private var pressed: Bool = false
    
    init(@ViewBuilder content: @escaping () -> Content, action: @escaping () -> Void) {
        self.content = content
        self.action = action
    }
    
    var body: some View {
        Button(action: action, label: {
            content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(pressed ? ThemeColors.whiteButtonPressedGray : ThemeColors.white)
            .cornerRadius(10)
            .shadow(radius: 1)
            .padding(.all, 1)
        })
        .gesture(
            DragGesture(minimumDistance: 0.0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

struct NumberValueKeyboard<ValueType: FixedWidthInteger, AccessoryType: View>: View {
    @Binding var mode: NumberValueKeyboardMode
    @Binding var value: ValueType?
    let supportedModes: [NumberValueKeyboardMode]
    let accessory: (() -> AccessoryType)
    
    init(mode: Binding<NumberValueKeyboardMode>, value: Binding<ValueType?>, supportedModes: [NumberValueKeyboardMode] = NumberValueKeyboardMode.allCases, @ViewBuilder accessory: @escaping () -> AccessoryType) {
        self._mode = mode
        self._value = value
        self.supportedModes = supportedModes
        self.accessory = accessory
    }
    
    var body: some View {
        VStack {
            ModePicker()
            Buttons()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(ThemeColors.lightGray)
    }
    
    private var base: Int {
        switch mode {
        case .hexadecimal: return 16
        case .decimal: return 10
        }
    }
    
    @ViewBuilder
    func ModePicker() -> some View {
        if supportedModes.count
            > 1 {
            Picker("", selection: $mode.animation(.spring())) {
                ForEach(supportedModes, id: \.rawValue) { mode in
                    Text(mode.rawValue)
                        .tag(mode)
                }
            }.pickerStyle(.segmented)
        }
    }
    
    @ViewBuilder
    func Buttons() -> some View {
        Group {
            if mode == .hexadecimal {
                HStack {
                    ValueButton(for: "D")
                    ValueButton(for: "E")
                    ValueButton(for: "F")
                }
                HStack {
                    ValueButton(for: "A")
                    ValueButton(for: "B")
                    ValueButton(for: "C")
                }
            }
            HStack {
                ValueButton(for: "7")
                ValueButton(for: "8")
                ValueButton(for: "9")
            }
            HStack {
                ValueButton(for: "4")
                ValueButton(for: "5")
                ValueButton(for: "6")
            }
            HStack {
                ValueButton(for: "1")
                ValueButton(for: "2")
                ValueButton(for: "3")
            }
            HStack {
                accessory()
                ValueButton(for: "0")
                DeleteButton()
            }
        }
    }
    
    @ViewBuilder
    func ValueButton(for value: String) -> some View {
        NumberKeyboardButton(content: {
            Text(value)
                .foregroundColor(.black)
                .font(.system(size: mode == .hexadecimal ? 20 : 26, weight: .regular, design: .default))
        }, action: { onValuePress(buttonValue: value) })
    }
    
    @ViewBuilder
    func DeleteButton() -> some View {
        NumberKeyboardButton(content: {
            Image(systemName: "delete.left")
                .foregroundColor(ThemeColors.middleGray)
        }, action: onDeleteDigit)
    }
    
    private func onValuePress(buttonValue: String) {
        let base = base
        guard let _ = ValueType(buttonValue, radix: base) else { return }
        var currentValue = ""
        if let value = value {
            currentValue = String(value, radix: base)
        }
        guard let newValue = ValueType(currentValue + buttonValue, radix: base) else { return }
        value = newValue
    }
    
    
    private func onDeleteDigit() {
        guard let value = value, value != 0 else { return }
        let base = base
        var currentValueString = String(value, radix: base)
        currentValueString.removeLast()
        self.value = ValueType(currentValueString, radix: base)
    }
}

extension NumberValueKeyboard where ValueType: SignedNumeric {
    private func onSignChange() {
        guard let value = value else { return }
        self.value = -value
    }
    
    @ViewBuilder
    func SignButton() -> some View {
        NumberKeyboardButton(content: {
            Text("+/-")
                .foregroundColor(.black)
                .font(.system(size: mode == .hexadecimal ? 20 : 26, weight: .regular, design: .default))
        }, action: onSignChange)
    }
}

extension NumberValueKeyboard {
    @ViewBuilder
    func SignButton() -> some View {
        Spacer()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum NumberValueKeyboardMode: String, Equatable, CaseIterable, Codable  {
    case decimal = "Dec"
    case hexadecimal = "Hex"
    
    init?(from mode: InstructionCell.ArgumentDisplayMode) {
        switch mode {
        case .decimal:
            self = .decimal
        case .hex:
            self = .hexadecimal
        default: return nil
        }
    }
}

struct NumberValueKeyboardPreview: PreviewProvider {
    @State static var value: Int? = 0
    @State static var displayedValue: String = ""
    @State static var mode: NumberValueKeyboardMode = .decimal
    
    static var previews: some View {
        Group {
            NumberValueKeyboard(mode: $mode, value: $value, accessory: { EmptyView() })
                .frame(width: 250, height: 300)
        }.previewLayout(.sizeThatFits)
    }
}
