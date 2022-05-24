//
//  BufferOverflowLevelScene.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI
import Combine

class BufferOverflowLevel: PwngroundLevelSetup, ApplicationUILevel {
    let scene: PwngroundScene.Scene = .bufferOverflow
    
    var viewModel = ApplicationUIView.ViewModel()
    
    var interactors: InteractorContainer
    
    var hasBeenCompleted = false
    var didDisplayHelpSheet = false
    
    var levelPassPublisher: AnyPublisher<Void, Never> { levelPassSubject.eraseToAnyPublisher() }
    var levelPassSubject = PassthroughSubject<Void, Never>()
    
    func checkSolution(for value: String) -> AnyPublisher<Bool, Never> {
        Empty().eraseToAnyPublisher()
    }
    
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
        solutionCheckerCancellable = viewModel.exceptionPublisher
            .sink { [weak self] in
                self?.levelPassSubject.send(())
            }
    }
    
    func solve() {
        viewModel.solutionSubject.send([
            Data(repeating: 0x41, count: 200)
        ])
    }
}

struct BufferOverflowLevelScene: View {
    let model: BufferOverflowLevel
    
    var body: some View {
        ApplicationUIView(viewModel: model.viewModel)
            .environment(\.levelSetup, model)
            .environment(\.interactors, model.interactors)
    }
}
