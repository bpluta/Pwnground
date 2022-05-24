//
//  ProcessSpawner.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

class ProcessSpawner {
    static func spawnProcess(pid: PID, from binary: Data, as context: UID) throws -> SystemProcess {
        let newProcess = SystemProcess(pid: pid, owner: context)
        let dynamicLinker = DynamicLinker()
        dynamicLinker.linkedProcess = newProcess
        try dynamicLinker.loadBinary(binary)
        return newProcess
    }
}
