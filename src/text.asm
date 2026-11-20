.ifndef TEXT_ASM
.equ TEXT_ASM, 1
.include "../include/defs.inc"

.wram
staging_text:
    .space 8192

.rom

.global setup_text

setup_text:
    shove push, d, e, dp

    ld al, MMIO_PAGE
    mtdp al

    ld al, 0b111
    st al, [PPUCTRL] ; Force blank

    xor a, a
    st a, [BG1ESRC]

    ld a, 4096
    st a, [BG2ESRC]

    ld a, 8192
    ld b, BG1GFXSRC
    st a, [b+]
    xor al, al
    st al, [b]

    ld a, 8192
    ld b, BG2GFXSRC
    st a, [b+]
    xor al, al
    st al, [b]

    ld a, 4
    st a, [BG2HOFS]

    ld al, 0b00010000
    st al, [BG1CTRL]
    st al, [BG2CTRL]

    xor al, al
    st al, [VDMACTRL]

    ld a, font
    ld b, VDMASRC
    st a, [b+]
    ld al, .pageof font
    st al, [b]

    ld a, 8192
    ld b, VDMADST
    st a, [b+]
    xor al, al
    st al, [b]

    ld a, FONT_BYTES
    st a, [VDMALEN]

    st al, [VDMASTART]

    xor al, al
    st al, [PPUCTRL]

    shove pop, d, e, dp
    rts

upload_text:
    shove push, dp

    ld al, MMIO_PAGE
    mtdp al

    ld al, 0b111
    st al, [PPUCTRL] ; Force blank

    ld b, VDMADST
    xor a, a
    st a, [b+]
    st al, [b]

    st al, [VDMACTRL] ; vram

    ld b, VDMASRC
    ld a, staging_text
    st a, [b+]
    ld al, .pageof staging_text
    st al, [b]

    ld a, 8192
    st a, [VDMALEN]

    st al, [VDMASTART]

    xor al, al
    st al, [PPUCTRL]

    shove pop, dp
    rts

; draw_text(string, max_col, x, y, color)
; al:b -> 24-bit pointer to NUL-terminated string
; cl: the maximum amount of characters per row
; [sp + 18]: starting row (y)
; [sp + 16]: starting column (x)
; [sp + 14]: color (0-8). 0-7 are one of the colors in the color.asm color table. 8 is rainbow.
draw_text:
    shove push, d, e, f, g, hi

    cmp cl, 0
    jz .0

    xor d, d ; string char idx
    xor e, e
    xor f, f
    xor g, g ; current char

    ld el, [sp+16] ; x
    mthi el ; use hi as scratch for initial x to avoid stack traffic

    ld fl, [sp+18] ; y

    and cl, 0x3f

    .1:
        ld.l gl, [al:b + d]
        inc d

        cmp gl, '\0'
        jz .0

        cmp gl, '\n'
        jz .2

        cmp gl, '\t'
        jnz .3
        add e, 4
        jmp .4

        .3:
        sub gl, ' ' ; font starts at space
        and g, 0x3ff

        push f
        ld f, [sp+16] ; color, WAS at sp + 14, went to sp + 16 after the push
        cmp f, 8
        jnz .5
        add f, d

        .5:
            and f, 0b111
            lsl f, 10
            or g, f
        pop f

        push f
        push e

        lsr e, 1 ; we use half-columns to pack text tighter so /2 is necessary
        lsl f, 6
        add f, e
        lsl f, 1
 
        pop e
        bt el, 1
        jz .6

        add f, 4096

        .6:
            st.l g, [staging_text + f]

        pop f
        .4:
            inc el
            cmp el, 64
            jgeu .2
            push c
            push a
            mfhi al
            add cl, al
            cmp el, cl
            pop a
            pop c
            jltu .1

        dec d
        ld.l gl, [al:b + d]
        inc d
        cmp gl, ' '
        jnz .7
        .2:
            mfhi el
            inc fl
            .7:
            cmp fl, 32
            jz .0
            jmp .1

    .0:
        shove pop, d, e, f, g, hi
        rts

font:
    .incbin "../assets/font_3x4.bin"
    .equ FONT_BYTES, 768
.endif
