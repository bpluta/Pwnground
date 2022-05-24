//
//  SceneHeader.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI
import Combine

class SceneHeaderConfiguration: ObservableObject {
    @Published fileprivate var isLevelListPresented = false
    @Published fileprivate var isHintListPresented = false
    
    fileprivate var helpEventSubject = PassthroughSubject<Void,Never>()
    var helpEventPublisher: AnyPublisher<Void,Never> { helpEventSubject.eraseToAnyPublisher() }
    
    fileprivate var solutionEventSubject = PassthroughSubject<Void,Never>()
    var solutionEventPublisher: AnyPublisher<Void,Never> { solutionEventSubject.eraseToAnyPublisher() }
}

struct SceneHeader: View {
    @Binding var currentScene: PwngroundScene.Scene
    var allLevels: [PwngroundLevel]
    let username: String
    
    @ObservedObject var configuration: SceneHeaderConfiguration

    var body: some View {
        HStack {
            HStack {
                LevelListButton()
                UserComponent()
                    .padding(.horizontal, 10)
                Spacer()
            }.frame(maxWidth: .infinity)
            SceneTitle()
            HStack {
                Spacer()
                HintButton()
                HelpButton()
            }.frame(maxWidth: .infinity)
        }.padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            ThemeColors.blueFocusedBackground
                .ignoresSafeArea()
                .shadow(color: ThemeColors.darkBlueBackground, radius: 3, x: 0, y: 3)
        )
    }
    
    @ViewBuilder
    private func SceneTitle() -> some View {
        VStack(alignment: .center, spacing: 5) {
            Text(currentScene.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ThemeColors.white)
            Text(currentScene.taskDescription)
                .multilineTextAlignment(.center)
                .font(.system(size: 14))
                .foregroundColor(ThemeColors.lighterBlue)
        }
    }
    
    @ViewBuilder
    private func LevelListButton() -> some View {
        ImageButton(systemName: "list.dash", action: showLevelList)
            .popover(isPresented: $configuration.isLevelListPresented, content: { LevelList() })
    }
    
    @ViewBuilder
    private func HintButton() -> some View {
        ImageButton(systemName: "lightbulb", action: showSolutionHintList)
            .popover(isPresented: $configuration.isHintListPresented, content: { SolutionHintList() })
    }
    
    @ViewBuilder
    private func HelpButton() -> some View {
        ImageButton(systemName: "questionmark.circle", action: help)
    }
    
    @ViewBuilder
    private func ImageButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ImageIcon(systemName: systemName)
        }.buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: true)
    }
    
    @ViewBuilder
    private func ImageIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .resizable()
            .scaledToFit()
            .font(Font.body.weight(.semibold))
            .foregroundColor(ThemeColors.white)
            .frame(width: 20, height: 20)
            .padding(10)
            .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private func SolutionHintList() -> some View {
        VStack(spacing: 20) {
            HintsHeader()
            HintsContent()
            Divider()
            HintsFooter()
        }.padding(20)
        .frame(width: 300)
    }
    
    @ViewBuilder
    private func HintsHeader() -> some View {
        Text("Hints")
            .foregroundColor(Color.black)
            .font(.system(size: 20, weight: .bold))
    }
    
    @ViewBuilder
    private func HintsFooter() -> some View {
        VStack(spacing: 7) {
            Text("Got stuck?")
                .foregroundColor(Color.black)
                .font(.system(size: 14))
            Button(action: solve) {
                Text("Show solution")
            }
        }
    }
    
    @ViewBuilder
    private func HintsContent() -> some View {
        VStack(spacing: 10) {
            ForEach(currentScene.hints, id: \.self) { hint in
                HintCell(hint: hint)
            }
        }
    }
    
    @ViewBuilder
    private func HintCell(hint: String) -> some View {
        HStack(alignment: .center) {
            Image(systemName: "lightbulb")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundColor(Color.yellow)
            Text(hint)
                .font(.system(size: 14))
                .foregroundColor(ThemeColors.darkGray)
                .frame(maxWidth: .infinity, alignment: .leading)
        }.fixedSize(horizontal: false, vertical: true)
    }
    
    @ViewBuilder
    private func LevelList() -> some View {
        VStack {
            ForEach(PwngroundScene.Scene.allCases, id: \.rawValue) { scene in
                Button(action: { select(scene: scene) }) {
                    LevelListCell(level: level(for: scene))
                }.buttonStyle(.plain)
            }
        }.padding(10)
        .frame(maxWidth: 300)
    }
    
    @ViewBuilder
    private func LevelListCell(level: PwngroundLevel?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(level?.scene.title ?? "-")
                .font(.system(size: 16, weight: .medium))
            CompletionLabel(completed: level?.hasBeenCompleted ?? false)
        }.padding(.horizontal, 15)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (currentScene == level?.scene ? ThemeColors.lightGray : Color.clear)
                .cornerRadius(10)
        )
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private func CompletionLabel(completed: Bool) -> some View {
        HStack {
            Image(systemName: completed ? "checkmark" : "xmark")
                .resizable()
                .scaledToFit()
                .font(Font.body.bold())
                .foregroundColor(completed ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            Text(completed ? "Completed" : "Not completed")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(ThemeColors.darkGray)
        }
    }
    
    @ViewBuilder
    private func UserComponent() -> some View {
        HStack {
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
            VStack(alignment: .leading) {
                Text("User")
                    .font(.system(size: 12))
                Text(username)
                    .font(.system(size: 15, weight: .semibold))
            }
        }.foregroundColor(ThemeColors.lightGray)
        
    }
}

// MARK: - Helpers
extension SceneHeader {
    private func level(for scene: PwngroundScene.Scene) -> PwngroundLevel? {
        allLevels.first(where: { $0.scene == scene })
    }
    
    private func select(scene: PwngroundScene.Scene) {
        hideLevelList()
        currentScene = scene
    }
    
    private func help() {
        configuration.helpEventSubject.send(())
    }
    
    private func solve() {
        hideSolutionHintList()
        configuration.solutionEventSubject.send(())
    }
    
    private func showLevelList() {
        configuration.isLevelListPresented = true
    }
    
    private func hideLevelList() {
        configuration.isLevelListPresented = false
    }
    
    private func showSolutionHintList() {
        configuration.isHintListPresented = true
    }
    
    private func hideSolutionHintList() {
        configuration.isHintListPresented = false
    }
}
