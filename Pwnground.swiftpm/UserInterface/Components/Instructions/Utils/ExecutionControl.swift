//
//  ExecutionControl.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI

struct ExecutionControl: View {
    @Binding var mode: Mode
    var controlHandlerAction: (Control) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            ControlButton(.jumpToStart)
            ControlButton(.moveBackward)
            ModeButton()
                .padding(.horizontal, 5)
            ControlButton(.moveForward)
            ControlButton(.jumpToEnd)
        }
        .padding(.horizontal, 10)
        .background(
            ThemeColors.blueFocusedBackground
                .clipShape(Capsule())
        )
    }
    
    @ViewBuilder
    private func ModeButton() -> some View {
        switch mode {
        case .auto:
            PauseButton()
        case .manual:
            PlayButton()
        }
    }
    
    @ViewBuilder
    private func PlayButton() -> some View {
        ImageButton(systemName: "play.fill", weight: .bold) {
            withAnimation { mode = .auto }
        }
    }
    
    @ViewBuilder
    private func PauseButton() -> some View {
        ImageButton(systemName: "pause.fill", weight: .regular) {
            withAnimation { mode = .manual }
        }
    }
    
    private func ControlButton(_ type: Control) -> some View {
        ImageButton(systemName: type.imageName, weight: .bold) {
            controlHandlerAction(type)
        }.disabled(mode == .auto)
    }
    
    struct ImageButton: View {
        @Environment(\.isEnabled) private var isEnabled
        
        let systemName: String
        let weight: Font.Weight
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Image(systemName: systemName)
                    .resizable()
                    .scaledToFit()
                    .font(Font.body.weight(weight))
                    .foregroundColor(isEnabled ? ThemeColors.lighterBlue : ThemeColors.middleBlue)
                    .frame(width: 15, height: 15)
                    .padding(10)
                    .contentShape(Rectangle())
            }.buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: true)
        }
    }
}

// MARK: - Models
extension ExecutionControl {
    enum Mode {
        case auto
        case manual
    }
    
    enum Control {
        case jumpToStart
        case moveBackward
        case moveForward
        case jumpToEnd
        
        fileprivate var imageName: String {
            switch self {
            case .jumpToStart:
                return "chevron.backward.2"
            case .moveBackward:
                return "chevron.backward"
            case .moveForward:
                return "chevron.forward"
            case .jumpToEnd:
                return "chevron.forward.2"
            }
        }
    }
}
