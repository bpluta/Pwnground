//
//  SignedNumberKeyboard.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI

protocol FixedWidthSignedInteger: FixedWidthInteger, SignedInteger { }

struct SignedNumberKeyboard<ValueType: FixedWidthInteger & SignedInteger>: View {
    @Binding var mode: NumberValueKeyboardMode
    @Binding var value: ValueType?
    let supportedModes: [NumberValueKeyboardMode] = NumberValueKeyboardMode.allCases
    
    var body: some View {
        NumberValueKeyboard(mode: _mode, value: _value, supportedModes: supportedModes) {
            NumberKeyboardButton(content: {
                Text("+/-")
                    .foregroundColor(.black)
                    .font(.system(size: mode == .hexadecimal ? 20 : 26, weight: .regular, design: .default))
            }, action: onSignChange)
        }
    }
    
    private func onSignChange() {
        guard let value = value else { return }
        self.value = -value
    }
}
