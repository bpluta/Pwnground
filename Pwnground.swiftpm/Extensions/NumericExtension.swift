//
//  NumericExtension.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

extension Numeric {
    var asBool: Bool {
        self != 0
    }
}

extension FixedWidthInteger {
    var hexString: String {
        String(format:"0x%0\(bitWidth / 4)llx", self as! CVarArg)
    }
    
    var dynamicWidthHexString: String {
        String(format:"0x%llx", self as! CVarArg)
    }
    
    var uppercaseDynamicWidthHexString: String {
        String(format:"0x%llX", self as! CVarArg)
    }
    
    var simplifiedDynamicWidthHexString: String {
        String(format:"%llX", self as! CVarArg)
    }
}

extension FixedWidthInteger {
    init(_ boolValue: Bool) {
        self = boolValue ? 1 : 0
    }
    
    subscript(_ index: Int) -> Bool? {
        self[index..<index+1]?.asBool
    }
    
    subscript(_ range: Range<Int>) -> Self? {
        guard
            range.startIndex >= 0, range.startIndex < Self.bitWidth,
            range.endIndex >= 0, range.endIndex <= Self.bitWidth,
            range.startIndex < range.endIndex
        else { return nil }
        return (self &<< (Self.bitWidth - range.endIndex)) &>> (Self.bitWidth - (range.endIndex - range.startIndex))
    }
    
    subscript(_ startPosition: Int, _ endPosition: Int) -> Self? {
        guard
            startPosition >= 0, startPosition < Self.bitWidth,
            endPosition >= 0, endPosition <= Self.bitWidth,
            startPosition < endPosition
        else { return nil }
        return (self &<< (Self(Self.bitWidth - endPosition))) &>> (Self(bitWidth - (endPosition - startPosition)))
    }
    
    var asUInt8: UInt8 {
        UInt8(truncatingIfNeeded: self)
    }
    
    var asInt16: Int16? {
        Int16(truncatingIfNeeded: self)
    }
    
    var asUInt16: UInt16 {
        UInt16(truncatingIfNeeded: self)
    }
    
    var asUInt32: UInt32 {
        UInt32(truncatingIfNeeded: self)
    }
    
    var asInt: Int {
        Int(truncatingIfNeeded: self)
    }
    
    static var ones: Self {
        var result: Self = 1
        for _ in 0 ..< bitWidth {
            result = (result &<< 1) | 0b1
        }
        return result
    }
    
    static var bytes: Int {
        bitWidth / 8
    }
}
