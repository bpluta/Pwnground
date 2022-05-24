//
//  AddressIndicator.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI

struct AddressIndicator: View {
    var address: UInt64
    @Binding var instructionFailure: ShellcodeBuilder.InstructionFailure?
    @Binding var instructionPointer: UInt64?
    
    @State private var isSelected: Bool = false
    
    private var mode: Mode {
        if let instructionFailure = instructionFailure, instructionFailure.address == address {
            return .failure
        } else if address == instructionPointer {
            return .currentExecution
        } else if let instructionPointer = instructionPointer, address <= instructionPointer {
            return .executed
        } else {
            return .notExectued
        }
    }
    
    var body: some View {
        AddressItem(address: address, accessory: { mode.accesory })
            .foregroundColor(mode.foregroundColor)
            .contentShape(Rectangle())
            .onTapGesture {
                if case .failure = mode {
                    isSelected = true
                }
            }.popover(isPresented: $isSelected) {
                PopoverMessage()
            }
    }
    
    @ViewBuilder
    private func AddressItem<Content: View>(address: UInt64, @ViewBuilder accessory: @escaping () -> Content) -> some View {
        HStack(alignment: .center) {
            Spacer(minLength: 0)
            Text(address.simplifiedDynamicWidthHexString)
                .font(.system(size: 12))
                .transition(.opacity)
                .animation(nil, value: UUID())
                .frame(maxHeight: .infinity)
        }
    }
        
    @ViewBuilder
    private func PopoverMessage() -> some View {
        switch mode {
        case .failure:
            FailureMessage()
                .frame(width: 300)
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func FailureMessage() -> some View {
        VStack {
            Text("Failed to execute instruction")
                .multilineTextAlignment(.center)
                .font(.system(size: 13))
            Divider()
            Text((instructionFailure?.message ?? "Unknown error"))
                .multilineTextAlignment(.center)
                .font(.system(size: 13))
                .foregroundColor(Color.red)
        }.padding()
    }
}

extension AddressIndicator {
    private enum Mode {
        case executed
        case notExectued
        case currentExecution
        case failure
        
        var foregroundColor: Color {
            switch self {
            case .currentExecution:
                return ThemeColors.green
            case .executed:
                return ThemeColors.white
            case .notExectued:
                return ThemeColors.middleBlue
            case .failure:
                return Color.red
            }
        }
        
        @ViewBuilder
        var accesory: some View {
            switch self {
            case .executed, .notExectued:
                EmptyView()
            case .currentExecution:
                Image(systemName: "chevron.right")
                    .resizable()
                    .scaledToFit()
                    .font(Font.body.bold())
                    .frame(height: 11)
            case .failure:
                Image(systemName: "exclamationmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 15)
            }
        }
    }
}
