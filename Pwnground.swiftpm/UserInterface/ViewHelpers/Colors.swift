//
//  Colors.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI

enum ThemeColors {
    static var white: Color {
        Color.init(red: 1.0, green: 1.0, blue: 1.0)
    }
    
    static var lightGray: Color {
        Color.init(red: 0.92, green: 0.92, blue: 0.92)
    }
    
    static var darkGray: Color {
        Color.init(red: 0.35, green: 0.35, blue: 0.35)
    }
    
    static var middleGray: Color {
        Color.init(red: 0.55, green: 0.55, blue: 0.55)
    }
    
    static var lighterGray: Color {
        Color.init(red: 0.96, green: 0.96, blue: 0.96)
    }
    
    static var diabledGray: Color {
        Color.init(red: 0.77, green: 0.77, blue: 0.77)
    }
    
    static var whiteButtonPressedGray: Color {
        Color.init(red: 0.90, green: 0.90, blue: 0.90)
    }
    
    static var darkBlueBackground: Color {
        Color.init(red: 0.073, green: 0.063, blue: 0.137)
    }
    
    static var blueBackground: Color {
        Color.init(red: 0.113, green: 0.097, blue: 0.211)
    }
    
    static var lighterBlue: Color {
        Color.init(red: 0.78 , green: 0.74, blue: 0.82)
    }
    
    static var middleBlue: Color {
        Color.init(red: 0.415, green: 0.399, blue: 0.52)
    }
    
    static var blueGrayishBackground: Color {
        Color.init(red: 0.18, green: 0.18, blue: 0.242)
    }
    
    static var blueGrayishSeparator: Color {
        Color.init(red: 0.25, green: 0.25, blue: 0.312)
    }
    
    static var blueFocusedBackground: Color {
        Color.init(red: 0.215, green: 0.199, blue: 0.32)
    }
    
    static var green: Color {
        Color.init(red: 0.299, green: 0.72, blue: 0.315)
    }
}

enum ThemeGradient {
    static var BackgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [.red, .purple, .blue]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
