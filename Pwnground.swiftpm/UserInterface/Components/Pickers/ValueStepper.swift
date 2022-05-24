//
//  ValueStepper.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI
import Combine

fileprivate struct StepperButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .foregroundColor(ThemeColors.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(backgroundColor(isPressed: configuration.isPressed))
    }
    
    @ViewBuilder
    private func backgroundColor(isPressed: Bool) -> some View {
        ThemeColors.middleBlue
            .blendMode(isPressed ? .screen : .normal)
            .opacity(isPressed ? 0.6 : 1)
    }
}

struct ValueStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    
    @StateObject var viewModel = ViewModel()
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            StepperButton(.plus)
            DividerLine()
            StepperButton(.minus)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeColors.middleBlue)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    @ViewBuilder
    private func DividerLine() -> some View {
        Rectangle()
            .frame(maxWidth: 2)
            .padding(.vertical, 10)
            .foregroundColor(ThemeColors.diabledGray)
    }
    
    private func StepperButton(_ type: ButtonType) -> some View {
        Button(action: {}) {
            Icon(systemName: type.imageName)
        }.buttonStyle(StepperButtonStyle())
            .onLongPressGesture(minimumDuration: 0) { } onPressingChanged: { inProgress in
                if inProgress {
                    let action = getAction(for: type)
                    viewModel.pressCancellable = setupPressHandler(action: action)
                } else {
                    viewModel.pressCancellable?.cancel()
                    viewModel.pressCancellable = nil
                }
            }
    }
    
    @ViewBuilder
    private func Icon(systemName: String) -> some View {
        Image(systemName: systemName)
            .resizable()
            .scaledToFit()
            .frame(width: 15, height: 15)
    }
}

// MARK: - Helpers
extension ValueStepper {
    private func setupPressHandler(action: @escaping () -> Void) -> AnyCancellable {
        Future<Void,Never> { promise in
            action()
            return promise(.success(()))
        }.delay(for: 0.3, scheduler: DispatchQueue.main)
        .flatMap {
            Timer.publish(every: 0.05, on: .main, in: .default)
                .autoconnect()
        }.receive(on: DispatchQueue.main)
        .sink { _ in action() }
    }
    
    private func getAction(for button: ButtonType) -> () -> Void {
        switch button {
        case .plus:
            return increment
        case .minus:
            return decrement
        }
    }
    
    private func increment() {
        guard value < range.upperBound else { return }
        value += 1
    }
    
    private func decrement() {
        guard value > range.lowerBound else { return }
        value -= 1
    }
}

// MARK: - Models
extension ValueStepper {
    class ViewModel: ObservableObject {
        var pressCancellable: AnyCancellable?
    }
    
    enum ButtonType {
        case plus
        case minus
        
        var imageName: String {
            switch self {
            case .minus:
                return "minus"
            case .plus:
                return "plus"
            }
        }
    }
}
