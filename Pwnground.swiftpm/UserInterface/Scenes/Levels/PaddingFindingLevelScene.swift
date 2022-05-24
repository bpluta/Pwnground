//
//  PaddingFindingLevelScene.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI
import Combine

class PaddingFindingLevel: PwngroundLevelSetup, DebuggerLevel {
    let scene: PwngroundScene.Scene = .findingPadding
    
    var viewModel = DebuggerContainer.ViewModel(
        baseAddress: 0x7fff_ffff_fef8,
        initialBreakpoint: 0x0000000010000194
    )
    var layoutState = DebuggerContainer.LayoutState(
        workspace: [.valueInspector, .interactionSection],
        valueInspector: [.memory],
        insteractionSection: [.paddingBuilder]
    )
    
    var interactors: InteractorContainer
    
    var hasBeenCompleted = false
    var didDisplayHelpSheet = false
    
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
        solutionCheckerCancellable = viewModel.$addressSpace
            .compactMap { memoryChunkList in
                memoryChunkList.first(where: { $0.key == 0x7fff_ffff_ff70 })
            }.compactMap { memoryChunk in
                memoryChunk.value
            }.filter { value in
                value == 0x7fff_ffff_ff78
            }.sink { [weak self] _ in
                guard !(self?.hasBeenCompleted ?? false) else { return }
                self?.viewModel.paddingBuilderModel.isAddressKeyboardPopoverDisplayed = false
                self?.levelPassSubject.send(())
            }
    }
    
    func solve() {
        withAnimation {
            viewModel.paddingBuilderModel.count = 120
            viewModel.paddingBuilderModel.address = 0x7fff_ffff_ff78
        }
    }
}

struct PaddingFindingLevelScene: View {
    let model: PaddingFindingLevel
    
    var body: some View {
        DebuggerContainer(viewModel: model.viewModel, layoutState: model.layoutState)
            .environment(\.levelSetup, model)
            .environment(\.interactors, model.interactors)
    }
}
