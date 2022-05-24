//
//  InstructionPicker.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI

struct InstructionPicker: View {
    class ViewModel: ObservableObject {
        @Published var instructions: [MnemonicFamily]
        @Published fileprivate var selectedMnemonic: MnemonicFamily?
        fileprivate var isConfigured = false
        
        init(instructions: [MnemonicFamily]) {
            self.instructions = instructions
        }
    }
    
    @ObservedObject var viewModel: ViewModel
    var pickAction: (InstructionCellItem) -> Void
    
    init(viewModel: ViewModel, pickAction: @escaping (InstructionCellItem) -> Void) {
        self.viewModel = viewModel
        self.pickAction = pickAction
    }
    
    var body: some View {
        HStack(spacing: 15) {
            InstructionList()
                .frame(maxWidth: 150, maxHeight: .infinity)
            InstructionInfo()
                .frame(maxWidth: .infinity)
        }
        .background(ThemeColors.blueBackground)
        .onAppear(perform: setupView)
    }
    
    @ViewBuilder
    private func InstructionList() -> some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(viewModel.instructions) { mnemonicFamily in
                    InstructionListComponent(mnemonicFamily: mnemonicFamily)
                        .onTapGesture {
                            withAnimation { viewModel.selectedMnemonic = mnemonicFamily }
                        }
                        .padding(.horizontal, 10)
                }
            }.padding(.vertical, 15)
        }.frame(maxWidth: .infinity)
        .background(ThemeColors.blueBackground)
    }
    
    @ViewBuilder
    private func InstructionInfo() -> some View {
        if let selectedMnemonic = viewModel.selectedMnemonic {
            ScrollView {
                VStack(spacing: 15) {
                    ForEach(selectedMnemonic.instructions, id: \.rawValue) { instruction in
                        VStack(alignment: .center) {
                            InstructionComponent(for: .init(type: instruction))
                            Text(instruction.behaviorDescription)
                                .font(.system(size: 12))
                                .foregroundColor(ThemeColors.lightGray)
                                .frame(maxWidth: 300)
                        }.padding(.vertical, 20)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity)
                        .background(ThemeColors.blueFocusedBackground.cornerRadius(10))
                    }
                }.padding(.vertical, 15)
                .padding(.trailing, 15)
            }
        }
    }
    
    @ViewBuilder
    private func InstructionComponent(for instruction: InstructionCellItem) -> some View {
        Button(action: { pick(instruction: instruction) }) {
            HStack(spacing: 5) {
                    MnemonicWithArguments(item: instruction, deleteAction: {})
                        .disabled(true)
                    Image(systemName: "plus.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(ThemeColors.white, Color.green)
                            .frame(minWidth: 10, maxWidth: 20, minHeight: 10, maxHeight: 20)
                            .contentShape(Rectangle())
            }
        }.fixedSize(horizontal: false, vertical: true)
    }
    
    @ViewBuilder
    private func InstructionListComponent(mnemonicFamily: MnemonicFamily) -> some View {
        HStack(spacing: 0) {
            Text(mnemonicFamily.mnemonic.rawValue)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ThemeColors.lighterBlue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
            Image(systemName: "chevron.right")
                .resizable()
                .scaledToFit()
                .frame(width: 13, height: 13)
                .foregroundColor(ThemeColors.middleBlue)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .background(
            viewModel.selectedMnemonic == mnemonicFamily ? ThemeColors.blueFocusedBackground : Color.clear
        ).cornerRadius(10)
    }
    
    private func pick(instruction: InstructionCellItem) {
        let newInstruction = InstructionCellItem(type: instruction.type)
        pickAction(newInstruction)
    }
    
    private func setupView() {
        guard !viewModel.isConfigured else { return }
        viewModel.isConfigured = true
        viewModel.selectedMnemonic = viewModel.instructions.first
    }
}

// MARK: - Models
extension InstructionPicker {
    struct MnemonicFamily: Identifiable, Equatable {
        let id = UUID()
        
        let mnemonic: ARMMnemonic
        let instructions: [InstructionCell.InstructionType]
    }
}

// MARK: - Alignment guides
fileprivate extension HorizontalAlignment {
    struct MnemonicComponentCenterGuide: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat {
            d[HorizontalAlignment.center]
        }
    }
    
    static let mnemonicComponentCenterGuide = HorizontalAlignment(MnemonicComponentCenterGuide.self)
}
