//
//  InteractorContainer.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI

struct InteractorContainer {
    let operatingSystemInteractor: OperatingSystemBusinessLogic
    let userInterfaceInteractor: UserInterfaceInteractionLogic
    
    init(operatingSystemInteractor: OperatingSystemBusinessLogic, userInterfaceInteractor: UserInterfaceInteractionLogic) {
        self.operatingSystemInteractor = operatingSystemInteractor
        self.userInterfaceInteractor = userInterfaceInteractor
    }
    
    static var stub: Self {
        Self(
            operatingSystemInteractor: StubOperatingSystemInteractor(),
            userInterfaceInteractor: StubUserInterfaceInteractor()
        )
    }
}

struct InteractorContainerKey: EnvironmentKey {
    static let defaultValue = InteractorContainer.stub
}

extension EnvironmentValues {
    var interactors: InteractorContainer {
        get {
            self[InteractorContainerKey.self]
        }
        set {
            self[InteractorContainerKey.self] = newValue
        }
    }
}
