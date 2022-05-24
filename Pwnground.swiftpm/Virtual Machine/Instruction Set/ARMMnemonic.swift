//
//  ARMMnemonic.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

enum ARMMnemonic: String, CaseIterable {
    case ADR
    case ADRP
    case ADD
    case ADDS
    case SUB
    case SUBS
    case ADDG
    case SUBG
    case AND
    case EOR
    case ORR
    case ANDS
    case MOVN
    case MOVZ
    case MOVK
    case SBFM
    case BFM
    case UBFM
    case EXTR
    case B
    case SVC
    case HVC
    case SMC
    case BRK
    case HLT
    case DCPS1
    case DCPS2
    case DCPS3
    case WFET
    case WFIT
    case HINT
    case NOP
    case YIELD
    case WFE
    case WFI
    case SEV
    case SEVL
    case DGH
    case XPACD, XPACI, XPACLRI
    case PACIA, PACIA1716, PACIASP, PACIAZ, PACIZA
    case PACIB, PACIB1716, PACIBSP, PACIBZ, PACIZB
    case AUTIA, AUTIA1716, AUTIASP, AUTIAZ, AUTIZA
    case AUTIB, AUTIB1716, AUTIBSP, AUTIBZ, AUTIZB
    case ESB
    case PSB_CSYNC = "PSB CSYNC"
    case TSB_CSYNC = "TSB CSYNC"
    case CSDB
    case BTI
    case CLREX
    case DMB
    case ISB
    case SB
    case DSB
    case SSBB
    case PSSBB
    case MSR
    case CFINV
    case XAFLAG
    case AXFLAG
    case SYS
    case SYSL
    case MRS
    case BR
    case BRAA, BRAAZ, BRAB, BRABZ
    case BLRAA, BLRAAZ, BLRAB, BLRABZ
    case BLR
    case RET
    case RETAA, RETAB
    case ERET
    case ERETAA, ERETAB
    case DRPS
    case BL
    case CBZ
    case CBNZ
    case TBZ
    case TBNZ
    case STG
    case STZGM
    case STZG
    case LDG
    case STGM
    case STZ2G
    case ST2G
    case LDGM
    case STXRB
    case STLXRB
    case CASP, CASPA, CASPAL, CASPL
    case LDXRB
    case LDAXRB
    case STLLRB
    case STLRB
    case CASB, CASAB, CASALB, CASLB
    case LDLARB
    case LDARB
    case STXRH
    case STLXRH
    case LDXRH
    case LDAXRH
    case STLLRH
    case STLRH
    case CASH, CASAH, CASALH, CASLH
    case LDLARH
    case LDARH
    case STXR
    case STLXR
    case STXP
    case STLXP
    case LDXR
    case LDAXR
    case LDXP
    case LDAXP
    case STLLR
    case STLR
    case CAS, CASA, CASAL, CASL
    case LDLAR
    case LDAR
    case STLURB
    case LDAPURB
    case LDAPURSB
    case STLURH
    case LDAPURH
    case LDAPURSH
    case STLUR
    case LDAPUR
    case LDAPURSW
    case LDR
    case LDRSW
    case PRFM
    case STNP
    case LDNP
    case STP
    case LDP
    case STGP
    case LDPSW
    case STURB
    case LDURB
    case LDURSB
    case STUR
    case LDUR
    case STURH
    case LDURH
    case LDURSH
    case LDURSW
    case PRFUM
    case STRB
    case LDRB
    case LDRSB
    case STR
    case STRH
    case LDRH
    case LDRSH
    case STTRB
    case LDTRB
    case LDTRSB
    case STTRH
    case LDTRH
    case LDTRSH
    case STTR
    case LDTR
    case LDTRSW
    case LDADDB, LDADDAB, LDADDALB, LDADDLB
    case LDCLRB, LDCLRAB, LDCLRALB, LDCLRLB
    case LDEORB, LDEORAB, LDEORALB, LDEORLB
    case LDSETB, LDSETAB, LDSETALB, LDSETLB
    case LDSMAXB, LDSMAXAB, LDSMAXALB, LDSMAXLB
    case LDSMINB, LDSMINAB, LDSMINALB, LDSMINLB
    case LDUMAXB, LDUMAXAB, LDUMAXALB, LDUMAXLB
    case LDUMINB, LDUMINAB, LDUMINALB, LDUMINLB
    case SWPB, SWPAB, SWPALB, SWPLB
    case LDAPRB
    case LDADDH, LDADDAH, LDADDALH, LDADDLH
    case LDCLRH, LDCLRAH, LDCLRALH, LDCLRLH
    case LDEORH, LDEORAH, LDEORALH, LDEORLH
    case LDSETH, LDSETAH, LDSETALH, LDSETLH
    case LDSMAXH, LDSMAXAH, LDSMAXALH, LDSMAXLH
    case LDSMINH, LDSMINAH, LDSMINALH, LDSMINLH
    case LDUMAXH, LDUMAXAH, LDUMAXALH, LDUMAXLH
    case LDUMINH, LDUMINAH, LDUMINALH, LDUMINLH
    case SWPH, SWPAH, SWPALH, SWPLH
    case LDADD, LDADDA, LDADDAL, LDADDL
    case LDCLR, LDCLRA, LDCLRAL, LDCLRL
    case LDEOR, LDEORA, LDEORAL, LDEORL
    case LDSET, LDSETA, LDSETAL, LDSETL
    case LDSMAX, LDSMAXA, LDSMAXAL, LDSMAXL
    case LDSMIN, LDSMINA, LDSMINAL, LDSMINL
    case LDUMAX, LDUMAXA, LDUMAXAL, LDUMAXL
    case LDUMIN, LDUMINA, LDUMINAL, LDUMINL
    case SWP, SWPA, SWPAL, SWPL
    case LDAPR
    case ST64BV0
    case ST64BV
    case ST64B
    case LD64B
    case LDRAA, LDRAB
    case UDIV
    case SDIV
    case LSLV
    case LSRV
    case ASRV
    case RORV
    case CRC32B, CRC32H, CRC32W, CRC32X
    case CRC32CB, CRC32CH, CRC32CW, CRC32CX
    case SUBP
    case IRG
    case GMI
    case PACGA
    case SUBPS
    case RBIT
    case REV16
    case REV
    case CLZ
    case CLS
    case REV32
    case PACDA, PACDZA
    case PACDB, PACDZB
    case AUTDA, AUTDZA
    case AUTDB, AUTDZB
    case ADC
    case ADCS
    case SBC
    case SBCS
    case RMIF
    case SETF8, SETF16
    case CCMN
    case CCMP
    case CSEL
    case CSINC
    case CSINV
    case CSNEG
    case MADD
    case MSUB
    case SMADDL
    case SMSUBL
    case SMULH
    case UMADDL
    case UMSUBL
    case UMULH
    case BIC
    case ORN
    case EON
    case BICS
    case MOV
    case CMP
    case TST
    case BFC
    case BFI
    case BFXIL
    case ASR
    case SBFIZ
    case SBFX
    case SXTB
    case SXTH
    case SXTW
    case LSL
    case LSR
    case UBFIZ
    case UBFX
    case UXTB
    case UXTH
    case ROR
    case CFP
    case CPP
    case DVP
    case AT
    case DC
    case IC
    case TLBI
    case STADDB, STADDLB
    case STCLRB, STCLRLB
    case STEORB, STEORLB
    case STSETB, STSETLB
    case STSMAXB, STSMAXLB
    case SSTSMINB, STSMINLB
    case STUMAXB, STUMAXLB
    case STUMINB, STUMINLB
    case STADDH, STADDLH
    case STCLRH, STCLRLH
    case STEORH, STEORLH
    case STSETH, STSETLH
    case STSMAXH, STSMAXLH
    case SSTSMINH, STSMINLH
    case STUMAXH, STUMAXLH
    case STUMINH, STUMINLH
    case STADD, STADDL
    case STCLR, STCLRL
    case STEOR, STEORL
    case STSET, STSETL
    case STSMAX, STSMAXL
    case SSTSMIN, STSMINL
    case STUMAX, STUMAXL
    case STUMIN, STUMINL
    case NGC
    case NGCS
    case CINC
    case CSET
    case CINV
    case CSETM
    case CNEG
    case MUL
    case MNEG
    case SMULL
    case SMNEGL
    case UMULL
    case UMNEGL
    case MVN
    case CMN
    case NEG
    case NEGS
}


extension ARMMnemonic {
    enum Shift: String, CaseIterable, Codable {
        case LSL
        case LSR
        case ASR
        case ROR
        
        init?(value: Int) {
            guard let shift = Self.allCases.first(where: { $0.value == value }) else { return nil }
            self = shift
        }
        
        var value: Int {
            switch self {
            case .LSL: return 0b00
            case .LSR: return 0b01
            case .ASR: return 0b10
            case .ROR: return 0b11
            }
        }
    }
    
    enum Extension: String, CaseIterable {
        case UXTB
        case UXTH
        case UXTW
        case UXTX
        case SXTB
        case SXTH
        case SXTW
        case SXTX
        case LSL
        
        init?(value: Int, mode: CPUMode) {
            guard let shift = Self.allCases.first(where: { $0.getValue(for: mode) == value }) else { return nil }
            self = shift
        }
        
        func getValue(for mode: CPUMode) -> Int {
            switch self {
            case .UXTB: return 0b000
            case .UXTH: return 0b001
            case .UXTW: return 0b010
            case .UXTX: return 0b011
            case .SXTB: return 0b100
            case .SXTH: return 0b101
            case .SXTW: return 0b110
            case .SXTX: return 0b111
            case .LSL: return mode == .x64 ? 0b011 : 0b010
            }
        }
    }
    
    enum IndirectionTarget: String, CaseIterable {
        case None = ""
        case C = "c"
        case J = "j"
        case Both = "jc"
        
        init?(value: Int) {
            guard let target = Self.allCases.first(where: { $0.value == value}) else { return nil }
            self = target
        }
        
        var value: Int {
            switch self {
            case .None: return 0b00
            case .C: return 0b01
            case .J: return 0b10
            case .Both: return 0b11
            }
        }
    }
    
    enum PSTATE: String, CaseIterable {
        case SSBS
        case SPSel
        case DAIFSet
        case DAIFClr
        case PAN
        case UAO
        case DIT
        case TCO
    }
    
    enum PredictionRestriction: String {
        case RCTX
    }
}

extension ARMMnemonic {
    static let defaultSeparator = ""
    
    enum Suffix: String {
        case S
        case G
        case B
        case N
        case Z
        case K
        
        case EQ
        case NE
        case HS
        case LO
        case MI
        case PL
        case VS
        case VC
        case HI
        case LS
        case GE
        case LT
        case GT
        case LE
        case AL
        case NV
    }
    
    enum Condition: Int, CaseIterable {
        case EQ = 0b0000
        case NE = 0b0001
        case CS = 0b0010
        case CC = 0b0011
        case MI = 0b0100
        case PL = 0b0101
        case VS = 0b0110
        case VC = 0b0111
        case HI = 0b1000
        case LS = 0b1001
        case GE = 0b1010
        case LT = 0b1011
        case GT = 0b1100
        case LE = 0b1101
        case AL = 0b1110
        case NV = 0b1111
        
        var suffix: Suffix? {
            switch self {
            case .EQ: return .EQ
            case .NE: return .NE
            case .CS: return .HS
            case .CC: return .LO
            case .MI: return .MI
            case .PL: return .PL
            case .VS: return .VS
            case .VC: return .VC
            case .HI: return .HI
            case .LS: return .LS
            case .GE: return .GE
            case .LT: return .LT
            case .GT: return .GT
            case .LE: return .LE
            case .NV: return .NV
            case .AL: return nil
            }
        }
        
        var inverted: Condition? {
            let invertedValue = (rawValue & ~0b1) | (~rawValue & 0b1)
            let condition = Condition(rawValue: invertedValue)
            switch condition {
            case .AL, .NV: return nil
            default: return condition
            }
        }
    }
    
    var suffixSeparator: String {
        switch self {
        case .B: return "."
        default: return Self.defaultSeparator
        }
    }
}

extension ARMMnemonic {
    enum SysOp {
        case AT
        case DC
        case IC
        case TLBI
        
        init?(op1: UInt8?, crn: UInt8?, crm: UInt8?, op2: UInt8?) {
            guard
                let op1 = op1,
                let crn = crn,
                let crm = crm,
                let op2 = op2
            else { return nil }
            switch (op1, crn, crm, op2) {
            // Sys_AT
            case (0b000, 0b0111, 0b1000, 0b000): self = .AT
            case (0b100, 0b0111, 0b1000, 0b000): self = .AT
            case (0b110, 0b0111, 0b1000, 0b000): self = .AT
            case (0b000, 0b0111, 0b1000, 0b001): self = .AT
            case (0b100, 0b0111, 0b1000, 0b001): self = .AT
            case (0b110, 0b0111, 0b1000, 0b001): self = .AT
            case (0b000, 0b0111, 0b1000, 0b010): self = .AT
            case (0b000, 0b0111, 0b1000, 0b011): self = .AT
            case (0b100, 0b0111, 0b1000, 0b100): self = .AT
            case (0b100, 0b0111, 0b1000, 0b101): self = .AT
            case (0b100, 0b0111, 0b1000, 0b110): self = .AT
            case (0b100, 0b0111, 0b1000, 0b111): self = .AT
            //Sys_DC
            case (0b011, 0b0111, 0b0100, 0b001): self = .DC
            case (0b000, 0b0111, 0b0110, 0b001): self = .DC
            case (0b000, 0b0111, 0b0110, 0b010): self = .DC
            case (0b011, 0b0111, 0b1010, 0b001): self = .DC
            case (0b000, 0b0111, 0b1010, 0b010): self = .DC
            case (0b011, 0b0111, 0b1011, 0b001): self = .DC
            case (0b011, 0b0111, 0b1110, 0b001): self = .DC
            case (0b000, 0b0111, 0b1110, 0b010): self = .DC
            case (0b011, 0b0111, 0b1101, 0b001): self = .DC
            //Sys_IC
            case (0b000, 0b0111, 0b0001, 0b000): self = .IC
            case (0b000, 0b0111, 0b0101, 0b000): self = .IC
            case (0b011, 0b0111, 0b0101, 0b001): self = .IC
            // Sys_TLBI
            case (0b100, 0b1000, 0b0000, 0b001): self = .TLBI
            case (0b100, 0b1000, 0b0000, 0b101): self = .TLBI
            case (0b000, 0b1000, 0b0011, 0b000): self = .TLBI
            case (0b100, 0b1000, 0b0011, 0b000): self = .TLBI
            case (0b110, 0b1000, 0b0011, 0b000): self = .TLBI
            case (0b000, 0b1000, 0b0011, 0b001): self = .TLBI
            case (0b100, 0b1000, 0b0011, 0b001): self = .TLBI
            case (0b110, 0b1000, 0b0011, 0b001): self = .TLBI
            case (0b000, 0b1000, 0b0011, 0b010): self = .TLBI
            case (0b000, 0b1000, 0b0011, 0b011): self = .TLBI
            case (0b100, 0b1000, 0b0011, 0b100): self = .TLBI
            case (0b000, 0b1000, 0b0011, 0b101): self = .TLBI
            case (0b100, 0b1000, 0b0011, 0b101): self = .TLBI
            case (0b110, 0b1000, 0b0011, 0b101): self = .TLBI
            case (0b100, 0b1000, 0b0011, 0b110): self = .TLBI
            case (0b000, 0b1000, 0b0011, 0b111): self = .TLBI
            case (0b100, 0b1000, 0b0100, 0b001): self = .TLBI
            case (0b100, 0b1000, 0b0100, 0b101): self = .TLBI
            case (0b000, 0b1000, 0b0111, 0b000): self = .TLBI
            case (0b100, 0b1000, 0b0111, 0b000): self = .TLBI
            case (0b110, 0b1000, 0b0111, 0b000): self = .TLBI
            case (0b000, 0b1000, 0b0111, 0b001): self = .TLBI
            case (0b100, 0b1000, 0b0111, 0b001): self = .TLBI
            case (0b110, 0b1000, 0b0111, 0b001): self = .TLBI
            case (0b000, 0b1000, 0b0111, 0b010): self = .TLBI
            case (0b000, 0b1000, 0b0111, 0b011): self = .TLBI
            case (0b100, 0b1000, 0b0111, 0b100): self = .TLBI
            case (0b000, 0b1000, 0b0111, 0b101): self = .TLBI
            case (0b100, 0b1000, 0b0111, 0b101): self = .TLBI
            case (0b110, 0b1000, 0b0111, 0b101): self = .TLBI
            case (0b100, 0b1000, 0b0111, 0b110): self = .TLBI
            case (0b000, 0b1000, 0b0111, 0b111): self = .TLBI
            default: return nil
            }
        }
    }
    
    enum ATInstruction: String {
        case S1E1R
        case S1E1W
        case S1E0R
        case S1E0W
        case S1E2R
        case S1E2W
        case S12E1R
        case S12E1W
        case S12E0R
        case S12E0W
        case S1E3R
        case S1E3W
        case S1E1RP
        case S1E1WP
        
        init?(op1: UInt8?, crm: UInt8?, op2: UInt8?) {
            switch (op1, crm, op2) {
            case (0b000, 0b0, 0b000): self = .S1E1R
            case (0b000, 0b0, 0b001): self = .S1E1W
            case (0b000, 0b0, 0b010): self = .S1E0R
            case (0b000, 0b0, 0b011): self = .S1E0W
            case (0b100, 0b0, 0b000): self = .S1E2R
            case (0b100, 0b0, 0b001): self = .S1E2W
            case (0b100, 0b0, 0b100): self = .S12E1R
            case (0b100, 0b0, 0b101): self = .S12E1W
            case (0b100, 0b0, 0b110): self = .S12E0R
            case (0b100, 0b0, 0b111): self = .S12E0W
            case (0b110, 0b0, 0b000): self = .S1E3R
            case (0b110, 0b0, 0b001): self = .S1E3W
            case (0b000, 0b1, 0b000): self = .S1E1RP
            case (0b000, 0b1, 0b001): self = .S1E1WP
            default: return nil
            }
        }
    }
    
    enum DCInstruction: String {
        case IVAC
        case ISW
        case CSW
        case CISW
        case ZVA
        case CVAC
        case CVAU
        case CIVAC
        case IGVAC
        case IGSW
        case IGDVAC
        case IGDSW
        case CGSW
        case CGDSW
        case CIGSW
        case CIGDSW
        case GVA
        case GZVA
        case CGVAC
        case CGDVAC
        case CGVAP
        case CGDVAP
        case CGVADP
        case CGDVADP
        case CIGVAC
        case CIGDVAC
        case CVAP
        case CVADP
        
        init?(op1: UInt8?, crm: UInt8?, op2: UInt8?) {
            switch (op1, crm, op2) {
            case (0b000, 0b0110, 0b001): self = .IVAC
            case (0b000, 0b0110, 0b010): self = .ISW
            case (0b000, 0b1010, 0b010): self = .CSW
            case (0b000, 0b1110, 0b010): self = .CISW
            case (0b011, 0b0100, 0b001): self = .ZVA
            case (0b011, 0b1010, 0b001): self = .CVAC
            case (0b011, 0b1011, 0b001): self = .CVAU
            case (0b011, 0b1110, 0b001): self = .CIVAC
                
            case (0b000, 0b0110, 0b011): self = .IGVAC
            case (0b000, 0b0110, 0b100): self = .IGSW
            case (0b000, 0b0110, 0b101): self = .IGDVAC
            case (0b000, 0b0110, 0b110): self = .IGDSW
            case (0b000, 0b1010, 0b100): self = .CGSW
            case (0b000, 0b1010, 0b110): self = .CGDSW
            case (0b000, 0b1110, 0b100): self = .CIGSW
            case (0b000, 0b1110, 0b110): self = .CIGDSW
                
            case (0b011, 0b0100, 0b011): self = .GVA
            case (0b011, 0b0100, 0b100): self = .GZVA
            case (0b011, 0b1010, 0b011): self = .CGVAC
            case (0b011, 0b1010, 0b101): self = .CGDVAC
            case (0b011, 0b1100, 0b011): self = .CGVAP
            case (0b011, 0b1100, 0b101): self = .CGDVAP
            case (0b011, 0b1101, 0b011): self = .CGVADP
            case (0b011, 0b1101, 0b101): self = .CGDVADP
            case (0b011, 0b1110, 0b011): self = .CIGVAC
            case (0b011, 0b1110, 0b101): self = .CIGDVAC
            case (0b011, 0b1100, 0b001): self = .CVAP
            case (0b011, 0b1101, 0b001): self = .CVADP
            default: return nil
            }
        }
    }
    
    enum ICInstruction: String {
        case IALLUIS
        case IALLU
        case IVAU
        
        init?(op1: UInt8?, crm: UInt8?, op2: UInt8?) {
            switch (op1, crm, op2) {
            case (0b000, 0b0001, 0b000): self = .IALLUIS
            case (0b000, 0b0101, 0b000): self = .IALLU
            case (0b011, 0b0101, 0b001): self = .IVAU
            default: return nil
            }
        }
    }
    
    enum TLBIInstruction: String {
        case VMALLE1IS
        case VAE1IS
        case ASIDE1IS
        case VAAE1IS
        case VALE1IS
        case VAALE1IS
        case VMALLE1
        case VAE1
        case ASIDE1
        case VAAE1
        case VALE1
        case VAALE1
        case IPAS2E1IS
        case IPAS2LE1IS
        case ALLE2IS
        case VAE2IS
        case ALLE1IS
        case VALE2IS
        case VMALLS12E1IS
        case IPAS2E1
        case IPAS2LE1
        case ALLE2
        case VAE2
        case ALLE1
        case VALE2
        case VMALLS12E1
        case ALLE3IS
        case VAE3IS
        case VALE3IS
        case ALLE3
        case VAE3
        case VALE3
        case VMALLE1OS
        case VAE1OS
        case ASIDE1OS
        case VAAE1OS
        case VALE1OS
        case VAALE1OS
        case ALLE2OS
        case VAE2OS
        case ALLE1OS
        case VALE2OS
        case VMALLS12E1OS
        case IPAS2E1OS
        case IPAS2LE1OS
        case ALLE3OS
        case VAE3OS
        case VALE3OS
        case RVAE1IS
        case RVAAE1IS
        case RVALE1IS
        case RVAALE1IS
        case RVAE1OS
        case RVAAE1OS
        case RVALE1OS
        case RVAALE1OS
        case RVAE1
        case RVAAE1
        case RVALE1
        case RVAALE1
        case RIPAS2E1IS
        case RIPAS2LE1IS
        case RVAE2IS
        case RVALE2IS
        case RIPAS2E1
        case RIPAS2E1OS
        case RIPAS2LE1
        case RIPAS2LE1OS
        case RVAE2OS
        case RVALE2OS
        case RVAE2
        case RVALE2
        case RVAE3IS
        case RVALE3IS
        case RVAE3OS
        case RVALE3OS
        case RVAE3
        case RVALE3
        
        init?(op1: UInt8?, crm: UInt8?, op2: UInt8?) {
            switch (op1, crm, op2) {
            case (0b000, 0b0011, 0b000): self = .VMALLE1IS
            case (0b000, 0b0011, 0b001): self = .VAE1IS
            case (0b000, 0b0011, 0b010): self = .ASIDE1IS
            case (0b000, 0b0011, 0b011): self = .VAAE1IS
            case (0b000, 0b0011, 0b101): self = .VALE1IS
            case (0b000, 0b0011, 0b111): self = .VAALE1IS
            case (0b000, 0b0111, 0b000): self = .VMALLE1
            case (0b000, 0b0111, 0b001): self = .VAE1
            case (0b000, 0b0111, 0b010): self = .ASIDE1
            case (0b000, 0b0111, 0b011): self = .VAAE1
            case (0b000, 0b0111, 0b101): self = .VALE1
            case (0b000, 0b0111, 0b111): self = .VAALE1
            case (0b100, 0b0000, 0b001): self = .IPAS2E1IS
            case (0b100, 0b0000, 0b101): self = .IPAS2LE1IS
            case (0b100, 0b0011, 0b000): self = .ALLE2IS
            case (0b100, 0b0011, 0b001): self = .VAE2IS
            case (0b100, 0b0011, 0b100): self = .ALLE1IS
            case (0b100, 0b0011, 0b101): self = .VALE2IS
            case (0b100, 0b0011, 0b110): self = .VMALLS12E1IS
            case (0b100, 0b0100, 0b001): self = .IPAS2E1
            case (0b100, 0b0100, 0b101): self = .IPAS2LE1
            case (0b100, 0b0111, 0b000): self = .ALLE2
            case (0b100, 0b0111, 0b001): self = .VAE2
            case (0b100, 0b0111, 0b100): self = .ALLE1
            case (0b100, 0b0111, 0b101): self = .VALE2
            case (0b100, 0b0111, 0b110): self = .VMALLS12E1
            case (0b110, 0b0011, 0b000): self = .ALLE3IS
            case (0b110, 0b0011, 0b001): self = .VAE3IS
            case (0b110, 0b0011, 0b101): self = .VALE3IS
            case (0b110, 0b0111, 0b000): self = .ALLE3
            case (0b110, 0b0111, 0b001): self = .VAE3
            case (0b110, 0b0111, 0b101): self = .VALE3
            case (0b000, 0b0001, 0b000): self = .VMALLE1OS
            case (0b000, 0b0001, 0b001): self = .VAE1OS
            case (0b000, 0b0001, 0b010): self = .ASIDE1OS
            case (0b000, 0b0001, 0b011): self = .VAAE1OS
            case (0b000, 0b0001, 0b101): self = .VALE1OS
            case (0b000, 0b0001, 0b111): self = .VAALE1OS
            case (0b100, 0b0001, 0b000): self = .ALLE2OS
            case (0b100, 0b0001, 0b001): self = .VAE2OS
            case (0b100, 0b0001, 0b010): self = .ALLE1OS
            case (0b100, 0b0001, 0b011): self = .VALE2OS
            case (0b100, 0b0001, 0b101): self = .VMALLS12E1OS
            case (0b110, 0b0001, 0b000): self = .IPAS2E1OS
            case (0b110, 0b0001, 0b001): self = .IPAS2LE1OS
            case (0b110, 0b0001, 0b010): self = .ALLE3OS
            case (0b110, 0b0001, 0b011): self = .VAE3OS
            case (0b110, 0b0001, 0b101): self = .VALE3OS
            case (0b000, 0b0010, 0b001): self = .RVAE1IS
            case (0b000, 0b0010, 0b011): self = .RVAAE1IS
            case (0b000, 0b0010, 0b101): self = .RVALE1IS
            case (0b000, 0b0010, 0b111): self = .RVAALE1IS
            case (0b000, 0b0101, 0b001): self = .RVAE1OS
            case (0b000, 0b0101, 0b011): self = .RVAAE1OS
            case (0b000, 0b0101, 0b101): self = .RVALE1OS
            case (0b000, 0b0101, 0b111): self = .RVAALE1OS
            case (0b000, 0b0110, 0b001): self = .RVAE1
            case (0b000, 0b0110, 0b011): self = .RVAAE1
            case (0b000, 0b0110, 0b101): self = .RVALE1
            case (0b000, 0b0110, 0b111): self = .RVAALE1
            case (0b100, 0b0000, 0b010): self = .RIPAS2E1IS
            case (0b100, 0b0000, 0b110): self = .RIPAS2LE1IS
            case (0b100, 0b0010, 0b001): self = .RVAE2IS
            case (0b100, 0b0010, 0b101): self = .RVALE2IS
            case (0b100, 0b0100, 0b010): self = .RIPAS2E1
            case (0b100, 0b0100, 0b011): self = .RIPAS2E1OS
            case (0b100, 0b0100, 0b110): self = .RIPAS2LE1
            case (0b100, 0b0100, 0b111): self = .RIPAS2LE1OS
            case (0b100, 0b0101, 0b001): self = .RVAE2OS
            case (0b100, 0b0101, 0b101): self = .RVALE2OS
            case (0b100, 0b0110, 0b001): self = .RVAE2
            case (0b100, 0b0110, 0b101): self = .RVALE2
            case (0b110, 0b0010, 0b001): self = .RVAE3IS
            case (0b110, 0b0010, 0b101): self = .RVALE3IS
            case (0b110, 0b0101, 0b001): self = .RVAE3OS
            case (0b110, 0b0101, 0b101): self = .RVALE3OS
            case (0b110, 0b0110, 0b001): self = .RVAE3
            case (0b110, 0b0110, 0b101): self = .RVALE3
            default: return nil
            }
        }
    }
}
