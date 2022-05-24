//
//  PublisherExtension.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Combine
import Foundation

extension Publisher {
    func unwrap<T>(orThrow error: Failure) -> Publishers.TryMap<Self, T> where Output == Optional<T> {
        tryMap { output in
            guard let output = output else { throw error }
            return output
        }
    }
    
    func withPrevious() -> AnyPublisher<(previous: Output?, current: Output), Failure> {
        scan(Optional<(Output?, Output)>.none) { ($0?.1, $1) }
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    @discardableResult
    func execute() -> Result<Output,Failure>? {
        var result: Result<Output,Failure>?
        let group = DispatchGroup()
        group.enter()
        _ = handleEvents(
            receiveSubscription: { _ in },
            receiveOutput: { _ in },
            receiveCompletion: { _ in },
            receiveCancel: {
                group.leave()
            }, receiveRequest: { _ in }
        ).sink(receiveCompletion: { completion in
            if case .failure(let error) = completion {
                result = .failure(error)
            }
            group.leave()
        }, receiveValue: { value in
            result = .success(value)
        })
        group.wait()
        return result
    }
}
