.once
.include "defs.asm"

.wram
staging_text:
    .pad 8192

.rom

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

    ld al, 0b0_00_10_00_0
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
    jz @return

    xor d, d ; string char idx
    xor e, e
    xor f, f
    xor g, g ; current char

    ld el, [sp+16] ; x
    mthi el ; use hi as scratch for initial x to avoid stack traffic

    ld fl, [sp+18] ; y

    and cl, 0x3f

    @loop:
        ld.l gl, [al:b + d]
        inc d
        cmp gl, 0 ; null terminator
        jz @return

        sub gl, 32 ; font starts at space
        and g, 0x3ff

        push f
        ld f, [sp+16] ; color, WAS at sp + 14, went to sp + 16 after the push
        cmp f, 8
        jnz @not_rainbow
        add f, d

        @not_rainbow:
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
        jz @even

        add f, 4096

        @even:
            st.l g, [staging_text + f]

        pop f
        @advance:
            inc el
            push c
            push a
            mfhi al
            add cl, al
            cmp el, cl
            pop a
            pop c
            jnz @loop

        @wrap:
            mfhi el
            inc fl
            cmp fl, 32
            jz @return
            jmp @loop

    @return:
        shove pop, d, e, f, g, hi
        rts

font:
    .incbin "../assets/font_3x4.bin"
    .equ FONT_BYTES, 768
