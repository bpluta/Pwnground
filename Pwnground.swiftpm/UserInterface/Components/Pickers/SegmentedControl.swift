//
//  SegmentedControl.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI

struct SegmentedControl<SelectionValue>: UIViewRepresentable where SelectionValue: (Hashable & CustomStringConvertible) {
    let values: [SelectionValue]
    @Binding var selectedValue: SelectionValue
    
    func makeUIView(context: Context) -> UISegmentedControl {
        let segmentedControl = UISegmentedControl(items: values.map(\.description))
        select(item: selectedValue, in: segmentedControl)
        
        segmentedControl.selectedSegmentTintColor = UIColor(ThemeColors.middleBlue)
        segmentedControl.backgroundColor = UIColor(ThemeColors.blueFocusedBackground)
        
        let normalTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor(ThemeColors.white)]
        let selectedTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor(ThemeColors.white)]
        segmentedControl.setTitleTextAttributes(normalTextAttributes, for: .normal)
        segmentedControl.setTitleTextAttributes(selectedTextAttributes, for: .selected)
        segmentedControl.addTarget(context.coordinator, action: #selector(context.coordinator.segmentSelected(sender:)), for: .valueChanged)
        return segmentedControl
    }
    
    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        select(item: selectedValue, in: uiView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func select(item: SelectionValue, in segmentedControl: UISegmentedControl) {
        if let selectedIndex = values.firstIndex(where: { $0 == selectedValue }) {
            segmentedControl.selectedSegmentIndex = selectedIndex
        }
    }
}

extension SegmentedControl {
    class Coordinator {
        private let parent: SegmentedControl<SelectionValue>
        
        init(_ parent: SegmentedControl<SelectionValue>) {
            self.parent = parent
        }
        
        @objc func segmentSelected(sender: UISegmentedControl) {
            let selectedIndex = sender.selectedSegmentIndex
            guard selectedIndex >= 0 && selectedIndex < parent.values.count else { return }
            let selectedValue = parent.values[selectedIndex]
            withAnimation { parent.selectedValue = selectedValue }
        }
    }
}
