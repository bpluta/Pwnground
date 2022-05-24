//
//  RoundedCorners.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension UIRectCorner {
    static var left: UIRectCorner {
        [.topLeft, .bottomLeft]
    }
    
    static var right: UIRectCorner {
        [.topRight, .bottomRight]
    }
    
    static var top: UIRectCorner {
        [.topLeft, .topRight]
    }
    
    static var bottom: UIRectCorner {
        [.bottomLeft, .bottomRight]
    }
}
