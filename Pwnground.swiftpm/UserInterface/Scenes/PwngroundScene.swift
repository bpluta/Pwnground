//
//  PwngroundScene.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import SwiftUI
import Combine

struct PwngroundScene: View {
    class ViewModel: ObservableObject {
        @Published var isHelpSheetPresented = false
        @Published var isSuccessMessagePresented = false
        @Published var currentLevel: Scene = .bufferOverflow
        
        var headerConfiguration = SceneHeaderConfiguration()
        
        var isConfigured = false
        var cancelBag = CancelBag()
    }
    
    @ObservedObject var levelContainer: LevelStateContainer
    @StateObject var viewModel = ViewModel()
    
    var body: some View {
        LevelScene(currentScene: $viewModel.currentLevel, allLevels: levelModels, username: levelContainer.user.name, headerConfiguration: viewModel.headerConfiguration) {
            ZStack {
                SceneContent()
                    .transition(.opacity)
                Overlay()
                SuccessMessage()
                    .zIndex(1)
                    .transition(.opacity)
                Sheet()
                    .zIndex(1)
                    .transition(.move(edge: .bottom))
            }
        }.onAppear(perform: setupView)
        .navigationBarHidden(true)
    }
    
    @ViewBuilder
    private func SceneContent() -> some View {
        switch viewModel.currentLevel {
        case .bufferOverflow:
            BufferOverflowLevelScene(model: levelContainer.bufferOverflowLevelModel)
        case .findingPadding:
            PaddingFindingLevelScene(model: levelContainer.paddingFindingLevelModel)
        case .buildingPath:
            ShellpathAssemblingLevelScene(model: levelContainer.shellpathAssemblingLevelModel)
        case .buildingShellcode:
            ShellcodeBuildingLevelScene(model: levelContainer.shellcodeBuildingLevelModel)
        case .finalExploitation:
            ExploitingLevelScene(model: levelContainer.exploitingLevelModel)
        }
    }
    
    @ViewBuilder
    private func Overlay() -> some View {
        if viewModel.isHelpSheetPresented || viewModel.isSuccessMessagePresented {
            VisualEffectView(effect: UIBlurEffect(style: .dark), animation: .easeIn(duration: 0.5))
                .ignoresSafeArea()
        }
    }
    
    @ViewBuilder
    private func Sheet() -> some View {
        if viewModel.isHelpSheetPresented {
            HelpSheet(isPresented: $viewModel.isHelpSheetPresented, currentScene: viewModel.currentLevel)
        }
    }
    
    @ViewBuilder
    private func SuccessMessage() -> some View {
        if viewModel.isSuccessMessagePresented {
            VStack(alignment: .center, spacing: 15) {
                HStack {
                    Spacer()
                    Button(action: closeSuccessMessage) {
                        Image(systemName: "xmark")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(ThemeColors.middleGray)
                            .frame(width: 15, height: 15)
                    }.buttonStyle(.plain)
                }
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(ThemeColors.green)
                    .frame(width: 80, height: 80)
                Text("Success!")
                    .font(.system(size: 24, weight: .bold))
                Text(viewModel.currentLevel.successMessage)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 14))
                if viewModel.currentLevel != Scene.allCases.last {
                    Button(action: proceedToNextScene) {
                        Text("Next scene")
                    }
                }
            }.padding(30)
            .background(ThemeColors.white.cornerRadius(20))
            .frame(maxWidth: 300, maxHeight: 400)
            .padding(50)
        }
    }
}

// MARK: - Helpers
extension PwngroundScene {
    var levelModels: [PwngroundLevel] {
        levelContainer.models
    }
    
    var currentModel: PwngroundLevel? {
        let currentLevel = viewModel.currentLevel
        let currentModel = levelModels.first(where: { level in
            level.scene == currentLevel
        })
        return currentModel
    }
    
    func getModel(of scene: Scene) -> PwngroundLevel? {
        let currentModel = levelModels.first(where: { level in
            level.scene == scene
        })
        return currentModel
    }
    
    private func setupView() {
        guard !viewModel.isConfigured else { return }
        viewModel.isConfigured = true
        
        viewModel.headerConfiguration.helpEventPublisher
            .sink(receiveValue: help)
            .store(in: viewModel.cancelBag)
        
        viewModel.headerConfiguration.solutionEventPublisher
            .sink(receiveValue: solve)
            .store(in: viewModel.cancelBag)
        
        Publishers.MergeMany(levelModels.map(\.levelPassPublisher))
            .receive(on: DispatchQueue.main)
            .compactMap {
                currentModel
            }.sink { level in
                let currentScenHasBeenAlreadyCompleted = level.hasBeenCompleted
                guard !currentScenHasBeenAlreadyCompleted else { return }
                level.hasBeenCompleted = true
                withAnimation { viewModel.isSuccessMessagePresented = true }
            }.store(in: viewModel.cancelBag)
        
        viewModel.$currentLevel
            .receive(on: DispatchQueue.main)
            .compactMap { currentLevel in
                getModel(of: currentLevel)
            }.filter { level in
                !level.didDisplayHelpSheet
            }.delay(for: 0.5, scheduler: DispatchQueue.main)
            .sink { level in
                withAnimation { viewModel.isHelpSheetPresented = true }
                level.didDisplayHelpSheet = true
            }.store(in: viewModel.cancelBag)
    }
    
    private func help() {
        withAnimation {
            viewModel.isHelpSheetPresented.toggle()
        }
    }
    
    private func solve() {
        currentModel?.solve()
    }
    
    private func closeSuccessMessage() {
        withAnimation { viewModel.isSuccessMessagePresented = false }
    }
    
    private func proceedToNextScene() {
        guard let nextItem = Scene.allCases.firstNext(after: viewModel.currentLevel) else { return }
        closeSuccessMessage()
        withAnimation { viewModel.currentLevel = nextItem }
    }
}

// MARK: - Models
extension PwngroundScene {
    enum Scene: Int, CaseIterable, CustomStringConvertible {
        case bufferOverflow
        case findingPadding
        case buildingPath
        case buildingShellcode
        case finalExploitation
        
        var description: String {
            switch self {
            case .bufferOverflow:
                return "Buffer overflow"
            case .findingPadding:
                return "Padding"
            case .buildingPath:
                return "Assembling shell path"
            case .buildingShellcode:
                return "Building shellcode"
            case .finalExploitation:
                return "Exploitation"
            }
        }
        
        var taskDescription: String {
            switch self {
            case .bufferOverflow:
                return "Enter text so long it causes buffer overflow"
            case .findingPadding:
                return "Redirect execution of the program into your payload"
            case .buildingPath:
                return "Store path to shell \"/bin/sh\" executable into X1 register"
            case .buildingShellcode:
                return "Build a code that launches shell"
            case .finalExploitation:
                return "Drag and drop the exploit and assign yourself to the winners"
            }
        }
        
        var fullTaskDescription: String {
            switch self {
            case .bufferOverflow:
                return "Play with the application. Find out if you won the scholarship. No? Maybe not all is lost yet, try sending very long username and see what happens. Perhaps the application has buffer overflow vulnerability."
            case .findingPadding:
                return "It looks that app allows us to overflow data on the stack. Cool! Now we can override the function return adddress on the stack and redirect execution of the program to our payload.\n\nPad your input with so many characters that will allow you to hit the return address and override it with address poining to the next address cell on the stack."
            case .buildingPath:
                return "Now we are able to execute arbitrary code. Nice! Let's try to make the application to launch system shell with its privlieges. But first we need to put the path to the system shell executable somewhere.\n\nTry assembling \"/bin/sh\" string from ASCII bytes and store it in X1 register"
            case .buildingShellcode:
                return "We have our shell path ready in the X1 register. Great! Now try to write code that will trigger execve syscall with our shell path as argument.\n\nRemember that the execve argument is pointer to the string not the string itself, so you need to store it somewhere into the memory first and pass its address into the syscall as argument"
            case .finalExploitation:
                return "Your exploit is ready to use! Drag and drop it into the input and submit. Having the shell launched with privileges of the application try if you can assign yourself to the winnner group in the system. Use help to find out about available commands.\n\nAfter all exit the shell and check if the application shows if you are among the winners"
            }
        }
        
        var successMessage: AttributedString {
            var string: String
            switch self {
            case .bufferOverflow:
                string = "Phrase \"application has crashed successfully\" usually does not seem to make much sense, but in this case it might mean that the application may have buffer overflow vulnerability. Let's find out if we can do something with it!"
            case .findingPadding:
                string = "Great! You have just made app to execute instructions from memory you can write to! Moving on, let's spawn a shell to access the system!"
            case .buildingPath:
                string = "You're getting closer! You have just assembled string with path to shell executable - now it's time to execute it!"
            case .buildingShellcode:
                string = "You've all set! You have got your exploit ready to use. Let's to this!"
            case .finalExploitation:
                string = "Congratulations! You have just assigned yourself to the group of the winners. Now check what the app tells if you put your name in it (you can return from the shell using `exit` command)"
            }
            let attributedString = try? AttributedString(markdown: string)
            return attributedString ?? ""
        }
        
        var help: [HelpParagaph] {
            switch self {
            case .bufferOverflow:
                return [
                    HelpParagaph(
                        title: "Buffer overflow",
                        paragraph: "Buffer overflow is a kind of anomaly in which user is able to write more bytes into a buffer they supposed to, attempting to override other data in memory beyond allocated bounds of the buffer. For example if some program expects input up to 10 bytes and does not check how many bytes users are trying to put they may be able to put more and overflow data beyond the allocated 10 byte long buffer.\n\nIn some cases this behavior can be exploited to do things that is was not intended to do. There are two main types of buffer overflow attacks - heap and stack based. In this game we will focus on the first one."
                    ),
                    HelpParagaph(
                        title: "What is stack?",
                        paragraph: "Stack is area of memory which stores information about program execution for example command line arguments, environmental variables and is responsible for proper handling of function calls - it stores function local variables as well as addresses of previous function calls (call stack). Stack is responsible for the correct execution flow of called functions so each thread needs to have their own even if threads share other memory with each other.\n\nOne of the most crucial elements regarding to a stack is a stack pointer which stores address of its current topmost element. The proper usage of the stack is to \"push\" and \"pop\" elements on it with last-in, first-out order by incrementing or decrementing the stack pointer and moving elements to a stack pointer related place in memory."
                    ),
                    HelpParagaph(
                        title: "Arbitrary code execution",
                        paragraph: "As you already know, stack is necessary for proper handling of function call flow in an executed program. Therefore, the stack-based buffer overflow may lead to redirection of execution flow and finally can cause arbitrary code execution.\n\nNowadays, modern operating systems have some mechanisms to make it harder to exploit it and in some cases even impossible without other memory leaks or other vulnerabilities but in this game we will focus on the most basic version of stack-based vulnerability."
                    )
                ]
            case .findingPadding:
                return [
                    HelpParagaph(
                        title: "Function calling convention",
                        paragraph: "At low level, there is no such thing as function call. When program needs to execute other code than the one that it has in the next place in memory it uses one of branching instructions and simply \"jumps\" to a place in the memory where the code is. In order to make this procedure stable and deterministic when dealing with code of high level functions and methods there is a special convention to deal with function calls.\n\nOn 64-bit ARM Apple platforms function right after jumping to its code puts both frame pointer and function return address onto a stack and after that it overwrites frame pointer with value from stack pointer. The next step is allocating space for local variables by adding necessary size value to the stack pointer (aligned to 16 bytes) to make dedicated space for them. After that, function body instructions are executed and finally the frame pointer and return address are restored back from the stack, the stack pointer is decremented by the initially incremented size value and function jumps back to the address of the return address."
                    ),
                    HelpParagaph(
                        title: "Redirecting execution flow",
                        paragraph: "The function call convention relies on preserving the return address to the next instruction after function call on the tack. That means if we have stack-based buffer overflow vulnerability we can simply override it with an arbitrary value. Therefore, we can put there an address to a different place in application code or an address to a place in memory where we can insert our arbitrary code like in the overflowed buffer."
                    )
                ]
            case .buildingPath:
                return [
                    HelpParagaph(
                        title: "What is shell?",
                        paragraph: "Shell is a program which provides an human interface layer to interact with operating system through given commands. There are many different shells out there but the most commonly available one on UNIX operating systems is the `/bin/sh` which provides most basic command line interface and is likeliest to be present regardless of system from UNIX family."
                    ),
                    HelpParagaph(
                        title: "What is assembly?",
                        paragraph: "Assembly is a programming language which is closest to the real machine code which is executed by the CPU remaining to be still human readable. It is strictly connected with the CPU architecture and it designed to work closely with hardware operating on a bit level with memory, CPU registers and CPU flags."
                    ),
                    HelpParagaph(
                        title: "What is register?",
                        paragraph: "CPU register is a very small set of data holding places that is an integral part of a processor. It has the fastest available value access time for the CPU but yet it is the smallest available space to store them. Registers are crucial when it comes to machine code execution by a processor. Due to the performance they are used as first-in-line storage for the instructions. For instance, registers keep the value of current instruction pointer which determines from what address next instruction should be fetched and executed, values of current stack pointer, flags, immediate storage for value transfer between two places in memory and many more.\n\nOn ARM64 architecture, the most important 64-bit registers are **SP** (stack pointer), **XZR** (read-only register storing 0 as value) and **X0-X30** general purpose registers for universal usage. On Apple platforms there is additional standard which applies to general purpose registers - **X0** stores returned value, **X16** stores syscall value, **X29** stores preserved frame pointer and **X30** stores preserved return address from an executed function. "
                    )
                ]
            case .buildingShellcode:
                return [
                    HelpParagaph(
                        title: "What is syscall?",
                        paragraph: "Typically, range of capabilities of a program executed in user mode is limited because of system safety. Due to that, program needs to request system to do certain actions on its behalf. System call is a way for program to request a service from an operating system kernel it does not have permissions to do directly.\n\nAfter receiving syscall request from a process, the operating system can it and decide if it should fulfill it depending on privileges of calling process or other factors. In ARM64 a syscall is triggered with `SVC` instruction."
                    ),
                    HelpParagaph(
                        title: "Execve syscall",
                        paragraph: "In the game we need to force the application to execute `/bin/ls` binary and because that is beyond program capabilities we need to request system kernel to do it for us. The syscall we are looking for is execve which asks kernel to execute a binary which path is passed as a first argument to the syscall.\n\nOn ARM64 architecture based Apple platforms the `SVC` instruction ignores its argument and takes seeks for the syscall number in **X16** register and up to 9 its arguments in **X0-X9** registers. On XNU kernel present on Apple platforms the identifier of execve syscall is **0x203b** and it takes pointer to executable path string as a first argument."
                    )
                ]
            case .finalExploitation:
                return [
                    HelpParagaph(
                        title: "What is possible to do with this exploit?",
                        paragraph: "The exploit you have just build let’s you to access operating system shell with privileges of the exploited application. That means if exploited program has admin privileges, the launched shell will have them too. Such privilege escalation allows us to perform actions we could not be allowed to do normally on our account.\n\nFor example with admin privileges we could simply assign ourselves to any group with higher privileges. In the case of our game we could for example assign ourselves to a group of the winners to become one."
                    ),
                    HelpParagaph(
                        title: "Further reads",
                        paragraph: "Well, that’s the end of the game! I hope you enjoyed exploiting the buffer overflow vulnerability and I hope this app helped you to understand how it works and what happens at the level of the operating system and the CPU. If you found this topic interesting and want to learn more about binary exploitation here are some topics for further research to learn more advanced aspects of the field:\n\n• ASLR (Address Space Layout Randomization)\n• NOP slide\n• Stack canaries\n• ROP (Return Oriented Programming)\n• User-after-free\n• Heap overflow\n• Format string vulnerability"
                    )
                ]
            }
        }
        
        var hints: [String] {
            switch self {
            case .bufferOverflow:
                return [
                    "It does not matter what you put into the textfield, it matters how much you put there",
                    "You can always add more letters (much more)",
                    "Copying some text and pasting it few times can be helpful"
                ]
            case .findingPadding:
                return [
                    "Look at memory inspector and see how your input expands in the memory and what values it overwrites",
                    "Address in 64-bit CPU is 8 byte long",
                    "The address needs to point a place in memory that is just behind the payload itself"
                ]
            case .buildingPath:
                return [
                    "Use ASCII table to find out which values correspond to characters you need to build your string",
                    "When you tap on register inespector value you can change the way it will be presented. Changing it to \"String\" will let you see how your shell path looks like",
                    "You can insert up to 2 letters into the register using each immediate-value MOV instruction",
                    "Remember to use value-preserving instructions when you don't want other bits you have just set to be zeroed",
                    "Remember to shift your value to be set in the proper place in the register"
                ]
            case .buildingShellcode:
                return [
                    "The first argument of the \"execve\" syscall must be pointer to the string with shell path, not the string itself",
                    "You need to store your shell path onto a stack first",
                    "Notice that the syscall identifier value is read from the X16 register, not from the SVC instruction argument itself"
                ]
            case .finalExploitation:
                return [
                    "You can preview all the available commands with \"help\" commmand",
                    "Remember to find out what groups are available in the system",
                    "After you assign yourself to the winner group you can exit the shell and return to the app with \"exit\" command"
                ]
            }
        }
        
        var title: String {
            "\(rawValue + 1). \(description)"
        }
    }
}
