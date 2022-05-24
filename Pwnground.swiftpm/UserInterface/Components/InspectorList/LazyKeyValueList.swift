//
//  LazyKeyValueList.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI

class LazyKeyValueListConfiguration: ObservableObject {
    @Published var amountOfRows: Int
    @Published var columnConfigurations: [LazyKeyValueListRowConfiguration]
    @Published var scrollToRowIndex: Int
    @Published var selectedRow: Int?
    
    required init(amountOfRows: Int, columnConfigurations: [LazyKeyValueListRowConfiguration], scrollToRowIndex: Int = 0) {
        self.amountOfRows = amountOfRows
        self.columnConfigurations = columnConfigurations
        self.scrollToRowIndex = scrollToRowIndex
    }
    
    static func baseListConfiguration(title: String, value: String = "Value") -> Self {
        Self(amountOfRows: 0, columnConfigurations: LazyKeyValueListRowConfiguration.baseColumnConfiguration(title: title, value: value))
    }
}

struct LazyKeyValueListRowConfiguration {
    let title: String
    let size: GridItem.Size
    let alignment: Alignment
    
    init(title: String, size: GridItem.Size = .flexible(minimum: 10, maximum: .infinity), alignment: Alignment = .center) {
        self.title = title
        self.size = size
        self.alignment = alignment
    }
    
    static func baseColumnConfiguration(title: String, value: String) -> [Self] {[
        Self(title: title, size: .flexible(minimum: 50, maximum: 100), alignment: .trailing),
        Self(title: value, alignment: .leading)
    ]}
}

struct LazyKeyValueList<Content: View>: View {
    @ObservedObject var config: LazyKeyValueListConfiguration
    let cellProvider: (Int, Int) -> Content
    
    init(config: LazyKeyValueListConfiguration, @ViewBuilder cellProvider: @escaping (Int, Int) -> Content) {
        self.config = config
        self.cellProvider = cellProvider
    }
    
    private var gridItems: [GridItem] {
        config.columnConfigurations.map { configuration in
            GridItem(configuration.size, spacing: 0)
        }
    }
    
    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                LazyVGrid(columns: gridItems, alignment: .center, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section(header:
                        VStack(spacing: 0) {
                            LazyVGrid(columns: gridItems, alignment: .center, spacing: 0) {
                                ForEach(0..<config.columnConfigurations.count, id: \.self) { colIndex in
                                    Text(config.columnConfigurations[colIndex].title)
                                        .font(.system(size: 12))
                                        .frame(maxWidth: .infinity, alignment: config.columnConfigurations[colIndex].alignment)
                                        .foregroundColor(ThemeColors.diabledGray)
                                        .padding(6)
                                }
                            }.padding(.vertical, 6)
                            .background(ThemeColors.blueBackground)
                            Separator()
                        }
                    ) {
                        ForEach(0..<config.amountOfRows, id: \.self) { rowIndex in
                            ForEach(0..<gridItems.count, id: \.self) { colIndex in
                                cellProvider(rowIndex, colIndex)
                                    .frame(maxWidth: .infinity, alignment: config.columnConfigurations[colIndex].alignment)
                                    .background(
                                        ThemeColors.blueBackground
                                            .overlay(config.selectedRow == rowIndex ? SelectionBackground(colIndex: colIndex) : nil)
                                    )
                            }
                            .id(rowIndex)
                            .onTapGesture(perform: {
                                config.selectedRow = rowIndex
                            })
                        }
                    }
                }
                .onReceive(config.$scrollToRowIndex.dropFirst()) { index in
                    proxy.scrollTo(index, anchor: .center)
                }
            }.padding(.horizontal, 6)
            .background(ThemeColors.blueBackground)
        }
    }
    
    @ViewBuilder
    private func SelectionBackground(colIndex: Int) -> some View {
        ThemeColors.blueFocusedBackground
            .cornerRadius(colIndex == 0 ? 5 : 0, corners: .left)
            .cornerRadius(colIndex == gridItems.count - 1 ? 5 : 0, corners: .right)
    }
    
    @ViewBuilder
    private func Separator() -> some View {
        Rectangle()
            .fill(ThemeColors.blueGrayishSeparator)
            .frame(maxWidth: .infinity, maxHeight: 1)
    }
}

#if DEBUG
struct LazyKeyValyeListPreview: PreviewProvider {
    @StateObject static var config = LazyKeyValueListConfiguration(
        amountOfRows: 200,
        columnConfigurations: [
            LazyKeyValueListRowConfiguration(title: "Title", size: .flexible(minimum: 40, maximum: .infinity)),
            LazyKeyValueListRowConfiguration(title: "Description", size: .flexible(minimum: 40, maximum: .infinity)),
            LazyKeyValueListRowConfiguration(title: "Details", size: .flexible(minimum: 40, maximum: .infinity))
        ],
        scrollToRowIndex: 40
    )
    
    static var previews: some View {
        LazyKeyValueList(config: config) { (row, column) in
            HStack {
                Text("Cell \(row)")
                Rectangle()
                    .fill(Color.green)
                    .frame(maxWidth: 10, maxHeight: 20)
                    .cornerRadius(5)
            }.padding(20)
        }.onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                config.scrollToRowIndex = 120
            }
        }
    }
}
#endif
