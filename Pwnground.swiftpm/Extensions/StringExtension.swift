//
//  StringExtension.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

extension String {
    var capitalizingFirstLetter: String {
        prefix(1).capitalized + dropFirst()
    }
    
    var isLetterOnly: Bool {
        range(of: "[^a-zA-Z]", options: .regularExpression) == nil
    }
}
