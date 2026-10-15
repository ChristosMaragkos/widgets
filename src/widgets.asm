.once
.include "defs.asm"

.wram
.equ WIDGET_STAGING_SIZE, 2048
staging_widgets:
    .pad WIDGET_STAGING_SIZE
staging_knobs:
    .pad WIDGET_STAGING_SIZE
next_oam_index:
    .pad 1
current_widget:
    .pad 1
widgets_amount:
    .pad 1
frames_since_last_input:
    .pad 1

.equ UI_TILES_VRAM_DEST, 0x0_3000
.equ WIDGET_LAYER_E_SRC, 0x0_2800

.rom
setup_widgets:
    shove push, dp
    ld al, MMIO_PAGE
    mtdp al

    ld al, 0b111
    st al, [PPUCTRL] ; force blank

    xor al, al
    st al, [VDMACTRL]

    ld b, VDMASRC
    ld a, textures
    st a, [b+]
    ld al, .pageof textures
    st al, [b]

    ld b, VDMADST
    ld a, UI_TILES_VRAM_DEST
    st a, [b+]
    ld al, .pageof UI_TILES_VRAM_DEST
    st al, [b]

    ld b, BG3GFXSRC
    ld a, UI_TILES_VRAM_DEST
    st a, [b+]
    ld al, .pageof UI_TILES_VRAM_DEST
    st al, [b]

    ld b, OAMGFXSRC
    ld a, UI_TILES_VRAM_DEST
    st a, [b+]
    ld al, .pageof UI_TILES_VRAM_DEST
    st al, [b]

    ld a, WIDGET_TEXTURES_SIZE
    st a, [VDMALEN]

    st al, [VDMASTART]

    ld b, BG3ESRC
    ld a, WIDGET_LAYER_E_SRC
    st a, [b+]
    ld al, .pageof WIDGET_LAYER_E_SRC
    st al, [b]

    xor al, al
    st al, [BG3CTRL]

    ld al, 1
    st al, [BG4CTRL]

    xor al, al
    st al, [OAMCTRL]
    st al, [PPUCTRL]

    shove pop, dp
    rts

; call once per render pass, before any render_widget calls
begin_widgets:
    xor c, c
    st.l cl, [next_oam_index]
    rts

; al:b -> 24-bit pointer to array of widgets
; c -> amount of widgets to render
render_widget_array:
    shove push, d, e, f, dp
    mtdp al

    ld.l dl, [current_widget]
    zxt dl
    lsl d, 4
    ld el, [b + d] ; kind
    cmp el, UI_LABEL
    jz @no_color

    inc d ; color
    ld el, [b + d]
    zxt el
    push e
    ld el, UI_YELLOW
    st el, [b + d]

    @no_color:
    xor d, d
    st.l dl, [next_oam_index]

    xor d, d
    @loop:
        shove push, a, b, c
        lsl d, 4
        add b, d
        jsr render_widget
        shove pop, a, b, c

        lsr d, 4
        inc d
        cmp d, c
        jltu @loop

    ld.l dl, [current_widget]
    zxt dl
    lsl d, 4
    ld el, [b + d]
    cmp el, UI_LABEL
    jz @return
    inc d ; color
    pop e
    st el, [b + d]

    @return:
    shove pop, d, e, f, dp
    rts

; al:b -> 24-bit pointer to any widget
render_widget:
;   enum WidgetKind : unsigned int { UI_LABEL, UI_BUTTON, UI_TOGGLE, UI_SLIDER_H, UI_SLIDER_V };
;   enum WidgetColor : unsigned int { /* ... all the UI colors defined in color.asm */ };
;
;   struct Widget {
;          WidgetKind type;
;          WidgetColor color;
;          uint8_t x, y;
;   };

    shove push, d, e, f, g, dp
    mtdp al

    ld cl, [b] ; kind
    ld dl, [b + 1] ; color

    ld el, [b + 2] ; x
    ld fl, [b + 3] ; y

    cmp cl, UI_LABEL
    jz @render_label

    and dl, 0b111 ; no rainbow for widgets

    cmp cl, UI_BUTTON
    jz @render_button

    cmp cl, UI_TOGGLE
    jz @render_toggle

    cmp cl, UI_SLIDER_H
    jz @render_slider_h

    cmp cl, UI_SLIDER_V
    jz @render_slider_v

    jmp @return

@render_label:
;   struct Label {
;       Widget base;
;       const int *__far text;
;       uint8_t max_width;
;   }

    shove push, a, b

    push f
    push e
    push d

    mov el, al
    mov f, b

    ld b, [f + 4]
    ld al, [f + 6]
    ld cl, [f + 7]

    jsr draw_text

    pop d
    pop e
    pop f

    shove pop, a, b
    jmp @return

@render_button:
; struct Button {
;       Widget base;
;       __far void (*callback)(void);
; }
    zxt dl
    zxt el
    zxt fl

    lsl d, 10
    ld g, TILE_TOP_LEFT_CORNER
    or g, d

    ; 1d grid index
    ; 32 * y + x
    lsl f, 5
    add f, e
    lsl f, 1

    st.l g, [staging_widgets + f]
    add f, 2
    or g, TILE_FLIP_H

    st.l g, [staging_widgets + f]
    add f, 62

    and g, 0x1fff ; clear top 3 bits

    or g, TILE_FLIP_V
    st.l g, [staging_widgets + f]
    add f, 2

    or g, TILE_FLIP_BOTH
    st.l g, [staging_widgets + f]
    jmp @return

@render_toggle:
; struct Toggle {
;       Widget base;
;       __far bool* enabled;
; }
    zxt dl
    zxt el
    zxt fl

    push e

    ld.l e, [al:b + 4]
    ld.l cl, [al:b + 6]

    ld.l cl, [cl:e]

    pop e

    lsl d, 10
    ld g, TILE_TOP_LEFT_CORNER_TOGGLE
    cmp cl, 0
    jnz @enabled

    dec g

    @enabled:
    or g, d

    lsl f, 5
    add f, e
    lsl f, 1

    st.l g, [staging_widgets + f]
    add f, 2
    or g, TILE_FLIP_H

    st.l g, [staging_widgets + f]
    add f, 62

    and g, 0x1fff

    or g, TILE_FLIP_V
    st.l g, [staging_widgets + f]
    add f, 2

    or g, TILE_FLIP_BOTH
    st.l g, [staging_widgets + f]
    jmp @return

@render_slider_h:
; struct Slider_H {
;       Widget base;
;       uint8_t width;
;       uint8_t step_size;
;       __far int16_t *value;
;       __far uint8_t (*derive_percent)(int16_t);
;       __far int16_t (*advance)(int16_t, int16_t);
; }
    zxt dl
    zxt el
    zxt fl

    shove push, d, e, f

    lsl d, 10
    ld g, TILE_TOP_LEFT_CORNER
    or g, d

    lsl f, 5
    add f, e
    lsl f, 1

    st.l g, [staging_widgets + f]

    add f, 64
    or g, TILE_FLIP_V

    st.l g, [staging_widgets + f]

    sub f, 62
    and g, 0x1fff

    ld.l cl, [al:b + 4]
    cmp cl, 2
    jleu @no_middle

    sub cl, 2
    ld g, TILE_TOP_EDGE
    or g, d
    @loop:
        st.l g, [staging_widgets + f]
        add f, 64
        or g, TILE_FLIP_V

        st.l g, [staging_widgets + f]
        sub f, 62

        and g, 0x1fff
        djnz cl, @loop

    @no_middle:
    ld g, TILE_TOP_LEFT_CORNER
    or g, d
    or g, TILE_FLIP_H

    st.l g, [staging_widgets + f]
    add f, 64
    or g, TILE_FLIP_BOTH

    st.l g, [staging_widgets + f]

    shove pop, d, e, f
    ; al:b -> pointer to slider
    ; cl -> unused
    ; dl -> color
    ; el -> x
    ; fl -> y

    ; scale x, y to pixels
    lsl e, 3
    lsl f, 3

    mov c, e

    add e, KNOB_MARGIN ; left margin, this is our starting X
    add f, 4 ; center vertically

    ld.l gl, [al:b + 4] ; width
    zxt gl
    lsl g, 3
    add c, g
    sub c, 5 ; maximum x: track x + track width - (margin + knob width)

    sub c, e ; travel span (max - min)

    shove push, d, e, f, g
    ld.l d, [al:b + 9]
    ld.l el, [al:b + 11]

    ld.l g, [al:b + 6]
    ld.l fl, [al:b + 8]

    ld.l a, [fl:g]

    jsr.l el:d ; a now holds the q0.8 percent value
    shove pop, d, e, f, g

    xchg c, a
    mov b, a
    mov a, e
    ; calculate_knob_pos(uint16_t x_min, uint16_t span, uint16_t pct_q0_16)
    mulu b, c
    lsr b, 8
    add a, b

    ld.l bl, [next_oam_index]
    zxt bl
    lsl b, 3

    st.l a, [staging_knobs + b]
    add b, 2
    st.l f, [staging_knobs + b]
    add b, 2
    ld c, TILE_KNOB_H
    lsl d, 10
    or c, d
    st.l c, [staging_knobs + b]

    sub b, 4
    lsr b, 3
    inc b
    st.l bl, [next_oam_index]

    jmp @return

@render_slider_v:
; struct Slider_V {
;       Widget base;
;       uint8_t height;
;       uint8_t step_size;
;       __far int16_t *value;
;       __far uint8_t (*derive_percent)(int16_t);
; }
    zxt dl
    zxt el
    zxt fl

    shove push, d, e, f

    lsl d, 10
    ld g, TILE_TOP_LEFT_CORNER
    or g, d

    lsl f, 5
    add f, e
    lsl f, 1

    st.l g, [staging_widgets + f]
    add f, 2
    or g, TILE_FLIP_H

    st.l g, [staging_widgets + f]
    add f, 62

    ld.l cl, [al:b + 4]
    cmp cl, 2
    jleu @no_middle

    sub cl, 2
    ld g, TILE_LEFT_EDGE
    or g, d
    @loop:
        st.l g, [staging_widgets + f]
        add f, 2
        or g, TILE_FLIP_H

        st.l g, [staging_widgets + f]
        add f, 62

        and g, 0x1fff
        djnz cl, @loop

    @no_middle:
    ld g, TILE_TOP_LEFT_CORNER
    or g, d
    or g, TILE_FLIP_V

    st.l g, [staging_widgets + f]
    add f, 2
    or g, TILE_FLIP_BOTH

    st.l g, [staging_widgets + f]
    shove pop, d, e, f
    ; al:b -> pointer to slider
    ; cl -> unused
    ; dl -> color
    ; el -> x
    ; fl -> y

    ; scale x, y to pixels
    lsl e, 3
    lsl f, 3

    mov c, f

    add f, KNOB_MARGIN ; top margin, this is our starting Y
    add e, 4 ; center horizontally

    ld.l gl, [al:b + 4] ; height
    zxt gl
    lsl g, 3
    add c, g
    sub c, 6 ; maximum y: track y + track height - (margin + knob height) BUT min y already had 4 added to it

    sub c, f ; travel span (max - min)

    shove push, d, e, f, g
    ld.l d, [al:b + 9]
    ld.l el, [al:b + 11]

    ld.l g, [al:b + 6]
    ld.l fl, [al:b + 8]

    ld.l a, [fl:g] ; load slider value into first arg

    shove push, b, c
    jsr.l el:d ; a now holds the q0.8 percent value
    shove pop, b, c
    shove pop, d, e, f, g

    ; a -> pct
    ; b -> garbo?
    ; c -> span
    ; d -> color
    ; e -> x
    ; f -> min y
    ; g -> garbo

    mov b, c ; b becomes span
    xchg a, c ; c becomes pct, a becomes span
    mov a, f ; a becomes min y
    add a, b
    ; calculate_knob_pos(uint16_t y_min, uint16_t span, uint16_t pct_q0_16)
    mulu b, c
    lsr b, 8
    sub a, b ; a now holds the final y value

    ld.l bl, [next_oam_index]
    zxt bl
    lsl b, 3 ; oam entries are 8 bytes
    ; AGAIN:
    ; e -> x
    ; a -> final y

    st.l e, [staging_knobs + b]
    add b, 2
    st.l a, [staging_knobs + b]
    add b, 2
    ld c, TILE_KNOB_V
    lsl d, 10
    or c, d
    st.l c, [staging_knobs + b]

    sub b, 4
    lsr b, 3
    inc b
    st.l bl, [next_oam_index]

    @return:
        shove pop, d, e, f, g, dp
        rts

upload_widgets:
    shove push, dp

    ld al, MMIO_PAGE
    mtdp al

    ld al, [PPUCTRL]
    push a ; saved blank state

    jsr upload_text

    ld al, MMIO_PAGE
    mtdp al

    ld al, 0b111
    st al, [PPUCTRL] ; force blank

    xor al, al
    st al, [VDMACTRL]

    ld b, VDMASRC
    ld a, staging_widgets
    st a, [b+]
    ld al, .pageof staging_widgets
    st al, [b]

    ld b, VDMADST
    ld a, WIDGET_LAYER_E_SRC
    st a, [b+]
    ld al, .pageof WIDGET_LAYER_E_SRC
    st al, [b]

    ld a, WIDGET_STAGING_SIZE
    st a, [VDMALEN]

    st al, [VDMASTART]

    ld b, VDMASRC
    ld a, staging_knobs
    st a, [b+]
    ld al, .pageof staging_knobs
    st al, [b]

    ld b, VDMADST
    xor a, a
    st a, [b+]
    st al, [b]

    ld al, 0b10
    st al, [VDMACTRL] ; OAM

    ld.l al, [next_oam_index]
    zxt al
    lsl a, 3
    st a, [VDMALEN]

    st al, [VDMASTART] ; vdmalen already contains the correct amount

    pop a
    st al, [PPUCTRL] ; restore entry blank state

    shove pop, dp
    rts

; a -> JOYPAD1 input
consume_input:
    bt a, JOYPAD_CONNECTED
    jz @return
    shove push, d, e, f
    ld.l dl, [frames_since_last_input]
    cmp dl, 6
    jltu @no_input

    bt a, BTN_L
    jz @no_l

    ld.l al, [current_widget]
    zxt al
    @nav_l_next:
        dec al
        ld.l bl, [widgets_amount]
        cmp al, bl
        jltu @nav_l_have
        ld.l al, [widgets_amount]
        dec al
    @nav_l_have:
        lsl a, 4
        ld.l bl, [widgets + a]
        cmp bl, UI_LABEL
        jnz @nav_l_break
        lsr a, 4
        jmp @nav_l_next
    @nav_l_break:
    lsr a, 4
    st.l al, [current_widget]
    jmp @reset_input_frames

    @no_l:
    bt a, BTN_R
    jz @no_r

    ld.l al, [current_widget]
    zxt al
    @nav_r_next:
        inc al
        ld.l bl, [widgets_amount]
        cmp al, bl
        jltu @nav_r_have
        xor al, al
    @nav_r_have:
        lsl a, 4
        ld.l bl, [widgets + a]
        cmp bl, UI_LABEL
        jnz @nav_r_break
        lsr a, 4
        jmp @nav_r_next
    @nav_r_break:
    lsr a, 4
    st.l al, [current_widget]
    jmp @reset_input_frames

    @no_r:
    ld dl, MMIO_PAGE
    mtdp dl

    ld.l cl, [current_widget]
    zxt cl
    lsl c, 4
    ld.l bl, [widgets + c] ; kind is offset zero so we're fine

    cmp bl, UI_BUTTON
    jz @button

    cmp bl, UI_TOGGLE
    jz @toggle

    cmp bl, UI_SLIDER_H
    jz @slider_h

    cmp bl, UI_SLIDER_V
    jz @slider_v

    jmp @no_input

@button:
    bt a, BTN_A
    jz @reset_input_frames

    add c, 4
    ld.l b, [widgets + c]
    add c, 2
    ld.l cl, [widgets + c]

    jsr.l cl:b
    jmp @reset_input_frames

@toggle:
    bt a, BTN_A
    jz @reset_input_frames

    add c, 4
    ld.l b, [widgets + c]
    add c, 2
    ld.l dl, [widgets + c]

    ld.l el, [dl:b]
    cmp el, 0
    jnz @set_false

    @set_true:
        ld el, 1
        st.l el, [dl:b]
        jmp @reset_input_frames

    @set_false:
        xor el, el
        st.l el, [dl:b]
        jmp @reset_input_frames

@slider_h:
    add c, 5
    ld.l fl, [widgets + c] ; step size
    zxt fl

    inc c
    ld.l d, [widgets + c]
    add c, 2
    ld.l bl, [widgets + c]

    ld.l e, [bl:d] ; underlying value

    bt a, BTN_LEFT
    jz @no_left

    neg f
    xchg a, e ; a becomes underlying value, e becomes input, useless, can overwrite
    add c, 4
    ld.l e, [widgets + c]
    add c, 2
    shove push, b, g
    ld.l gl, [widgets + c]
    xchg b, f ; b becomes step size
    jsr.l gl:e ; a now holds new value
    shove pop, b, g
    mov e, a
    jmp @store_back_hor

    @no_left:
    bt a, BTN_RIGHT
    jz @reset_input_frames

    xchg a, e ; a becomes underlying value, e becomes input, useless, can overwrite
    add c, 4
    ld.l e, [widgets + c]
    add c, 2
    shove push, b, g
    ld.l gl, [widgets + c]
    xchg b, f ; b becomes step size
    jsr.l gl:e ; a now holds new value
    shove pop, b, g
    mov e, a

    @store_back_hor:
    st.l e, [bl:d]

    jmp @reset_input_frames

@slider_v:
    add c, 5
    ld.l fl, [widgets + c] ; step size
    zxt fl

    inc c
    ld.l d, [widgets + c]
    add c, 2
    ld.l bl, [widgets + c]

    ld.l e, [bl:d] ; underlying value

    bt a, BTN_DOWN
    jz @no_down

    neg f
    xchg a, e ; a becomes underlying value, e becomes input, useless, can overwrite
    add c, 4
    ld.l e, [widgets + c]
    add c, 2
    shove push, b, g
    ld.l gl, [widgets + c]
    xchg b, f ; b becomes step size
    jsr.l gl:e ; a now holds new value
    shove pop, b, g
    mov e, a
    jmp @store_back_vert

    @no_down:
    bt a, BTN_UP
    jz @reset_input_frames

    xchg a, e ; a becomes underlying value, e becomes input, useless, can overwrite
    add c, 4
    ld.l e, [widgets + c]
    add c, 2
    shove push, b, g
    ld.l gl, [widgets + c]
    xchg b, f ; b becomes step size
    jsr.l gl:e ; a now holds new value
    shove pop, b, g
    mov e, a

    @store_back_vert:
    st.l e, [bl:d]

@reset_input_frames:
    xor al, al
    st.l al, [frames_since_last_input]
    jmp @return

@no_input:
    inc dl
    st.l dl, [frames_since_last_input]

    @return:
    shove pop, d, e, f
    rts

textures:
    .incbin "../assets/widgets_big.bin"
    .equ WIDGET_TEXTURES_SIZE, 56

    .equ UI_LABEL, 0
    .equ UI_BUTTON, 1
    .equ UI_TOGGLE, 2
    .equ UI_SLIDER_H, 3
    .equ UI_SLIDER_V, 4

    .equ TILE_EMPTY, 0
    .equ TILE_TOP_LEFT_CORNER, 1
    .equ TILE_TOP_LEFT_CORNER_TOGGLE, 2
    .equ TILE_LEFT_EDGE, 3
    .equ TILE_TOP_EDGE, 4
    .equ TILE_KNOB_H, 5
    .equ TILE_KNOB_V, 6

    .equ TILE_FLIP_H, 0b00_1_0000000000000
    .equ TILE_FLIP_V, 0b0_1_00000000000000
    .equ TILE_FLIP_BOTH, 0b0_11_0000000000000

    .equ KNOB_MARGIN, 2
    .equ KNOB_WIDTH, 4

.include "text.asm"
.include "color.asm"
