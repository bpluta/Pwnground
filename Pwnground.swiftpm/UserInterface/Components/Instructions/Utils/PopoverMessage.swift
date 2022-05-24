//
//  PopoverMessage.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI

struct PopoverMessage: View {
    @State var message: String
    @State var type: MessageType
    
    var body: some View {
        HStack {
            Image(systemName: type.imageName)
                .resizable()
                .foregroundColor(type.color)
                .frame(width: 25, height: 25)
            Text(message)
        }
        .padding(.vertical)
        .padding(.horizontal, 20)
        .background(ThemeColors.lightGray)
        .cornerRadius(40)
    }
}

extension PopoverMessage {
    enum MessageType {
        case success
        case failure
        case info
        case warning
        
        var imageName: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .failure: return "xmark.octagon.fill"
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .success: return .green
            case .failure: return .red
            case .info: return .blue
            case .warning: return .yellow
            }
        }
    }
}

#if DEBUG
struct PopoverMessagePreview: PreviewProvider {
    static var previews: some View {
        VStack {
            PopoverMessage(message: "Some success", type: .success)
                .previewLayout(.sizeThatFits)
            
            PopoverMessage(message: "Some failure", type: .failure)
                .previewLayout(.sizeThatFits)
            
            PopoverMessage(message: "Some information", type: .info)
                .previewLayout(.sizeThatFits)
            
            PopoverMessage(message: "Some warning", type: .warning)
                .previewLayout(.sizeThatFits)
        }
        
    }
}
#endif
