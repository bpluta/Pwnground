//
//  ShellIInterpreter.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation
import Combine

enum InterpretorError: Error {
    case unterminatedToken
    case unexpectedToken
    case expressionParsingFailure
    case commandNotFound
    
    var description: String {
        switch self {
        case .unterminatedToken:
            return "Unterminated token"
        case .unexpectedToken:
            return "Unexpected token"
        case .expressionParsingFailure:
            return "Expression parsing failure"
        case .commandNotFound:
            return "Command not found"
        }
    }
}

enum ShellCommandExecutionError: Error {
    case missingArguments
    case fileDoesNotExist(path: String)
    case executionHasFailed
    case accessDenied
    
    init(from operatingSytemError: OperatingSystemError) {
        switch operatingSytemError {
        case .permissionDenied:
            self = .accessDenied
        case .fileNotExists(let filename):
            self = .fileDoesNotExist(path: filename)
        default:
            self = .executionHasFailed
        }
    }
    
    var description: String {
        switch self {
        case .missingArguments:
            return "Missing arguments"
        case .fileDoesNotExist(path: let path):
            return "File \(path) does not exist"
        case .executionHasFailed:
            return "Execution has failed"
        case .accessDenied:
            return "Permission denied"
        }
    }
}

protocol ShellComandHandler: AnyObject {
    func execute(command: ShellCommand, arguments: [String], in shell: ShellInterpreter)
}

enum ShellCommand: String, CaseIterable {
    case whoami
    case help
    case exit
    case listusers
    case listgroups
    case assigntogroup
    
    init?(rawValue: String){
        let commandName = rawValue.lowercased()
        guard let command = Self.allCases.first(where: { $0.rawValue == commandName }) else {
            return nil
        }
        self = command
    }
    
    private static func isDirectoryPath(rawTokenValue: String) -> Bool {
        let directoryIndicatorSet = CharacterSet(charactersIn: "./")
        guard let firstCharacter = rawTokenValue.first?.unicodeScalars else { return false }
        return firstCharacter.allSatisfy(directoryIndicatorSet.contains(_:))
    }
    
    private var arguments: [String] {
        switch self {
        case .assigntogroup:
            return ["group name", "user name"]
        default:
            return []
        }
    }
    
    var usage: String {
        let formattedArguments = arguments.map { "<\($0)>" }
        let usageComponents = [rawValue] + formattedArguments
        return usageComponents.joined(separator: " ")
    }
    
    var helpMessage: String {
        switch self {
        case .whoami:
            return "Displays current user identifier"
        case .help:
            return "Prints information about available commands and their usage"
        case .exit:
            return "Terminates shell process"
        case .listusers:
            return "Prints list of all users in the system"
        case .listgroups:
            return "Prints list of all groups in the system"
        case .assigntogroup:
            return "Assigns given user to a group of given name"
        }
    }
}

protocol OperatingSystemShell {
    var standardInputOutput: StandardInputOutput? { get set }
    var commandHandler: ShellComandHandler? { get set }
    
    func launch() -> AnyPublisher<UInt64,Never>
    
    init(owner: SystemUser, parentProcess: SystemProcess)
}

class ShellInterpreter: OperatingSystemShell {
    private static let quotationMarkSet = CharacterSet(charactersIn: "\"\'")
    private static let prompt = ">"
    static let shellpath = "/bin/sh"
    
    var standardInputOutput: StandardInputOutput?
    weak var commandHandler: ShellComandHandler?
    
    let owner: SystemUser
    let parentProcess: SystemProcess
    
    private var inputOutputCancellable: AnyCancellable?
    
    private var shellCommandExecutionQueue = DispatchQueue(label: "ShellInterpreter.Queue")
    private var interruptSubject = PassthroughSubject<Void,Never>()
    private var cancelBag = CancelBag()
    
    required init(owner: SystemUser, parentProcess: SystemProcess) {
        self.owner = owner
        self.parentProcess = parentProcess
    }
    
    func launch() -> AnyPublisher<UInt64,Never> {
        Publishers.Merge(startInterpreter(), interruptSubject)
            .first()
            .flatMap { [weak self] _ in
                self?.stopInterpreter() ?? Just(()).eraseToAnyPublisher()
            }.map {
                UInt64(0)
            }.eraseToAnyPublisher()
    }
    
    func exit() {
        interruptSubject.send()
    }
    
    private func startInterpreter() -> AnyPublisher<Void,Never> {
        Future { [weak self] promise in
            guard let self = self else { return promise(.success(())) }
            self.sendOutput(message: "Logged as \(self.owner.name)")
            self.setupShellInterpreterPipeline()
        }.eraseToAnyPublisher()
    }
    
    private func setupShellInterpreterPipeline() {
        inputOutputCancellable = standardInputOutput?.standardInputPublisher
            .receive(on: shellCommandExecutionQueue)
            .map { inputData in
                inputData.rawStringRepresentation(as: UTF8.self)
            }.flatMap { [weak self] inputString in
                self?.handle(input: inputString) ?? Just(()).eraseToAnyPublisher()
            }.sink { _ in }
    }
    
    private func stopInterpreter() -> AnyPublisher<Void,Never> {
        Future { [weak self] promise in
            guard let self = self else { return promise(.success(())) }
            self.inputOutputCancellable?.cancel()
            self.inputOutputCancellable = nil
            return promise(.success(()))
        }.eraseToAnyPublisher()
    }
    
    private func handle(input: String) -> AnyPublisher<Void,Never> {
        Future { [weak self] promise in
            guard let self = self else { return promise(.success(())) }
            self.interpret(input: input)
            return promise(.success(()))
        }.eraseToAnyPublisher()
    }
    
    private func interpret(input: String) {
        do {
            let expression = try getParsedExpression(input: input)
            handle(expression: expression)
        } catch let error {
            handle(error: error)
        }
    }
    
    private func handle(error: Error) {
        let error = error as? InterpretorError
        let errorDescription = error?.description ?? "Unknown error"
        sendOutput(message: "Error: \(errorDescription)")
    }
    
    private func sendOutput(message: String) {
        var messageData = message.data(using: .utf8)
        if messageData == nil {
            messageData = Self.prompt.data(using: .utf8)
        }
        standardInputOutput?.write(data: messageData ?? Data())
            .sink { _ in }
            .store(in: cancelBag)
    }
    
    private func handle(expression: Expression?) {
        guard let expression = expression else {
            sendOutput(message: Self.prompt)
            return
        }
        switch expression {
        case .execute(let command, let arguments):
            commandHandler?.execute(command: command, arguments: arguments, in: self)
        }
    }
    
    func getParsedExpression(input: String) throws -> Expression? {
        let tokens = try getTokens(from: input)
        return try parse(tokens: tokens)
    }
}

class StubShellInterpreter: OperatingSystemShell {
    var standardInputOutput: StandardInputOutput?
    
    weak var commandHandler: ShellComandHandler?
    
    func launch() -> AnyPublisher<UInt64, Never> {
        Just(UInt64(0)).eraseToAnyPublisher()
    }
    
    required init(owner: SystemUser, parentProcess: SystemProcess) {  }
}

// MARK: - Parser
extension ShellInterpreter {
    enum Expression {
        case execute(command: ShellCommand, arguments: [String])
    }
    
    func parse(tokens: [TokenItem]) throws -> Expression? {
        try parseExecutionExpresion(tokens: tokens)
    }
    
    private func parseExecutionExpresion(tokens: [TokenItem]) throws -> Expression? {
        guard let firstToken = tokens.first else { return nil }
        let rawCommandName = escapeRawTokenValue(firstToken)
        var arguments = [String]()
        
        for token in tokens {
            let argumentValue: String
            switch token.type {
            case .string, .quotedString:
                argumentValue = escapeRawTokenValue(token)
            default:
                throw InterpretorError.unexpectedToken
            }
            arguments.append(argumentValue)
        }
            
        guard let command = ShellCommand(rawValue: rawCommandName) else {
            throw InterpretorError.commandNotFound
        }
        return .execute(command: command, arguments: arguments)
    }
    
    private func escapeRawTokenValue(_ token: TokenItem) -> String {
        let tokenString = String(token.substring)
        switch token.type {
        case .quotedString:
            let escapedString = tokenString.trimmingCharacters(in: Self.quotationMarkSet)
            return escapedString
        default:
            return tokenString
        }
    }
}

// MARK: - Lexer
extension ShellInterpreter {
    enum Token {
        case string
        case quotedString
        
        case glyph
        case whitespace
        case quotationMark
    }

    struct TokenItem {
        let type: Token
        let substring: Substring
        let subtokens: [TokenItem]
    }
    
    func getTokens(from input: String) throws -> [TokenItem] {
        let startIndex = input.startIndex
        let endIndex = input.endIndex
        
        var currentIndex = startIndex
        var tokens = [TokenItem]()
        
        while currentIndex != endIndex {
            let currentPart = input[currentIndex...]
            guard let characterToken = try processCharacterToken(in: currentPart) else {
                throw InterpretorError.unexpectedToken
            }
            var token: TokenItem?
            switch characterToken.type {
            case .glyph:
                token = try processStringToken(in: currentPart)
            case .quotationMark:
                token = try processQuotedStringToken(in: currentPart)
            case .whitespace:
                currentIndex = characterToken.substring.endIndex
                continue
            default:
                throw InterpretorError.unexpectedToken
            }
            
            guard let token = token else {
                throw InterpretorError.unexpectedToken
            }
            tokens.append(token)
            currentIndex = token.substring.endIndex
        }
        return tokens
    }
    
    func processStringToken(in substring: Substring) throws -> TokenItem? {
        let startIndex = substring.startIndex
        let endIndex = substring.endIndex
        
        var currentIndex = startIndex
        var subtokens = [TokenItem]()
        
        while currentIndex != endIndex {
            let currentPart = substring[currentIndex...]
            guard let characterToken = try processCharacterToken(in: currentPart) else {
                throw InterpretorError.unexpectedToken
            }
            
            var token: TokenItem?
            switch characterToken.type {
            case .glyph:
                token = characterToken
            case .quotationMark:
                token = try processQuotedStringToken(in: currentPart)
            case .whitespace:
                let procesedValue = substring[startIndex..<currentIndex]
                return TokenItem(type: .string, substring: procesedValue, subtokens: subtokens)
            default:
                throw InterpretorError.unexpectedToken
            }
            
            guard let token = token else {
                throw InterpretorError.unexpectedToken
            }
            subtokens.append(token)
            currentIndex = token.substring.endIndex
        }
        
        let procesedValue = substring[startIndex..<currentIndex]
        return TokenItem(type: .string, substring: procesedValue, subtokens: subtokens)
    }
    
    func processQuotedStringToken(in substring: Substring) throws -> TokenItem? {
        let quotationMark = substring.first
        
        let startIndex = substring.startIndex
        let endIndex = substring.endIndex
        
        var currentIndex = startIndex
        var subtokens = [TokenItem]()
        
        while currentIndex != endIndex {
            let currentPart = substring[currentIndex...]
            guard let characterToken = try processCharacterToken(in: currentPart) else {
                throw InterpretorError.unexpectedToken
            }
            subtokens.append(characterToken)
            
            guard currentIndex != startIndex,
                  characterToken.type == .quotationMark,
                  characterToken.substring.first == quotationMark
            else {
                currentIndex = characterToken.substring.endIndex
                continue
            }
            let processedValue = substring[startIndex...currentIndex]
            return TokenItem(type: .quotedString, substring: processedValue, subtokens: subtokens)
        }
        throw InterpretorError.unterminatedToken
    }
    
    private func processCharacterToken(in substring: Substring) throws -> TokenItem? {
        let startIndex = substring.startIndex
        let endIndex = substring.endIndex
        
        guard startIndex < endIndex else {
            throw InterpretorError.unterminatedToken
        }
        
        let characterEndIndex = substring.index(after: startIndex)
        let processedValue = substring[startIndex..<characterEndIndex]
        
        let currentCharacter = substring[startIndex]
        
        let tokenType: Token
        if isQuotationMark(currentCharacter) {
            tokenType = .quotationMark
        } else if isWhitespace(currentCharacter) {
            tokenType = .whitespace
        } else {
            tokenType = .glyph
        }
        return TokenItem(type: tokenType, substring: processedValue, subtokens: [])
    }
    
    func isQuotationMark(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy(Self.quotationMarkSet.contains(_:))
    }
    
    func isWhitespace(_ character: Character) -> Bool {
        character.isWhitespace
    }
}
