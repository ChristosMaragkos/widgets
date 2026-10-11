.once
.include "defs.asm"

.equ PALETTE_SIZE, 256

.equ COLOR_WHITE, 0x7FFF
.equ COLOR_RED, 0x001F
.equ COLOR_GREEN, 0x03E0
.equ COLOR_BLUE, 0x7C00
.equ COLOR_YELLOW, 0x03FF
.equ COLOR_ORANGE, 0x021F
.equ COLOR_LIME, 0x03F0
.equ COLOR_BROWN, 0x1132

.equ UI_WHITE, 0
.equ UI_RED, 1
.equ UI_GREEN, 2
.equ UI_BLUE, 3
.equ UI_YELLOW, 4
.equ UI_ORANGE, 5
.equ UI_LIME, 6
.equ UI_BROWN, 7
.equ UI_RAINBOW, 8

setup_color:
    shove push, d, e, flags, dp

    sub sp, 256

    xor b, b
    ld el, 8
    xor c, c
    @pal_loop_outer:
        ld.l a, [colors + b]
        add b, 2
        @pal_loop_inner:
            st a, [sp + c]
            add c, 2
            bt c, 31
            jnz @pal_loop_inner
        djnz el, @pal_loop_outer

    xor a, a
    st a, [sp]

    ld al, MMIO_PAGE
    mtdp al

    ld al, 0b111
    st al, [PPUCTRL]

    ld al, 0b01 ; CRAM
    st al, [VDMACTRL]

    ld b, VDMASRC
    st sp, [b+]
    ld al, STACK_PAGE
    st al, [b]

    ld a, 0
    ld b, VDMADST
    st a, [b+]
    st al, [b+]

    ld a, 256
    st a, [VDMALEN]

    st al, [VDMASTART]

    ; mirror the same 8 colors into palettes 8-15 (CRAM 256-511):
    ; OAM sprites index the upper half, BG layers the lower half
    ld a, 256
    ld b, VDMADST
    st a, [b+]
    st al, [b]

    st al, [VDMASTART]

    xor al, al
    st al, [PPUCTRL]

    add sp, 256
    shove pop, d, e, flags, dp
    rts

colors:
    .dw COLOR_WHITE
    .dw COLOR_RED
    .dw COLOR_GREEN
    .dw COLOR_BLUE
    .dw COLOR_YELLOW
    .dw COLOR_ORANGE
    .dw COLOR_LIME
    .dw COLOR_BROWN
