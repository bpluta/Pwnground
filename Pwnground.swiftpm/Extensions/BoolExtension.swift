//
//  BoolExtension.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

extension Bool {
    init(_ value: UInt32) {
        self = value != 0
    }
    
    static func &<<<IntegerType: FixedWidthInteger>(lhs: Bool, rhs: IntegerType) -> IntegerType {
        guard lhs, rhs >= 0 else { return 0 }
        return 1 &<< rhs
    }
}
