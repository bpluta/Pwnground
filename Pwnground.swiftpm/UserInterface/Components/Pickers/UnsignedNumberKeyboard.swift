//
//  UnsignedNumberKeyboard.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI

struct UnsignedNumberKeyboard<ValueType: FixedWidthInteger>: View {
    @Binding var mode: NumberValueKeyboardMode
    @Binding var value: ValueType?
    let supportedModes: [NumberValueKeyboardMode]
    
    var body: some View {
        NumberValueKeyboard(mode: _mode, value: _value, supportedModes: supportedModes) {
            Spacer()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
