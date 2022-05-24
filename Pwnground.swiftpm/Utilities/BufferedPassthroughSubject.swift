//
//  BufferedPassthroughSubject.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Combine

class BufferedPassthroughSubject<Output, Failure: Error>: Subject {
    private let wrappedSubject: CurrentValueSubject<Output?, Failure>
    
    var wrappedPublisher: AnyPublisher<Output, Failure> {
        wrappedSubject
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    init() {
        wrappedSubject = .init(nil)
    }
    
    func send(_ value: Output) {
        wrappedSubject.send(value)
    }
    
    func send(completion: Subscribers.Completion<Failure>) {
        wrappedSubject.send(completion: completion)
    }
    
    func send(subscription: Subscription) {
        wrappedSubject.send(subscription: subscription)
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        wrappedSubject
            .compactMap { $0 }
            .flatMap { output in
                self.flushBufferedValue(receivedOutput: output)
            }.subscribe(subscriber)
    }
    
    func flushBufferedValue(receivedOutput: Output) -> AnyPublisher<Output, Failure> {
        Future<Output,Failure> { [weak self] promise in
            self?.wrappedSubject.value = nil
            return promise(.success(receivedOutput))
        }.eraseToAnyPublisher()
    }
}

extension BufferedPassthroughSubject where Output: RangeReplaceableCollection {
    func appendToBuffer(_ newElement: Output.Element) {
        var newValue: Output
        if let currentValue = wrappedSubject.value {
            newValue = currentValue
            newValue.append(newElement)
        } else {
            newValue = Output([newElement])
        }
        send(newValue)
    }
    
    func appendToBuffer(_ newBuffer: Output) {
        let newValue: Output
        if let currentValue = wrappedSubject.value {
            newValue = currentValue + newBuffer
        } else {
            newValue = newBuffer
        }
        send(newValue)
    }
}
