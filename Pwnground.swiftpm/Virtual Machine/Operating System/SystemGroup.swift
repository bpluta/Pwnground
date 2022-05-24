//
//  SystemGroup.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

typealias GID = UInt32

class SystemGroup: ObservableObject {
    let gid: GID
    let name: String
    @Published var users: [SystemUser]
    
    init(gid: GID, name: String, users: [SystemUser] = []) {
        self.gid = gid
        self.name = name
        self.users = users
    }
}
