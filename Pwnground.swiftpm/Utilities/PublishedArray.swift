//
//  PublishedArray.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Combine
import SwiftUI

@propertyWrapper
class PublishedArray<ArrayItemType: ObservableObject>: ObservableObject {
    @Published private var wrappedArray: PublishedArrayWrapper<ArrayItemType>
    
    private(set) var projectedValue: PublishedArray<ArrayItemType>.Publisher
    var wrappedValue: Array<ArrayItemType>  {
        get { wrappedArray.values }
        set { wrappedArray.values = newValue }
    }
    
    private var cancelBag = CancelBag()
    
    public init(wrappedValue value: Array<ArrayItemType>) {
        let wrappedArray = PublishedArrayWrapper(value)
        self.wrappedArray = wrappedArray
        self.projectedValue = Publisher(wrappedArray)
    }
    
    public init(initialValue value: Array<ArrayItemType>) {
        let wrappedArray = PublishedArrayWrapper(value)
        self.wrappedArray = wrappedArray
        self.projectedValue = Publisher(wrappedArray)
    }
}

extension PublishedArray {
    struct Publisher: Combine.Publisher {
        typealias Output = Array<ArrayItemType>
        typealias Failure = Never
        
        private var publishedArray: PublishedArrayWrapper<ArrayItemType>
        
        fileprivate init(_ publishedArray: PublishedArrayWrapper<ArrayItemType>) {
            self.publishedArray = publishedArray
        }
        
        func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, Array<ArrayItemType> == S.Input {
            publishedArray
                .objectWillChange
                .merge(with: Just(()).eraseToAnyPublisher())
                .receive(on: DispatchQueue.main)
                .map { publishedArray.values }
                .eraseToAnyPublisher()
                .receive(subscriber: subscriber)
        }
        
        func register<Value>(observableObject: Value) -> AnyCancellable where Value: ObservableObject {
            receive(on: DispatchQueue.main).sink { [weak observableObject] _ in
                guard let objectWillChangePublisher = observableObject?.objectWillChange as? ObservableObjectPublisher else { return }
                objectWillChangePublisher.send()
            }
        }
    }
}

extension Published.Publisher {
    func register<Value>(observableObject: Value) -> AnyCancellable where Value: ObservableObject {
        sink(receiveValue: { [weak observableObject] _ in
            guard let objectWillChangePublisher = observableObject?.objectWillChange as? ObservableObjectPublisher else { return }
            objectWillChangePublisher.send()
        })
    }
}

fileprivate extension PublishedArray {
    class PublishedArrayWrapper<ArrayItemType: ObservableObject>: DynamicProperty, ObservableObject {
        private var arrayChangedSubscription: AnyCancellable?
        private var elementsChangedSubscription: AnyCancellable?
        
        @Published var values: Array<ArrayItemType>
        
        init(_ values: Array<ArrayItemType>) {
            self.values = values
            self.setupObjectChangePipepine()
        }
        
        private func setupObjectChangePipepine() {
            arrayChangedSubscription = $values.sink { [weak self] _ in
                guard let elementsChangePublishers = self?.values.map(\.objectWillChange) else { return }
                self?.elementsChangedSubscription = Publishers.MergeMany(elementsChangePublishers)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] _ in
                        self?.objectWillChange.send()
                    }
            }
        }
    }
}
