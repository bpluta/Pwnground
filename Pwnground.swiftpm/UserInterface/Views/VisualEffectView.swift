//
//  VisualEffectView.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI

struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    var animation: Animation? = nil
    
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView {
        UIVisualEffectView()
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) {
        UIView.animate(withDuration: 0.5) {
            uiView.effect = effect
        }
    }
    
    static func dismantleUIView(_ uiView: UIVisualEffectView, coordinator: ()) {
        UIView.animate(withDuration: 0.5) {
            uiView.effect = nil
        }
    }
}
