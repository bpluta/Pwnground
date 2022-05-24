//
//  PwngroundLevelSetup.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI
import Combine

protocol PwngroundLevelSetup {
    var applicationBinary: Data { get }
    var initialPayload: Data? { get }
    var setupPublisher: AnyPublisher<Void,Never> { get }
}

extension PwngroundLevelSetup {
    var applicationBinary: Data {
        BinaryAssembler.encodeBinary(from: ScholarshipApp().buildMachOFile())
    }
    var initialPayload: Data? { nil }
    var setupPublisher: AnyPublisher<Void,Never> {
        Empty().eraseToAnyPublisher()
    }
}

class DefaultPwngroundLevelSetup: PwngroundLevelSetup { }

struct PwngroundLevelSetupKey: EnvironmentKey {
    static let defaultValue: PwngroundLevelSetup = DefaultPwngroundLevelSetup()
}

extension EnvironmentValues {
    var levelSetup: PwngroundLevelSetup {
        get {
            self[PwngroundLevelSetupKey.self]
        }
        set {
            self[PwngroundLevelSetupKey.self] = newValue
        }
    }
}
