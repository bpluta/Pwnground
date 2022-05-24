//
//  AsciiValue.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

class AsciiValue: Interpretable, ObservableObject {
    let key: Character
    @Published var value: UInt64?
    @Published var presentationType: ValueInterpretationType = .hexadecimal
    @Published var displayMode: InterpretableDisplayMode = .normal
    
    var suggestedPresentationTypes: [ValueInterpretationType] { [.hexadecimal] }
    var presentedKey: String {
        guard let value = key.asciiValue else { return "�" }
        return Data(from: value).printableStringRepresentation(as: Unicode.ASCII.self)
    }
    
    required init(key: Character, value: UInt64?) {
        self.key = key
        self.value = value
    }
    
    required init(from oldObject: AsciiValue, updatedTo newValue: UInt64? = nil) {
        self.key = oldObject.key
        self.value = newValue
        self.presentationType = oldObject.presentationType
    }
}
