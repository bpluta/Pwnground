//
//  ArrayExtension.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < endIndex else { return nil }
        return self[index]
    }
    
    func firstNext(after item: Element) -> Element? where Element: Equatable {
        guard let index = firstIndex(where: { $0 == item }), index < endIndex - 1 else { return nil }
        let nextItemIndex = self.index(after: index)
        return self[nextItemIndex]
    }
}

extension Array where Element: Hashable {
    func removeDuplicates() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}
