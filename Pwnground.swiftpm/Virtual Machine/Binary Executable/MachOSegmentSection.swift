//
//  MachOSegmentSection.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

class MachOSegmentSection {
    let sectname: String
    let segname: String
    let addr: UInt64 // adress in vm
    let size: UInt64 // size in vm
    let offset: UInt32 // offset in file to this section
    let align: UInt32 // byte alignment (to power of 2)
    let reloff: UInt32 // file offset of first relocation entry
    let nreloc: UInt32 // number of relocations
    let flags: UInt32
    let reserved1: UInt32
    let reserved2: UInt32
    
    static let size = 76
    
    init(section: String, segment: String, address: Address, size: UInt64, offset: UInt32) {
        self.sectname = section
        self.segname = segment
        self.addr = address
        self.size = size
        self.offset = offset
        self.align = 0
        self.reloff = 0
        self.nreloc = 0
        self.flags = 0
        self.reserved1 = 0
        self.reserved2 = 0
    }
    
    init(from rawData: Data) throws {
        guard rawData.count >= MachOSegmentSection.size,
              let sectname = String(data: Data(rawData[0..<16]), encoding: .utf8),
              let segname = String(data: Data(rawData[16..<32]), encoding: .utf8),
              let addr = Data(rawData[32..<40]).to(type: UInt64.self),
              let size = Data(rawData[40..<48]).to(type: UInt64.self),
              let offset = Data(rawData[48..<52]).to(type: UInt32.self),
              let align = Data(rawData[52..<56]).to(type: UInt32.self),
              let reloff = Data(rawData[56..<60]).to(type: UInt32.self),
              let nreloc = Data(rawData[60..<64]).to(type: UInt32.self),
              let flags = Data(rawData[64..<68]).to(type: UInt32.self),
              let reserved1 = Data(rawData[68..<72]).to(type: UInt32.self),
              let reserved2 = Data(rawData[72..<76]).to(type: UInt32.self)
        else {
            throw MachOHeaderError.InvalidData
        }
        self.sectname = sectname
        self.segname = segname
        self.addr = addr
        self.size = size
        self.offset = offset
        self.align = align
        self.reloff = reloff
        self.nreloc = nreloc
        self.flags = flags
        self.reserved1 = reserved1
        self.reserved2 = reserved2
    }
    
    private func getData(for string: String) -> Data {
        let size = 16
        var data = Data(string.utf8)
        if data.count < size {
            let padding = Data(count: size - data.count)
            data.append(padding)
            return data
        } else if data.count > size {
            return data[0..<size]
        }
        return data
    }
}
