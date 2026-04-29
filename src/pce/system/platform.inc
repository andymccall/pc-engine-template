; ***************************************************************************
;
; platform.inc
;
; Project-wide PC Engine equates. A single home for hardware constants
; and project-wide layout decisions, included by every translation unit.
;
; ***************************************************************************

; ---------------------------------------------------------------------------
; VRAM layout
; ---------------------------------------------------------------------------
; The PC Engine VDC sees 64KB of VRAM as 16-bit words. The default screen
; mode initialised by init_256x224 (in vdc.asm) gives a 64x32 BAT, which we
; place at the start of VRAM, followed by the SAT (16 tiles' worth), and
; then the ASCII font tiles.
;
;   $0000..$07FF   BAT  (64 columns x 32 rows = 2048 words)
;   $0800..$08FF   SAT  (256 words = 64 sprites x 4 attribute words)
;   $0900..        Tile data (font here, then game tiles)

BAT_LINE        =       64                  ; BAT stride in tiles per row.
BAT_SIZE        =       64 * 32             ; Total BAT cells.
SAT_ADDR        =       BAT_SIZE            ; SAT lives just past the BAT.
CHR_ZERO        =       BAT_SIZE / 16       ; First tile slot after BAT.
CHR_0x10        =       CHR_ZERO + 16       ; First slot after BAT + SAT.
CHR_0x20        =       CHR_ZERO + 32       ; ASCII space-glyph tile slot.
