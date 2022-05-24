//
//  SystemUser.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

typealias UID = UInt32

class SystemUser: ObservableObject {
    let uid: UID
    @Published var name: String
    @Published var groups: [SystemGroup]
    
    init(uid: UID, name: String, groups: [SystemGroup] = []) {
        self.uid = uid
        self.name = name
        self.groups = groups
    }
}
