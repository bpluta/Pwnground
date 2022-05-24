//
//  RawARMInstruction.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

typealias RawARMInstruction = UInt32

extension RawARMInstruction {
    var asBinaryString: String {
        var binaryString = ""
        var value = self
        while value > 0 {
            let nextBit = value % 2 == 0 ? "0" : "1"
            binaryString = nextBit + binaryString
            value >>= 1
        }
        if binaryString.isEmpty {
            binaryString = "0"
        }
        return binaryString
    }
    
    var asPaddedBinaryString: String {
        var binaryString = ""
        var value = self
        for _ in 0..<32 {
            let nextBit =  value % 2 == 0 ? "0" : "1"
            binaryString = nextBit + binaryString
            value >>= 1
        }
        return binaryString
    }
}

extension FixedWidthInteger {
    func masked(including range: Range<Int>) -> Self {
        self & ((Self.max << (Self.bitWidth - range.count)) >> (Self.bitWidth - range.endIndex))
    }
    
    func masked(excluding range: Range<Int>) -> Self {
        self & ((Self.max << range.endIndex) | (Self.max >> (Self.bitWidth - range.startIndex)))
    }
    
    static func &<<(_ lhs: Self, _ range: Range<Int>) -> Self {
        (lhs &<< (Self.bitWidth - range.count)) &>> (Self.bitWidth - range.endIndex)
    }
    
    static func &>>(_ lhs: Self, _ range: Range<Int>) -> Self {
        (lhs &<< (Self.bitWidth - range.endIndex)) &>> (Self.bitWidth - (range.endIndex - range.startIndex))
    }
}
