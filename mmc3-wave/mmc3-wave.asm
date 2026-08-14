.include "macros.inc"
.include "mmc3-registers.asm"
.include "ppu.asm"
.include "gamepad.asm"

.segment "HEADER" ; (mmc3, 16k PRG, 8k CHR)
.byte $4E, $45, $53, $1A, $01, $01, $41, $00

START_SCANLINE = 55
END_SCANLINE   = 120

.macro enable_rendering
  set PPUMASK, #%00001010
.endmacro

.segment "CHR"
.incbin "tiles.chr"

.segment "ZEROPAGE"
addr_lo:    .res 1
addr_hi:    .res 1
loop_ct:    .res 1
inlp_ct:    .res 1 ; inner loop count
tick:       .res 1
frame:      .res 1
line_ct:    .res 1
main_done:  .res 1
cur_anim:   .res 1
anim_size:  .res 1
anim_addr:  .res 2

.segment "CODE"

.proc reset_handler
  SEI ; SEt Interrupt ignore bit (IRQ disable)
  set APUCOUNT, #$40 ; disable frame counter IRQs
  CLD ; CLear Decimal mode bit (BCD [binary-coded decimal] disable)

  ; By storing $00 to both PPUCTRL and PPUMASK, we turn off NMIs and disable rendering to the screen during startup,
  ; to ensure that we don't draw random garbage to the screen.
  LDX #$00
  STX PPUMASK
  STX PPUCTRL

  ; disable mmc3 irqs
  mmc3_disable_irq

  ; set horizontal mirror
  mmc3_set_horizontal_mirror

  ; set chr banks
  mmc3_bank_switch_chr_2k

  clear_ram

  ; initialize stack
  LDX #$FF
  TXS

  BIT PPUSTATUS
  wait_for_vblank
  wait_for_vblank

  ; write palettes
  write_palettes palette, #8

  ; fill the nametable and attribute table
  set_ppu_addr $2000
  write_nametable nametable

  ; clear the second nametable
  set_ppu_addr $2800
  clear_nametable
  clear_attr_table

  ; set initial animation
  set cur_anim, #0

  LDA #%10001000  ; turn on NMIs, sprites use second pattern table, backgrounds first
  STA PPUCTRL

  enable_rendering

  CLI ; CLear Interrupt disable

  JMP main
.endproc

.proc nmi_handler

  INC tick
  LDA tick

  ; every 2 frames
  ;EOR #253
  ;AND #1
  ; every 4 frames
  ;EOR #253
  ;AND #2
  ; every 8 frames
  EOR #252
  AND #3
  ; every 16 frames
  ;EOR #248
  ;AND #7
  ; every 32 frames
  ;EOR #240
  ;AND #15
  BNE :+
    INC frame
  :

  JSR poll_gamepad
  check_button_release BUTTON_SELECT, JSR change_anim

  ; read and store frame info
  ; for current anim
  LDY cur_anim
  LDA anim_sizes,Y
  STA anim_size
  DEC anim_size

  ; read and store addr info
  ; for current anim
  LDA cur_anim
  ASL
  TAY
  LDA anim_addrs,Y
  STA anim_addr
  INY
  LDA anim_addrs,Y
  STA anim_addr+1

  set main_done, #0

  set line_ct, #START_SCANLINE+1

  ; set initial scanline irq
  mmc3_set_irq #START_SCANLINE+1

  ; reset scroll and enable rendering
  reset_scroll
  enable_rendering

  RTI
.endproc

.proc irq_handler

  INC line_ct

  LDX #%10001000

  ; get x offset value from table
  ; and set scroll while animating
  LDA line_ct
  CLC
  ; animate
  ADC frame
  ; loop values
  AND anim_size
  TAY
  LDA (anim_addr),Y

  BPL :+
    INX ; next nametable
  :
  STX PPUCTRL

  ; delay
  ; delay, delay
  delay #$0B, 2

  ; set scroll near the end of scanline
  STA PPUSCROLL
  ; and clear write toggle bit
  BIT PPUSTATUS

  ; increment and check for end
  LDY line_ct
  CPY #END_SCANLINE+1
  BNE :+
    set_scroll #0, #0
    ; disable irq for remainder of frame
    mmc3_disable_irq
    RTI
  :
  mmc3_set_irq #0
  RTI
.endproc

.proc change_anim
  INC cur_anim
  LDA cur_anim
  CMP num_anims
  BNE :+
    set cur_anim, #0
  :
  RTS
.endproc

.proc main
  start_main:

  set main_done, #1

  ; wait until NMI fires
  wait_loop:
  LDA main_done
  BNE wait_loop

 JMP start_main
.endproc

.segment "RODATA"

  num_anims:
    .byte anim_sizes_end - anim_sizes

  anim_addrs:
    .word heat_wave
    .word smooth, ocean, bayou_shallow, chaos, bayou_mid
    ;.word bayou_mid_scallop, bayou_shallow_scallop
    .word bayou_deep
    ;.word hula
    ;.word scallop, smooth_scallop_flipped
    .word zig_zag, deep_zig_zag, ziggurat
    .word fuzz
    ;.word deep_fuzz, deeper_fuzz
  anim_addrs_end:

  anim_sizes:
    .byte heat_wave_end - heat_wave
    .byte smooth_end - smooth, ocean_end - ocean, bayou_shallow_end - bayou_shallow, chaos_end - chaos, bayou_mid_end - bayou_mid
    ;.byte bayou_mid_end - bayou_mid_scallop, bayou_shallow_end - bayou_shallow_scallop
    .byte bayou_deep_end - bayou_deep
    ;.byte hula_end - hula
    ;.byte scallop_end - scallop, smooth_scallop_flipped_end - smooth_scallop_flipped
    .byte zig_zag_end - zig_zag, deep_zig_zag_end - deep_zig_zag, ziggurat_end - ziggurat
    .byte fuzz_end - fuzz
    ;.byte deep_fuzz_end - deep_fuzz, deeper_fuzz_end - deeper_fuzz
  anim_sizes_end:

  ; NOTE: the number of values in each animation must be a power of two

  bayou_deep:
    .byte $1A, $2B, $37, $40, $48, $4C, $4D, $4D, $4C, $48, $40, $37, $2B, $1D, $0F, $05
    .byte $F9, $F0, $E2, $D4, $C8, $BF, $B7, $B3, $B2, $B2, $B3, $B7, $BF, $C8, $D4, $E5
  bayou_deep_end:

  bayou_mid:
    .byte $03, $0C, $13, $18, $1C, $1E, $1F, $1F, $1E, $1C, $19, $15, $11, $0B, $06, $00
  bayou_mid_scallop:
    .byte $FC, $F7, $F3, $EE, $EA, $E6, $E3, $E1, $E0, $E0, $E1, $E3, $E6, $EA, $F0, $F8
  bayou_mid_end:

  bayou_shallow:
    .byte $01, $05, $08, $0A, $0C, $0D, $0E, $0E, $0E, $0E, $0D, $0C, $0A, $08, $05, $01
  bayou_shallow_scallop:
    .byte $FD, $FA, $F7, $F5, $F3, $F2, $F1, $F1, $F1, $F1, $F2, $F3, $F5, $F7, $FA, $FD
  bayou_shallow_end:

  chaos:
    .byte $00, $03, $06, $09, $0C, $0E, $10, $12, $14, $15, $16, $17, $18, $18, $19, $19
    .byte $19, $19, $18, $18, $17, $16, $15, $14, $12, $10, $0E, $0C, $09, $06, $03, $00
  chaos_scallop:
    .byte $FE, $FC, $F9, $F6, $F3, $F1, $EF, $ED, $EB, $EA, $E9, $E8, $E7, $E7, $E6, $E6
    .byte $E6, $E6, $E7, $E7, $E8, $E9, $EA, $EB, $ED, $EF, $F1, $F3, $F6, $F9, $FC, $FE
  chaos_end:

  deep_fuzz:
    .byte $00, $02
  deep_fuzz_end:

  deeper_fuzz:
    .byte $00, $00, $04, $04
  deeper_fuzz_end:

  deep_zig_zag:
    .byte $F4, $F6, $F8, $FA, $FC, $FE, $00, $02, $04, $06, $08, $0A, $0C, $0E, $10, $12
    .byte $10, $0E, $0C, $0A, $08, $06, $04, $02, $00, $FE, $FC, $FA, $F8, $F6, $F4, $F2
  deep_zig_zag_end:

  fuzz:
    .byte $00, $01
  fuzz_end:

  heat_wave:
    .byte $00, $00, $01, $01, $02, $02, $03, $03, $03, $03, $02, $02, $01, $01, $00, $00
    .byte $FF, $FF, $FE, $FE, $FD, $FD, $FC, $FC, $FC, $FC, $FD, $FD, $FE, $FE, $FF, $FF
    .byte $FF, $FF, $FE, $FE, $FD, $FD, $FC, $FC, $FC, $FC, $FD, $FD, $FE, $FE, $FF, $FF
    .byte $00, $00, $00, $01, $01, $01, $01, $02, $02, $02, $02, $01, $01, $01, $01, $00
  heat_wave_end:

  hula:
    .byte $FF, $FF, $FF, $FE, $FE, $FE, $FD, $FD, $FD, $FD, $FE, $FE, $FE, $FF, $FF, $FF
    .byte $FF, $FF, $FF, $FE, $FE, $FE, $FD, $FD, $FD, $FD, $FE, $FE, $FE, $FF, $FF, $FF
    .byte $00, $00, $00, $01, $01, $01, $02, $02, $02, $02, $01, $01, $01, $00, $00, $00
    .byte $00, $00, $00, $01, $01, $01, $02, $02, $02, $02, $01, $01, $01, $00, $00, $00
  hula_end:

  ocean:
    .byte $00, $02, $03, $04, $06, $07, $07, $08, $08, $08, $07, $07, $06, $04, $03, $02
    .byte $00, $FE, $FD, $FC, $FA, $F9, $F9, $F8, $F8, $F8, $F9, $F9, $FA, $FC, $FD, $FE
  ocean_end:

  scallop:
    .byte $FE, $FD, $FD, $FC, $FC, $FC, $FB, $FB, $FB, $FB, $FC, $FC, $FC, $FD, $FD, $FE
  scallop_end:

  smooth:
    .byte $FF, $FF, $FE, $FE, $FD, $FD, $FC, $FC, $FC, $FC, $FD, $FD, $FE, $FE, $FF, $FF
  smooth_end:

  smooth_scallop:
    .byte $FF, $FF, $FF, $FE, $FE, $FE, $FD, $FD, $FD, $FD, $FE, $FE, $FE, $FF, $FF, $FF
  smooth_scallop_end:

  smooth_scallop_flipped:
    .byte $00, $00, $00, $01, $01, $01, $02, $02, $02, $02, $01, $01, $01, $00, $00, $00
  smooth_scallop_flipped_end:

  ziggurat:
    .byte $00, $02, $04, $06, $08, $08, $08, $08, $0A, $0C, $0E, $10, $12, $12, $12, $12
    .byte $10, $0E, $0C, $0A, $08, $08, $08, $08, $06, $04, $02, $01, $00, $00, $00, $00
  ziggurat_end:

  zig_zag:
    .byte $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0A, $0B, $0C, $0D, $0E, $0F
    .byte $0E, $0D, $0C, $0B, $0A, $09, $08, $07, $06, $05, $04, $03, $02, $01, $00, $FF
  zig_zag_end:

  nametable:
    .incbin "nametable.bin"
  palette:
    .incbin "palette.bin"

; point to vectors
; $FFFA-$FFFB Start of NMI handler
; $FFFC-$FFFD Start of reset handler
; $FFFE-$FFFF Start of IRQ handler
.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler
