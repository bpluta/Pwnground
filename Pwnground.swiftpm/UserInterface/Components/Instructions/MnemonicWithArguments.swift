//
//  MnemonicWithArguments.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI

struct MnemonicWithArguments: View {
    @ObservedObject var item: InstructionCellItem
    var deleteAction: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            Mnemonic()
            Spacer().frame(width: 10)
            Arguments(item.arguments)
        }.padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(ThemeColors.blueGrayishSeparator.cornerRadius(10))
        .onTapGesture {
            item.isSelected = true
        }.popover(isPresented: $item.isSelected) {
            PickerView(instructionInfo: item, deleteAction: deleteAction)
                .frame(width: 300)
        }
    }

    @ViewBuilder
    private func Mnemonic() -> some View {
        Text(item.type.mnemonic.rawValue)
            .font(.system(size: 14))
            .foregroundColor(ThemeColors.white)
    }

    @ViewBuilder
    private func Arguments(_ arguments: [InstructionCell.Argument]) -> some View {
        ForEach(arguments, id: \.id) { argument in
            ArgumentItem(argument)
            CommaSeparator(argument, argumentList: arguments)
        }
    }
    
    @ViewBuilder
    private func Subarguments(_ arguments: [InstructionCell.Argument]) -> some View {
        ForEach(arguments, id: \.id) { argument in
            SubargumentItem(argument)
            CommaSeparator(argument, argumentList: arguments)
        }
    }

    @ViewBuilder
    private func ArgumentItem(_ argument: InstructionCell.Argument) -> some View {
        if !argument.subarguments.isEmpty {
            AddressArgument(argument)
        } else if argument.mutability == .mutable {
            MutableArgument(argument)
        } else {
            ImmutableArgument(argument)
        }
    }
    
    @ViewBuilder
    private func SubargumentItem(_ argument: InstructionCell.Argument) -> some View {
        if argument.mutability == .mutable {
            MutableArgument(argument)
        } else {
            ImmutableArgument(argument)
        }
    }

    @ViewBuilder
    private func AddressArgument(_ argument: InstructionCell.Argument) -> some View {
        HStack(spacing: 0) {
            PrefixComponent(argument)
                .alignComponentHeight()
            Subarguments(argument.subarguments)
            PostfixComponent(argument)
                .alignComponentHeight()
        }
    }

    @ViewBuilder
    private func PrefixComponent(_ argument: InstructionCell.Argument) -> some View {
        switch argument.argumentType {
        case .preIndexedAddress(_,_), .postIndexedAddress(_,_):
            Bracket(type: .opening)
                .stroke(lineWidth: 1.5)
                .foregroundColor(ThemeColors.white)
                .frame(maxWidth: 5, maxHeight: .infinity)
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func PostfixComponent(_ argument: InstructionCell.Argument) -> some View {
        switch argument.argumentType {
        case .postIndexedAddress(_,_):
            Bracket(type: .closing)
                .stroke(lineWidth: 1.5)
                .foregroundColor(ThemeColors.white)
                .frame(maxWidth: 5, maxHeight: .infinity)
        case .preIndexedAddress(_,_):
            HStack(spacing: 10) {
                Bracket(type: .closing)
                    .stroke(lineWidth: 1.5)
                    .foregroundColor(ThemeColors.white)
                    .frame(maxWidth: 5, maxHeight: .infinity)
                ExclamationMark()
                    .fill(ThemeColors.white)
                    .foregroundColor(ThemeColors.white)
                    .frame(maxWidth: 1.5, maxHeight: 30)
                    .padding(.vertical, 3)
            }
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func ImmutableArgument(_ argument: InstructionCell.Argument) -> some View {
        Text(argument.valueDescription ?? argument.argumentType.description)
            .font(.system(size: 14))
            .foregroundColor(ThemeColors.white)
            .frame(maxHeight: .infinity)
            .alignComponentHeight()
    }

    @ViewBuilder
    private func MutableArgument(_ argument: InstructionCell.Argument) -> some View {
        Text(argumentValueDescription(from: argument))
            .font(.system(size: 12))
            .minimumScaleFactor(0.8)
            .lineLimit(3)
            .foregroundColor(ThemeColors.white)
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .frame(maxHeight: .infinity)
            .alignComponentHeight()
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(!argument.validationResult.isValid ? Color.red : Color.clear, lineWidth: 2)
                    .background(ThemeColors.blueGrayishBackground.cornerRadius(5))
            )
    }

    @ViewBuilder
    private func CommaSeparator(_ argument: InstructionCell.Argument, argumentList: [InstructionCell.Argument]) -> some View {
        if argument.id != argumentList.last?.id {
            Text(",")
                .foregroundColor(ThemeColors.white)
                .padding(.trailing, 5)
        }
    }
}

// MARK: Helpers
extension MnemonicWithArguments {
    private func argumentValueDescription(from argument: InstructionCell.Argument) -> String {
        return argument.valueDescription ?? argument.argumentType.purposeDescription
    }
}

// MARK: - Shapes
extension MnemonicWithArguments {
    struct Bracket: Shape {
        enum BracketType {
            case opening
            case closing
        }
        
        let type: BracketType
        
        func path(in rect: CGRect) -> Path {
            let width: CGFloat = rect.width
            let height: CGFloat = rect.height
            
            var path = Path()
            
            path.move(to: CGPoint(x: width, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: height))
            path.addLine(to: CGPoint(x: width, y: height))
            
            let flipTransformation = CGAffineTransform(scaleX: type == .closing ? -1 : 1, y: 1)
            let translationTransformation = CGAffineTransform(translationX: type == .closing ? width : 0, y: 0)
            
            path = path.applying(flipTransformation)
            path = path.applying(translationTransformation)
            
            return path
        }
    }
    
    struct ExclamationMark: Shape {
        func path(in rect: CGRect) -> Path {
            let width: CGFloat = rect.width
            let height: CGFloat = rect.height
            
            var path = Path()
            
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: width, y: 0))
            path.addLine(to: CGPoint(x: width, y: height * 0.8))
            path.addLine(to: CGPoint(x: 0, y: height * 0.8))
            path.closeSubpath()
            
            let dotSize = width * 2
            path.addEllipse(in: CGRect(x: (width - dotSize) / 2, y: height - dotSize / 2, width: dotSize, height: dotSize))
            
            return path
        }
    }
}

// MARK: - Alignment guides
fileprivate extension VerticalAlignment {
    struct InstructionArgumentsTopGuide: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat {
            d[.top]
        }
    }

    struct InstructionArgumentsBottomGuide: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat {
            d[.bottom]
        }
    }
    
    static let instructionArgumentsTopGuide = VerticalAlignment(InstructionArgumentsTopGuide.self)
    static let instructionArgumentsBottomGuide = VerticalAlignment(InstructionArgumentsBottomGuide.self)
}


fileprivate extension View {
    func alignComponentHeight() -> some View {
        self
            .alignmentGuide(.instructionArgumentsTopGuide) { d in d[.top] }
            .alignmentGuide(.instructionArgumentsBottomGuide) { d in d[.bottom] }
    }
}
