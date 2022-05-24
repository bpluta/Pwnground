//
//  LevelScene.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI
import Combine

struct LevelScene<Content: View>: View {
    @Binding var currentScene: PwngroundScene.Scene
    var allLevels: [PwngroundLevel]
    @ObservedObject var headerConfiguration: SceneHeaderConfiguration
    let username: String
    
    let content: () -> Content
    
    init(currentScene: Binding<PwngroundScene.Scene>, allLevels: [PwngroundLevel], username: String,  headerConfiguration: SceneHeaderConfiguration, @ViewBuilder content: @escaping () -> Content) {
        self._currentScene = currentScene
        self.allLevels = allLevels
        self.username = username
        self.headerConfiguration = headerConfiguration
        self.content = content
    }
    
    var body: some View {
        ZStack {
            ThemeColors.blueBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                SceneHeader(currentScene: _currentScene, allLevels: allLevels, username: username, configuration: headerConfiguration)
                    .zIndex(1)
                content()
            }
        }
    }
}
