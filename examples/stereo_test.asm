.rom
    jmp main

.include "defs.asm"
.include "widgets.asm"

.wram
widgets:
    .pad WIDGETS_SIZE
current_widget:
    .pad 1
toggle_enabled:
    .pad 1
frames_since_last_input:
    .pad 1
prev_joy:
    .pad 2
tri_vol_l:
    .pad 2
tri_vol_r:
    .pad 2
tri_gate_val:
    .pad 1

.rom
main:
    jsr setup_ivt
    jsr setup_text
    jsr setup_color
    jsr setup_widgets
    jsr init_rom_widgets

    xor a, a
    mtdp al
    st al, [toggle_enabled]

    st a, [prev_joy]
    st al, [frames_since_last_input]
    st al, [current_widget]
    st a, [tri_vol_l]
    st a, [tri_vol_r]
    ld al, 1
    st al, [tri_gate_val]
    ld al, WIDGETS_LEN
    st al, [widgets_amount]

    ld al, MMIO_PAGE
    mtdp al

    ; triangle, A4, full sustain, gate on
    ld a, 0x1B80
    st a, [TRIPITCH]
    xor al, al
    st al, [TRIVOL]
    st al, [TRIVOR]
    ld al, 2
    st al, [TRICTRL]
    ld a, 0x40F4
    st a, [TRIADSR]

    ld al, 0b100
    st al, [PPUCTRL]

    fi:
        ld.l cl, [current_widget]
        zxt cl
        lsl c, 4
        ld.l al, [widgets + c] ; kind
        cmp al, UI_LABEL
        jz @no_color

        inc c ; color
        ld.l al, [widgets + c]
        zxt al
        push a
        ld al, UI_YELLOW
        st.l al, [widgets + c]

        @no_color:
        xor c, c
        st.l cl, [next_oam_index]

        @loop:
            push c
            lsl c, 4
            ld al, .pageof widgets
            ld b, widgets
            add b, c
            jsr render_widget
            pop c
            inc c
            cmp cl, WIDGETS_LEN
            jltu @loop

        ld.l cl, [current_widget]
        zxt cl
        lsl c, 4
        ld.l al, [widgets + c]
        cmp al, UI_LABEL
        jz @still_no_color
        inc c ; color
        pop a
        st.l al, [widgets + c]

        @still_no_color:
        wfi

        ld.l a, [JOYPAD1]
        jsr consume_input

        ld.l a, [tri_vol_l]
        st.l al, [TRIVOL]
        ld.l a, [tri_vol_r]
        st.l al, [TRIVOR]
        ld al, 0b10
        not al
        ld.l bl, [TRICTRL]
        and bl, al
        ld.l al, [tri_gate_val]
        and al, 1
        zxt al
        lsl a, 1
        or al, bl
        st.l al, [TRICTRL]

        jmp fi

.equ ROM_IVT_BYTES, 6

setup_ivt:
    shove push, d, e

    ld al, .pageof ivt_entries
    ld b, ivt_entries
    ld cl, .pageof IVT_BASE
    ld d, IVT_BASE
    ld e, ROM_IVT_BYTES
    blkcp [al:b], [cl:d], e

    shove pop, d, e
    rts

_isr_vblank:
    shove push, a, b, c, d, e, f, g, hi, dp
    jsr upload_widgets
    shove pop, a, b, c, d, e, f, g, hi, dp
    rti

_isr_hblank:
    rti

derive_q0_8:
    and a, 0xff
    rts.l

; a -> current value
; b -> delta
advance_volume:
    add a, b
    cmp a, 0
    jlts @clamp_zero

    cmp a, 0xff
    jgts @clamp_full
    jmp @return

    @clamp_zero:
    xor a, a
    jmp @return

    @clamp_full:
    ld a, 0xff

    @return:
    rts.l

init_rom_widgets:
    shove push, d, e
    ld al, .pageof rom_widgets
    ld b, rom_widgets
    ld cl, .pageof widgets
    ld d, widgets
    ld e, WIDGETS_SIZE
    blkcp [al:b], [cl:d], e
    shove pop, d, e
    rts

ivt_entries:
    .d24 _isr_vblank
    .d24 _isr_hblank

.equ WIDGETS_LEN, 6
.equ WIDGETS_SIZE, 96

rom_widgets:
vol_l_slider:
    .db UI_SLIDER_V
    .db UI_WHITE
    .db 7, 21
    .db 9
    .db 5
    .d24 tri_vol_l
    .d24 derive_q0_8
    .d24 advance_volume
    .pad 1
label_l:
    .db UI_LABEL
    .db UI_WHITE
    .db 12, 25
    .d24 text_l
    .db 1
    .pad 8
toggle_gate:
    .db UI_TOGGLE
    .db UI_WHITE
    .db 15, 23
    .d24 tri_gate_val
    .pad 9
label_toggle:
    .db UI_LABEL
    .db UI_WHITE
    .db 30, 21
    .d24 text_tog
    .db 4
    .pad 8
vol_r_slider:
    .db UI_SLIDER_V
    .db UI_WHITE
    .db 23, 21
    .db 9
    .db 5
    .d24 tri_vol_r
    .d24 derive_q0_8
    .d24 advance_volume
    .pad 1
label_r:
    .db UI_LABEL
    .db UI_WHITE
    .db 51, 25
    .d24 text_r
    .db 1
    .pad 8

text_l:
    .db "L", 0
text_r:
    .db "R", 0
text_tog:
    .db "GATE", 0
