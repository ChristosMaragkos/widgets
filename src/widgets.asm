.ifndef WIDGETS_ASM
.equ WIDGETS_ASM, 1
.include "../include/defs.inc"

.wram
.equ WIDGET_STAGING_SIZE, 2048
staging_widgets:
    .space WIDGET_STAGING_SIZE
staging_knobs:
    .space WIDGET_STAGING_SIZE
next_oam_index:
    .space 1
current_widget:
    .space 1
widgets_amount:
.global widgets_amount
    .space 1
frames_since_last_input:
    .space 1

.equ UI_TILES_VRAM_DEST, 0x03000
.equ WIDGET_LAYER_E_SRC, 0x02800

.rom
.global setup_widgets
.global render_widget
.global render_widget_array
.global consume_input
.global upload_widgets
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
    jz .0
    cmp el, UI_BOX
    jz .0

    inc d ; color
    ld el, [b + d]
    zxt el
    push e
    ld el, UI_YELLOW
    st el, [b + d]

    .0:
    xor d, d
    st.l dl, [next_oam_index]

    xor d, d
    .1:
        shove push, a, b, c
        lsl d, 4
        add b, d
        jsr render_widget
        shove pop, a, b, c

        lsr d, 4
        inc d
        cmp d, c
        jltu .1

    ld.l dl, [current_widget]
    zxt dl
    lsl d, 4
    ld el, [b + d]
    cmp el, UI_LABEL
    jz .3
    cmp el, UI_BOX
    jz .3
    inc d ; color
    pop e
    st el, [b + d]

    .3:
    shove pop, d, e, f, dp
    rts

; al:b -> 24-bit pointer to any widget
render_widget:
;   enum WidgetKind : unsigned int { UI_LABEL, UI_BUTTON, UI_TOGGLE, UI_SLIDER_H, UI_SLIDER_V, UI_BOX };
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
    jz .4

    and dl, 0b111 ; no rainbow for widgets

    cmp cl, UI_BUTTON
    jz .5

    cmp cl, UI_TOGGLE
    jz .6

    cmp cl, UI_SLIDER_H
    jz .7

    cmp cl, UI_SLIDER_V
    jz .8

    cmp cl, UI_BOX
    jz .9

    jmp .3

.4:
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
    jmp .3

.5:
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
    jmp .3

.6:
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
    jnz .27

    dec g

    .27:
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
    jmp .3

.7:
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
    jleu .2

    sub cl, 3
    ld g, TILE_TOP_EDGE
    or g, d
    .1:
        st.l g, [staging_widgets + f]
        add f, 64
        or g, TILE_FLIP_V

        st.l g, [staging_widgets + f]
        sub f, 62

        and g, 0x1fff
        djnc cl, .1

    .2:
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

    jmp .3

.8:
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
    jleu .200

    sub cl, 3
    ld g, TILE_LEFT_EDGE
    or g, d
    .100:
        st.l g, [staging_widgets + f]
        add f, 2
        or g, TILE_FLIP_H

        st.l g, [staging_widgets + f]
        add f, 62

        and g, 0x1fff
        djnc cl, .100

    .200:
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
    jmp .3

.9:
;   struct Box {
;       Widget base;
;       uint8_t w, h;
;   }
; c, d, e, f -> kind, color, x, y
; Hollow w*h border from the button corner tiles + edge tiles.
; Interior cells are left untouched (staging is zero-init, widgets static).
    push a

    zxt dl
    zxt el
    zxt fl

    lsl d, 10

    ld cl, [b + 4] ; w
    zxt cl
    ld al, [b + 5] ; h

    cmp cl, 2
    jgeu .10
    ld cl, 2
    .10:
    cmp al, 2
    jgeu .11
    ld al, 2
    .11:

    ; grid base: (32 * y + x) * 2
    lsl f, 5
    add f, e
    lsl f, 1

    ; top-left corner
    ld g, TILE_TOP_LEFT_CORNER
    or g, d
    st.l g, [staging_widgets + f]
    add f, 2

    ; top edge: (w - 2) x TOP_EDGE
    mov e, c
    sub e, 2
    jz .12
    dec e
    ld g, TILE_TOP_EDGE
    or g, d
    .13:
    st.l g, [staging_widgets + f]
    add f, 2
    djnc e, .13

    .12:
    ld g, TILE_TOP_LEFT_CORNER
    or g, d
    or g, TILE_FLIP_H
    st.l g, [staging_widgets + f]
    add f, 2

    ; middle rows: (h - 2)
    sub al, 2
    jz .14
    dec al

    .17:
    mov g, c
    lsl g, 1
    add f, 64
    sub f, g
    ld g, TILE_LEFT_EDGE
    or g, d
    st.l g, [staging_widgets + f]
    add f, 2

    mov e, c
    sub e, 2
    jz .15
    dec e
    .16:
    add f, 2
    djnc e, .16

    .15:
    ld g, TILE_LEFT_EDGE
    or g, d
    or g, TILE_FLIP_H
    st.l g, [staging_widgets + f]
    add f, 2
    djnc al, .17

    .14:
    mov g, c
    lsl g, 1
    add f, 64
    sub f, g
    ld g, TILE_TOP_LEFT_CORNER
    or g, d
    or g, TILE_FLIP_V
    st.l g, [staging_widgets + f]
    add f, 2

    mov e, c
    sub e, 2
    jz .18
    dec e
    ld g, TILE_TOP_EDGE
    or g, d
    or g, TILE_FLIP_BOTH
    .19:
    st.l g, [staging_widgets + f]
    add f, 2
    djnc e, .19

    .18:
    ld g, TILE_TOP_LEFT_CORNER
    or g, d
    or g, TILE_FLIP_BOTH
    st.l g, [staging_widgets + f]

    pop a
    jmp .3

    .3:
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
    .extern widgets
    shove push, d, e, f, dp
    bt a, JOYPAD_CONNECTED
    jz .3
    ld.l dl, [frames_since_last_input]
    cmp dl, 6
    jltu .20

    bt a, BTN_L
    jz .21

    ld.l al, [current_widget]
    zxt al
    .22:
        dec al
        ld.l bl, [widgets_amount]
        cmp al, bl
        jltu .23
        ld.l al, [widgets_amount]
        dec al
    .23:
        lsl a, 4
        ld.l bl, [widgets + a]
        cmp bl, UI_LABEL
        jz .24
        cmp bl, UI_BOX
        jnz .25
        .24:
        lsr a, 4
        jmp .22
    .25:
    lsr a, 4
    st.l al, [current_widget]
    jmp .26

    .21:
    bt a, BTN_R
    jz .28

    ld.l al, [current_widget]
    zxt al
    .29:
        inc al
        ld.l bl, [widgets_amount]
        cmp al, bl
        jltu .30
        xor al, al
    .30:
        lsl a, 4
        ld.l bl, [widgets + a]
        cmp bl, UI_LABEL
        jz .31
        cmp bl, UI_BOX
        jnz .32
        .31:
        lsr a, 4
        jmp .29
    .32:
    lsr a, 4
    st.l al, [current_widget]
    jmp .26

    .28:
    ld dl, MMIO_PAGE
    mtdp dl

    ld.l cl, [current_widget]
    zxt cl
    lsl c, 4
    ld.l bl, [widgets + c] ; kind is offset zero so we're fine

    cmp bl, UI_BUTTON
    jz .33

    cmp bl, UI_TOGGLE
    jz .34

    cmp bl, UI_SLIDER_H
    jz .35

    cmp bl, UI_SLIDER_V
    jz .36

    jmp .20

.33:
    bt a, BTN_A
    jz .26

    add c, 4
    ld.l b, [widgets + c]
    add c, 2
    ld.l cl, [widgets + c]

    jsr.l cl:b
    jmp .26

.34:
    bt a, BTN_A
    jz .26

    add c, 4
    ld.l b, [widgets + c]
    add c, 2
    ld.l dl, [widgets + c]

    ld.l el, [dl:b]
    cmp el, 0
    jnz .37

    .38:
        ld el, 1
        st.l el, [dl:b]
        jmp .26

    .37:
        xor el, el
        st.l el, [dl:b]
        jmp .26

.35:
    add c, 5
    ld.l fl, [widgets + c] ; step size
    zxt fl

    inc c
    ld.l d, [widgets + c]
    add c, 2
    ld.l bl, [widgets + c]

    ld.l e, [bl:d] ; underlying value

    bt a, BTN_LEFT
    jz .39

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
    jmp .40

    .39:
    bt a, BTN_RIGHT
    jz .26

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

    .40:
    st.l e, [bl:d]

    jmp .26

.36:
    add c, 5
    ld.l fl, [widgets + c] ; step size
    zxt fl

    inc c
    ld.l d, [widgets + c]
    add c, 2
    ld.l bl, [widgets + c]

    ld.l e, [bl:d] ; underlying value

    bt a, BTN_DOWN
    jz .41

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
    jmp .42

    .41:
    bt a, BTN_UP
    jz .26

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

    .42:
    st.l e, [bl:d]

.26:
    xor al, al
    st.l al, [frames_since_last_input]
    jmp .3

.20:
    inc dl
    st.l dl, [frames_since_last_input]

    .3:
    shove pop, d, e, f, dp
    rts

textures:
    .incbin "../assets/textures.bin"
    .equ WIDGET_TEXTURES_SIZE, 56

    .equ UI_LABEL, 0
    .global UI_LABEL
    .equ UI_BUTTON, 1
    .global UI_BUTTON
    .equ UI_TOGGLE, 2
    .global UI_TOGGLE
    .equ UI_SLIDER_H, 3
    .global UI_SLIDER_H
    .equ UI_SLIDER_V, 4
    .global UI_SLIDER_V
    .equ UI_BOX, 5
    .global UI_BOX

    .equ SIZEOF_WIDGET, 16
    .global SIZEOF_WIDGET
    .equ LABEL_PADDING, 8
    .global LABEL_PADDING
    .equ BUTTON_PADDING, 9
    .global BUTTON_PADDING
    .equ TOGGLE_PADDING, 9
    .global TOGGLE_PADDING
    .equ SLIDER_PADDING, 1
    .global SLIDER_PADDING
    .equ BOX_PADDING, 10
    .global BOX_PADDING

    .equ TILE_EMPTY, 0
    .equ TILE_TOP_LEFT_CORNER, 1
    .equ TILE_TOP_LEFT_CORNER_TOGGLE, 2
    .equ TILE_LEFT_EDGE, 3
    .equ TILE_TOP_EDGE, 4
    .equ TILE_KNOB_H, 5
    .equ TILE_KNOB_V, 6

    .equ TILE_FLIP_H, 0b0010000000000000
    .equ TILE_FLIP_V, 0b0100000000000000
    .equ TILE_FLIP_BOTH, 0b0110000000000000

    .equ KNOB_MARGIN, 2
    .equ KNOB_WIDTH, 4

.include "text.asm"
.include "color.asm"
.endif
