//
//  DataExtension.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

extension Data {
    init<T>(from value: T) {
        self = Swift.withUnsafeBytes(of: value) { Data($0) }
    }
    
    init<T>(fromArray values: [T]) {
        self = values.withUnsafeBytes { Data($0) }
    }
    
    func to<T>(type: T.Type) -> T? where T: ExpressibleByIntegerLiteral {
        var value: T = 0
        guard count <= MemoryLayout.size(ofValue: value) else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value) { copyBytes(to: $0) }
        return value
    }
    
    func toArray<T>(of type: T.Type) -> [T]? where T: ExpressibleByIntegerLiteral {
        let chunkSize = MemoryLayout.size(ofValue: 0 as T)
        var bytesLeft = count
        var values = [T]()
        while bytesLeft > 0 {
            let bytesToCopy = bytesLeft >= chunkSize ? chunkSize : bytesLeft
            var value: T = 0
            _ = Swift.withUnsafeMutableBytes(of: &value) {
                copyBytes(to: $0, from: count - bytesLeft ..< count - bytesLeft + bytesToCopy)
            }
            bytesLeft -= bytesToCopy
            values.append(value)
        }
        return values
    }
    
    func printableStringRepresentation<Encoding>(as encoding: Encoding.Type) -> String where Encoding : _UnicodeEncoding, Element == Encoding.CodeUnit {
        var value = String(decoding: self, as: encoding)
        if let indexOfNullByte = value.firstIndex(where: { $0.asciiValue == 0 }) {
            value = String(value[value.startIndex..<indexOfNullByte])
        }
        return value
            .components(separatedBy: .controlCharacters)
            .joined(separator: "�")
    }
    
    func rawStringRepresentation<Encoding>(as encoding: Encoding.Type) -> String where Encoding : _UnicodeEncoding, Element == Encoding.CodeUnit {
        var value = String(decoding: self, as: encoding)
        if let indexOfNullByte = value.firstIndex(where: { $0.asciiValue == 0 }) {
            value = String(value[value.startIndex..<indexOfNullByte])
        }
        let shouldFilterASCII = encoding == Unicode.ASCII.self
        return value
            .unicodeScalars
            .map { $0.escaped(asASCII: shouldFilterASCII) }
            .joined(separator: "")
    }
    
    var hexComponents: [String] {
        map { String(format: "%02hhX", $0) }
    }
}
