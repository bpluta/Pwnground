//
//  Validator.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Combine

typealias ValidatorResultPublisher = AnyPublisher<ValidatorResult, Never>
    
struct ValidatorResult {
    let isValid: Bool
    let validatorMessage: String?
    
    init(isValid: Bool, message: String? = nil) {
        self.isValid = isValid
        self.validatorMessage = message
    }
}

protocol Validator {
    func validate(_ value: Int?) -> ValidatorResultPublisher
}
