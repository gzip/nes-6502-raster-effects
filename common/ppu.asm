; VPHB SINN
; |||| ||||
; |||| ||++- Base nametable address (0 = $2000; 1 = $2400; 2 = $2800; 3 = $2C00)
; |||| |+--- VRAM address increment per CPU read/write of PPUDATA (0: add 1, going across; 1: add 32, going down)
; |||| +---- Sprite pattern table address for 8x8 sprites (0: $0000; 1: $1000; ignored in 8x16 mode)
; |||+------ Background pattern table address (0: $0000; 1: $1000)
; ||+------- Sprite size (0: 8x8 pixels; 1: 8x16 pixels)
; |+-------- PPU master/slave select (0: read backdrop from EXT pins; 1: output color on EXT pins)
; +--------- Generate an NMI at the start of the
;            vertical blanking interval (0: off; 1: on)
PPUCTRL   = $2000

; BGRs bMmG
; |||| ||||
; |||| |||+- Greyscale (0: normal color, 1: produce a greyscale display)
; |||| ||+-- 1: Show background in leftmost 8 pixels of screen, 0: Hide
; |||| |+--- 1: Show sprites in leftmost 8 pixels of screen, 0: Hide
; |||| +---- 1: Show background
; |||+------ 1: Show sprites
; ||+------- Emphasize red (green on PAL/Dendy)
; |+-------- Emphasize green (red on PAL/Dendy)
; +--------- Emphasize blue
PPUMASK   = $2001

; VSO. ....
; |||| ||||
; |||+-++++- Least significant bits previously written into a PPU register
; |||        (due to register not being updated for this address)
; ||+------- Sprite overflow. The intent was for this flag to be set
; ||         whenever more than eight sprites appear on a scanline, but a
; ||         hardware bug causes the actual behavior to be more complicated
; ||         and generate false positives as well as false negatives; see
; ||         PPU sprite evaluation. This flag is set during sprite
; ||         evaluation and cleared at dot 1 (the second dot) of the
; ||         pre-render line.
; |+-------- Sprite 0 Hit.  Set when a nonzero pixel of sprite 0 overlaps
; |          a nonzero background pixel; cleared at dot 1 of the pre-render
; |          line.  Used for raster timing.
; +--------- Vertical blank has started (0: not in vblank; 1: in vblank).
;            Set at dot 1 of line 241 (the line *after* the post-render
;            line); cleared after reading $2002 and at dot 1 of the
;            pre-render line.
PPUSTATUS = $2002

; write twixe, x then y
PPUSCROLL = $2005

; write twice, high then low, valid addresses are $0000-$3FFF
PPUADDR   = $2006

; write to address set in PPUADDR ($2006), after each write it increments by an amount determined by bit 2 of PPUCTRL ($2000)
PPUDATA   = $2007

; Used to set where in OAM we want to write to.
OAMADDR   = $2003

; Initiates the transfer of an entire page of memory into OAM.
; Writing the high byte of a memory address to OAMDMA will transfer that page.
OAMDMA    = $4014

APUCOUNT  = $4017


.macro wait_for_vblank
  .local vblankwait
  vblankwait:       ; wait for vblank before continuing
    BIT PPUSTATUS
    BPL vblankwait
.endmacro

.macro wait_for_sprite_0 fail_label
  ; wait until sprite 0 is clear
  LDA #%01000000   ; Allow either vblank or sprite 0 to break this loop
: BIT PPUSTATUS
  BNE :-

  ; wait until sprite 0 is hit
  LDA #%11000000   ; Allow either vblank or sprite 0 to break this loop
: BIT PPUSTATUS
  BEQ :-

  ; At this point, either bit 6 or 7 is true.
  ; If bit 6 is true then sprite 0 hit occurred.

.ifnblank fail_label
  ; Otherwise, sprite 0 was missed and vblank started so branch to failure case
  BVC fail_label
.endif
.endmacro


; clobbers X
.macro set_scroll xpos, ypos
  LDX xpos
  STX PPUSCROLL
  LDX ypos
  STX PPUSCROLL
.endmacro

; clobbers X
.macro reset_scroll
  set_scroll #0, #0
.endmacro

; clobbers X
.macro disable_rendering
  set PPUMASK, #0
.endmacro


; Writes two address bytes to $2006
; hi - high byte of address or full 16-bit address
; lo - low byte of address (optional if hi is 16-bit)
; reset - to reset the latch
; Clobbers: X
.macro set_ppu_addr hi, lo, reset
  .ifnblank reset
  LDX PPUSTATUS
  .endif
  .ifblank lo
    LDX #>hi
    STX PPUADDR
    LDX #<hi
    STX PPUADDR
  .else
    LDX hi
    STX PPUADDR
    LDX lo
    STX PPUADDR
  .endif
.endmacro

.macro write_palettes src, ct
  set_ppu_addr $3F00
  write_loop_ppu src, ct
.endmacro

.macro write_ppu_byte addr, val
  set_ppu_addr #>addr, #<addr
  LDX val
  STX PPUDATA
.endmacro

; clobbers A, X and Y
.macro fill_ppu val, ct, outer_ct
  .local inner_loop
  .local outer_loop
  LDA val
  .ifnblank outer_ct
  LDY outer_ct
  outer_loop:
  .endif
    LDX ct
    inner_loop:
      STA PPUDATA
      DEX
    BNE inner_loop
  .ifnblank outer_ct
  DEY
  BNE outer_loop
  .endif
.endmacro


; max 256 bytes
; clobbers A and X
.macro write_loop_ppu src, ct, dont_init_x
  .local copy_loop
  .ifblank dont_init_x
  LDX #$00
  .endif
  copy_loop:
    LDA src,X
    STA PPUDATA
    INX
    CPX ct
    BNE copy_loop
.endmacro

.macro write_nametable src
  write_loop_ppu src,       #$00
  write_loop_ppu {src+256}, #$00, 1
  write_loop_ppu {src+512}, #$00, 1
  write_loop_ppu {src+768}, #$00, 1
.endmacro

.macro fill_nametable val
  fill_ppu val, #$F0, #4
.endmacro

.macro fill_attr_table val
  fill_ppu val, #$40
.endmacro

.macro clear_attr_table
  fill_attr_table #0
.endmacro

.macro clear_nametable
  fill_nametable #0
.endmacro
