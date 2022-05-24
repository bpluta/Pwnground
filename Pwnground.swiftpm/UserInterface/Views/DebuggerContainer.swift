//
//  DebuggerContainer.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI
import Combine

extension DebuggerContainer {
    class LayoutState: ObservableObject {
        @Published var valueInspectorWidth: CGFloat? = 290
        @Published var builderSectionWidth: CGFloat?
        
        @Published var addressSpaceInspectorHeight: CGFloat?
        @Published var registerInspectorHeight: CGFloat?
        @Published var flagsInspectorHeight: CGFloat? = 160
        @Published var asciiInspectorHeight: CGFloat?
        
        @Published var shellcodeBuilderHeight: CGFloat?
        @Published var paddingBuilderHeight: CGFloat?
        @Published var toolPickerHeight: CGFloat? = 300
        
        @Published var separatorSize: CGFloat = 10
        
        @Published var addresSpaceConfiguration: LazyKeyValueListConfiguration = .baseListConfiguration(title: "Address")
        @Published var registersConfiguration: LazyKeyValueListConfiguration = .baseListConfiguration(title: "Register")
        @Published var flagsConfiguration: LazyKeyValueListConfiguration = .baseListConfiguration(title: "Flags")
        @Published var asciiConfiguration: LazyKeyValueListConfiguration = .baseListConfiguration(title: "Character")
        
        @Published var workspaceComponents: [WorkspaceComponent]
        @Published var valueInspectorComponents: [ValueInspectorComponent]
        @Published var interactionSectionComponents: [InteractionSectionComponent]
        
        init(workspace: [WorkspaceSectionType], valueInspector: [ValueInspectorType], insteractionSection: [InteractionSectionType]) {
            self.workspaceComponents = workspace.map { .init(type: $0) }
            self.valueInspectorComponents = valueInspector.map { .init(type: $0) }
            self.interactionSectionComponents = insteractionSection.map { .init(type: $0) }
        }
    }
    
    class ViewModel: ObservableObject {
        @PublishedArray var addressSpace: [AddressValue]
        @PublishedArray var registers: [RegisterValue]
        @PublishedArray var flags: [FlagValue]
        @PublishedArray var ascii: [AsciiValue]
        
        @Published var executionModel: ShellcodeBuilder.ExecutionModel
        @Published var instructionPickerModel: InstructionPicker.ViewModel
        @Published var paddingBuilderModel: PaddingBuilder.ViewModel
        @Published var breakpointAddress: Address
        @Published var executionMode: ExecutionControl.Mode = .auto
        
        var payload: Data = Data()
        
        var inspectorSetup: InspectorSetup
        var hasBeenConfigured = false
        
        var cancelBag = CancelBag()
        var exceptionCancellable: AnyCancellable?
        
        init(baseAddress: Address, initialBreakpoint: Address? = nil, displayedInstructions: [InstructionPicker.MnemonicFamily] = [], inspectorSetup: InspectorSetup = .default) {
            let initialBreakpoint = initialBreakpoint ?? baseAddress
            
            self.inspectorSetup = inspectorSetup
            self.addressSpace = AddressValue.placeholder(setup: inspectorSetup)
            self.registers = RegisterValue.placeholder(setup: inspectorSetup)
            self.flags = FlagValue.placeholder(setup: inspectorSetup)
            self.ascii = AsciiValue.placeholder(setup: inspectorSetup)
            
            self.executionModel = .init(baseAddress: initialBreakpoint)
            self.paddingBuilderModel = .init(baseAddress: baseAddress)
            self.breakpointAddress = initialBreakpoint
            
            instructionPickerModel = .init(instructions: displayedInstructions)
            $addressSpace.register(observableObject: self).store(in: cancelBag)
            $registers.register(observableObject: self).store(in: cancelBag)
            $flags.register(observableObject: self).store(in: cancelBag)
        }
    }
}

struct DebuggerContainer: View {
    @Environment(\.notificationPublisher) var notificationPublisher: NotificationSubject
    @Environment(\.interactors) var interactors: InteractorContainer
    @Environment(\.levelSetup) var levelSetup: PwngroundLevelSetup
    
    @ObservedObject var viewModel: ViewModel
    @ObservedObject var layoutState: LayoutState
    
    var body: some View {
        GeometryReader { geometry in
            Workspace()
                .onChange(of: geometry.size, perform: { size in handleLayout(for: size) })
                .onAppear { handleNotDeterminedSpace(for: geometry.size) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear(perform: setupView)
        .onDrop(
            of: [InstructionCellItem.dataUTI],
            delegate: ShellcodeBuilder.OuterDropManager(
                draggedItem: $viewModel.executionModel.draggedItem,
                items: $viewModel.executionModel.instructions
            )
        )
    }
    
    private func Workspace() -> some View {
        HStack(spacing: 0) {
            ForEach(layoutState.workspaceComponents) { component in
                ComponentWithMinimum(\.width, minSize: component.type.minWidth) {
                    switch component.type {
                    case .valueInspector:
                        ValueInspector()
                    case .interactionSection:
                        IneractionSection()
                    }
                }.frame(width: layoutState[keyPath: component.type.sizePath])
                if let nextComponent = layoutState.workspaceComponents.firstNext(after: component) {
                    ResizableVerticalLine(left: component.type.sizePath, right: nextComponent.type.sizePath)
                }
            }
        }
    }
    
    @ViewBuilder
    private func ValueInspector() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(layoutState.valueInspectorComponents) { component in
                Group {
                    InspectorComponent(for: component.type)
                }.frame(height: layoutState[keyPath: component.type.sizePath])
                if let nextComponent = layoutState.valueInspectorComponents.firstNext(after: component) {
                    ResizableHorizontalLine(upper: component.type.sizePath, lower: nextComponent.type.sizePath)
                }
            }
        }
    }
    
    @ViewBuilder
    private func InspectorComponent(for type: ValueInspectorType) -> some View {
        switch type {
        case .memory:
            InspectorList(
                items: $viewModel.addressSpace,
                config: $layoutState.addresSpaceConfiguration
            ).onAppear(perform: focusOnBaseAddressSpace)
        case .register:
            InspectorList(
                items: $viewModel.registers,
                config: $layoutState.registersConfiguration
            )
        case .flags:
            InspectorList(
                items: $viewModel.flags,
                config: $layoutState.flagsConfiguration
            )
        case .ascii:
            InspectorList(
                items: $viewModel.ascii,
                config: $layoutState.asciiConfiguration
            ).onAppear(perform: focusOnLowercaseLetters)
        }
    }
    
    @ViewBuilder
    private func IneractionSection() -> some View { 
        VStack(alignment: .leading, spacing: 0) {
            ForEach(layoutState.interactionSectionComponents) { component in
                ComponentWithMinimum(\.width, minSize: component.type.minWidth) {
                    switch component.type {
                    case .shellcodeBuilder:
                        ShellcodeBuilderContainer()
                    case .instructionPicker:
                        InstructionPicker(
                            viewModel: viewModel.instructionPickerModel,
                            pickAction: addNewInstruction
                        )
                    case .paddingBuilder:
                        PaddingBuilder(viewModel: viewModel.paddingBuilderModel)
                    }
                }.frame(height: layoutState[keyPath: component.type.sizePath])
                if let nextComponent = layoutState.interactionSectionComponents.firstNext(after: component) {
                    ResizableHorizontalLine(upper: component.type.sizePath, lower: nextComponent.type.sizePath)
                }
            }
        }
    }
    
    @ViewBuilder
    func ComponentWithMinimum<Content: View>(_ sizePath: KeyPath<CGSize,CGFloat>, minSize: CGFloat, @ViewBuilder content: @escaping () -> Content) -> some View {
        GeometryReader { geometry in
            if geometry.size[keyPath: sizePath] > minSize {
                content()
            } else {
                PlaceholderMessage(
                    title: "No enough space",
                    subtitle: "This component need some more space, please resize the window to display it properly"
                )
            }
        }
    }
    
    @ViewBuilder
    func ShellcodeBuilderContainer() -> some View {
        if viewModel.executionModel.instructions.isEmpty {
            ShellcodeContainerPlaceholder()
        } else {
            ShellcodeContentContainer()
        }
    }
    
    @ViewBuilder
    func ShellcodeContainerPlaceholder() -> some View {
        PlaceholderMessage(
            title: "No instructions added",
            subtitle: "You can add them from the instruction picker below"
        )
    }
    
    @ViewBuilder
    func PlaceholderMessage(title: String, subtitle: String) -> some View {
        VStack(alignment: .center, spacing: 10) {
            Group {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
            }
            .multilineTextAlignment(.center)
            .foregroundColor(ThemeColors.diabledGray)
            .frame(maxWidth: 200, alignment: .center)
        }.padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    @ViewBuilder
    func ShellcodeContentContainer() -> some View {
        ZStack {
            ScrollView {
                ShellcodeBuilder(executionModel: viewModel.executionModel)
                    .padding(.vertical, 20)
            }
            ZStack(alignment: .bottomTrailing) {
                ExecutionControl(mode: $viewModel.executionMode, controlHandlerAction: onControlChange)
                    .frame(maxWidth: 250, minHeight: 60, maxHeight: 60)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }
    
    @ViewBuilder
    private func ResizableVerticalLine(left: ReferenceWritableKeyPath<LayoutState, CGFloat?>, right: ReferenceWritableKeyPath<LayoutState, CGFloat?>) -> some View {
        Rectangle()
            .foregroundColor(ThemeColors.darkBlueBackground)
            .frame(maxWidth: layoutState.separatorSize, maxHeight: .infinity)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let height = gesture.translation.width
                        resizeSections(upper: left, lower: right, translationValue: height, minSize: 100)
                    }
            )
    }
    
    @ViewBuilder
    private func ResizableHorizontalLine(upper: ReferenceWritableKeyPath<LayoutState, CGFloat?>, lower: ReferenceWritableKeyPath<LayoutState, CGFloat?>) -> some View {
        Rectangle()
            .foregroundColor(ThemeColors.darkBlueBackground)
            .frame(maxWidth: .infinity, maxHeight: layoutState.separatorSize)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let height = gesture.translation.height
                        resizeSections(upper: upper, lower: lower, translationValue: height, minSize: 50)
                    }
            )
    }
}

// MARK: - Setup
extension DebuggerContainer {
    func setupView() {
        guard !viewModel.hasBeenConfigured else { return }
        viewModel.hasBeenConfigured = true
        
        setupConfigurationPipelines()
        setupInstructionCellPayloadBuilder()
        setupPaddingPayloadBuilder()
        launchApp()
    }
    
    private func focusOnBaseAddressSpace() {
        DispatchQueue.main.async {
            guard let index = viewModel.addressSpace.firstIndex(where: { $0.key == viewModel.executionModel.baseAddress }) else { return }
            layoutState.addresSpaceConfiguration.scrollToRowIndex = Int(index)
        }
    }
    
    private func focusOnLowercaseLetters() {
        DispatchQueue.main.async {
            layoutState.asciiConfiguration.scrollToRowIndex = 97
        }
    }
    
    private func setupInstructionCellPayloadBuilder() {
        Publishers.CombineLatest(viewModel.executionModel.instructionsUpdatePublisher, viewModel.$executionMode)
            .sink { instructions, executionMode in
                updatePayload(with: instructionPayload)
                updateBreakpoint()
                launchApp()
            }.store(in: viewModel.cancelBag)
    }
    
    private func updatePayload(with newPayload: Data) {
        let initialPaylaod = levelSetup.initialPayload ?? Data()
        viewModel.payload = initialPaylaod + newPayload
    }
    
    private func setupPaddingPayloadBuilder() {
        viewModel.paddingBuilderModel.$payload
            .dropFirst()
            .debounce(for: 0.3, scheduler: DispatchQueue.main)
            .sink { newPayload in
                updatePayload(with: newPayload)
                launchApp()
            }.store(in: viewModel.cancelBag)
    }
    
    private func setupConfigurationPipelines() {
        viewModel.$addressSpace
            .sink(receiveValue: { values in
                layoutState.addresSpaceConfiguration.amountOfRows = values.count
            }).store(in: viewModel.cancelBag)
        viewModel.$registers
            .sink(receiveValue: { values in
                layoutState.registersConfiguration.amountOfRows = values.count
            }).store(in: viewModel.cancelBag)
        viewModel.$flags
            .sink(receiveValue: { values in
                layoutState.flagsConfiguration.amountOfRows = values.count
            }).store(in: viewModel.cancelBag)
        viewModel.$ascii
            .sink(receiveValue: { values in
                layoutState.asciiConfiguration.amountOfRows = values.count
            }).store(in: viewModel.cancelBag)
    }
}

// MARK: - Interactions
extension DebuggerContainer {
    private var breakpointAddress: Address {
        viewModel.breakpointAddress
    }
    
    func registerExceptionHandler(for process: SystemProcess) -> AnyPublisher<SystemProcess,OperatingSystemError> {
        Future { promise in
            viewModel.exceptionCancellable?.cancel()
            viewModel.exceptionCancellable = setupExceptionHandler(for: process)
            return promise(.success(process))
        }.eraseToAnyPublisher()
    }
    
    func setupExceptionHandler(for process: SystemProcess) -> AnyCancellable {
        interactors.operatingSystemInteractor.getExceptionUpdates(for: process)
            .first()
            .receive(on: DispatchQueue.main)
            .flatMap { exception in
                handleException(exception: exception, in: process)
            }.flatMap { process in
                extractProcessState(from: process)
            }.receive(on: DispatchQueue.main)
            .flatMap { inspectorState, stateDiff in
                handleProcessState(inspectorState: inspectorState, stateDiff: stateDiff)
            }.sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    let notification = NotificationModel(type: .failure, message: error.description)
                    showNotification(notification)
                }
            }, receiveValue: { })
    }
    
    private func handleException(exception: RuntimeException, in process: SystemProcess) -> AnyPublisher<SystemProcess,OperatingSystemError> {
        Future { promise in
            updateExecutionModel(with: exception)
            return promise(.success(process))
        }.eraseToAnyPublisher()
    }
    
    private func handleProcessState(inspectorState: InspectorState, stateDiff: ProcessStateDiff) -> AnyPublisher<Void,OperatingSystemError> {
        Future { promise in
            updateNewValues(with: inspectorState)
            updateDiffState(with: stateDiff)
            return promise(.success(()))
        }.eraseToAnyPublisher()
    }
    
    func launchApp() {
        viewModel.executionModel.instructionFailure = nil
        let operatingSystemInteractor = interactors.operatingSystemInteractor
        operatingSystemInteractor.killAllProcesses()
            .flatMap {
                operatingSystemInteractor.setupProcess(executable: levelSetup.applicationBinary)
            }.flatMap { process in
                operatingSystemInteractor.setBreakpoint(in: process, at: breakpointAddress)
            }.flatMap { process in
                registerExceptionHandler(for: process)
            }.flatMap { process in
                operatingSystemInteractor.start(process: process)
            }.flatMap { _ in
                operatingSystemInteractor.sendToStandardInput(data: viewModel.payload)
            }.receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    viewModel.exceptionCancellable?.cancel()
                    let notification = NotificationModel(type: .failure, message: error.description)
                    showNotification(notification)
                }
            }, receiveValue: { })
            .store(in: viewModel.cancelBag)
    }
    
    private func extractProcessState(from proces: SystemProcess) -> AnyPublisher<(InspectorState,ProcessStateDiff),OperatingSystemError> {
        Publishers.Zip(getState(of: proces), getStateDiff(of: proces))
            .first()
            .eraseToAnyPublisher()
    }
    
    private func getState(of process: SystemProcess) -> AnyPublisher<InspectorState,OperatingSystemError> {
        Publishers.Zip3(readRegisters(from: process), readMemory(from: process), readFlags(from: process))
            .first()
            .map { registers, memoryChunk, flags in
                InspectorState(
                    registers: registers,
                    memoryChunk: memoryChunk,
                    flags: flags
                )
            }.eraseToAnyPublisher()
    }
    
    private func getStateDiff(of process: SystemProcess) -> AnyPublisher<ProcessStateDiff,OperatingSystemError> {
        interactors.operatingSystemInteractor.getStateDiff(for: process)
            .catch { _ in
                Just(.init()).setFailureType(to: OperatingSystemError.self)
            }.eraseToAnyPublisher()
    }
    
    private func readRegisters(from process: SystemProcess) -> AnyPublisher<[ARMGeneralPurposeRegister.GP64:UInt64],OperatingSystemError> {
        let registers = viewModel.inspectorSetup.registers
        return interactors.operatingSystemInteractor
            .read(registers: registers, from: process)
            .catch { _ in
                Just([:]).setFailureType(to: OperatingSystemError.self)
            }.eraseToAnyPublisher()
    }
    
    private func readMemory(from process: SystemProcess) -> AnyPublisher<[Address:UInt64], OperatingSystemError> {
        let memoryChunkSize = viewModel.inspectorSetup.memoryChunkSize
        return interactors.operatingSystemInteractor
            .getBaseStackAddress(of: process)
            .flatMap { address in
                interactors.operatingSystemInteractor.read(memoryAddress: address, count: -memoryChunkSize, from: process)
            }.catch { _ in
                Just([:]).setFailureType(to: OperatingSystemError.self)
            }.eraseToAnyPublisher()
    }
    
    private func readFlags(from process: SystemProcess) -> AnyPublisher<[ARMConditionFlag:Bool],OperatingSystemError> {
        let flags = viewModel.inspectorSetup.flags
        return interactors.operatingSystemInteractor
            .read(flags: flags, from: process)
            .catch { _ in
                Just([:]).setFailureType(to: OperatingSystemError.self)
            }.eraseToAnyPublisher()
    }
    
    private func update<InterpretableItem: Interpretable>(path: ReferenceWritableKeyPath<ViewModel,[InterpretableItem]>, with newValues: [InterpretableItem.Key:InterpretableItem.Value]) {
        let oldItems = viewModel[keyPath: path]
        let newItems: [InterpretableItem] = oldItems.map { item in
            let newValue = newValues[item.key]
            return InterpretableItem(from: item, updatedTo: newValue)
        }
        viewModel[keyPath: path] = newItems
    }
    
    private func updateEditedItems<InterpretableItem: Interpretable>(path: ReferenceWritableKeyPath<ViewModel,[InterpretableItem]>, with editedItems: [InterpretableItem.Key]) {
        for item in viewModel[keyPath: path] {
            let isEdited = editedItems.contains(where: { $0 == item.key })
            let newDisplayMode: InterpretableDisplayMode = isEdited ? .edited : .normal
            item.displayMode = newDisplayMode
        }
    }
    
    private func updateNewValues(with inspectorState: InspectorState) {
        update(path: \.addressSpace, with: inspectorState.memoryChunk)
        update(path: \.registers, with: inspectorState.registers)
        update(path: \.flags, with: inspectorState.flags)
    }
    
    private func updateDiffState(with diffState: ProcessStateDiff) {
        guard viewModel.breakpointAddress != viewModel.executionModel.baseAddress else { return }
        let updatedFlags = Array(diffState.flags.keys)
        let updatedRegisters = Array(diffState.registers.keys)
        let updatedAddresses: [Address] = diffState.memory
            .flatMap { address, data -> [Address] in
                let quadWordSize = UInt64.bytes
                let quadWordsCount = Int(ceil(Double(data.count) / Double(quadWordSize)))
                let baseAddress = address - (address % UInt64(quadWordSize))
                let addresses = (0..<quadWordsCount).map { index in
                    baseAddress + Address(index * quadWordSize)
                }
                return addresses
            }.removeDuplicates()
        updateEditedItems(path: \.flags, with: updatedFlags)
        updateEditedItems(path: \.registers, with: updatedRegisters)
        updateEditedItems(path: \.addressSpace, with: updatedAddresses)
    }
    
    private func showNotification(_ notification: NotificationModel) {
        interactors.userInterfaceInteractor.showNotification(notification, with: notificationPublisher)
    }
    
    private func handle(error: OperatingSystemError) {
        guard
            case .runtimeException(exception: let exception) = error,
            exception.exceptionType != .breakpointHit
        else {
            updateExecutionModel(with: nil)
            let notification = NotificationModel(type: .failure, message: error.description)
            showNotification(notification)
            return
        }
        updateExecutionModel(with: exception)
    }
    
    private func updateExecutionModel(with exception: RuntimeException?) {
        var lastExecutedInstructionPointer: Address?
        var instructionFailure: ShellcodeBuilder.InstructionFailure?
        var instructionPointer: Address?
        if let exception = exception {
            instructionPointer = exception.address
            lastExecutedInstructionPointer = exception.lastExecutedInstruction
            if exception.exceptionType != .breakpointHit {
                instructionFailure = ShellcodeBuilder.InstructionFailure(
                    address: exception.address,
                    message: exception.exceptionType.description
                )
            }
        }
        viewModel.executionModel.instructionPointer = instructionPointer
        viewModel.executionModel.instructionFailure = instructionFailure
        viewModel.executionModel.lastExecutedInstructionPointer = lastExecutedInstructionPointer
    }
    
    private func addNewInstruction(instruction: InstructionCellItem) {
        withAnimation { viewModel.executionModel.instructions.append(instruction) }
    }
    
    private func onControlChange(_ controlEvent: ExecutionControl.Control) {
        guard viewModel.executionMode == .manual else { return }
        switch controlEvent {
        case .jumpToStart:
            jumpToTheStartOfThePayload()
        case .moveBackward:
            jumpOneInstructionBackward()
        case .moveForward:
            jumpOneInstructionForward()
        case .jumpToEnd:
            jumpToTheEndOfThePayload()
        }
        launchApp()
    }
    
    private func updateBreakpoint() {
        guard viewModel.executionMode == .manual else {
            jumpToTheEndOfThePayload()
            return
        }
        let instructions = viewModel.executionModel.instructions
        let baseAddress = viewModel.executionModel.baseAddress
        let instructionSize = UInt64(RawARMInstruction.bytes)
        
        let upperboundIndex: UInt64 = UInt64(instructions.firstIndex(where: { instruction in
            instruction.build() == nil
        }) ?? instructions.count)
        let upperboundAddress = baseAddress + upperboundIndex * instructionSize
        
        guard viewModel.breakpointAddress > upperboundAddress else { return }
        viewModel.breakpointAddress = upperboundAddress
    }
    
    private var instructionPayload: Data {
        var payload = Data()
        let instructions = viewModel.executionModel.instructions
        for instruction in instructions {
            guard let encodedInstruction = try? instruction.build()?.encode() else { break }
            payload.append(Data(from: encodedInstruction))
        }
        return payload
    }
    
    private func jumpToTheStartOfThePayload() {
        let baseAddress = viewModel.executionModel.baseAddress
        viewModel.breakpointAddress = baseAddress
    }
    
    private func jumpOneInstructionBackward() {
        let baseAddress = viewModel.executionModel.baseAddress
        let currentBreakpointAddress = viewModel.breakpointAddress
        let instructionSize = UInt64(RawARMInstruction.bytes)
        
        let newBreapkpointAddress = currentBreakpointAddress - instructionSize
        guard newBreapkpointAddress >= baseAddress else { return }
        
        viewModel.breakpointAddress = newBreapkpointAddress
    }
    
    private func jumpOneInstructionForward() {
        let instructions = viewModel.executionModel.instructions
        let baseAddress = viewModel.executionModel.baseAddress
        let currentBreakpointAddress = viewModel.breakpointAddress
        
        let instructionSize = UInt64(RawARMInstruction.bytes)
        let currentIndex = (currentBreakpointAddress - baseAddress) / instructionSize
        
        let upperboundIndex: UInt64 = UInt64(instructions.firstIndex(where: { instruction in
            instruction.build() == nil
        }) ?? instructions.count)
        let upperboundAddress = baseAddress + upperboundIndex * instructionSize
        
        let newBreakpointAddress: Address
        if currentIndex < upperboundIndex {
            newBreakpointAddress = currentBreakpointAddress + instructionSize
        } else {
            newBreakpointAddress = upperboundAddress
        }
        
        viewModel.breakpointAddress = newBreakpointAddress
    }
    
    private func jumpToTheEndOfThePayload() {
        let instructions = viewModel.executionModel.instructions
        let baseAddress = viewModel.executionModel.baseAddress
        
        let instructionSize = UInt64(RawARMInstruction.bytes)
        
        let upperboundIndex: UInt64 = UInt64(instructions.firstIndex(where: { instruction in
            instruction.build() == nil
        }) ?? instructions.count)
        let newBreakpointAddress = baseAddress + upperboundIndex * instructionSize
        
        viewModel.breakpointAddress = newBreakpointAddress
    }
}

// MARK: - Layout
extension DebuggerContainer {
    private var workspaceComponentKeys: [ReferenceWritableKeyPath<LayoutState, CGFloat?>] {
        layoutState.workspaceComponents.map(\.type.sizePath)
    }
    
    private var valueInspectorComponentKeys: [ReferenceWritableKeyPath<LayoutState, CGFloat?>] {
        layoutState.valueInspectorComponents.map(\.type.sizePath)
    }
    
    private var interactionSectionComponentKeys: [ReferenceWritableKeyPath<LayoutState, CGFloat?>] {
        layoutState.interactionSectionComponents.map(\.type.sizePath)
    }
    
    private func handleLayout(for size: CGSize) {
        handleLayout(of: valueInspectorComponentKeys, in: size.height, separatorSize: layoutState.separatorSize)
        handleLayout(of: interactionSectionComponentKeys, in: size.height, separatorSize: layoutState.separatorSize)
        handleLayout(of: workspaceComponentKeys,in: size.width, separatorSize: layoutState.separatorSize)
    }
    
    private func handleNotDeterminedSpace(for size: CGSize) {
        handleNotDeterminedSpace(of: valueInspectorComponentKeys, in: size.height, separatorSize: layoutState.separatorSize)
        handleNotDeterminedSpace(of: interactionSectionComponentKeys,in: size.height, separatorSize: layoutState.separatorSize)
        handleNotDeterminedSpace(of: workspaceComponentKeys, in: size.width, separatorSize: layoutState.separatorSize)
    }
    
    private func resizeSections(upper: ReferenceWritableKeyPath<LayoutState,CGFloat?>, lower: ReferenceWritableKeyPath<LayoutState,CGFloat?>, translationValue: CGFloat, minSize: CGFloat) {
        let currentUpperItemSize = layoutState[keyPath: upper] ?? 0
        let currentLowerItemSize = layoutState[keyPath: lower] ?? 0
        
        var difference = translationValue
        
        let draggedUpperItemSize = currentUpperItemSize + difference
        let draggedLowerItemSize = currentLowerItemSize - difference
        
        let desiredUpperItemSize = max(draggedUpperItemSize, minSize)
        let desiredLowerItemSize = max(draggedLowerItemSize, minSize)
        
        if desiredUpperItemSize != draggedUpperItemSize {
            difference = -(currentUpperItemSize - desiredUpperItemSize)
        } else if desiredLowerItemSize != draggedLowerItemSize {
            difference = currentLowerItemSize - desiredLowerItemSize
        }
        
        let newUpperItemSize = currentUpperItemSize + difference
        let newLowerItemSize = currentLowerItemSize - difference
        
        layoutState[keyPath: upper] = newUpperItemSize
        layoutState[keyPath: lower] = newLowerItemSize
    }
    
    private func handleNotDeterminedSpace(of elements: [ReferenceWritableKeyPath<LayoutState, CGFloat?>], in height: CGFloat, separatorSize: CGFloat) {
        let spaceTakenBySeparators = CGFloat(elements.count - 1) * separatorSize
        var freeSpace = height - spaceTakenBySeparators
        var nonDeterminedElements = elements.count
        
        for elementKey in elements {
            guard let currentValue = layoutState[keyPath: elementKey] else { continue }
            freeSpace -= currentValue
            nonDeterminedElements -= 1
        }
        if nonDeterminedElements > 0, freeSpace > 0 {
            let spaceForFreeElement = freeSpace / CGFloat(nonDeterminedElements)
            for elementKey in elements {
                guard layoutState[keyPath: elementKey] == nil else { continue }
                layoutState[keyPath: elementKey] = spaceForFreeElement
            }
            return
        }
    }
    
    private func handleLayout(of elements: [ReferenceWritableKeyPath<LayoutState, CGFloat?>], in size: CGFloat, separatorSize: CGFloat) {
        handleNotDeterminedSpace(of: elements, in: size, separatorSize: separatorSize)
        
        let spaceTakenBySeparators = CGFloat(elements.count - 1) * separatorSize
        
        let totalCurrentsizeOfElements = elements.reduce(0, { $0 + (layoutState[keyPath: $1] ?? 0) })
        let containerFreeSpace = size - spaceTakenBySeparators
        
        guard totalCurrentsizeOfElements != containerFreeSpace else { return }
        
        let scaleFactor = containerFreeSpace / totalCurrentsizeOfElements
        for elementKey in elements {
            guard let currentValue = layoutState[keyPath: elementKey] else { continue }
            layoutState[keyPath: elementKey] = currentValue * scaleFactor
        }
    }
}

// MARK: - DropDelegate
extension DebuggerContainer {
    struct DropOutsideDelegate: DropDelegate {
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
    
    struct InstructionDropManager: DropDelegate {
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

// MARK: - Container component models
extension DebuggerContainer {
    // MARK: General setup
    struct InspectorSetup {
        let baseStackAddress: Address = 0x8000_0000_0000
        let memoryChunkSize: Int
        let registers: [ARMGeneralPurposeRegister.GP64]
        let flags: [ARMConditionFlag]
        
        static var `default`: Self {
            .init(
                memoryChunkSize: 128,
                registers: [.sp] + ARMGeneralPurposeRegister.GP64.allCases.prefix(31),
                flags: ARMConditionFlag.allCases
            )
        }
    }
    
    // MARK: Workspace
    struct WorkspaceComponent: Identifiable, Equatable {
        let id = UUID()
        let type: WorkspaceSectionType
    }
    
    struct InspectorState {
        let registers: [ARMGeneralPurposeRegister.GP64:UInt64]
        let memoryChunk: [Address:UInt64]
        let flags: [ARMConditionFlag:Bool]
    }
    
    enum WorkspaceSectionType {
        case valueInspector
        case interactionSection
        
        var minWidth: CGFloat {
            switch self {
            case .interactionSection:
                return .zero
            case .valueInspector:
                return 150
            }
        }
        
        var sizePath: ReferenceWritableKeyPath<LayoutState, CGFloat?> {
            switch self {
            case .valueInspector:
                return \.valueInspectorWidth
            case .interactionSection:
                return \.builderSectionWidth
            }
        }
    }
    
    // MARK: Value Inspector
    struct ValueInspectorComponent: Identifiable, Equatable {
        let id = UUID()
        let type: ValueInspectorType
    }
    
    enum ValueInspectorType {
        case memory
        case register
        case flags
        case ascii
        
        var listConfiguration: ReferenceWritableKeyPath<LayoutState, LazyKeyValueListConfiguration> {
            switch self {
            case .memory:
                return \.addresSpaceConfiguration
            case .register:
                return \.registersConfiguration
            case .flags:
                return \.flagsConfiguration
            case .ascii:
                return \.asciiConfiguration
            }
        }
        
        var sizePath: ReferenceWritableKeyPath<LayoutState, CGFloat?> {
            switch self {
            case .memory:
                return \.addressSpaceInspectorHeight
            case .register:
                return \.registerInspectorHeight
            case .flags:
                return \.flagsInspectorHeight
            case .ascii:
                return \.asciiInspectorHeight
            }
        }
    }
    
    // MARK: Interaction Section
    struct InteractionSectionComponent: Identifiable, Equatable {
        let id = UUID()
        let type: InteractionSectionType
    }
    
    enum InteractionSectionType {
        case shellcodeBuilder
        case instructionPicker
        case paddingBuilder
                
        var minWidth: CGFloat {
            switch self {
            case .shellcodeBuilder:
                return 300
            case .instructionPicker:
                return 300
            case .paddingBuilder:
                return 400
            }
        }
        
        var sizePath: ReferenceWritableKeyPath<LayoutState, CGFloat?> {
            switch self {
            case .shellcodeBuilder:
                return \.shellcodeBuilderHeight
            case .instructionPicker:
                return \.toolPickerHeight
            case .paddingBuilder:
                return \.paddingBuilderHeight
            }
        }
    }
}

// MARK: - Value inspector placeholders
fileprivate extension RegisterValue {
    static func placeholder(setup: DebuggerContainer.InspectorSetup) -> [RegisterValue] {
        setup.registers.map { register in
           RegisterValue(key: register, value: nil)
        }
    }
}

fileprivate extension AddressValue {
    static func placeholder(setup: DebuggerContainer.InspectorSetup) -> [AddressValue] {
        (0..<setup.memoryChunkSize).map { index in
            let offset = UInt64((index + 1) * 8)
            let address = setup.baseStackAddress - offset
            return AddressValue(key: address, value: nil)
        }
    }
}

fileprivate extension FlagValue {
    static func placeholder(setup: DebuggerContainer.InspectorSetup) -> [FlagValue] {
        setup.flags.map { flag in
            FlagValue(key: flag, value: nil)
        }
    }
}

fileprivate extension AsciiValue {
    static func placeholder(setup: DebuggerContainer.InspectorSetup) -> [AsciiValue] {
        (UInt8.min..<0x80).map { value in
            let character = Character(UnicodeScalar(value))
            return AsciiValue(key: character, value: UInt64(value))
        }
    }
}
