; ***************************************************************************
;
; boot.asm
;
; PC Engine / TurboGrafx-16 hello-world template entry point.
;
; Built on top of the "CORE(not TM)" library that ships with HuC's PCEAS
; examples. CORE provides the reset-vector startup code, IRQ handling, a
; joypad reader, common VDC helpers, and an 8x8 font dropper. The library
; itself lives outside this repo (in the HuC install) and is pulled in via
; PCE_INCLUDE - see the Makefile.
;
; The CORE library is Boost-licensed (Copyright John Brandwood 2021), see:
;   https://github.com/pce-devel/huc/tree/master/examples/asm/elmer/include
;
; ***************************************************************************

        ; Project-wide equates (VRAM layout, BAT/SAT addresses, etc).

        include "platform.inc"

        ; CORE startup. Hands control to bare_main once init is done.

        include "bare-startup.asm"

        .list
        .mlist

        ; CORE helpers we use below.

        include "common.asm"            ; Common helpers + zp pseudo-regs.
        include "vdc.asm"               ; VDC init, MAWR/VWR helpers.
        include "font.asm"              ; dropfnt8x8_vdc.
        include "joypad.asm"            ; Reads pad state every vsync.



; ***************************************************************************
;
; bare_main - Entry point. Called by CORE startup once IRQs and the kernel
; are ready. We never return from here; CORE only re-enters via interrupts.
;

        .code

bare_main:
        call    init_256x224            ; 256x224 mode, default screen.

        ; --- Upload the font to VRAM ---------------------------------------
        ;
        ; Font goes at tile slot CHR_0x10 (16 tiles past the BAT, leaving
        ; room for the SAT). The font is 16 graphics tiles + 96 ASCII
        ; glyphs. It uses palette colours 4..7 (bitplane 2 = $FF, bp 3 = 0).

        stz     <_di + 0
        lda     #>(CHR_0x10 * 16)
        sta     <_di + 1

        lda     #$FF
        sta     <_al
        stz     <_ah

        lda     #16 + 96
        sta     <_bl

        lda     #<my_font
        sta     <_bp + 0
        lda     #>my_font
        sta     <_bp + 1
        ldy     #^my_font

        call    dropfnt8x8_vdc

        ; --- Upload the palette to the VCE ---------------------------------

        stz     <_al                    ; Start at palette 0 (BG).
        lda     #1                      ; One palette of 16 colours.
        sta     <_ah
        lda     #<my_palette
        sta     <_bp + 0
        lda     #>my_palette
        sta     <_bp + 1
        ldy     #^my_palette
        call    load_palettes
        call    xfer_palettes

        ; --- Print the message ---------------------------------------------
        ;
        ; Centre-ish on a 32-tile-wide visible area. Row 13, col 8.

        lda     #<(13 * BAT_LINE + 8)
        sta     <_di + 0
        lda     #>(13 * BAT_LINE + 8)
        sta     <_di + 1
        call    vdc_di_to_mawr

        cly
        bsr     .print_message

        ; --- Show the screen and idle --------------------------------------

        call    set_dspon

.hang:
        call    wait_vsync
        bra     .hang


; Write an ASCII text string directly to the VDC's VWR data register.
; Each byte fetched from .message_text is offset by CHR_ZERO so it
; lands on the right tile in the font we uploaded above.

.print_loop:
        clc
        adc     #<CHR_ZERO
        sta     VDC_DL
        lda     #$00
        adc     #>CHR_ZERO
        sta     VDC_DH
        iny
.print_message:
        lda     .message_text, y
        bne     .print_loop
        rts

.message_text:
        db      "Hello, PC Engine!", 0



; ***************************************************************************
;
; Data
;
; CORE startup initialises .DATA on boot, so we don't need to do it again.
;

        .data

        align   2
my_palette:
        ; Palette 0 (BG):
        ;   $0  transparent
        ;   $1  dark blue shadow
        ;   $2  white font
        ;   $4  dark blue background  $5  light blue shadow  $6  yellow font
        dw      $0000,$0001,$01B2,$01B2,$0002,$004C,$0169,$01B2
        dw      $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000

my_font:
        incbin  "font8x8-ascii-bold-short.dat"
