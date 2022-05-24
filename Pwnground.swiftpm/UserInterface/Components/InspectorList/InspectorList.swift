//
//  InspectorList.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI

struct InspectorList<InspectorItem: Interpretable>: View {
    @Binding var items: [InspectorItem]
    @Binding var config: LazyKeyValueListConfiguration
    
    var body: some View {
        LazyKeyValueList(config: config) { (row, column) in
            Group {
                Item(row: row, column: column)
            }.font(.system(size: 13, design: .monospaced))
            .minimumScaleFactor(0.8)
            .lineLimit(1)
            .truncationMode(.head)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
        }.clipped()
    }
    
    @ViewBuilder
    private func Item(row: Int, column: Int) -> some View {
        switch column {
        case 0:
            Key(row: row)
        case 1:
            Value(row: row)
        default:
            Text("")
        }
    }
    
    @ViewBuilder
    private func Key(row: Int) -> some View {
        if let object = items[safe: row] {
            Text(object.presentedKey)
                .foregroundColor(object.displayMode.textColor)
        }
    }
    
    @ViewBuilder
    private func Value(row: Int) -> some View {
        if let object = items[safe: row] {
            InterpretationMenu(
                presentationType: $items[row].presentationType,
                suggestedTypes: items[row].suggestedPresentationTypes
            ) {
                Text(object.presentedValue)
                    .foregroundColor(object.displayMode.textColor)
                    .frame(maxWidth: .infinity, maxHeight: 14, alignment: .leading)
            }
        }
    }
}

fileprivate extension InterpretableDisplayMode {
    var textColor: Color {
        switch self {
        case .normal:
            return ThemeColors.white
        case .error:
            return Color.red
        case .edited:
            return Color.green
        }
    }
}
