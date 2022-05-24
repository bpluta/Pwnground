//
//  SystemProcess.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation
import Combine

enum SystemProcessException: Error {
    case noVirtualMemory
    case valueConversionError
    case missingFlag
    case missingRegister
    case unknownRegister
    case unknownSyscall
    case invalidDescriptior
    case processFailure
    case permissionDenied
    case fileNotExists(filename: String)
    case systemInterrupt(interrupt: SystemInterrupt)
    case runtimeException(exception: RuntimeException)
}

enum RuntimeExceptionType: Equatable {
    case segmentationFault(address: Address?)
    case invalidInstruction
    case breakpointHit
    case unknownException
    
    var description: String {
        switch self {
        case .segmentationFault(let address):
            let baseString = "Segmentation fault"
            guard let address = address else { return baseString }
            return "\(baseString) at \(address.hexString)"
        case .invalidInstruction:
            return "Invalid instruction"
        case .breakpointHit:
            return "Hit breakpoint"
        case .unknownException:
            return "Unknown exception"
        }
    }
}

struct RuntimeException: Equatable, Error {
    let address: Address
    let lastExecutedInstruction: Address?
    let exceptionType: RuntimeExceptionType
    
    static var `default`: Self {
        .init(address: 0, lastExecutedInstruction: nil, exceptionType: .unknownException)
    }
}

enum SystemInterrupt: Error {
    case processKill
    case processExit
    case breakpointHit
    
    var description: String {
        switch self {
        case .processKill:
            return "Process killed"
        case .processExit:
            return "Process exited"
        case .breakpointHit:
            return "Hit breakpoint"
        }
    }
}

typealias PID = UInt32

struct ProcessStateDiff {
    fileprivate(set) var memory: [Address:Data] = [:]
    fileprivate(set) var registers: [ARMGeneralPurposeRegister.GP64:UInt64] = [:]
    fileprivate(set) var flags: [ARMConditionFlag:Bool] = [:]
}

class SystemProcess: ObservableObject {
    let pid: PID
    let owner: UID
    
    @Published private(set) var stateDiff = ProcessStateDiff()
    
    private(set) var gprRegisters: [ARMGeneralPurposeRegister.GP64:UInt64] = [:]
    private(set) var flags: [ARMConditionFlag:Bool] = ARMConditionFlag.flags
    private(set) var instructionPointer: Address = 0
    
    private var preservedInstructionPointer: Address = 0
    private var lastExecutedInstructionPointer: Address?
    private var instructionExecutor: ARMInstructionExecutor = .init()
    
    private(set) var entryPoint: Address?
    private(set) var stackSize: UInt64?
    private(set) var virtualMemory: VirtualMemory?
    
    weak var kernelDelegate: KernelSubroutineDelegate?
    
    private var interruptionSubject = PassthroughSubject<RuntimeException,Never>()
    var interruptionPublisher: AnyPublisher<RuntimeException,Never> { interruptionSubject.eraseToAnyPublisher() }
    
    private var runtimeExceptionSubject = PassthroughSubject<RuntimeException,Never>()
    var runtimeExceptionPublisher: AnyPublisher<RuntimeException,Never> { runtimeExceptionSubject.eraseToAnyPublisher() }
    
    private var breakpoints = [Address:Bool]()
    private var lastHitBreakpoint: Address?
    private var breakpointToRestore: Address?
    private var shouldInterruptExcecution: Bool = false
    
    private var cancelBag = CancelBag()
    
    var stackAddress: Address?
    
    static let defaultErrorValue = UInt64(bitPattern: -1)
    
    init(pid: PID, owner: UID) {
        self.pid = pid
        self.owner = owner
        for register in allWritableRegisters {
            gprRegisters[register] = 0
        }
    }
    
    func initializeRegisters() {
        for register in allWritableRegisters {
            gprRegisters[register] = 0
        }
        if let stackAddress = stackAddress {
            gprRegisters[.sp] = stackAddress - UInt64(Address.bytes * 3)
        }
    }
    
    private var allWritableRegisters: [ARMGeneralPurposeRegister.GP64] {
        ARMGeneralPurposeRegister.GP64.allCases.filter({ $0 != .xzr })
    }
}

// MARK: Execution
extension SystemProcess {
    func run(debug: Bool = false) throws {
        guard let virtualMemory = virtualMemory else { throw SystemProcessException.noVirtualMemory }
        setupProcessRun()
        runProcess(within: virtualMemory, debug: debug)
    }
    
    func start(on queue: DispatchQueue) -> AnyPublisher<SystemProcess,SystemProcessException> {
        Future { [weak self] promise in
            guard let self = self else { return promise(.failure(.processFailure)) }
            guard let virtualMemory = self.virtualMemory else { return promise(.failure(.noVirtualMemory)) }
            self.setupProcessRun()
            queue.async {
                self.runProcess(within: virtualMemory, debug: false)
            }
            return promise(.success(self))
        }.eraseToAnyPublisher()
    }
    
    func run(on queue: DispatchQueue) -> AnyPublisher<SystemProcess,SystemProcessException> {
        Future { [weak self] promise in
            guard let self = self else { return promise(.failure(.processFailure)) }
            guard let virtualMemory = self.virtualMemory else { return promise(.failure(.noVirtualMemory)) }
            self.setupProcessRun()
            _ = self.runtimeExceptionPublisher
                .merge(with: self.interruptionPublisher)
                .first()
                .map { exception in
                    SystemProcessException.runtimeException(exception: exception)
                }.sink(receiveValue: { exception in
                    return promise(.failure(exception))
                })
            queue.sync {
                self.runProcess(within: virtualMemory, debug: false)
            }
            return promise(.success(self))
        }.eraseToAnyPublisher()
    }
    
    func continueRun(debug: Bool = false) throws {
        guard let virtualMemory = virtualMemory else { throw SystemProcessException.noVirtualMemory }
        runProcess(within: virtualMemory, debug: debug)
    }
    
    func kill() {
        cancelBag.cancel()
        shouldInterruptExcecution = true
    }
    
    func setBreakpoint(at address: Address) {
        breakpoints[address] = true
    }
    
    func disableBreakpoint(at address: Address) {
        breakpoints.removeValue(forKey: address)
    }
    
    private func setupProcessRun() {
        preservedInstructionPointer = instructionPointer
        lastExecutedInstructionPointer = nil
        initializeRegisters()
        instructionExecutor.delegate = self
        instructionPointer = entryPoint ?? 0
        stateDiff = ProcessStateDiff()
    }
    
    private func runProcess(within memory: VirtualMemory, debug: Bool) {
        do {
            while true {
                try execute(within: memory, debug: debug)
            }
        } catch SystemInterrupt.processExit, SystemInterrupt.processKill {
           return
        } catch SystemInterrupt.breakpointHit {
            handleBreakpointHit()
        } catch (let error) {
            handleRuntimeError(error)
        }
    }
        
    private func execute(within memory: VirtualMemory, debug: Bool = false) throws {
        guard !shouldInterruptExcecution else {
            shouldInterruptExcecution = false
            throw SystemInterrupt.processKill
        }
        if breakpoints[instructionPointer] == true {
            throw SystemInterrupt.breakpointHit
        }
        preservedInstructionPointer = instructionPointer
        let fetchedInstruction = try memory.fetch(at: instructionPointer)
        let decodedInstruction = try ARMInstruction.decode(rawInstruction: fetchedInstruction)
        if debug {
            debugDescription(of: decodedInstruction)
        }
        resetDiffState()
        try execute(instruction: decodedInstruction)
        lastExecutedInstructionPointer = preservedInstructionPointer
        incrementInstructionPointer()
        restoreBreakpointIfNeeded()
    }
    
    private func handleBreakpointHit() {
        lastHitBreakpoint = instructionPointer
        breakpoints[instructionPointer] = false
        let exception = RuntimeException(
            address: instructionPointer,
            lastExecutedInstruction: lastExecutedInstructionPointer,
            exceptionType: .breakpointHit
        )
        interruptionSubject.send(exception)
    }
    
    private func handleRuntimeError(_ error: Error) {
        var exceptionType: RuntimeExceptionType?
        if let error = error as? VirtualMemoryError {
            var address: Address?
            switch error {
            case .SegmentationFault(let exceptionAddress):
                address = exceptionAddress
            case .PageFault(let exceptionAddress):
                address = exceptionAddress
            default: break
            }
            exceptionType = .segmentationFault(address: address)
        }
        if let _ = error as? ARMInstructionDecoderError {
            exceptionType = .invalidInstruction
        }
        let exception = RuntimeException(
            address: instructionPointer,
            lastExecutedInstruction: lastExecutedInstructionPointer,
            exceptionType: exceptionType ?? .unknownException
        )
        runtimeExceptionSubject.send(exception)
    }
    
    private func incrementInstructionPointer() {
        guard preservedInstructionPointer == instructionPointer else { return }
        instructionPointer += UInt64(RawARMInstruction.bytes)
    }
    
    private func restoreBreakpointIfNeeded() {
        guard let adddress = breakpointToRestore else { return }
        breakpointToRestore = nil
        guard let _ = breakpoints[adddress] else { return }
        breakpoints[adddress] = true
    }
    
    private func resetDiffState() {
        stateDiff = .init()
    }
    
    private func debugDescription(of executedInstruction: ARMInstruction) {
        let instructionPointer =  instructionPointer.hexString
        let executedInstructionDescription = (try? executedInstruction.describe()) ?? "<Unknown instruction>"
        print("\(instructionPointer) : \(executedInstructionDescription)")
    }
    
    private func execute(instruction: ARMInstruction) throws {
        try instructionExecutor.execute(instruction: instruction)
    }
}

// MARK: Data operations
extension SystemProcess {
    func readFromMemory<IntegerType: FixedWidthInteger>(at address: Address) throws -> IntegerType {
        guard let virtualMemory = virtualMemory else { throw SystemProcessException.noVirtualMemory }
        let count = IntegerType.bitWidth >> 3
        guard let value = try virtualMemory.read(at: address, count: count).to(type: IntegerType.self) else {
            throw SystemProcessException.valueConversionError
        }
        return value
    }
    
    func writeToMemory<IntegerType: FixedWidthInteger>(value: IntegerType, to address: Address) throws {
        guard let virtualMemory = virtualMemory else { throw SystemProcessException.noVirtualMemory }
        let valueData = Data(from: value)
        try write(data: valueData, at: address, to: virtualMemory)
    }
    
    func writeToMemory(data: Data, to address: Address) -> AnyPublisher<Void,SystemProcessException> {
        Future { [weak self] promise in
            guard let self = self else { return promise(.failure(.processFailure)) }
            guard let virtualMemory = self.virtualMemory else { return promise(.failure(.noVirtualMemory)) }
            do {
                try self.write(data: data, at: address, to: virtualMemory)
            } catch let error {
                guard let error = error as? SystemProcessException else {
                    return promise(.failure(.processFailure))
                }
                return promise(.failure(error))
            }
            return promise(.success(()))
        }.eraseToAnyPublisher()
    }
    
    func set<IntegerType: FixedWidthInteger>(register: ARMRegister, to value: IntegerType) throws {
        guard let destinationRegister = getRegister(from: register) else {
            throw SystemProcessException.unknownRegister
        }
        guard let currentValue = gprRegisters[destinationRegister] else {
            throw SystemProcessException.missingRegister
        }
        let trimmedValue = trim(value: value, to: register)
        let preservedBits = maskOutHigherBits(from: currentValue, for: register)
        let newValue = preservedBits | trimmedValue
        update(register: destinationRegister, with: newValue)
    }
    
    func get<IntegerType: FixedWidthInteger>(register: ARMRegister) throws -> IntegerType {
        if let constantValue = register.constantValue {
            return IntegerType(truncatingIfNeeded: constantValue)
        }
        guard let destinationRegister = getRegister(from: register) else {
            throw SystemProcessException.unknownRegister
        }
        guard let currentValue = gprRegisters[destinationRegister] else {
            throw SystemProcessException.missingRegister
        }
        let maskedValue = maskOutLowerBits(from: currentValue, for: register)
        return IntegerType(truncatingIfNeeded: maskedValue)
    }
    
    func getRegisterValue(of register: ARMGeneralPurposeRegister.GP64) -> UInt64? {
        gprRegisters[register]
    }
    
    private func update(register: ARMGeneralPurposeRegister.GP64, with value: UInt64) {
        guard gprRegisters.keys.contains(register) else { return }
        gprRegisters[register] = value
        stateDiff.registers[register] = value
    }
    
    private func update(flag: ARMConditionFlag, with value: Bool) {
        guard flags.keys.contains(flag) else { return }
        flags[flag] = value
        stateDiff.flags[flag] = value
    }
    
    private func write(data: Data, at address: Address, to virtualMemory: VirtualMemory) throws {
        try virtualMemory.write(at: address, value: data, as: .user)
        stateDiff.memory[address] = data
    }
    
    func setRegisterValue(of register: ARMGeneralPurposeRegister.GP64, to value: UInt64) -> AnyPublisher<Void,SystemProcessException> {
        Future { [weak self] promise in
            guard let self = self else { return promise(.failure(.processFailure)) }
            self.update(register: register, with: value)
            return promise(.success(()))
        }.eraseToAnyPublisher()
    }
    
    private func getRegister(from register: ARMRegister) -> ARMGeneralPurposeRegister.GP64? {
        guard let registerValue = register.value else { return nil }
        let register = ARMGeneralPurposeRegister.getRegister(from: UInt32(registerValue), in: .x64, for: .stackPointer)
        return register as? ARMGeneralPurposeRegister.GP64
    }
    
    private func getCurrentValue(for register: ARMRegister) -> AnyPublisher<(ARMGeneralPurposeRegister.GP64, UInt64), SystemProcessException> {
        Future { [weak self] promise in
            guard let self = self else { return promise(.failure(.processFailure)) }
            guard let register = self.getRegister(from: register) else {
                return promise(.failure(.unknownRegister))
            }
            guard let currentValue = self.gprRegisters[register] else {
                return promise(.failure(.missingRegister))
            }
            return promise(.success((register, currentValue)))
        }.eraseToAnyPublisher()
    }
}

// MARK: - Setup
extension SystemProcess {
    func setupEntry(to address: Address) {
        entryPoint = address
    }
    
    func setupStackSize(to size: UInt64) {
        stackSize = size
    }
    
    func setupVirtualMemory(to memory: VirtualMemory) {
        virtualMemory = memory
    }
}

// MARK: - Operations
extension SystemProcess: ARMInstructionExecutorDelegate {
    func read(at address: Address) throws -> UInt32 {
        try readFromMemory(at: address)
    }
    
    func read(at address: Address) throws -> UInt64 {
        try readFromMemory(at: address)
    }
    
    func write(value: UInt32, to address: Address) throws {
        try writeToMemory(value: value, to: address)
    }
    
    func write(value: UInt64, to address: Address) throws {
        try writeToMemory(value: value, to: address)
    }
    
    func store(value: UInt32, at register: ARMGeneralPurposeRegister.GP32) throws {
        try set(register: register, to: value)
    }
    
    func store(value: UInt64, at register: ARMGeneralPurposeRegister.GP64) throws {
        try set(register: register, to: value)
    }
    
    func getValue(from register: ARMGeneralPurposeRegister.GP32) throws -> UInt32 {
        try get(register: register)
    }
    
    func getValue(from register: ARMGeneralPurposeRegister.GP64) throws -> UInt64 {
        try get(register: register)
    }
    
    func getInstructionPointer() -> Address {
        instructionPointer
    }
    
    func updateInstructionPointer(to value: Address) {
        instructionPointer = value
    }
    
    func getFlag(flag: ARMConditionFlag) -> Bool {
        flags[flag] ?? false
    }
    
    func setFlag(flag: ARMConditionFlag, to value: Bool) {
        update(flag: flag, with: value)
    }
    
    func updateFlags(flags: [ARMConditionFlag: Bool]) {
        for (flag, value) in flags {
            update(flag: flag, with: value)
        }
    }
    
    func getFlags() -> [ARMConditionFlag: Bool] {
        flags
    }
    
    func triggerSystemCall(syscallValue: UInt32?) throws {
        guard
            let syscallValue = syscallValue,
            let syscall = Syscall(rawValue: syscallValue)
        else {
            throw SystemProcessException.unknownSyscall
        }
        try handleSyscall(syscall)
    }
    
    private func handle(kernelPublisher: KernelSubroutinePublisher?) throws -> UInt64 {
        guard let kernelOperationPublisher = kernelPublisher else { return Self.defaultErrorValue }
        return try handle(publisher: kernelOperationPublisher)
    }
    
    private func handle<Output>(publisher: AnyPublisher<Output,SystemProcessException>) throws -> Output {
        var returnedValue: Output?
        var returnedError: SystemProcessException?
        
        let group = DispatchGroup()
        group.enter()
        
        publisher
            .first()
            .handleEvents(
                receiveSubscription: { _ in },
                receiveOutput: { _ in },
                receiveCompletion: { _ in },
                receiveCancel: { group.leave() },
                receiveRequest: { _ in }
            ).sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    returnedError = error
                }
                group.leave()
            }, receiveValue: { value in
                returnedValue = value
            }).store(in: cancelBag)
        group.wait()
        
        if let returnedError = returnedError {
            throw returnedError
        }
        guard let returnedValue = returnedValue else {
            throw SystemProcessException.processFailure
        }
        return returnedValue
    }
}

// MARK: - Syscalls
extension SystemProcess {
    private func handleSyscall(_ syscall: Syscall) throws {
        switch syscall {
        case .read:
            try readSyscall()
        case .write:
            try writeSyscall()
        case .exit:
            try exitSyscall()
        case .execve:
            try execveSyscall()
        case .getUidForName:
            try getUidForNameSyscall()
        case .uidBelongsToGid:
            try uidBelondsToGidSyscall()
        }
    }
    
    private func writeSyscall() throws {
        guard
            let fd = getRegisterValue(of: .x0),
            let buf = getRegisterValue(of: .x1),
            let nbytes = getRegisterValue(of: .x2)
        else {
            throw SystemProcessException.missingRegister
        }
        let kernelOperationPublisher = kernelDelegate?.write(process: self, fd: fd, buf: buf, nbytes: nbytes)
        let returnedValue = try handle(kernelPublisher: kernelOperationPublisher)
        try set(register: ARMGeneralPurposeRegister.GP64.x0, to: returnedValue)
    }
    
    private func readSyscall() throws {
        guard
            let fd = getRegisterValue(of: .x0),
            let buf = getRegisterValue(of: .x1)
        else {
            throw SystemProcessException.missingRegister
        }
        let kernelOperationPublisher = kernelDelegate?.read(process: self, fd: fd, buf: buf)
        let returnedValue = try handle(kernelPublisher: kernelOperationPublisher)
        try set(register: ARMGeneralPurposeRegister.GP64.x0, to: returnedValue)
    }
    
    private func exitSyscall() throws {
        guard let code = getRegisterValue(of: .x0) else {
            throw SystemProcessException.missingRegister
        }
        let kernelOperationPublisher = kernelDelegate?.exit(process: self, code: Int64(bitPattern: code))
        let returnedValue = try handle(kernelPublisher: kernelOperationPublisher)
        try set(register: ARMGeneralPurposeRegister.GP64.x0, to: returnedValue)
    }
    
    private func execveSyscall() throws {
        guard let fname = getRegisterValue(of: .x0) else {
            throw SystemProcessException.missingRegister
        }
        let kernelOperationPublisher = kernelDelegate?.execve(process: self, fname: fname)
        let returnedValue = try handle(kernelPublisher: kernelOperationPublisher)
        try set(register: ARMGeneralPurposeRegister.GP64.x0, to: returnedValue)
    }
    
    private func getUidForNameSyscall() throws {
        guard let address = getRegisterValue(of: .x0)
        else {
            throw SystemProcessException.missingRegister
        }
        let kernelOperationPublisher = kernelDelegate?.getUidForName(process: self, address: address)
        let returnedValue = try handle(kernelPublisher: kernelOperationPublisher)
        try set(register: ARMGeneralPurposeRegister.GP64.x0, to: returnedValue)
    }
    
    private func uidBelondsToGidSyscall() throws {
        guard
            let uid = getRegisterValue(of: .x0),
            let gid = getRegisterValue(of: .x1)
        else {
            throw SystemProcessException.missingRegister
        }
        let kernelOperationPublisher = kernelDelegate?.uidBelongsToGid(
            process: self,
            uid: UInt32(truncatingIfNeeded: uid),
            gid: UInt32(truncatingIfNeeded: gid)
        )
        let returnedValue = try handle(kernelPublisher: kernelOperationPublisher)
        try set(register: ARMGeneralPurposeRegister.GP64.x0, to: returnedValue)
    }
}

// MARK: - Helpers
extension SystemProcess {
    private func trim<IntegerType: FixedWidthInteger>(value: IntegerType, to register: ARMRegister) -> UInt64 {
        let registerWidth = register.width ?? 0
        var shiftValue = UInt64.bitWidth - registerWidth
        if shiftValue < 0 {
            shiftValue = 0
        } else if shiftValue > UInt64.bitWidth {
            shiftValue = UInt64.bitWidth
        }
        let trimmedValue = (UInt64.max >> shiftValue) & UInt64(clamping: value)
        return trimmedValue
    }
    
    private func maskOutHigherBits(from currentValue: UInt64, for register: ARMRegister) -> UInt64 {
        let registerWidth = register.width ?? 0
        let mask = UInt64.max << registerWidth
        return currentValue & mask
    }
    
    private func maskOutLowerBits(from currentValue: UInt64, for register: ARMRegister) -> UInt64 {
        let registerWidth = register.width ?? 0
        let mask = UInt64.max >> (UInt64.bitWidth - registerWidth)
        return currentValue & mask
    }
}

