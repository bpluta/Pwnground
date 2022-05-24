//
//  ApplicationUIView.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI
import Combine

struct ApplicationUIView: View {
    @Environment(\.notificationPublisher) var notificationPublisher: NotificationSubject
    @Environment(\.interactors) var interactors: InteractorContainer
    @Environment(\.levelSetup) var levelSetup: PwngroundLevelSetup
    
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
        ZStack {
            Wallpaper()
            VStack {
                Icon()
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 50)
            VStack {
                Spacer()
                Window()
                Spacer()
            }
            .padding(20)
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear(perform: setupView)
    }
    
    @ViewBuilder
    private func Wallpaper() -> some View {
        ThemeGradient.BackgroundGradient
    }
    
    @ViewBuilder
    private func Window() -> some View {
        SystemWindow {
            VStack(alignment: .center, spacing: 0) {
                Spacer()
                VStack(spacing: 0) {
                    UserInput()
                        .padding(.bottom,10)
                    CheckButton()
                        .padding(.top, 10)
                }
                .frame(maxWidth: 400)
                Divider()
                    .padding(.vertical, 30)
                Text(viewModel.outputMessage)
                    .transition(.opacity)
                    .id("outputMessage\(viewModel.outputMessage)")
                Spacer()
            }
            .padding(.horizontal, 30)
            .background(ThemeColors.white)
        }.frame(
            minWidth: 300,
            idealWidth: 400,
            maxWidth: 500,
            minHeight: 350,
            idealHeight: 450,
            maxHeight: 450,
            alignment: .center
        )
    }
    
    @ViewBuilder
    private func UserInput() -> some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "person")
                    .foregroundColor(.gray)
                TextField("Enter username", text: $viewModel.usernameInput)
                    .submitLabel(.return)
                    .onSubmit(sendInputToApp)
                    .font(Font.system(size: 18))
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
            }.onDrop(
                of: [BinaryFile.dataUTI],
                delegate: DataDropDelegate(rawData: $viewModel.rawDataInput, description: $viewModel.usernameInput)
            )
            .padding(.vertical, 12)
            .padding(.horizontal)
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.gray, lineWidth: 1)
            )
        }
    }
    
    @ViewBuilder
    private func CheckButton() -> some View {
        HStack {
            Button(action: sendInputToApp) {
                HStack {
                    Spacer()
                    Text("Check your scholarship status")
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 40)
                .stroke(Color.blue, lineWidth: 1))
    }
    
    @ViewBuilder
    private func Icon() -> some View {
        if let binaryFile = viewModel.binaryFile {
            HStack {
                Spacer()
                VStack {
                    Image(systemName: "doc.fill")
                        .resizable()
                        .foregroundColor(.white)
                        .frame(width: 50, height: 65, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                        .shadow(radius: 5)
                        .onDrag({
                            NSItemProvider(object: binaryFile)
                        })
                    Text("Exploit")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 5)
                }
            }
        }
    }
}

// MARK: - Setup
extension ApplicationUIView {
    private func setupView() {
        guard !viewModel.isConfigured else { return }
        viewModel.isConfigured = true
        
        setupStandardOuptutPipeline()
        setupBinaryFile()
        launchApp()
        
        viewModel.$rawDataInput
            .sink { value in
                guard let value = value else {
                    viewModel.usernameInput = ""
                    return
                }
                viewModel.usernameInput = String(decoding: value, as: UTF8.self)
            }.store(in: viewModel.cancelBag)
        
        viewModel.submitSubject
            .sink(receiveValue: sendInputToApp)
            .store(in: viewModel.cancelBag)
        
        viewModel.solutionSubject
            .flatMap { solutions in
                setupAppForSolutionInjection(solutions: solutions)
            }.flatMap { solutions in
                solutions.publisher
            }.flatMap(maxPublishers: .max(1)) { solution in
                sendSolution(solution).delay(for: 1, scheduler: DispatchQueue.main)
            }.sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    let notification = NotificationModel(type: .failure, message: error.description)
                    showNotification(notification)
                }
            }, receiveValue: { })
            .store(in: viewModel.cancelBag)
    }
    
    private func sendSolution(_ solution: Data) -> AnyPublisher<Void,OperatingSystemError> {
        insertSolutionIntoInput(solution)
            .delay(for: 1, scheduler: DispatchQueue.main)
            .flatMap {
                interactors.operatingSystemInteractor.sendToStandardInput(data: dataToSend)
            }.flatMap {
                clearInputPublisher()
                    .setFailureType(to: OperatingSystemError.self)
            }.eraseToAnyPublisher()
    }
    
    private func setupAppForSolutionInjection(solutions: [Data]) -> AnyPublisher<[Data],Never> {
        Future { promise in
            launchApp()
            return promise(.success(solutions))
        }.eraseToAnyPublisher()
    }
    
    private func clearInputPublisher() -> AnyPublisher<Void,Never> {
        Future { promise in
            clearInput()
            return promise(.success(()))
        }.eraseToAnyPublisher()
    }
    
    private func insertSolutionIntoInput(_ solution: Data) -> AnyPublisher<Void,Never> {
        solution.count < 100 ? typeSolutionIntoInput(solution) : putSolutionIntoInput(solution)
    }
    
    private func typeSolutionIntoInput(_ solution: Data) -> AnyPublisher<Void,Never> {
        [UInt8](solution).publisher
            .flatMap(maxPublishers: .max(1)) { byte in
                appendByteToInput(byte: byte)
                    .delay(for: 0.05, scheduler: DispatchQueue.main)
            }.collect()
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    private func putSolutionIntoInput(_ solution: Data) -> AnyPublisher<Void,Never> {
        Future { promise in
            viewModel.rawDataInput = solution
            return promise(.success(()))
        }.eraseToAnyPublisher()
    }
    
    private func appendByteToInput(byte: UInt8) -> AnyPublisher<Void,Never> {
        Future { promise in
            if viewModel.rawDataInput == nil {
                viewModel.rawDataInput = Data(from: byte)
            } else {
                viewModel.rawDataInput?.append(byte)
            }
            return promise(.success(()))
        }.eraseToAnyPublisher()
    }
    
    private func setupBinaryFile() {
        if let payload = levelSetup.initialPayload {
            viewModel.binaryFile = BinaryFile(binaryData: payload)
        }
    }
    
    private func setupStandardOuptutPipeline() {
        interactors.operatingSystemInteractor.standardOutputPublisher
            .receive(on: DispatchQueue.main)
            .sink { output in
                withAnimation(.easeIn(duration: 0.1)) {
                    viewModel.outputMessage = output
                }
            }.store(in: viewModel.cancelBag)
    }
}

// MARK: - Interactions
extension ApplicationUIView {
    func launchApp() {
        clearInputAndOutput()
        
        viewModel.executionCancellable?.cancel()
        viewModel.executionCancellable = interactors.operatingSystemInteractor.killAllProcesses()
            .flatMap {
                interactors.operatingSystemInteractor.setupProcess(executable: levelSetup.applicationBinary)
            }.flatMap { process in
                registerRuntimeExceptionPipeline(for: process)
            }.flatMap { process in
                interactors.operatingSystemInteractor.start(process: process)
            }.receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    let notification = NotificationModel(type: .failure, message: error.description)
                    showNotification(notification)
                }
            }, receiveValue: { _ in })
    } 
    
    private func sendInputToApp() {
        interactors.operatingSystemInteractor.sendToStandardInput(data: dataToSend)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    let notification = NotificationModel(type: .failure, message: error.description)
                    showNotification(notification)
                } else {
                    clearInput()
                }
            }, receiveValue: {})
            .store(in: viewModel.cancelBag)
    }
    
    private func showNotification(_ notification: NotificationModel) {
        interactors.userInterfaceInteractor.showNotification(notification, with: notificationPublisher)
    }
    
    private func registerRuntimeExceptionPipeline(for process: SystemProcess) -> AnyPublisher<SystemProcess,OperatingSystemError> {
        Future { promise in
            viewModel.exceptionCancellable?.cancel()
            viewModel.exceptionCancellable = interactors.operatingSystemInteractor
                .getExceptionUpdates(for: process)
                .receive(on: DispatchQueue.main)
                .sink { exception in
                    let notification = NotificationModel(type: .failure, message: "Application has crashed and was relauched")
                    showNotification(notification)
                    viewModel.exceptionSubject.send(())
                    launchApp()
                }
            return promise(.success(process))
        }.setFailureType(to: OperatingSystemError.self)
        .eraseToAnyPublisher()
    }
}

// MARK: - Helpers
extension ApplicationUIView {
    private var dataToSend: Data {
        if let rawDataInput = viewModel.rawDataInput {
            viewModel.rawDataInput = nil
            return rawDataInput
        } else {
            return viewModel.usernameInput.data(using: .utf8) ?? Data()
        }
    }
    
    private func clearInputAndOutput() {
        clearInput()
        clearOutput()
    }
    
    private func clearInput() {
        viewModel.rawDataInput = nil
        viewModel.usernameInput = ""
    }
    
    private func clearOutput() {
        viewModel.outputMessage = ""
    }
}

// MARK: - DropDelegate
extension ApplicationUIView {
    private struct DataDropDelegate: DropDelegate {
        @Binding var rawData: Data?
        @Binding var description: String
        
        func validateDrop(info: DropInfo) -> Bool {
            return info.hasItemsConforming(to: [BinaryFile.dataUTI])
        }
        
        func performDrop(info: DropInfo) -> Bool {
            guard let item = info.itemProviders(for: [BinaryFile.dataUTI]).first else { return false }
            item.loadItem(forTypeIdentifier: BinaryFile.dataUTI, options: nil) { (data, error) in
                DispatchQueue.main.async {
                    if let data = data as? Data {
                        DispatchQueue.main.async {
                        self.rawData = data
                        }
                    }
                }
            }
            return true
        }
    }
}

// MARK: - Models
extension ApplicationUIView {
    class ViewModel: ObservableObject {
        @Published var usernameInput: String = ""
        @Published var outputMessage: String = ""
        @Published var rawDataInput: Data?
        
        @Published var binaryFile: BinaryFile?
        
        var solutionSubject = PassthroughSubject<[Data],Never>()
        
        var submitSubject = PassthroughSubject<Void,Never>()
        var exceptionPublisher: AnyPublisher<Void,Never> {
            exceptionSubject.eraseToAnyPublisher()
        }
        fileprivate var exceptionSubject = PassthroughSubject<Void,Never>()
        
        fileprivate var isConfigured = false
        
        fileprivate var cancelBag = CancelBag()
        fileprivate var executionCancellable: AnyCancellable?
        fileprivate var exceptionCancellable: AnyCancellable?
    }
}
