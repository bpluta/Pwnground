//
//  PwngroundLevel.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI
import Combine

protocol PwngroundLevel: PwngroundLevelSetup, AnyObject {
    var scene: PwngroundScene.Scene { get }
    
    var initialPayload: Data? { get }
    var hasBeenCompleted: Bool { get set }
    var didDisplayHelpSheet: Bool { get set }
    var interactors: InteractorContainer { get }
    
    var levelPassPublisher: AnyPublisher<Void, Never> { get }
    
    func solve()
}

class LevelStateContainer: ObservableObject {
    @Published private(set) var user: SystemUser
    
    var bufferOverflowLevelModel: BufferOverflowLevel
    var paddingFindingLevelModel: PaddingFindingLevel
    var shellpathAssemblingLevelModel: ShellpathAssemblingLevel
    var shellcodeBuildingLevelModel: ShellcodeBuildingLevel
    var exploitingLevelModel: ExploitingLevel
    
    var models: [PwngroundLevel] {[
        bufferOverflowLevelModel,
        paddingFindingLevelModel,
        shellpathAssemblingLevelModel,
        shellcodeBuildingLevelModel,
        exploitingLevelModel
    ]}
    
    init(username: String) {
        let user = SystemUser(uid: 1337, name: username)
        self.user = user
        self.bufferOverflowLevelModel = BufferOverflowLevel(user: user)
        self.paddingFindingLevelModel = PaddingFindingLevel(user: user)
        self.shellpathAssemblingLevelModel = ShellpathAssemblingLevel(user: user)
        self.shellcodeBuildingLevelModel = ShellcodeBuildingLevel(user: user)
        self.exploitingLevelModel = ExploitingLevel(user: user)
    }
}

protocol ApplicationUILevel: PwngroundLevel {
    var viewModel: ApplicationUIView.ViewModel { get set }
}

protocol DebuggerLevel: PwngroundLevel {
    var viewModel: DebuggerContainer.ViewModel { get set }
    var layoutState: DebuggerContainer.LayoutState { get set }
}

extension InteractorContainer {
    static var pwngroundOperatingSystem: OperatingSystem {
        let system = OperatingSystem()
        system.groups = [SystemGroup.winnerGroup]
        system.users = [SystemUser.admin]
        return system
    }
    
    static func pwngroundInteractors(operatingSystem: OperatingSystem, user: SystemUser) -> InteractorContainer {
        .init(
            operatingSystemInteractor: OperatingSystemInteractor(
                operatingSystem: operatingSystem,
                user: user
            ),
            userInterfaceInteractor: UserInterfaceInteractor()
        )
    }
}

extension OperatingSystem {
    static func pwngroundOperatingSystem(with user: SystemUser) -> OperatingSystem {
        let system = OperatingSystem()
        system.groups = [SystemGroup.winnerGroup]
        system.users = [SystemUser.admin, user]
        return system
    }
}

extension SystemGroup {
    static var winnerGroup: SystemGroup {
        SystemGroup(gid: ScholarshipApp.wwdcScholarsGroupId, name: "wwdc")
    }
}

extension SystemUser {
    static var admin: SystemUser {
        SystemUser(uid: 0, name: "admin")
    }
}
