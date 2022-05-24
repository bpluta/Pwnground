//
//  ShellcodeBuildingLevelScene.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI
import Combine

class ShellcodeBuildingLevel: PwngroundLevelSetup, DebuggerLevel {
    let scene: PwngroundScene.Scene = .buildingShellcode
    
    var viewModel = DebuggerContainer.ViewModel(
        baseAddress: 0x7fff_ffff_ff78 + UInt64(PayloadProvider.shellPath.count),
        displayedInstructions: [
            .init(mnemonic: .MOV, instructions: [.movRegister, .movImmediate]),
            .init(mnemonic: .MOVK, instructions: [.movkImmediateWithShift]),
            .init(mnemonic: .STR, instructions: [.strPreIndexedAddress, .strOffsetIndexedAddress, .strPostIndexedAddress]),
            .init(mnemonic: .ADD, instructions: [.addImmediate, .addRegisters]),
            .init(mnemonic: .SVC, instructions: [.svcImmediate])
        ]
    )
    var layoutState = DebuggerContainer.LayoutState(
        workspace: [.valueInspector, .interactionSection],
        valueInspector: [.memory, .register, .flags],
        insteractionSection: [.shellcodeBuilder, .instructionPicker]
    )
    
    var interactors: InteractorContainer
    
    var hasBeenCompleted = false
    var didDisplayHelpSheet = false
    
    var initialPayload: Data? {
        PayloadProvider.paddedValuesPayload +
        PayloadProvider.addressPayload +
        PayloadProvider.shellPath
    }
    
    var levelPassPublisher: AnyPublisher<Void, Never> { levelPassSubject.eraseToAnyPublisher() }
    var levelPassSubject = PassthroughSubject<Void, Never>()
    
    func checkSolution(for value: String) -> AnyPublisher<Bool, Never> {
        Empty().eraseToAnyPublisher()
    }
    
    private var solutionCheckerCancellable: AnyCancellable?
    
    init(user: SystemUser) {
        let operatingSystem = OperatingSystem.pwngroundOperatingSystem(with: user)
        operatingSystem.defaultShell = StubShellInterpreter.self
        interactors = InteractorContainer.pwngroundInteractors(
            operatingSystem: operatingSystem,
            user: user
        )
        setupSolutionChecker()
    }
    
    func setupSolutionChecker() {
        solutionCheckerCancellable = interactors.operatingSystemInteractor
            .syscallTriggered
            .receive(on: DispatchQueue.main)
            .sink { [weak self] syscall in
                guard case .execve(_, let filepath) = syscall,
                      filepath == ShellInterpreter.shellpath
                else { return }
                guard !(self?.hasBeenCompleted ?? false) else { return }
                self?.viewModel.executionModel.instructions.forEach { instructionCell in
                    instructionCell.isSelected = false
                }
                self?.levelPassSubject.send(())
            }
    }
    
    func solve() {
        let instructions = PayloadProvider.shellcodeTriggerInstructions
            .compactMap { instruction in
                InstructionCellItem(from: instruction)
            }
        withAnimation {
            viewModel.executionModel.instructions = instructions
            viewModel.executionMode = .auto
        }
    }
}

struct ShellcodeBuildingLevelScene: View {
    let model: ShellcodeBuildingLevel
    
    var body: some View {
        DebuggerContainer(viewModel: model.viewModel, layoutState: model.layoutState)
            .environment(\.levelSetup, model)
            .environment(\.interactors, model.interactors)
    }
}
