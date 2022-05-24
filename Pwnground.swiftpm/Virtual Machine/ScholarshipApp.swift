//
//  ScholarshipApp.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation


struct ScholarshipApp {
    let linker = StaticLinker()
    
    private let textSectionBaseAddess: Address = 0x10000000
    
    static let wwdcScholarsGroupId: GID = 2022
    
    static let winnerLabel = "You made it! Your submission was outstanding and we are happy to award you the scholarship. Congratulations!"
    static let tryAgainLabel = "Thank you for applying but unfortunately we are unable to offer you a scholarship this time. Keep trying!"
    static let userNotFoundLabel = "User not found"
    static let enterUsernameLabel = "Enter your username"
    
    static let winnerSymbol = "winner_label"
    static let tryAgainSymbol = "try_again_label"
    static let userNotFoundSymbol = "user_not_found_label"
    static let enterUsernameSymbol = "enter_username_label"
    
    func buildMachOFile() -> MachOFile {
        let stringSectionData = getStringSectionData() ?? Data()
        let codeSectionData = getCodeSectionData() ?? Data()
        var contentData = Data()
        contentData.append(stringSectionData)
        contentData.append(codeSectionData)
        
        let entryPoint = textSectionBaseAddess + UInt64(stringSectionData.count)
        let fileSize = UInt32(contentData.count)
        
        let loadTextSegment = MachOLoadSegmentCommand(
            segname: "__TEXT",
            address: textSectionBaseAddess,
            vmsize: VirtualMemoryPage.pageSize,
            fileSize: fileSize
        )
        let loadMainCommand =  MachOLoadMainCommand(
            entryPoint: entryPoint,
            stackSize: VirtualMemory.defaultStackSize
        )
        let loadCommands: [MachOLoadCommand] = [
            loadMainCommand,
            loadTextSegment
        ]
        updateFileOffset(for: loadTextSegment, allCommands: loadCommands)
        
        let header = MachOHeader(
            cpuSubtype: .arm64_v8,
            fileType: .executable,
            ncmds: UInt32(loadCommands.count),
            flags: [.allowStackExecution]
        )
        let machOFile = MachOFile(header: header, loadCommands: loadCommands, data: contentData)
        return machOFile
    }
    
    private func updateFileOffset(for loadSegmentCommand: MachOLoadSegmentCommand, allCommands: [MachOLoadCommand]) {
        var fileOffset = UInt32(MachOHeader.headerSize)
        for command in allCommands {
            fileOffset += command.cmdsize
        }
        loadSegmentCommand.fileoff = fileOffset
    }
    
    func getStringSectionData() -> Data? {
        let strings: [StaticLinkerStringObject] = [
            StaticLinkerStringObject(
                name: Self.winnerSymbol,
                label: Self.winnerLabel
            ),
            StaticLinkerStringObject(
                name: Self.tryAgainSymbol,
                label: Self.tryAgainLabel
            ),
            StaticLinkerStringObject(
                name: Self.userNotFoundSymbol,
                label: Self.userNotFoundLabel
            ),
            StaticLinkerStringObject(
                name: Self.enterUsernameSymbol,
                label: Self.enterUsernameLabel
            ),
        ]
        let linkedData = linker.link(stringSections: strings)
        return linkedData
    }
    
    func getCodeSectionData() -> Data? {
        typealias GP64 = ARMGeneralPurposeRegister.GP64
        typealias GP32 = ARMGeneralPurposeRegister.GP32
        
        var startFunction = StaticLinkerCodeObject(name: "start")
        var mainFunction = StaticLinkerCodeObject(name: "main")
        var uidBelongsToGidFunction = StaticLinkerCodeObject(name: "uid_belongs_to_gid")
        var getUidForNameFunction = StaticLinkerCodeObject(name: "get_uid_for_name")
        var checkStatusFunction = StaticLinkerCodeObject(name: "check_status")
        var userNotFoundFunction = StaticLinkerCodeObject(name: "user_not_found")
        var tryNextYearFunction = StaticLinkerCodeObject(name: "try_next_year")
        var winnerFunction = StaticLinkerCodeObject(name: "winner")
        
        let mainFrameSize: Int16 = 128
        startFunction.instructionBuilders = [
            // call main()
            .movz(register: GP64.x29, immediate: .literal(value: 0), shift: 0),
            .movz(register: GP64.x30, immediate: .literal(value: 0), shift: 0),
            .bl(address: .resolvable(id: mainFunction.name, resolver: linker.resolveSymbolOffset(for:))),
            
            .bUnconditional(address: .resolvable(id: startFunction.name, resolver: linker.getResolver(offset: 2 * 4))),
            .movImmediate(register: GP64.x0, immediate: .literal(value: 0)),
            .movImmediate(register: GP64.x16, immediate: .literal(value: Syscall.exit.number )),
            .svc(immediate: .literal(value: 1337)),
        ]
        mainFunction.instructionBuilders = [
            
            .stp(register1: GP64.x29, register2: GP64.x30, addressRegister: GP64.sp, index: .literal(value: -mainFrameSize), indexingMode: .pre),
            .movRegister(destination: GP64.x29, source: GP64.sp),
            
            // call read(0, sp + (mainFrameSize - 16), 0)
            .movImmediate(register: GP64.x0, immediate: .literal(value: 0)),
            .subImmediate(destination: GP64.x1, source: GP64.x29, immediate: .literal(value: UInt16(mainFrameSize - 16))),
            .movImmediate(register: GP64.x2, immediate: .literal(value: 0)),
            .movImmediate(register: GP64.x16, immediate: .literal(value: Syscall.read.number )),
            .svc(immediate: .literal(value: 1337)),
            
            // call getUidForNameFunction(sp + (mainFrameSize - 16))
            .subImmediate(destination: GP64.x0, source: GP64.x29, immediate: .literal(value: UInt16(mainFrameSize - 16))),
            .bl(address: .resolvable(id: getUidForNameFunction.name, resolver: linker.resolveSymbolOffset(for:))),
            
            // branch to "user not found" if carry set
            .bConditional(address: .resolvable(id: mainFunction.name, resolver: linker.getResolver(offset: (22-5) * 4)), condition: .CS),
            
            // call check_status(uid)
            .bl(address: .resolvable(id: checkStatusFunction.name, resolver: linker.resolveSymbolOffset(for:))),
            
            // branch to "try next year"  if x0 = 0
            .cmpImmediate(register: GP64.x0, immediate: .literal(value: 0), shift: false),
            .bConditional(address: .resolvable(id: mainFunction.name, resolver: linker.getResolver(offset: (20-5) * 4)), condition: .EQ),
            
            // call winner()
            .bl(address: .resolvable(id: winnerFunction.name, resolver: linker.resolveSymbolOffset(for:))),
            .bUnconditional(address: .literal(value: 16)),
            
            // call try_next_year()
            .bl(address: .resolvable(id: tryNextYearFunction.name, resolver: linker.resolveSymbolOffset(for:))),
            .bUnconditional(address: .literal(value: 8)),
            
            // call user_not_found()
            .bl(address: .resolvable(id: userNotFoundFunction.name, resolver: linker.resolveSymbolOffset(for:))),
            
            .ldp(register1: GP64.x29, register2: GP64.x30, addressRegister: GP64.sp, index: .literal(value: mainFrameSize), indexingMode: .post),
            .ret(register: GP64.x30)
        ]
        
        uidBelongsToGidFunction.instructionBuilders = [
            .stp(register1: GP64.x29, register2: GP64.x30, addressRegister: GP64.sp, index: .literal(value: -16), indexingMode: .pre),
            .movRegister(destination: GP64.x29, source: GP64.sp),
            
            .movImmediate(register: GP64.x16, immediate: .literal(value: Syscall.uidBelongsToGid.number)),
            .svc(immediate: .literal(value: 1337)),
            
            .ldp(register1: GP64.x29, register2: GP64.x30, addressRegister: GP64.sp, index: .literal(value: 16), indexingMode: .post),
            .ret(register: GP64.x30)
        ]
        
        getUidForNameFunction.instructionBuilders = [
            .stp(register1: GP64.x29, register2: GP64.x30, addressRegister: GP64.sp, index: .literal(value: -16), indexingMode: .pre),
            .movRegister(destination: GP64.x29, source: GP64.sp),
            
            .movImmediate(register: GP64.x16, immediate: .literal(value: Syscall.getUidForName.number)),
            .svc(immediate: .literal(value: 1337)),
            
            .ldp(register1: GP64.x29, register2: GP64.x30, addressRegister: GP64.sp, index: .literal(value: 16), indexingMode: .post),
            .ret(register: GP64.x30)
        ]
        
        checkStatusFunction.instructionBuilders = [
            .stp(register1: GP64.x29, register2: GP64.x30, addressRegister: GP64.sp, index: .literal(value: -16), indexingMode: .pre),
            .movRegister(destination: GP64.x29, source: GP64.sp),
            
            .movImmediate(register: GP64.x1, immediate: .literal(value: Self.wwdcScholarsGroupId)),
            .movImmediate(register: GP64.x16, immediate: .literal(value: Syscall.uidBelongsToGid.number)),
            .svc(immediate: .literal(value: 1337)),
            
            .ldp(register1: GP64.x29, register2: GP64.x30, addressRegister: GP64.sp, index: .literal(value: 16), indexingMode: .post),
            .ret(register: GP64.x30)
        ]
        
        userNotFoundFunction.instructionBuilders = [
            .stp(register1: GP64.x29, register2: GP64.x30, addressRegister: GP64.sp, index: .literal(value: -16), indexingMode: .pre),
            .movRegister(destination: GP64.x29, source: GP64.sp),
            
            .movImmediate(register: GP64.x0, immediate: .literal(value: 1)),
            .adr(register: GP64.x1, immediate: .resolvable(id: Self.userNotFoundSymbol, resolver: linker.resolveSymbolOffset(for:))),
            .movImmediate(register: GP64.x2, immediate: .literal(value: 0)),
            .movImmediate(register: GP64.x16, immediate: .literal(value: Syscall.write.number)),
            .svc(immediate: .literal(value: 1337)),
            
            .ldp(register1: GP64.x29, register2: GP64.x30, addressRegister: GP64.sp, index: .literal(value: 16), indexingMode: .post),
            .ret(register: GP64.x30)
        ]
        
        tryNextYearFunction.instructionBuilders = [
            .stp(register1: GP64.x29, register2: GP64.x30, addressRegister: GP64.sp, index: .literal(value: -16), indexingMode: .pre),
            .movRegister(destination: GP64.x29, source: GP64.sp),
            
            .movImmediate(register: GP64.x0, immediate: .literal(value: 1)),
            .adr(register: GP64.x1, immediate: .resolvable(id: Self.tryAgainSymbol, resolver: linker.resolveSymbolOffset(for:))),
            .movImmediate(register: GP64.x2, immediate: .literal(value: 0)),
            .movImmediate(register: GP64.x16, immediate: .literal(value: Syscall.write.number)),
            .svc(immediate: .literal(value: 1337)),
            
            .ldp(register1: GP64.x29, register2: GP64.x30, addressRegister: GP64.sp, index: .literal(value: 16), indexingMode: .post),
            .ret(register: GP64.x30)
        ]
        
        winnerFunction.instructionBuilders = [
            .stp(register1: GP64.x29, register2: GP64.x30, addressRegister: GP64.sp, index: .literal(value: -16), indexingMode: .pre),
            .movRegister(destination: GP64.x29, source: GP64.sp),
            
            .movImmediate(register: GP64.x0, immediate: .literal(value: 1)),
            .adr(register: GP64.x1, immediate: .resolvable(id: Self.winnerSymbol, resolver: linker.resolveSymbolOffset(for:))),
            .movImmediate(register: GP64.x2, immediate: .literal(value: 0)),
            .movImmediate(register: GP64.x16, immediate: .literal(value: Syscall.write.number)),
            .svc(immediate: .literal(value: 1337)),
            
            .ldp(register1: GP64.x29, register2: GP64.x30, addressRegister: GP64.sp, index: .literal(value: 16), indexingMode: .post),
            .ret(register: GP64.x30)
        ]
        
        let linkedData = linker.link(codeSections: [
            startFunction,
            mainFunction,
            uidBelongsToGidFunction,
            getUidForNameFunction,
            checkStatusFunction,
            userNotFoundFunction,
            tryNextYearFunction,
            winnerFunction
        ])
        return linkedData
    }
    
}
