//
//  StandardInputOutput.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation
import Combine

protocol InputOutputDelegate {
    func read() -> AnyPublisher<Data,Never>
    func write(data: Data) -> AnyPublisher<Void,Never>
}

protocol InputSourceDelegate {
    func fillBuffer(with data: Data)
    func pushInfoBuffer(data: Data)
}

class StandardInputOutput {
    var standardOutputPublisher: AnyPublisher<Data,Never> { standardOutputSubject.wrappedPublisher.eraseToAnyPublisher() }
    private var standardOutputSubject = BufferedPassthroughSubject<Data,Never>()
    
    var standardInputPublisher: AnyPublisher<Data,Never> { standardInputSubject.wrappedPublisher.eraseToAnyPublisher() }
    private var standardInputSubject = BufferedPassthroughSubject<Data,Never>()
    
    private var bufferAccessQueue = DispatchQueue(label: "standardInputOutput.bufferAccessQueue")
    private var cancelBag = CancelBag()
}

extension StandardInputOutput: InputOutputDelegate {
    func read() -> AnyPublisher<Data,Never> {
        standardInputSubject
            .first()
            .eraseToAnyPublisher()
    }
    
    func write(data: Data) -> AnyPublisher<Void,Never> {
        Future { [standardOutputSubject] promise in
            standardOutputSubject.send(data)
            return promise(.success(()))
        }.eraseToAnyPublisher()
    }
}

extension StandardInputOutput: InputSourceDelegate {
    func fillBuffer(with data: Data) {
        standardInputSubject.send(data)
    }
    
    func pushInfoBuffer(data: Data) {
        standardInputSubject.appendToBuffer(data)
    }
}
