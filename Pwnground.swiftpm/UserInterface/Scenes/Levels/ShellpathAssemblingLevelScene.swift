//
//  ShellpathAssemblingLevelScene.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI
import Combine

class ShellpathAssemblingLevel: PwngroundLevelSetup, DebuggerLevel {
    let scene: PwngroundScene.Scene = .buildingPath
    
    var viewModel = DebuggerContainer.ViewModel(
        baseAddress: 0x7fff_ffff_ff78,
        displayedInstructions: [
            .init(mnemonic: .MOV, instructions: [.movRegister, .movImmediate]),
            .init(mnemonic: .MOVK, instructions: [.movkImmediateWithShift])
        ]
    )
    var layoutState = DebuggerContainer.LayoutState(
        workspace: [.valueInspector, .interactionSection],
        valueInspector: [.register, .ascii],
        insteractionSection: [.shellcodeBuilder, .instructionPicker]
    )
    
    var interactors: InteractorContainer
    
    var hasBeenCompleted = false
    var didDisplayHelpSheet = false
    
    var initialPayload: Data? {
        PayloadProvider.paddedValuesPayload +
        PayloadProvider.addressPayload
    }
    
    var levelPassPublisher: AnyPublisher<Void, Never> { levelPassSubject.eraseToAnyPublisher() }
    var levelPassSubject = PassthroughSubject<Void, Never>()
    
    private var solutionCheckerCancellable: AnyCancellable?
    
    init(user: SystemUser) {
        let operatingSystem = OperatingSystem.pwngroundOperatingSystem(with: user)
        interactors = InteractorContainer.pwngroundInteractors(
            operatingSystem: operatingSystem,
            user: user
        )
        setupSolutionChecker()
    }
    
    func setupSolutionChecker() {
        solutionCheckerCancellable = viewModel.$registers
            .compactMap { registers in
                registers.first(where: { $0.key == .x1 })
            }.compactMap { register in
                register.value
            }.map { value in
                Data(from: value)
            }.filter { rawData in
                rawData.contains(0)
            }.map { rawData in
                rawData.printableStringRepresentation(as: Unicode.ASCII.self)
            }.filter { string in
                string == ShellInterpreter.shellpath
            }.sink { [weak self] _ in
                guard !(self?.hasBeenCompleted ?? false) else { return }
                self?.viewModel.executionModel.instructions.forEach { instructionCell in
                    instructionCell.isSelected = false
                }
                self?.levelPassSubject.send(())
            }
    }
    
    func solve() {
        let instructions = PayloadProvider.shellPathCodeInstructions
            .compactMap { instruction in
                InstructionCellItem(from: instruction)
            }
        withAnimation {
            viewModel.executionModel.instructions = instructions
            viewModel.executionMode = .auto
        }
    }
}

struct ShellpathAssemblingLevelScene: View {
    let model: ShellpathAssemblingLevel
    
    var body: some View {
        DebuggerContainer(viewModel: model.viewModel, layoutState: model.layoutState)
            .environment(\.levelSetup, model)
            .environment(\.interactors, model.interactors)
    }
}
