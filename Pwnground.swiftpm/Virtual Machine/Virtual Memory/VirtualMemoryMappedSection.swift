//
//  VirtualMemoryMappedSegment.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

enum UserControlledMemorySegment: String {
    case Heap
    case Stack
}

struct VirtualMemoryMappedSegment {
    let name: String
    let startAddress: Address
    let size: UInt64
    let protection: VirtualMemoryProtectionType
    
    var endAddress: Address { startAddress + size }
    var range: Range<Address> { startAddress..<endAddress }
}
