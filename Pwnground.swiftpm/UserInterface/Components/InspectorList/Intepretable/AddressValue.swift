//
//  AddressValue.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

class AddressValue: Interpretable, ObservableObject {
    let key: UInt64
    @Published var value: UInt64?
    @Published var presentationType: ValueInterpretationType = .hexadecimal
    @Published var displayMode: InterpretableDisplayMode = .normal
    
    var presentedKey: String { key.simplifiedDynamicWidthHexString }
    
    required init(key: UInt64, value: UInt64?) {
        self.key = key
        self.value = value
    }
    
    required init(from oldObject: AddressValue, updatedTo newValue: UInt64? = nil) {
        self.key = oldObject.key
        self.value = newValue
        self.presentationType = oldObject.presentationType
    }
}
