.include "macros.inc"
.include "ppu.asm"

.segment "HEADER" ; (nrom, 16k PRG, 8k CHR)
.byte $4E, $45, $53, $1A, $01, $01, $01, $00

START_SCANLINE = 60
END_SCANLINE   = 180

; uncomment these for various effects
; or pass them to ca65 with e.g. -D FILL_EFFECT
;FILL_EFFECT = 1
;WIPE_OUT = 1

.segment "CHR"
.incbin "tiles.chr"

.segment "ZEROPAGE"
addr_lo:    .res 1
addr_hi:    .res 1
loop_ct:    .res 1
inlp_ct:    .res 1 ; inner loop count
tick:       .res 1
line_ct:    .res 1 ; line count
main_done:  .res 1

.segment "CODE"

.proc reset_handler
  SEI ; SEt Interrupt ignore bit (IRQ disable)
  set APUCOUNT, #$40 ; disable frame counter IRQs
  CLI ; CLear Interrupt disable
  CLD ; CLear Decimal mode bit (BCD [binary-coded decimal] disable)

  ; By writing $00 to both PPUCTRL and PPUMASK, we turn off NMIs and disable rendering to the screen during startup,
  ; ensuring that we don't draw random garbage to the screen.
  LDX #$00
  STX PPUMASK
  STX PPUCTRL

  clear_ram

  wait_for_vblank
  wait_for_vblank

  ; write palettes
  write_palettes palette, #16

  ; fill the nametable and attribute table
.ifdef WIPE_OUT
  set_ppu_addr $2400
.else
  set_ppu_addr $2000
.endif
  write_nametable nametable

.ifdef FILL_EFFECT
  ; fill the second nametable and attribute table
  write_nametable nametable_alt
.else
  ; clear the second nametable
  clear_nametable
  clear_attr_table
.endif

  JMP main
.endproc

.proc nmi_handler
  disable_rendering

  INC tick
  set main_done, #0

  LDA #%10001000  ; turn on NMIs, sprites use second pattern table, backgrounds first
  STA PPUCTRL

  ; reset scroll and enable rendering
  reset_scroll
  set PPUMASK, #%00001010

  ; delay until top of screen
  LDX #$02
    LDY #$3C
    : NOP
      DEY
    BNE :-
  DEX
  BNE :-

  RTI
.endproc

.proc irq_handler
  RTI
.endproc

.proc main
  start_main:

  ; additional delay for each scanline
  LDX line_ct
  : delay #$15
    DEX
    NOP
  BNE :-

  ; end wipe at a specific scanline
  LDX line_ct
  CPX #END_SCANLINE
  BCC :+
    set main_done, #1
    BNE wait_loop

  ; start wipe at a specific scanline
: CPX #START_SCANLINE
  BCC increment

  ; set scroll
  LDA #%10001001 ; next nametable
  STA PPUCTRL

  set main_done, #1

  increment:
    INC line_ct

  ; wait until NMI fires
  ; when main_done will be reset
  wait_loop:
  LDA main_done
  BNE wait_loop

 JMP start_main
.endproc

.segment "RODATA"
  nametable:
    .incbin "nametable.bin"
  nametable_alt:
    .incbin "nametable_alt.bin"
  palette:
    .incbin "palette.bin"

; point to vectors
; $FFFA-$FFFB NMI handler
; $FFFC-$FFFD Reset handler
; $FFFE-$FFFF IRQ handler
.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler
