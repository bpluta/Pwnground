//
//  VirtualMemoryBlock.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

class VirtualMemoryBlock {
    let address: Address
    let size: UInt64
    
    var next: VirtualMemoryBlock?
    weak var previous: VirtualMemoryBlock?
    
    init(address: Address, size: UInt64) {
        self.address = address
        self.size = size
    }
    
    func contains(_ address: Address) -> Bool {
        address >= self.address && address < self.address + size
    }
    
    func place(between first: VirtualMemoryBlock?, and second: VirtualMemoryBlock?) {
        first?.next = self
        second?.previous = self
        
        previous = first
        next = second
    }
}

