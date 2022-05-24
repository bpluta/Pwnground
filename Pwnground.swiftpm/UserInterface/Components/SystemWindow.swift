//
//  SystemWindow.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI

struct SystemWindow<Content: View>: View {
    var content: () -> Content
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(ThemeColors.lightGray)
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12, alignment: .center)
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 12, height: 12, alignment: .center)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12, alignment: .center)
                    Spacer()
                }.padding(.horizontal)
                .frame(minHeight: 50, maxHeight: 50)
                HStack(content: content)
            }
        }
        .cornerRadius(10)
        .shadow(radius: 10)
    }
}

#if DEBUG
struct SystemWindowPreview: PreviewProvider {
    static var previews: some View {
        SystemWindow {
            Rectangle()
                .fill(Color.gray)
        }
            .frame(height: 400)
            .previewLayout(.sizeThatFits)
    }
}

#endif
