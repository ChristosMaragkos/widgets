.ifndef DEFS_ASM
.equ DEFS_ASM, 1

; ================================
;         Section Macros
; ================================

; Header (executable, initialized, allocatable)
.macro .header
.section "header", "acrx"
.endm

; ROM (executable, initialized, allocatable)
.macro .rom
.section "rom", "acrx"
.endm

; WRAM (uninitialized, allocatable, no bits)
.macro .wram
.section "wram", "aurw"
.endm

; Stack (uninitialized, allocatable, no bits)
.macro .stack
.section "stack", "aurw"
.endm

; SRAM (uninitialized, allocatable, no bits)
.macro .sram
.section "sram", "aurw"
.endm

.equ true, 1
.equ false, 0

; ---- Memory map pages (docs/spec.md) ----
.equ MMIO_PAGE, 0x05
.equ STACK_PAGE, 0x04

; ---- Interrupt vector table (docs/interrupts.md) ----
; Each entry is a 3-byte absolute address (256 vectors starting here).
.equ IVT_BASE, 0x050000
.equ IVT_SIZE, 768

.equ VBLNK_VEC, 0x050000
.equ HBLNK_VEC, 0x050003
.equ DIV0VEC, 0x050006
.equ STOF_VEC, 0x050009
.equ STUF_VEC, 0x05000C
.equ INVOP_VEC, 0x05000F
; Software-interrupt vectors 128-255 live at 0x050180-0x0502FD.
.equ SWI_VEC_BASE, 0x050180
; Fault-type interrupts stash pre-instruction state here, not on the stack.
.equ FAULT_FLAGS, 0x050300
.equ FAULT_PP, 0x050302
.equ FAULT_PC, 0x050303

; ---- Joypads (docs/input.md) ----
.equ JOYPAD1, 0x050400
.equ JOYPAD2, 0x050402
.equ JOYPAD3, 0x050404
.equ JOYPAD4, 0x050406

.equ BTN_UP, 1
.equ BTN_DOWN, 2
.equ BTN_LEFT, 4
.equ BTN_RIGHT, 8
.equ BTN_START, 16
.equ BTN_OPTION, 32
.equ BTN_A, 64
.equ BTN_B, 128
.equ BTN_X, 256
.equ BTN_Y, 512
.equ BTN_L, 1024
.equ BTN_R, 2048
.equ JOYPAD_CONNECTED, 0x8000

; ---- PPU general state (docs/graphics.md) ----
.equ PPUSTATUS, 0x050500
.equ CRNTLN, 0x050501
.equ PPUCTRL, 0x050502
.equ BACKDROP, 0x050503

; ---- Background layer scroll (docs/graphics.md) ----
.equ BG1HOFS, 0x050504
.equ BG1VOFS, 0x050506
.equ BG2HOFS, 0x050508
.equ BG2VOFS, 0x05050A
.equ BG3HOFS, 0x05050C
.equ BG3VOFS, 0x05050E
.equ BG4HOFS, 0x050510
.equ BG4VOFS, 0x050512

; ---- Background layer entry (tilemap) sources ----
.equ BG1ESRC, 0x050514
.equ BG2ESRC, 0x050517
.equ BG3ESRC, 0x05051A
.equ BG4ESRC, 0x05051D

; ---- Background layer graphics (tile) sources ----
.equ BG1GFXSRC, 0x050520
.equ BG2GFXSRC, 0x050523
.equ BG3GFXSRC, 0x050526
.equ BG4GFXSRC, 0x050529

; ---- Background layer control ----
.equ BG1CTRL, 0x05052C
.equ BG2CTRL, 0x05052D
.equ BG3CTRL, 0x05052E
.equ BG4CTRL, 0x05052F

; ---- OAM (docs/graphics.md) ----
.equ OAMGFXSRC, 0x050530
.equ OAMCTRL, 0x050533

; ---- Video memory port (docs/graphics.md) ----
.equ VMPCTRL, 0x050534
.equ VMADDR, 0x050535
.equ VMDATAL, 0x050538
.equ VMDATAH, 0x050539

; ---- Video memory DMA (docs/dma.md) ----
.equ VDMACTRL, 0x05053A
.equ VDMASRC, 0x05053B
.equ VDMADST, 0x05053E
.equ VDMALEN, 0x050541
.equ VDMASTAT, 0x050543
.equ VDMASTART, 0x050544

; ---- System memory DMA, ROM/SRAM -> WRAM (docs/dma.md) ----
.equ SDMACTL, 0x050600
.equ SDMASRC, 0x050601
.equ SDMADST, 0x050604
.equ SDMALEN, 0x050607
.equ SDMASTAT, 0x050609
.equ SDMASTART, 0x05060A

; ---- Audio DMA, main bus -> ARAM (docs/dma.md) ----
.equ ADMACTL, 0x050700
.equ ADMASRC, 0x050701
.equ ADMADST, 0x050704
.equ ADMALEN, 0x050706
.equ ADMASTAT, 0x050708
.equ ADMASTART, 0x050709

; ---- APU global controls (docs/audio.md) ----
.equ APUCTRL, 0x05070A
.equ MASVOL, 0x05070B
.equ MASVOR, 0x05070C

; ---- Pulse channel ----
.equ PULCTRL, 0x05070D
.equ PULPITCH, 0x05070E
.equ PULVOL, 0x050710
.equ PULVOR, 0x050711
.equ PULADSR, 0x050712

; ---- Saw channel ----
.equ SAWCTRL, 0x050714
.equ SAWPITCH, 0x050715
.equ SAWVOL, 0x050717
.equ SAWVOR, 0x050718
.equ SAWADSR, 0x050719

; ---- Triangle channel ----
.equ TRICTRL, 0x05071B
.equ TRIPITCH, 0x05071C
.equ TRIVOL, 0x05071E
.equ TRIVOR, 0x05071F
.equ TRIADSR, 0x050720

; ---- Noise channel ----
.equ NOICTRL, 0x050722
.equ NOIRATE, 0x050723
.equ NOIVOL, 0x050725
.equ NOIVOR, 0x050726
.equ NOIADSR, 0x050727

; ---- Wavetable channels ----
.equ WT1CTRL, 0x050729
.equ WT1PITCH, 0x05072A
.equ WT1VOL, 0x05072C
.equ WT1VOR, 0x05072D
.equ WT1ADSR, 0x05072E
.equ WT1IDX, 0x050730
.equ WT1END, 0x050731
.equ WT1MARK, 0x050732

.equ WT2CTRL, 0x050733
.equ WT2PITCH, 0x050734
.equ WT2VOL, 0x050736
.equ WT2VOR, 0x050737
.equ WT2ADSR, 0x050738
.equ WT2IDX, 0x050739
.equ WT2END, 0x05073B
.equ WT2MARK, 0x05073C

; TODO: Expansion port MMIO once devices are implemented
.endif
