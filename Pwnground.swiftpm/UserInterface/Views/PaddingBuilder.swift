//
//  PaddingBuilder.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI
import Combine

struct PaddingBuilder: View {
    class ViewModel: ObservableObject {
        @Published var count = 0
        @Published var address: Address?
        @Published var isAddressKeyboardPopoverDisplayed = false
        @Published fileprivate(set) var payload = Data()
        var baseAddress: Address
        
        fileprivate var isConfigured = false
        fileprivate var cancelBag = CancelBag()
        
        init(baseAddress: Address) {
            self.baseAddress = baseAddress
        }
    }
    
    @State var displayMode: DisplayMode = .hex
    @ObservedObject var viewModel: ViewModel
    
    static let paddedCharacter = Character("A")
    
    var body: some View {
        VStack(alignment: .center) {
            VStack(alignment: .center, spacing: 15) {
                HStack(alignment: .middleGuide, spacing: 20) {
                    CountComponent()
                    AddressComponent()
                }.padding()
                .frame(maxWidth: 400)
                .background(ThemeColors.blueFocusedBackground.cornerRadius(15))
                PayloadPreview()
                    .frame(maxWidth: 400, maxHeight: 450)
                    .background(ThemeColors.blueFocusedBackground.cornerRadius(15))
            }
            .padding()
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onAppear(perform: setupView)
    }
    
    @ViewBuilder
    private func CharacterComponent() -> some View {
        Text("\'\(Self.paddedCharacter.description)\'")
            .font(.system(size: 26))
            .minimumScaleFactor(0.8)
            .lineLimit(1)
            .fixedSize()
            .foregroundColor(ThemeColors.white)
            .alignmentGuide(.middleGuide) { d in d[VerticalAlignment.center] }
    }
    
    @ViewBuilder
    private func CountComponent() -> some View {
        VStack(alignment: .center, spacing: 20) {
            HStack(alignment: .center, spacing: 15) {
                CharacterComponent()
                HStack(alignment: .center, spacing: 5) {
                    Image(systemName: "xmark")
                        .resizable()
                        .scaledToFit()
                        .font(Font.system(size: 13, weight: .medium))
                        .frame(width: 13, height: 13)
                    Text("\(viewModel.count)")
                        .font(.system(size: 24, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.opacity)
                        .id(viewModel.count)
                }.foregroundColor(ThemeColors.white)
            }.alignmentGuide(.middleGuide) { d in d[VerticalAlignment.center] }
            ValueStepper(value: $viewModel.count, range: 0...300)
                .frame(maxWidth: 100, maxHeight: 35, alignment: .center)
        }
    }
    
    @ViewBuilder
    private func AddressComponent() -> some View {
        Text(viewModel.address?.uppercaseDynamicWidthHexString ?? "Address")
            .font(.system(size: 18))
            .minimumScaleFactor(0.8)
            .lineLimit(1)
            .foregroundColor(ThemeColors.white)
            .padding(10)
            .frame(minWidth: 200)
            .background(ThemeColors.middleBlue.cornerRadius(10))
            .alignmentGuide(.middleGuide) { d in d[VerticalAlignment.center] }
            .onTapGesture {
                viewModel.isAddressKeyboardPopoverDisplayed = true
            } .popover(isPresented: $viewModel.isAddressKeyboardPopoverDisplayed) {
                UnsignedNumberKeyboard(
                    mode: .constant(.hexadecimal),
                    value: $viewModel.address,
                    supportedModes: [.hexadecimal]
                ).frame(width: 300)
            }
            .transition(.opacity)
            .id(viewModel.address ?? 0)
    }
    
    @ViewBuilder
    private func PayloadPreview() -> some View {
        VStack(alignment: .center, spacing: 20) {
            SegmentedControl(values: DisplayMode.allCases, selectedValue: $displayMode)
                .frame(maxWidth: 200)
            VStack(alignment: .center, spacing: 5) {
                VStack(spacing: 5) {
                    AddressCell(title: "Start address", address: viewModel.baseAddress)
                    Separator()
                }
                Text(payloadString)
                    .font(.system(size: 14))
                    .multilineTextAlignment(.leading)
                    .truncationMode(.head)
                    .foregroundColor(ThemeColors.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                    .id(displayMode.rawValue)
                Spacer(minLength: 0)
                VStack(spacing: 5) {
                    Separator()
                    AddressCell(title: "End address", address: endAddress)
                }
            }
            
        }.padding(.horizontal, 20)
        .padding(.vertical, 25)
    }
    
    @ViewBuilder
    private func Separator() -> some View {
        Rectangle()
            .foregroundColor(ThemeColors.white)
            .opacity(0.3)
            .frame(height: 1)
    }
    
    @ViewBuilder
    private func AddressCell(title: String, address: Address) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(address.uppercaseDynamicWidthHexString)
                .bold()
        }
        .font(.system(size: 13))
        .foregroundColor(ThemeColors.white)
    }
    
}

// MARK: - Helpers
extension PaddingBuilder {
    private func getPayload(paddingLength: Int, address: Address?) -> Data {
        var payload = Data()
        if let paddedCharacterValue = Self.paddedCharacter.asciiValue {
            let paddedValues = Data(repeating: paddedCharacterValue, count: paddingLength)
            payload += paddedValues
        }
        guard let address = address else {
            return payload
        }
        let addressValue = Data(from: address)
        payload += addressValue
        return payload
    }
    
    private var payloadString: String {
        switch displayMode {
        case .hex:
            return viewModel.payload.hexComponents.joined(separator: " ")
        case .string:
            return "\"\(viewModel.payload.printableStringRepresentation(as: UTF8.self))\""
        }
    }
    
    private var endAddress: Address {
        viewModel.baseAddress + UInt64(viewModel.payload.count)
    }
    
    private func setupView() {
        guard !viewModel.isConfigured else { return }
        viewModel.isConfigured = true
        
        Publishers.CombineLatest(viewModel.$count, viewModel.$address)
            .sink { count, address in
                viewModel.payload = getPayload(paddingLength: count, address: address)
            }.store(in: viewModel.cancelBag)
    }
}

// MARK: - Models
extension PaddingBuilder {
    enum DisplayMode: String, CaseIterable, CustomStringConvertible {
        case hex = "Hexadecimal"
        case string = "String"
        
        var description: String { rawValue }
    }
}

// MARK: - Alignment guides
fileprivate extension VerticalAlignment {
    struct MiddleGuide: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat {
            d[VerticalAlignment.center]
        }
    }
    
    static let middleGuide = VerticalAlignment(MiddleGuide.self)
}
