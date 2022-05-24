//
//  OperatingSystem.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation
import Combine

typealias KernelSubroutinePublisher = AnyPublisher<UInt64,SystemProcessException>

protocol KernelSubroutineDelegate: AnyObject {
    func exit(process: SystemProcess, code: Int64) -> KernelSubroutinePublisher
    func write(process: SystemProcess, fd: UInt64, buf: Address, nbytes: UInt64) -> KernelSubroutinePublisher
    func read(process: SystemProcess, fd: UInt64, buf: Address) -> KernelSubroutinePublisher
    func execve(process: SystemProcess, fname: Address) -> KernelSubroutinePublisher
    func getUidForName(process: SystemProcess, address: Address) -> KernelSubroutinePublisher
    func uidBelongsToGid(process: SystemProcess, uid: UInt32, gid: UInt32) -> KernelSubroutinePublisher
}

enum KernelSubroutine {
    case exit(process: SystemProcess, code: Int64)
    case write(process: SystemProcess, fd: UInt64, buf: Address, nbytes: UInt64)
    case read(process: SystemProcess, fd: UInt64, buf: Address)
    case execve(process: SystemProcess, path: String)
    case getUidForName(process: SystemProcess, name: String)
    case uidBelongsToGid(process: SystemProcess, uid: UInt32, gid: UInt32)
}

class OperatingSystem: ObservableObject {
    @PublishedArray var users: [SystemUser] = []
    @PublishedArray var groups: [SystemGroup] = []
    
    var shellInterpreter: OperatingSystemShell?
    var processList = [SystemProcess]()
    
    var defaultShell: OperatingSystemShell.Type = ShellInterpreter.self
    
    private(set) var standardInputOutput = StandardInputOutput()
    
    private var cancelBag = CancelBag()
    
    init() {
        $users.register(observableObject: self).store(in: cancelBag)
        $groups.register(observableObject: self).store(in: cancelBag)
    }
    
    private var systemGroupsUpdatesSubject = PassthroughSubject<[SystemGroup], Never>()
    var systemGroupsUpdates: AnyPublisher<[SystemGroup],Never> {
        systemGroupsUpdatesSubject.eraseToAnyPublisher()
    }
    
    private var syscallTriggeredSubject = PassthroughSubject<KernelSubroutine, Never>()
    var syscallTriggered: AnyPublisher<KernelSubroutine,Never> {
        syscallTriggeredSubject.eraseToAnyPublisher()
    }
    
    var outputPublisher: AnyPublisher<Data,Never> {
        standardInputOutput.standardOutputPublisher
    }
    
    func setupProcess(from binary: Data, as user: SystemUser) throws -> SystemProcess {
        let pid = getPID()
        let process = try ProcessSpawner.spawnProcess(pid: pid, from: binary, as: user.uid)
        process.kernelDelegate = self
        processList.append(process)
        return process
    }
    
    func runApplication(binary: Data, as user: SystemUser, debug: Bool = false) throws {
        let process = try setupProcess(from: binary, as: user)
        try process.run(debug: debug)
    }
    
    private func getPID() -> PID {
        var pid = PID.random(in: 0..<PID.max)
        while processList.contains(where: { $0.pid == pid }) {
            pid = PID.random(in: 0..<PID.max)
        }
        return pid
    }
}

// MARK: - Syscalls
extension OperatingSystem: KernelSubroutineDelegate {
    func exit(process: SystemProcess, code: Int64) -> KernelSubroutinePublisher {
        Future { [weak self] promise in
            self?.syscallTriggeredSubject.send(.exit(process: process, code: code))
            return promise(.failure(.systemInterrupt(interrupt: .processExit)))
        }.eraseToAnyPublisher()
    }
    
    func write(process: SystemProcess, fd: UInt64, buf: Address, nbytes: UInt64) -> KernelSubroutinePublisher {
        Future<Void, SystemProcessException> { [weak self] promise in
            self?.syscallTriggeredSubject.send(.write(process: process, fd: fd, buf: buf, nbytes: nbytes))
            guard fd == 1 else { return promise(.failure(.invalidDescriptior)) }
            return promise(.success(()))
        }.flatMap {
            Self.readStringPublisher(at: buf, in: process, bytesToRead: Int(nbytes))
        }.flatMap { [standardInputOutput] string in
            standardInputOutput.write(data: string.data(using: .utf8) ?? Data())
        }.flatMap {
            Just(0)
        }.eraseToAnyPublisher()
    }
    
    func read(process: SystemProcess, fd: UInt64, buf: Address) -> KernelSubroutinePublisher {
        Future<Void,SystemProcessException> { [weak self] promise in
            self?.syscallTriggeredSubject.send(.read(process: process, fd: fd, buf: buf))
            guard fd == 0 else { return promise(.failure(.invalidDescriptior)) }
            return promise(.success(()))
        }.flatMap { [standardInputOutput] in
            standardInputOutput.read()
        }.map { data in
            data + [UInt8(0)]
        }.flatMap { data in
            process.writeToMemory(data: data, to: buf).map { data }
        }.map { data in
            UInt64(data.count)
        }.eraseToAnyPublisher()
    }
    
    func execve(process: SystemProcess, fname: Address) -> KernelSubroutinePublisher {
        Just(fname)
            .tryMap { address in
                try Self.readString(at: address, in: process)
            }.mapError { _ in SystemProcessException.processFailure }
            .flatMap { [weak self] filepath -> KernelSubroutinePublisher in
                self?.syscallTriggeredSubject.send(.execve(process: process, path: filepath))
                return self?.execute(filepath: filepath, in: process) ?? Empty().eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }
    
    func getUidForName(process: SystemProcess, address: Address) -> KernelSubroutinePublisher {
        Future { [weak self] promise in
            guard let self = self else { return promise(.failure(.processFailure)) }
            do {
                let name = try Self.readString(at: address, in: process)
                self.syscallTriggeredSubject.send(.getUidForName(process: process, name: name))
                guard let user = self.users.first(where: { $0.name == name }) else {
                    process.setFlag(flag: .carry, to: true)
                    return promise(.success(UInt64(bitPattern: -1)))
                }
                process.setFlag(flag: .carry, to: false)
                return promise(.success(UInt64(user.uid)))
            } catch let error  {
                guard let error = error as? SystemProcessException else {
                    return promise(.failure(.processFailure))
                }
                return promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    func uidBelongsToGid(process: SystemProcess, uid: UInt32, gid: UInt32) -> KernelSubroutinePublisher {
        Future { [weak self] promise in
            guard let self = self else { return promise(.failure(.processFailure)) }
            self.syscallTriggeredSubject.send(.uidBelongsToGid(process: process, uid: uid, gid: gid))
            guard
                let user = self.users.first(where: { $0.uid == uid }),
                let group = self.groups.first(where: { $0.gid == gid })
            else { return promise(.success(0)) }
            let uidBelongsToGid = group.users.contains(where: { $0.uid == user.uid })
            return promise(.success(uidBelongsToGid ? 1 : 0))
        }.eraseToAnyPublisher()
    }
    
    private func execute(filepath: String, in process: SystemProcess) -> KernelSubroutinePublisher {
        Future<KernelSubroutinePublisher,SystemProcessException> { [weak self] promise in
            let filepath = filepath
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard let self = self,
                  let owner = self.users.first(where: { $0.uid == process.owner })
            else { return promise(.failure(.processFailure)) }
            let publisher: KernelSubroutinePublisher
            
            var shell = self.defaultShell.init(owner: owner, parentProcess: process)
            shell.standardInputOutput = self.standardInputOutput
            shell.commandHandler = self
            
            self.shellInterpreter = shell
            
            switch filepath {
            case ShellInterpreter.shellpath:
                publisher = shell.launch()
                    .setFailureType(to: SystemProcessException.self)
                    .eraseToAnyPublisher()
            default:
                publisher = self.runExecutable(path: filepath, parentProcess: process)
                    .catch { _ in Just(UInt64(bitPattern: -1)) }
                    .setFailureType(to: SystemProcessException.self)
                    .eraseToAnyPublisher()
            }
            return promise(.success(publisher))
        }.flatMap { $0 }
        .eraseToAnyPublisher()
    }
    
    private func runExecutable(path: String, parentProcess: SystemProcess) -> AnyPublisher<UInt64,OperatingSystemError> {
        getBinary(path: path)
            .flatMap { [weak self] binary in
                self?.setupProcess(executable: binary, parent: parentProcess) ?? Empty().eraseToAnyPublisher()
            }.flatMap { [weak self] process in
                self?.executeProcess(process: process) ?? Empty().eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }
    
    private func getBinary(path: String) -> AnyPublisher<Data,OperatingSystemError> {
        Future { promise in
            return promise(.failure(.fileNotExists(filename: path)))
        }.eraseToAnyPublisher()
    }
    
    private func setupProcess(executable: Data, parent: SystemProcess) -> AnyPublisher<SystemProcess,OperatingSystemError> {
        Future { [weak self] promise in
            guard let self = self,
                  let owner = self.users.first(where: { $0.uid == parent.owner })
            else { return promise(.failure(.processSetupError)) }
            do {
                let process = try self.setupProcess(from: executable, as: owner)
                promise(.success(process))
            } catch let error {
                guard let error = error as? DynamicLinkerError else {
                    return promise(.failure(.processSetupError))
                }
                return promise(.failure(.dynamicLinkerError(error: error)))
            }
        }.eraseToAnyPublisher()
    }
    
    private func executeProcess(process: SystemProcess) -> AnyPublisher<UInt64,OperatingSystemError> {
        let executionQueue = DispatchQueue(label: "OperatingSystem.executionQueue")
        let executionPublisher = process.start(on: executionQueue)
            .eraseToAnyPublisher()
        let interruptPublisher = Publishers.Merge(process.interruptionPublisher, process.runtimeExceptionPublisher)
            .setFailureType(to: SystemProcessException.self)
            .eraseToAnyPublisher()
        return Publishers.CombineLatest(executionPublisher, interruptPublisher)
            .first()
            .map { _ in
                UInt64(bitPattern: -1)
            }.catch { _ in
                Just(UInt64(bitPattern: -1)).eraseToAnyPublisher()
            }.setFailureType(to: OperatingSystemError.self)
            .eraseToAnyPublisher()
    }
}

// MARK: - Shell command handling
extension OperatingSystem: ShellComandHandler {
    func execute(command: ShellCommand, arguments: [String], in shell: ShellInterpreter) {
        let operationPublisher: AnyPublisher<Void,ShellCommandExecutionError>
        switch command {
        case .whoami:
            operationPublisher = whoAmI(shell: shell)
        case .help:
            operationPublisher = help(shell: shell)
        case .exit:
            operationPublisher = exit(shell: shell)
        case .listusers:
            operationPublisher = listUsers(shell: shell)
        case .listgroups:
            operationPublisher = listGroups(shell: shell)
        case .assigntogroup:
            operationPublisher = assignToGroup(shell: shell, arguments: arguments)
        }
        guard
            let result = operationPublisher.execute(),
            case .failure(let error) = result
        else { return }
        
        let errorMessage = "Error : \(error.description)"
        printToStandardOutput(message: errorMessage)
    }
    
    private func exit(shell: ShellInterpreter) -> AnyPublisher<Void,ShellCommandExecutionError> {
        Future { [weak self] promise in
            shell.exit()
            let message = "[Shell process terminated]"
            self?.printToStandardOutput(message: message)
            return promise(.success(()))
        }.eraseToAnyPublisher()
    }
    
    private func whoAmI(shell: ShellInterpreter) -> AnyPublisher<Void,ShellCommandExecutionError> {
        Future { [weak self] promise in
            self?.printToStandardOutput(message: shell.owner.name)
            return promise(.success(()))
        }.eraseToAnyPublisher()
    }
    
    private func help(shell: ShellInterpreter) -> AnyPublisher<Void,ShellCommandExecutionError> {
        Future { [weak self] promise in
            let helpMessage = ShellCommand.allCases
                .map(\.usage)
                .joined(separator: "\n")
            self?.printToStandardOutput(message: helpMessage)
            return promise(.success(()))
        }.eraseToAnyPublisher()
    }
    
    private func listUsers(shell: ShellInterpreter) -> AnyPublisher<Void,ShellCommandExecutionError> {
        Future { [weak self] promise in
            let separator = "\t"
            let header = Self.getTableHeader(columns: ["uid", "user name"], separator: separator)
            let groupContent = self?.users
                .map { group in
                    [ group.uid.description, group.name ]
                }.map { rowColumns in
                    Self.getTableRow(columnData: rowColumns, separator: separator)
                }
            var output = [header]
            output.append(contentsOf: groupContent ?? ["Empty list"])
            
            let message = output.joined(separator: "\n")
            self?.printToStandardOutput(message: message)
            
            return promise(.success(()))
        }.eraseToAnyPublisher()
    }
    
    private func listGroups(shell: ShellInterpreter) -> AnyPublisher<Void,ShellCommandExecutionError> {
        Future { [weak self] promise in
            let separator = "\t"
            let header = Self.getTableHeader(columns: ["gid", "group name"], separator: separator)
            let groupContent = self?.groups
                .map { group in
                    [ group.gid.description, group.name ]
                }.map { rowColumns in
                    Self.getTableRow(columnData: rowColumns, separator: separator)
                }
            var output = [header]
            output.append(contentsOf: groupContent ?? ["Empty list"])
            
            let message = output.joined(separator: "\n")
            self?.printToStandardOutput(message: message)
            
            return promise(.success(()))
        }.eraseToAnyPublisher()
    }
    
    private func assignToGroup(shell: ShellInterpreter, arguments: [String]) -> AnyPublisher<Void,ShellCommandExecutionError> {
        Future { [weak self] promise in
            guard arguments.count >= 3 else {
                promise(.failure(.missingArguments))
                return
            }
            let groupname = arguments[1]
            let usermame = arguments[2]
            
            guard let group = self?.groups.first(where: { $0.name == groupname }) else {
                let message = "There's no group called \"\(groupname)\""
                self?.printToStandardOutput(message: message)
                return promise(.success(()))
            }
            guard let user = self?.users.first(where: { $0.name == usermame }) else {
                let message = "There's no user called \"\(usermame)\""
                self?.printToStandardOutput(message: message)
                return promise(.success(()))
            }
            defer {
                if let groups = self?.groups {
                    self?.systemGroupsUpdatesSubject.send(groups)
                }
            }
            guard !group.users.contains(where: { $0.uid == user.uid }) else {
                let message = "User \"\(usermame)\" already belongs to group \"\(groupname)\""
                self?.printToStandardOutput(message: message)
                return promise(.success(()))
            }
            group.users.append(user)
            let message = "User \"\(usermame)\" has been successfully assigned to group \"\(groupname)\""
            self?.printToStandardOutput(message: message)
            return promise(.success(()))
        }.eraseToAnyPublisher()
    }
    
    private func source(shell: ShellInterpreter, arguments: [String]) -> AnyPublisher<Void,ShellCommandExecutionError> {
        Future<String,ShellCommandExecutionError> { promise in
            guard !arguments.isEmpty else { return promise(.failure(.missingArguments)) }
            let firstArgument = arguments[0]
            let path: String
            
            if firstArgument.lowercased() == "source" {
                guard arguments.count > 1 else {
                    return promise(.failure(.missingArguments))
                }
                let secondArgument = arguments[1]
                path = secondArgument
            } else {
                path = firstArgument
            }
            return promise(.success(path))
        }.flatMap { [weak self] path -> AnyPublisher<UInt64, ShellCommandExecutionError> in
           (self?.execute(filepath: path, in: shell.parentProcess) ?? Empty().eraseToAnyPublisher())
                .mapError { error in
                    let operatingSystemError = OperatingSystemError(from: error)
                    return ShellCommandExecutionError(from: operatingSystemError)
                }.eraseToAnyPublisher()
        }.map { _ in () }
        .eraseToAnyPublisher()
    }
    
    private func printToStandardOutput(message: String) {
        guard let messageData = message.data(using: .utf8) else { return }
        standardInputOutput.write(data: messageData).execute()
    }
    
    static private func getTableHeader(columns: [String], separator: String) -> String {
        let header = getTableRow(columnData: columns, separator: separator)
        let divider = String(repeating: "=", count: header.count)
        return [header,divider].joined(separator: "\n")
    }
    
    static private func getTableRow(columnData: [String], separator: String) -> String {
        columnData.joined(separator: separator)
    }
}

// MARK: - Helpers
extension OperatingSystem {
    private static func readString(at address: Address, in process: SystemProcess, bytesToRead: Int = 0) throws -> String {
        var lastByte: UInt8?
        var currentAddress = address
        var bytesRead: UInt64 = 0
        var rawBytes = [UInt8]()
        repeat {
            lastByte = try process.readFromMemory(at: currentAddress)
            guard lastByte != 0 else { break }
            rawBytes.append(lastByte ?? 0)
            currentAddress += 1
            bytesRead += 1
        } while (bytesRead != bytesToRead && lastByte != nil)
        let data = Data(rawBytes)
        let string = String(decoding: data, as: UTF8.self)
        return string
    }
    
    private static func readStringPublisher(at address: Address, in process: SystemProcess, bytesToRead: Int = 0) -> AnyPublisher<String, SystemProcessException> {
        Future { promise in
            do {
                let string = try readString(at: address, in: process, bytesToRead: bytesToRead)
                return promise(.success(string))
            } catch let error {
                guard let error = error as? SystemProcessException else {
                    return promise(.failure(.processFailure))
                }
                return promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
}
