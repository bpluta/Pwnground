//
//  FlagValue.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

class FlagValue: Interpretable, ObservableObject {
    let key: ARMConditionFlag
    @Published var value: Bool?
    @Published var presentationType: ValueInterpretationType = .boolean
    @Published var displayMode: InterpretableDisplayMode = .normal
    
    var suggestedPresentationTypes: [ValueInterpretationType] { [.boolean] }
    var presentedKey: String { key.description }
    
    required init(key: ARMConditionFlag, value: Bool?) {
        self.key = key
        self.value = value
    }
    
    required init(from oldObject: FlagValue, updatedTo newValue: Bool? = nil) {
        self.key = oldObject.key
        self.value = newValue
        self.presentationType = oldObject.presentationType
    }
}
