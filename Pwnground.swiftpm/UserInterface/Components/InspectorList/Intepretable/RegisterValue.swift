//
//  RegisterValue.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

class RegisterValue: Interpretable, ObservableObject {
    let key: ARMGeneralPurposeRegister.GP64
    @Published var value: UInt64?
    @Published var presentationType: ValueInterpretationType = .hexadecimal
    @Published var displayMode: InterpretableDisplayMode = .normal
    
    var presentedKey: String { key.description?.uppercased() ?? "?" }
    
    required init(key: ARMGeneralPurposeRegister.GP64, value: UInt64?) {
        self.key = key
        self.value = value
    }
    
    required init(from oldObject: RegisterValue, updatedTo newValue: UInt64? = nil) {
        self.key = oldObject.key
        self.value = newValue
        self.presentationType = oldObject.presentationType
    }
}
