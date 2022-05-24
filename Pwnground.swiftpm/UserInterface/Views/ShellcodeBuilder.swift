//
//  ShellcodeBuilder.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI
import Combine

struct ShellcodeBuilder: View {
    @ObservedObject var executionModel: ExecutionModel
    @StateObject var viewModel = ViewModel()
    
    var body: some View {
        ListContent()
            .onAppear(perform: setupView)
    }
    
    @ViewBuilder
    private func Content() -> some View {
        if executionModel.instructions.isEmpty {
            EmptyPlaceholder()
        } else {
            ListContent()
        }
    }
    
    @ViewBuilder
    private func EmptyPlaceholder() -> some View {
        VStack(alignment: .center) {
            Text("No instructions added")
                .foregroundColor(ThemeColors.white)
                .frame(maxWidth: 200, maxHeight: .infinity, alignment: .center)
                .background(Color.gray)
        }.frame(maxHeight: .infinity, alignment: .center)
        .background(ThemeColors.white)
    }
    
    @ViewBuilder
    private func ListContent() -> some View {
        LazyVGrid(columns: viewModel.columnSetup, alignment: .center, spacing: 10) {
            ForEach(executionModel.instructions, id: \.id) { item in
                AddressItem(address: addressOf(item: item))
                CellItem(item: item)
            }
        }
    }
    
    @ViewBuilder
    private func CellItem(item: InstructionCellItem) -> some View {
        HStack {
            DraggableItem(item: item)
            Spacer()
        }
    }
    
    @ViewBuilder
    private func DraggableItem(item: InstructionCellItem) -> some View {
        InstructionCell(item: item)
            .onDrag({ NSItemProvider(object: item) }, preview: {
                Item(item: item)
                    .onAppear {
                        viewModel.didReorderList = false
                        withAnimation { executionModel.draggedItem = item }
                    }
            }).onDrop(
                of: [InstructionCellItem.dataUTI],
                delegate: InnerDropManager(
                    item: item,
                    items: $executionModel.instructions,
                    draggedItem: $executionModel.draggedItem,
                    didReorderList: $viewModel.didReorderList
                )
            )
    }
    
    @ViewBuilder
    private func InstructionCell(item: InstructionCellItem) -> some View {
        if item == executionModel.draggedItem {
            EmptyItemPlaceholder(item: item)
        } else {
            Item(item: item)
        }
    }
    
    @ViewBuilder
    private func EmptyItemPlaceholder(item: InstructionCellItem) -> some View {
        Item(item: item)
            .opacity(0)
            .overlay {
                Rectangle()
                    .fill(Color.clear)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
    }
    
    @ViewBuilder
    private func Item(item: InstructionCellItem) -> some View {
        MnemonicWithArguments(item: item, deleteAction: {
            withAnimation { executionModel.instructions.removeAll(where: { $0 === item }) }
        })
    }
    
    @ViewBuilder
    private func AddressItem(address: UInt64?) -> some View {
        if let address = address {
            AddressIndicator(
                address: address,
                instructionFailure: $executionModel.instructionFailure,
                instructionPointer: $executionModel.lastExecutedInstructionPointer
            )
        }
    }
}

extension ShellcodeBuilder {
    class ExecutionModel: ObservableObject {
        @Published var draggedItem: InstructionCellItem?
        @PublishedArray var instructions: [InstructionCellItem] = []
        @Published var instructionPointer: Address?
        @Published var lastExecutedInstructionPointer: Address?
        @Published var instructionFailure: InstructionFailure?
        @Published var baseAddress: Address
        
        private var cancelBag = CancelBag()
        private var argumentsCancellable: AnyCancellable?
        
        var instructionsUpdatePublisher: AnyPublisher<[InstructionCellItem],Never> {
            _instructions
                .objectWillChange
                .compactMap { [weak self] _ in
                    self?.instructions
                }.merge(with: $instructions)
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
        
        init(baseAddress: Address) {
            self.baseAddress = baseAddress
            $instructions.register(observableObject: self).store(in: cancelBag)
            setupInstructionChangesPublisher()
        }
        
        private func setupInstructionChangesPublisher() {
            $instructions.sink(receiveValue: { [weak self] cells in
                let arguments = cells.flatMap { $0.arguments }
                self?.argumentsCancellable = Publishers.MergeMany(arguments.map(\.objectWillChange))
                    .sink { [weak self] in
                        self?._instructions.objectWillChange.send()
                    }
            }).store(in: cancelBag)
        }
    }
    
    class ViewModel: ObservableObject {
        var columnSetup: [GridItem] = [
            GridItem(.fixed(100), spacing: 10),
            GridItem(.flexible(minimum: 100, maximum: .infinity))
        ]
        var didReorderList = false
        var isConfigured = false
        
        var cancelBag = CancelBag()
    }
    
    struct InstructionFailure {
        let address: UInt64
        let message: String
    }
}

// MARK: Setup
extension ShellcodeBuilder {
    private func setupView() {
        guard !viewModel.isConfigured else { return }
        viewModel.isConfigured = true
        setupDropCancellationPipeline()
    }
    
    private func setupDropCancellationPipeline() {
        executionModel.$draggedItem
            .debounce(for: 4, scheduler: DispatchQueue.main)
            .compactMap { $0 }
            .sink(receiveValue: { _ in
                guard !viewModel.didReorderList else { return }
                withAnimation { executionModel.draggedItem = nil }
            }).store(in: viewModel.cancelBag)
    }
}

// MARK: Helpers
extension ShellcodeBuilder {
    private func addressOf(item: InstructionCellItem) -> UInt64? {
        let items = executionModel.instructions
        guard let index = items.firstIndex(of: item) else { return nil }
        let offset = UInt64(items.distance(from: items.startIndex, to: index))
        return executionModel.baseAddress + offset * 4
    }
}

// MARK: DragDelegate
extension ShellcodeBuilder {
    struct OuterDropManager: DropDelegate {
        @Binding var draggedItem: InstructionCellItem?
        @Binding var items: [InstructionCellItem]
        
        func performDrop(info: DropInfo) -> Bool {
            withAnimation { draggedItem = nil }
            return true
        }
        
        func dropUpdated(info: DropInfo) -> DropProposal? {
            guard let draggedItem = draggedItem, items.contains(draggedItem) else {
                return DropProposal(operation: .copy)
            }
            return DropProposal(operation: .move)
        }
    }
    
    struct InnerDropManager: DropDelegate {
        let item : InstructionCellItem
        
        @Binding var items: [InstructionCellItem]
        @Binding var draggedItem: InstructionCellItem?
        @Binding var didReorderList: Bool
        
        func performDrop(info: DropInfo) -> Bool {
            withAnimation { draggedItem = nil }
            return true
        }
        
        func dropUpdated(info: DropInfo) -> DropProposal? {
            guard items.contains(item) else {
                return DropProposal(operation: .copy)
            }
            return DropProposal(operation: .move)
        }
        
        func dropEntered(info: DropInfo) {
            if draggedItem == nil {
                draggedItem = item
            }
            guard let draggedItem = draggedItem, draggedItem != item else { return }
            guard let from = items.firstIndex(of: draggedItem),
                  let to = items.firstIndex(of: item)
            else { return }
            
            didReorderList = true
            withAnimation {
                let fromOffsets = IndexSet(integer: from)
                let toOffset = to > from ? to + 1 : to
                items.move(fromOffsets: fromOffsets, toOffset: toOffset)
            }
        }
    }
}
