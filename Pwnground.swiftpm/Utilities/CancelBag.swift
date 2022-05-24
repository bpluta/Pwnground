//
//  CancelBag.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Combine

final class CancelBag {
    fileprivate(set) var cancellables: Set<AnyCancellable> = []
    
    func cancel() {
        cancellables.forEach { cancellable in
            cancellable.cancel()
        }
        cancellables.removeAll()
    }
}

extension AnyCancellable {
    func store(in cancelBag: CancelBag) {
        cancelBag.cancellables.insert(self)
    }
}
