//
//  InterpretationMenu.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI

struct InterpretationMenu<Content: View>: View {
    @Binding var presentationType: ValueInterpretationType
    var suggestedTypes: [ValueInterpretationType]
    let content: () -> Content
    
    init(presentationType: Binding<ValueInterpretationType>, suggestedTypes: [ValueInterpretationType], @ViewBuilder content: @escaping () -> Content) {
        self._presentationType = presentationType
        self.suggestedTypes = suggestedTypes
        self.content = content
    }
    
    var body: some View {
        if suggestedTypes.count > 1 {
            ContentWithMenu()
        } else {
            PlainContent()
        }
    }
    
    @ViewBuilder
    private func ContentWithMenu() -> some View {
        Menu {
            ForEach(suggestedTypes, id: \.rawValue) { interpretationType in
                Button {
                    presentationType = interpretationType
                } label: {
                    if presentationType == interpretationType {
                        Label(interpretationType.description, systemImage: "checkmark")
                    } else {
                        Text(interpretationType.description)
                    }
                }
            }
        } label: {
            content()
        }
    }
    
    private func PlainContent() -> some View {
        content()
    }
}
