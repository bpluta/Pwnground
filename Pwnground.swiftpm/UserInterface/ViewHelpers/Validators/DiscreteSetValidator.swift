//
//  DiscreteRangeNumberValidator.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI
import Combine

class DiscreteRangeNumberValidator: Validator {
    var discreteSet: [Int]
    
    init(discreteSet: [Int]) {
        self.discreteSet = discreteSet
    }
    
    func validate(_ value: Int?) -> ValidatorResultPublisher {
        var result: ValidatorResult
        guard let value = value else {
            return Just(ValidatorResult(isValid: true)).eraseToAnyPublisher()
        }
        if discreteSet.contains(value) {
            result = ValidatorResult(isValid: true)
        } else {
            result = ValidatorResult(isValid: false, message: "")
        }
        return Just(result).eraseToAnyPublisher()
    }
}
