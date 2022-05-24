//
//  HelpSheet..swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI

struct HelpParagaph: Identifiable {
    let id = UUID()
    
    let title: String
    let paragraph: AttributedString
    
    init(title: String, paragraph: String) {
        self.title = title
        self.paragraph = (try? AttributedString(
            markdown: paragraph,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? ""
    }
}

struct HelpSheet: View {
    @Binding var isPresented: Bool
    var currentScene: PwngroundScene.Scene
    
    var body: some View {
        Canvas {
            VStack(alignment: .leading, spacing: 30) {
                LevelTitle()
                Section(title: "Challenge", icon: .task) {
                    Text(currentScene.fullTaskDescription)
                        .font(.system(size: 16))
                }
                HelpContent()
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private func Canvas<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(spacing: 15) {
            HStack {
                Spacer()
                Button(action: closeSheet) {
                    Image(systemName: "xmark")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(ThemeColors.middleGray)
                        .frame(width: 15, height: 15)
                }.buttonStyle(.plain)
            }.padding(.horizontal, 30)
            ScrollView {
                content()
                    .padding(.horizontal, 50)
            }
        }.padding(.vertical, 30)
        .frame(maxWidth: 600, maxHeight: .infinity)
        .background(ThemeColors.white.cornerRadius(20, corners: .top))
        .padding(.horizontal, 50)
        .padding(.top, 50)
        .ignoresSafeArea()
    }
    
    @ViewBuilder
    private func LevelTitle() -> some View {
        Text(currentScene.title)
            .font(.system(size: 36, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private func Section<Content: View>(title: String, icon: Icon, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Separator()
                icon.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text(title)
                    .font(.system(size: 15))
                Separator()
            }.foregroundColor(ThemeColors.middleGray)
            content().padding(.vertical, 10)
            Separator()
        }
    }
    
    @ViewBuilder
    private func Separator() -> some View {
        Rectangle()
            .frame(maxWidth: .infinity, maxHeight: 1)
            .foregroundColor(ThemeColors.lightGray)
    }
    
    @ViewBuilder
    private func HelpContent() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(currentScene.help) { item in
                Paragraph(title: item.title, paragraph: item.paragraph)
            }
        }
    }
    
    @ViewBuilder
    private func Paragraph(title: String, paragraph: AttributedString) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 24, weight: .semibold))
            Text(paragraph)
                .font(.system(size: 16))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Helpers
extension HelpSheet {
    func closeSheet() {
        withAnimation { isPresented = false }
    }
}

// MARK: - Models
extension HelpSheet {
    enum Icon {
        case task
        
        var image: Image {
            switch self {
            case .task:
                return Image(systemName: "checkmark.seal")
            }
        }
    }
}
