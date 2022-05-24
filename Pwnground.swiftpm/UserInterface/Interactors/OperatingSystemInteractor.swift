//
//  OperatingSystemInteractor.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation
import UIKit
import Combine

protocol OperatingSystemBusinessLogic {
    var systemGroupsUpdates: AnyPublisher<[SystemGroup],Never> { get }
    var systemUsersUpdates: AnyPublisher<[SystemUser],Never> { get }
    var standardOutputPublisher: AnyPublisher<String,Never> { get }
    var syscallTriggered: AnyPublisher<KernelSubroutine,Never> { get }
    
    func getExceptionUpdates(for process: SystemProcess) -> AnyPublisher<RuntimeException,Never>
    
    func killAllProcesses() -> AnyPublisher<Void,Never>
    func setupProcess(executable: Data) -> AnyPublisher<SystemProcess,OperatingSystemError>
    func setBreakpoint(in process: SystemProcess, at address: Address?) -> AnyPublisher<SystemProcess,OperatingSystemError>
    func start(process: SystemProcess) -> AnyPublisher<SystemProcess,OperatingSystemError>
    func run(process: SystemProcess) -> AnyPublisher<SystemProcess,OperatingSystemError>
    func sendAndReceiveMessage(data: Data) -> AnyPublisher<String,OperatingSystemError>
    func sendToStandardInput(data: Data) -> AnyPublisher<Void,OperatingSystemError>
    func readFromStandardOutput() -> AnyPublisher<Data,OperatingSystemError>
    
    func read(memoryAddress: Address, count: Int, from process: SystemProcess) -> AnyPublisher<[Address:UInt64], SystemProcessException>
    func read(registers: [ARMGeneralPurposeRegister.GP64], from process: SystemProcess) -> AnyPublisher<[ARMGeneralPurposeRegister.GP64:UInt64],SystemProcessException>
    func read(flags: [ARMConditionFlag], from process: SystemProcess) -> AnyPublisher<[ARMConditionFlag:Bool],SystemProcessException>
    func getBaseStackAddress(of process: SystemProcess) -> AnyPublisher<Address,SystemProcessException>
    func getStateDiff(for process: SystemProcess) -> AnyPublisher<ProcessStateDiff,SystemProcessException>
}

enum OperatingSystemError: Error {
    case executionFailure
    case processSetupError
    case inputOutputError
    case permissionDenied
    case fileNotExists(filename: String)
    case dynamicLinkerError(error: DynamicLinkerError)
    case systemInterrupt(interrupt: SystemInterrupt)
    case runtimeException(exception: RuntimeException)
    
    var description: String {
        switch self {
        case .executionFailure:
            return "Execution failure"
        case .processSetupError:
            return "Process has failed"
        case .inputOutputError:
            return "Input / output error"
        case .permissionDenied:
            return "Permission denied"
        case .fileNotExists(let filename):
            return "File \(filename) does not exist"
        case .dynamicLinkerError(_):
            return "Dynamic linker error"
        case .systemInterrupt(let interrupt):
            return "Received system interrupt - \(interrupt.description)"
        case .runtimeException(let exception):
            return "\(exception.exceptionType.description) at \(exception.address.hexString)"
        }
    }
    
    init(from systemException: SystemProcessException) {
        switch systemException {
        case .noVirtualMemory, .processFailure:
            self = .processSetupError
        case .valueConversionError, .missingFlag, .missingRegister, .unknownRegister, .unknownSyscall, .invalidDescriptior:
            self = .executionFailure
        case .permissionDenied:
            self = .permissionDenied
        case .fileNotExists(let filename):
            self = .fileNotExists(filename: filename)
        case .systemInterrupt(let interrupt):
            self = .systemInterrupt(interrupt: interrupt)
        case .runtimeException(let exception):
            self = .runtimeException(exception: exception)
        }
    }
}

class OperatingSystemInteractor: ObservableObject, OperatingSystemBusinessLogic {
    var operatingSystem: OperatingSystem
    let currentUser: SystemUser
    
    let inputStream: InputSourceDelegate
    
    let executionQueue = DispatchQueue(label: "operatingSystem.executionQueue")
    private var cancelBag = CancelBag()
    
    private var runtimeExceptionCancellables = [PID:AnyCancellable]()
    
    init(operatingSystem: OperatingSystem, user: SystemUser) {
        self.operatingSystem = operatingSystem
        self.currentUser = user
        self.inputStream = operatingSystem.standardInputOutput
    }
    
    var syscallTriggered: AnyPublisher<KernelSubroutine,Never> {
        operatingSystem.syscallTriggered.eraseToAnyPublisher()
    }
    
    var systemGroupsUpdates: AnyPublisher<[SystemGroup],Never> {
        operatingSystem.systemGroupsUpdates.eraseToAnyPublisher()
    }
    
    var systemUsersUpdates: AnyPublisher<[SystemUser],Never> {
        operatingSystem.$users.eraseToAnyPublisher()
    }
    
    var standardOutputPublisher: AnyPublisher<String,Never> {
        operatingSystem.outputPublisher
            .map { data in
                String(decoding: data, as: UTF8.self)
            }.eraseToAnyPublisher()
    }
    
    func killAllProcesses() -> AnyPublisher<Void,Never> {
        Future { [weak self] promise in
            guard let self = self else { return promise(.success(())) }
            for process in self.operatingSystem.processList {
                self.kill(process: process)
            }
            self.operatingSystem.processList = []
            return promise(.success(()))
        }.eraseToAnyPublisher()
    }
    
    func setupProcess(executable: Data) -> AnyPublisher<SystemProcess,OperatingSystemError> {
        Future { [weak self] promise in
            guard
                let self = self,
                let admin = self.operatingSystem.users.first(where: { $0.uid == 0 })
            else { return promise(.failure(.processSetupError)) }
            do {
                let process = try self.operatingSystem.setupProcess(from: executable, as: admin)
                promise(.success(process))
            } catch let error {
                guard let error = error as? DynamicLinkerError else {
                    return promise(.failure(.processSetupError))
                }
                return promise(.failure(.dynamicLinkerError(error: error)))
            }
        }.eraseToAnyPublisher()
    }
    
    func setBreakpoint(in process: SystemProcess, at address: Address?) -> AnyPublisher<SystemProcess,OperatingSystemError> {
        Future { promise in
            guard let address = address else {
                return promise(.success(process))
            }
            process.setBreakpoint(at: address)
            return promise(.success(process))
        }.eraseToAnyPublisher()
    }
    
    func start(process: SystemProcess) -> AnyPublisher<SystemProcess,OperatingSystemError> {
        process
            .start(on: executionQueue)
            .mapError { runtimeError in
                OperatingSystemError(from: runtimeError)
            }.eraseToAnyPublisher()
    }
    
    func run(process: SystemProcess) -> AnyPublisher<SystemProcess,OperatingSystemError> {
        process
            .run(on: executionQueue)
            .mapError { runtimeError in
                OperatingSystemError(from: runtimeError)
            }.eraseToAnyPublisher()
    }
    
    func sendToStandardInput(data: Data) -> AnyPublisher<Void,OperatingSystemError> {
        Future { [weak self] promise in
            guard let self = self else { return promise(.failure(.inputOutputError)) }
            self.inputStream.fillBuffer(with: data)
            return promise(.success(()))
        }.eraseToAnyPublisher()
    }
    
    func sendAndReceiveMessage(data: Data) -> AnyPublisher<String,OperatingSystemError> {
        Future { [weak self] promise in
            guard let self = self else { return promise(.failure(.inputOutputError)) }
            self.operatingSystem.outputPublisher
                .debounce(for: 0.1, scheduler: self.executionQueue)
                .first()
                .map { data in
                    String(decoding: data, as: UTF8.self)
                }.sink { output in
                    promise(.success(output))
                }.store(in: self.cancelBag)
            self.inputStream.fillBuffer(with: data)
        }.eraseToAnyPublisher()
    }
    
    func readFromStandardOutput() -> AnyPublisher<Data,OperatingSystemError> {
        operatingSystem.outputPublisher
            .first()
            .setFailureType(to: OperatingSystemError.self)
            .eraseToAnyPublisher()
    }
    
    func getExceptionUpdates(for process: SystemProcess) -> AnyPublisher<RuntimeException,Never> {
        process.runtimeExceptionPublisher
            .merge(with: process.interruptionPublisher)
            .eraseToAnyPublisher()
    }
    
    func read<IntegerType: FixedWidthInteger>(memoryAddress: Address, count: Int, from process: SystemProcess) -> AnyPublisher<[Address:IntegerType], SystemProcessException> {
        Future { promise in
            var memoryContent = [Address:IntegerType]()
            do {
                let isReversed = count < 0
                for index in 0 ..< abs(count) {
                    let offset = UInt64(index * IntegerType.bytes)
                    var currentAddress = memoryAddress
                    if isReversed {
                        currentAddress -= offset
                    } else {
                        currentAddress += offset
                    }
                    memoryContent[currentAddress] = try process.readFromMemory(at: currentAddress)
                }
            } catch let error {
                guard let error = error as? SystemProcessException else {
                    return promise(.failure(.processFailure))
                }
                return promise(.failure(error))
            }
            return promise(.success(memoryContent))
        }.eraseToAnyPublisher()
    }
    
    func read<Register: ARMRegister, IntegerType: FixedWidthInteger>(registers: [Register], from process: SystemProcess) -> AnyPublisher<[Register:IntegerType], SystemProcessException> {
        Future { promise in
            var registerValues = [Register:IntegerType]()
            do {
                for register in registers {
                    registerValues[register] = try process.get(register: register)
                }
            } catch let error {
                guard let error = error as? SystemProcessException else {
                    return promise(.failure(.processFailure))
                }
                return promise(.failure(error))
            }
            return promise(.success(registerValues))
        }.eraseToAnyPublisher()
    }
    
    func read(flags: [ARMConditionFlag], from process: SystemProcess) -> AnyPublisher<[ARMConditionFlag:Bool],SystemProcessException> {
        Future { promise in
            var flagValues = [ARMConditionFlag:Bool]()
            for flag in flags {
                flagValues[flag] = process.getFlag(flag: flag)
            }
            return promise(.success(flagValues))
        }.eraseToAnyPublisher()
    }
    
    func getBaseStackAddress(of process: SystemProcess) -> AnyPublisher<Address,SystemProcessException> {
        Just(process.stackAddress)
            .setFailureType(to: SystemProcessException.self)
            .unwrap(orThrow: SystemProcessException.processFailure)
            .map { value in
                value - UInt64(UInt64.bytes)
            }
            .mapError { ($0 as? SystemProcessException) ?? .processFailure }
            .eraseToAnyPublisher()
    }
    
    func getStateDiff(for process: SystemProcess) -> AnyPublisher<ProcessStateDiff,SystemProcessException> {
        Just(process.stateDiff)
            .setFailureType(to: SystemProcessException.self)
            .eraseToAnyPublisher()
    }
}

// MARK: - Helpers
extension OperatingSystemInteractor {
    private func kill(process: SystemProcess) {
        process.kill()
        runtimeExceptionCancellables[process.pid]?.cancel()
        runtimeExceptionCancellables.removeValue(forKey: process.pid)
    }
}

// MARK: - KernelSubroutineDelegate
extension OperatingSystemInteractor: KernelSubroutineDelegate {
    func exit(process: SystemProcess, code: Int64) -> KernelSubroutinePublisher {
        operatingSystem.exit(process: process, code: code)
    }
    
    func write(process: SystemProcess, fd: UInt64, buf: Address, nbytes: UInt64) -> KernelSubroutinePublisher {
        operatingSystem.write(process: process, fd: fd, buf: buf, nbytes: nbytes)
    }
    
    func read(process: SystemProcess, fd: UInt64, buf: Address) -> KernelSubroutinePublisher {
        operatingSystem.read(process: process, fd: fd, buf: buf)
    }
    
    func execve(process: SystemProcess, fname: Address) -> KernelSubroutinePublisher {
        operatingSystem.execve(process: process, fname: fname)
    }
    
    func getUidForName(process: SystemProcess, address: Address) -> KernelSubroutinePublisher {
        operatingSystem.getUidForName(process: process, address: address)
    }
    
    func uidBelongsToGid(process: SystemProcess, uid: UInt32, gid: UInt32) -> KernelSubroutinePublisher {
        operatingSystem.uidBelongsToGid(process: process, uid: uid, gid: gid)
    }
}

struct StubOperatingSystemInteractor: OperatingSystemBusinessLogic {
    var systemGroupsUpdates: AnyPublisher<[SystemGroup], Never> {
        Empty().eraseToAnyPublisher()
    }
    
    var systemUsersUpdates: AnyPublisher<[SystemUser], Never> {
        Empty().eraseToAnyPublisher()
    }
    
    var standardOutputPublisher: AnyPublisher<String, Never> {
        Empty().eraseToAnyPublisher()
    }
    
    var syscallTriggered: AnyPublisher<KernelSubroutine, Never> {
        Empty().eraseToAnyPublisher()
    }
    
    func getExceptionUpdates(for process: SystemProcess) -> AnyPublisher<RuntimeException, Never> {
        Empty().eraseToAnyPublisher()
    }
    
    func killAllProcesses() -> AnyPublisher<Void, Never> {
        Empty().eraseToAnyPublisher()
    }
    
    func setupProcess(executable: Data) -> AnyPublisher<SystemProcess, OperatingSystemError> {
        Empty().eraseToAnyPublisher()
    }
    
    func setBreakpoint(in process: SystemProcess, at address: Address?) -> AnyPublisher<SystemProcess, OperatingSystemError> {
        Empty().eraseToAnyPublisher()
    }
    
    func start(process: SystemProcess) -> AnyPublisher<SystemProcess, OperatingSystemError> {
        Empty().eraseToAnyPublisher()
    }
    
    func run(process: SystemProcess) -> AnyPublisher<SystemProcess, OperatingSystemError> {
        Empty().eraseToAnyPublisher()
    }
    
    func sendAndReceiveMessage(data: Data) -> AnyPublisher<String, OperatingSystemError> {
        Empty().eraseToAnyPublisher()
    }
    
    func sendToStandardInput(data: Data) -> AnyPublisher<Void, OperatingSystemError> {
        Empty().eraseToAnyPublisher()
    }
    
    func readFromStandardOutput() -> AnyPublisher<Data, OperatingSystemError> {
        Empty().eraseToAnyPublisher()
    }
    
    func read(memoryAddress: Address, count: Int, from process: SystemProcess) -> AnyPublisher<[Address : UInt64], SystemProcessException> {
        Empty().eraseToAnyPublisher()
    }
    
    func read(registers: [ARMGeneralPurposeRegister.GP64], from process: SystemProcess) -> AnyPublisher<[ARMGeneralPurposeRegister.GP64 : UInt64], SystemProcessException> {
        Empty().eraseToAnyPublisher()
    }
    
    func read(flags: [ARMConditionFlag], from process: SystemProcess) -> AnyPublisher<[ARMConditionFlag : Bool], SystemProcessException> {
        Empty().eraseToAnyPublisher()
    }
    
    func getBaseStackAddress(of process: SystemProcess) -> AnyPublisher<Address, SystemProcessException> {
        Empty().eraseToAnyPublisher()
    }
    
    func getStateDiff(for process: SystemProcess) -> AnyPublisher<ProcessStateDiff, SystemProcessException> {
        Empty().eraseToAnyPublisher()
    }
}

fileprivate extension AnyCancellable {
    func store(in exceptionDictionary: inout [PID:AnyCancellable], for process: SystemProcess) {
        exceptionDictionary[process.pid] = self
    }
}
