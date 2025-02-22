.include "macros.inc"
.include "mmc3-registers.asm"
.include "ppu.asm"

.segment "HEADER" ; MMC3 (mapper 4, 64k PRG [16 banks], 16k CHR)
.byte $4E, $45, $53, $1A, $04, $01, $40, $00

.segment "CHR"
.incbin "tiles.chr"
.res 1024, $00
.res 1024, $FF
.res 1024, $00
.res 1024, $FF

.segment "ZEROPAGE"
addr_lo:    .res 1
addr_hi:    .res 1
loop_ct:    .res 1
inlp_ct:    .res 1 ; inner loop count
next_step:  .res 2

.macro set_next_step pointer
  set next_step, #<pointer
  set next_step+1, #>pointer
.endmacro

.macro set_next_halfstep pointer
  set next_step, #<pointer
.endmacro

.macro enable_rendering
  set PPUMASK, #%00001010
.endmacro

; uncomment the following symbols or pass them in the build,
; e.g. build mmc3-palette3 -D NUMBER_COLUMN=1
;BACKGROUND_COLUMNS = 1
;COLOR_COLUMNS = 1
;NUMBER_COLUMN = 1
;VERTICAL_MIRROR = 1

; Clobbers: A, X
.macro setup_palette_change addr_lo, color

  ; set up a few vars for next interrupt
  ; start setting palette address
  LDX #$3F
  STX PPUADDR
  ; load ppu low addr
  LDX addr_lo
  ; load palette color
  LDA color
.endmacro

; Clobbers: A, X, Y
; Param: coarse_byte_1
; Param: coarse_byte_2 - see Quick coarse X/Y split:
;      First      Second
;   /¯¯¯¯¯¯¯¯¯\  /¯¯¯¯¯¯¯\
;   0 0yy NN YY  YYY XXXXX
;     ||| || ||  ||| +++++-- coarse X scroll  ($00-$1F)
;     ||| || ||  +++-------- coarse Y scroll  ($20, $40, $80, $C0, $E0)
;     ||| || ++------------- coarse Y scroll  ($00, $01, $02, $03)
;     ||| ++---------------- nametable        ($00, $04, $08, $0C)
;     +++------------------- fine Y scroll    ($10, $20, $30)
; Param: irq_val - sets the next irq for n lines from now
; Param: next_step - the subroutine that will be called on the next irq
.macro set_palette_color coarse_byte_1, coarse_byte_2, irq_val, next_step

  ; Y should be 0 at this point from delay
  ; disable rendering
  STY PPUMASK

  LDY coarse_byte_2

  ; finish setting palette address
  STX PPUADDR

  ; load coarse ppu address
  LDX coarse_byte_1

  ; write palette color
  STA PPUDATA

  ; reset coarse scroll
  STX PPUADDR
  STY PPUADDR

  enable_rendering

  ; set next interrupt
  mmc3_set_irq irq_val
  set_next_step next_step
.endmacro


.segment "RESET"

.proc reset_handler
  set APUCOUNT, #$40
  CLI ; CLear Interrupt disable
  CLD ; CLear Decimal mode bit (BCD disable)

  ; turn off NMIs and disable rendering
  LDX #$00
  STX PPUCTRL
  STX PPUMASK

  clear_ram

  wait_for_vblank
  wait_for_vblank

  ; write palettes
  write_palettes palette, #16

  ; set horizontal mirror
  mmc3_set_horizontal_mirror

  ; fill the first nametable
  set_ppu_addr $2000
  fill_nametable #$42
  ; fill the first attribute table
  fill_ppu #$00, #16
  fill_ppu #$55, #16
  fill_ppu #$AA, #16
  fill_ppu #$FF, #16

  ; clear the second nametable and attribute table
  set_ppu_addr $2800
  clear_nametable
  clear_attr_table

.ifdef BACKGROUND_COLUMNS
  ; overlay a few blank columns
  ; to hide visual artifacts
  set PPUCTRL, #%00000100
  set_ppu_addr $201F
  LDY #$00
  LDX #30
: STY PPUDATA
  DEX
  BNE :-
  set_ppu_addr $2400
  LDX #30
: STY PPUDATA
  DEX
  BNE :-
.endif

.ifdef COLOR_COLUMNS
  ; overlay a few blank columns
  ; to reveal visual artifacts
  LDY #$1C
  STY addr_lo
  set PPUCTRL, #%00000100
  LDY #$04
  LDA #$FF
  : set_ppu_addr #$20, addr_lo
    CLC
    ADC #1
    LDX #30
    : STA PPUDATA
      DEX
    BNE :-
    INC addr_lo
    DEY
  BNE :--
.endif

.ifdef NUMBER_COLUMN
  ; overlay a column of numbered tiles for this example,
  ; which helps to make sure alignment is correct for coarse x/y
  set PPUCTRL, #%00000100
  set_ppu_addr $2000
  LDX #30
: TXA
  CLC
  ADC #$E1
  STA PPUDATA
  DEX
  BNE :-
.endif

.ifdef VERTICAL_MIRROR
  ; set vertical mirror
  mmc3_set_vertical_mirror
.endif

  ; turn on NMIs, sprites use second pattern table, backgrounds first
  set PPUCTRL, #%10001000

  JMP main
.endproc


.segment "CODE"

.proc irq_handler
  JMP (next_step) ; 5 cycles
.endproc

.proc nmi_handler

  ; restore original palettes
  write_palettes palette, #16

  ; restore ppu addr
  set_ppu_addr $0000

  ; reset scroll and enable rendering
  reset_scroll
  enable_rendering

  ; set initial interrupt
  mmc3_set_irq #$0E
  set_next_step setup_pal_change

  RTI
.endproc


setup_pal_change:

  ; set next interrupt
  mmc3_set_irq #0
  set_next_step change_pal_00

  setup_palette_change #$00, #$04
RTI

change_pal_00:

  ; delay until late in the next scanline
  delay #$11, 1

  set_palette_color #$00, #$40, #$06, change_pal_01

  setup_palette_change #$01, #$13
RTI

change_pal_01:

  ; delay until late in the next scanline
  delay #$11,, 1

  set_palette_color #$00, #$60, #$0E, change_pal_02

  setup_palette_change #$02, #$23
RTI

.align 256
change_pal_02:

  ; delay until late in the next scanline
  delay #$11,, 1

  set_palette_color #$00, #$A0, #$06, change_pal_03

  setup_palette_change #$03, #$34
RTI

change_pal_03:

  ; delay until late in the next scanline
  delay #$11,, 1

  set_palette_color #$00, #$C0, #$0E, change_pal_04

  setup_palette_change #$00, #$06
RTI

change_pal_04:

  ; delay until late in the next scanline
  delay #$11,, 1

  set_palette_color #$01, #$00, #$0E, change_pal_05

  setup_palette_change #$05, #$17
RTI

change_pal_05:

  ; delay until late in the next scanline
  delay #$11,, 1

  set_palette_color #$01, #$40, #$0E, change_pal_06

  setup_palette_change #$06, #$26
RTI

.align 256
change_pal_06:

  ; delay until late in the next scanline
  delay #$11,, 1

  set_palette_color #$01, #$80, #$0E, change_pal_07

  setup_palette_change #$07, #$37
RTI

change_pal_07:

  ; delay until late in the next scanline
  delay #$10, 4

  set_palette_color #$01, #$C0, #$16, change_pal_08

  setup_palette_change #$00, #$07
RTI

change_pal_08:

  ; delay until late in the next scanline
  delay #$11,, 1

  set_palette_color #$02, #$20, #$0E, change_pal_09

  setup_palette_change #$09, #$18
RTI

change_pal_09:

  ; delay until late in the next scanline
  delay #$11,, 1

  set_palette_color #$02, #$60, #$0E, change_pal_0A

  setup_palette_change #$0A, #$28
RTI

.align 256
change_pal_0A:

  ; delay until late in the next scanline
  delay #$11,, 1

  set_palette_color #$02, #$A0, #$0E, change_pal_0B

  setup_palette_change #$0B, #$38
RTI

change_pal_0B:

  ; delay until late in the next scanline
  delay #$11,, 1

  set_palette_color #$02, #$E0, #$06, change_pal_0C

  setup_palette_change #$00, #$08
RTI

change_pal_0C:

  ; delay until late in the next scanline
  delay #$11,, 1

  set_palette_color #$03, #$00, #$0E, change_pal_0D

  setup_palette_change #$0F, #$3C;#$0D, #$1C
RTI

change_pal_0D:

  ; delay until late in the next scanline
  delay #$11,, 1

  set_palette_color #$03, #$40, #$06, change_pal_0E

  setup_palette_change #$0E, #$2C
RTI

.align 256
change_pal_0E:

  ; delay until late in the next scanline
  delay #$11,, 1

  set_palette_color #$03, #$60, #$06, change_pal_0F

  setup_palette_change #$0D, #$1C;#$0F, #$3C
RTI

change_pal_0F:

  ; delay until late in the next scanline
  delay #$11,, 1

  set_palette_color #$03, #$80, #$01, disable_irq
RTI

disable_irq:
  mmc3_disable_irq
RTI

.proc main
forever:
  JMP forever
.endproc


.segment "RODATA"

palette:
  .incbin "palette.bin"


.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler
