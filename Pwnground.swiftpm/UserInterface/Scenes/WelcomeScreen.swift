//
//  WelcomeScreen.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI

struct WelcomeScreen: View {
    @StateObject var viewModel = ViewModel()
    @FocusState var isUsernameInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 40) {
            if viewModel.isUsernameInputDisplayed {
                UserSetup()
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
            } else {
                WelcomeMessage()
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
            }
        }.padding(50)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(ThemeGradient.BackgroundGradient.ignoresSafeArea())
        .onAppear(perform: setupView)
        .navigationBarHidden(true)
    }
    
    @ViewBuilder
    private func WelcomeMessage() -> some View {
        Group {
            Title()
            Description("Pwnground is a game in which you will learn principles of buffer overflow vulberability and ARM64 assembly by building your own exploit")
            Button(action: proceedToUserInput) {
                ProceedButton(action: proceedToUserInput)
            }.buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private func UserSetup() -> some View {
        Group {
            Description("But before you start plase pick an username...")
            UsernameInput(action: proceedToPwnground)
            Group {
                NavigationLink(
                    isActive: $viewModel.navigateToApp,
                    destination: pwngroundScene,
                    label: { EmptyView() }
                )
                ProceedButton(action: proceedToPwnground).disabled(!viewModel.isValid)
            }
        }
    }
    
    private func pwngroundScene() -> some View {
        PwngroundScene(levelContainer: .init(username: viewModel.username))
    }
   
    @ViewBuilder
    private func UsernameInput(action: @escaping () -> Void) -> some View {
        VStack {
            ZStack(alignment: .leading) {
                if viewModel.username.isEmpty {
                    Text("Username")
                        .foregroundColor(ThemeColors.white.opacity(0.5))
                }
                TextField("", text: $viewModel.username)
                    .submitLabel(.return)
                    .onSubmit(action)
                    .disableAutocorrection(true)
                    .focused($isUsernameInputFocused)
                    .autocapitalization(.none)
            }
            .font(.system(size: 24))
            .foregroundColor(ThemeColors.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .overlay(
                Capsule()
                    .stroke(hasValidationMessage ? invalidatedColor : ThemeColors.white, lineWidth: 2)
            )
            if let validationMessage = viewModel.validationMessage {
                Text(validationMessage)
                    .font(.system(size: 18))
                    .foregroundColor(invalidatedColor)
            }
        }.frame(maxWidth: 300, alignment: .center)
    }
    
    @ViewBuilder
    private func Title() -> some View {
        Text("Welcome to Pwngorund!")
            .font(.system(size: 48, weight: .bold))
            .foregroundColor(ThemeColors.white)
    }
    
    @ViewBuilder
    private func Description(_ description: String) -> some View {
        Text(description)
            .multilineTextAlignment(.center)
            .font(.system(size: 24, weight: .semibold))
            .foregroundColor(ThemeColors.white)
            .frame(maxWidth: 500, alignment: .center)
    }
    
    @ViewBuilder
    private func ProceedButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Proceed")
                .font(.system(size: 24))
                .foregroundColor(ThemeColors.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(
                    Capsule()
                        .stroke(ThemeColors.white, lineWidth: 2)
                )
                .contentShape(Capsule())
        }.buttonStyle(.plain)
    }
    
    private var invalidatedColor: Color {
        Color.orange
    }
}

// MARK: - Helpers
extension WelcomeScreen {
    private var hasValidationMessage: Bool {
        !(viewModel.validationMessage?.isEmpty ?? true)
    }
    
    private func setupView() {
        guard !viewModel.isConfigured else { return }
        viewModel.isConfigured = true
        setupInputValidators()
    }
    
    private func setupInputValidators() {
        viewModel.$username
            .sink(receiveValue: validateInput)
            .store(in: viewModel.cancelBag)
    }
    
    private func validateInput(value: String) {
        var isValid = true
        var validationMessage: String?
        
        if value.isEmpty {
            isValid = false
        } else if !value.isLetterOnly {
            isValid = false
            validationMessage = "Username may contain only letters from the English alphabet"
        } else if value.contains(where: \.isUppercase) {
            isValid = false
            validationMessage = "Username should contain only lowercase letters"
        } else if value == SystemUser.admin.name {
            isValid = false
            validationMessage = "This username is already taken"
        }
        
        withAnimation {
            viewModel.isValid = isValid
            viewModel.validationMessage = validationMessage
        }
    }
    
    private func proceedToPwnground() {
        viewModel.navigateToApp = true
    }
    
    private func proceedToUserInput() {
        withAnimation { viewModel.isUsernameInputDisplayed = true }
        isUsernameInputFocused = true
    }
}

// MARK: - Models
extension WelcomeScreen {
    class ViewModel: ObservableObject {
        @Published var username: String = ""
        @Published var isValid = true
        @Published var validationMessage: String?
        @Published var isUsernameInputDisplayed = false
        @Published var navigateToApp = false
        
        var isConfigured = false
        
        var cancelBag = CancelBag()
    }
}
