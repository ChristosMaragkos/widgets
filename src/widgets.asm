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

    ; knob sprites share the 1bpp widget tiles
    xor al, al
    st al, [OAMCTRL]

    xor al, al
    st al, [PPUCTRL]

    shove pop, dp
    rts

; call once per render pass, before any render_widget calls
begin_widgets:
    xor c, c
    st.l cl, [next_oam_index]
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

    shove push, d, e, f, g

    ld.l cl, [al:b] ; kind
    ld.l dl, [al:b + 1] ; color

    ld.l el, [al:b + 2] ; x
    ld.l fl, [al:b + 3] ; y

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
;       const __far int *text;
;       uint8_t max_width;
;   }

    shove push, a, b

    push f
    push e
    push d

    mov el, al
    mov f, b

    ld.l b, [el:f + 4]
    ld.l al, [el:f + 6]
    ld.l cl, [el:f + 7]

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
        shove pop, d, e, f, g
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
    st al, [VDMACTRL]

    st al, [VDMASTART] ; vdmalen already contains the correct amount

    pop a
    st al, [PPUCTRL] ; restore entry blank state

    shove pop, dp
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
