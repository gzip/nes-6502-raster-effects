.include "macros.inc"
.include "ppu.asm"

.macro write_palette_set
  BIT PPUDATA ; skip bg color
  STA PPUDATA
  STX PPUDATA
  STY PPUDATA
.endmacro

.macro enable_rendering
  ; reset scroll and enable rendering
  set_scroll #248, #0
  set PPUMASK, #%00011010
.endmacro


.segment "HEADER"
.byte $4E, $45, $53, $1A
; 16k PRG, 8k CHR, mapper 0 (NROM) with horizontal mirroring
.byte $01, $01, $00, $00

.segment "CHR"
.incbin "top_chr.chr"
.incbin "bottom_chr.chr"

.segment "ZEROPAGE"
addr_lo:    .res 1
addr_hi:    .res 1
loop_ct:    .res 1
inlp_ct:    .res 1 ; inner loop count
bpal:       .res 16
game_state: .res 1

.segment "CODE"

.proc reset_handler
  set APUCOUNT, #$40
  SEI ; SEt Interrupt disable
  CLD ; CLear Decimal mode bit (BCD disable)

  ; turn off NMIs and disable rendering
  LDX #$00
  STX PPUCTRL
  STX PPUMASK

  clear_ram

  wait_for_vblank

  ; store palette in zero page for faster access
  mem_copy bottom_palette, bpal, #16

  ; copy sprite 0 into oam
  mem_copy sprite_0, $0200, #04

  wait_for_vblank

  ; fill the nametable and attribute table
  set_ppu_addr $2000
  write_nametable nametable

  ; enable NMIs
  set PPUCTRL, #%10000000

  ; wait for first nmi
  set game_state, #$80
  JMP wait_loop
.endproc

.proc nmi_handler

  disable_rendering

  ; reset backgrounds and sprites to first table, enable NMIs
  set PPUCTRL, #%10000000

  ; write palettes
  write_palettes top_palette, #16

  ; write oam
  set OAMADDR, #$00
  set OAMDMA,  #$02

  ; restore ppu addr
  set_ppu_addr $2000

  enable_rendering

  set game_state, #0

  RTI
.endproc

.proc main

  ; wait until sprite 0 overlaps with the background
  wait_for_sprite_0

  delay_pal_1:
    delay #$03, 1
    disable_rendering

  set_pal_1_addr:
    set_ppu_addr $3F00

  prepare_pal_1_vals:
    LDA bpal+1
    LDX bpal+2
    LDY bpal+3

  write_pal_1:
    write_palette_set


  delay_pal_2:
    delay #$11, 2

  prepare_pal_2_values:
    LDA bpal+5
    LDX bpal+6
    LDY bpal+7

  write_pal_2:
    write_palette_set


  delay_pal_3:
    delay #$11, 1

  prepare_pal_3_values:
    LDA bpal+9
    LDX bpal+10
    LDY bpal+11

  write_pal_3:
    write_palette_set


  delay_pal_4:
    delay #$12

  prepare_pal_4_values:
    LDA bpal+13
    LDX bpal+14
    LDY bpal+15

  write_pal_4:
    write_palette_set


  change_chr_bank:
    ; change background patterns to $1000
    set PPUCTRL, #%10011000

  delay_enable_render:
    delay #$20, 4

  ; restore coarse ppu addr
  set_ppu_addr $21E0

  enable_rendering

  set game_state, #$80
.endproc

; wait until NMI fires (where game_state is reset)
wait_loop:
  LDA game_state
  BMI wait_loop

JMP main


.segment "RODATA"

nametable:
  .incbin "nametable.bin"
top_palette:
  .incbin "top_pal.bin"
bottom_palette:
  .incbin "bottom_pal.bin"
sprite_0:
  ; y, tile, flags, x
  .byte $74, $FF, %00100000, $65

.segment "VECTORS"
.addr nmi_handler, reset_handler
