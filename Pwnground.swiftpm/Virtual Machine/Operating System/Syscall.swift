//
//  Syscall.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

enum SystemCall: Error {
    case requestService(_ code: Syscall?)
}

enum Syscall: UInt32 {
    // BSD sycalls
    case exit = 0x2001
    case read = 0x2002
    case write = 0x2004
    case execve = 0x203b
    
    // Custom sycalls
    case getUidForName = 0x5001
    case uidBelongsToGid = 0x5002
    
    var number: UInt32 {
        rawValue
    }
}
