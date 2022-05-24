//
//  RangeValidator.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI
import Combine

class RangeValidator: Validator {
    var range: ClosedRange<Int>
    
    init(range: ClosedRange<Int>) {
        self.range = range
    }
    
    func validate(_ value: Int?) -> ValidatorResultPublisher {
        var result: ValidatorResult
        guard let value = value else {
            return Just(ValidatorResult(isValid: true)).eraseToAnyPublisher()
        }
        if range ~= value {
            result = ValidatorResult(isValid: true)
        } else {
            result = ValidatorResult(isValid: false, message: "Value should be within range of \(range.lowerBound) and \(range.upperBound)")
        }
        return Just(result).eraseToAnyPublisher()
    }
}
