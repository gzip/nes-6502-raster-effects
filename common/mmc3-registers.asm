; https://www.nesdev.org/wiki/MMC3#Registers
; 7  bit  0
; ---- ----
; CPMx xRRR
; |||   |||
; |||   +++- Specify which bank register to update on next write to Bank Data register
; |||            000: R0: Select 2 KB CHR bank at PPU $0000-$07FF (or $1000-$17FF)
; |||            001: R1: Select 2 KB CHR bank at PPU $0800-$0FFF (or $1800-$1FFF)
; |||            010: R2: Select 1 KB CHR bank at PPU $1000-$13FF (or $0000-$03FF)
; |||            011: R3: Select 1 KB CHR bank at PPU $1400-$17FF (or $0400-$07FF)
; |||            100: R4: Select 1 KB CHR bank at PPU $1800-$1BFF (or $0800-$0BFF)
; |||            101: R5: Select 1 KB CHR bank at PPU $1C00-$1FFF (or $0C00-$0FFF)
; |||            110: R6: Select 8 KB PRG ROM bank at $8000-$9FFF (or $C000-$DFFF)
; |||            111: R7: Select 8 KB PRG ROM bank at $A000-$BFFF
; ||+------- Nothing on the MMC3, see MMC6
; |+-------- PRG ROM bank mode (0: $8000-$9FFF swappable,
; |                                $C000-$DFFF fixed to second-last bank;
; |                             1: $C000-$DFFF swappable,
; |                                $8000-$9FFF fixed to second-last bank)
; +--------- CHR A12 inversion (0: two 2 KB banks at $0000-$0FFF,
;                                  four 1 KB banks at $1000-$1FFF;
;                               1: two 2 KB banks at $1000-$1FFF,
;                                  four 1 KB banks at $0000-$0FFF)

MMC3_REG_SELECT      := $8000
MMC3_REG_DATA        := $8001
MMC3_REG_MIRROR      := $A000
MMC3_REG_PRAM        := $A001 ; used to protect PRG RAM on reset

MMC3_REG_IRQ_LATCH   := $C000
MMC3_REG_IRQ_RELOAD  := $C001 ; any value triggers
MMC3_REG_IRQ_DISABLE := $E000 ; any value triggers
MMC3_REG_IRQ_ENABLE  := $E001 ; any value triggers


; CHR modes
.define MMC3_MODE_CHR_2_4    #%00000000
.define MMC3_MODE_CHR_4_2    #%10000000

; CHR banks
.define MMC3_SELECT_CHR_2K_0 #%00000000
.define MMC3_SELECT_CHR_2K_1 #%00000001
.define MMC3_SELECT_CHR_1K_0 #%00000010
.define MMC3_SELECT_CHR_1K_1 #%00000011
.define MMC3_SELECT_CHR_1K_2 #%00000100
.define MMC3_SELECT_CHR_1K_3 #%00000101


; PRG modes
.define MMC3_MODE_FIXED_C000 #%00000000
.define MMC3_MODE_FIXED_8000 #%01000000

; PRG banks
.define MMC3_SELECT_PRG_8K_0 #%00000110
.define MMC3_SELECT_PRG_8K_1 #%00000111


; Mirror
.macro mmc3_set_mirror val
  LDX val
  STX MMC3_REG_MIRROR
.endmacro

.macro mmc3_set_horizontal_mirror
  mmc3_set_mirror #1
.endmacro

.macro mmc3_set_vertical_mirror
  mmc3_set_mirror #0
.endmacro


.macro mmc3_write_reg use_prg_8000, use_chr_4_2
  ; set select mmc3 mode
  .ifnblank use_prg_8000
  ORA MMC3_MODE_FIXED_8000
  .endif
  .ifnblank use_chr_4_2
  ORA MMC3_MODE_CHR_4_2
  .endif
  STA MMC3_REG_SELECT
  STX MMC3_REG_DATA
.endmacro


.macro mmc3_bank_switch_prg_0
  LDA MMC3_SELECT_PRG_8K_0
  mmc3_write_reg
.endmacro

.macro mmc3_bank_switch_prg_1
  LDA MMC3_SELECT_PRG_8K_1
  mmc3_write_reg
.endmacro


.macro mmc3_bank_switch_chr_2k0
  LDA MMC3_SELECT_CHR_2K_0
  mmc3_write_reg
.endmacro

.macro mmc3_bank_switch_chr_2k1
  LDA MMC3_SELECT_CHR_2K_1
  mmc3_write_reg
.endmacro

; set them both at once to successive banks
.macro mmc3_bank_switch_chr_2k
  mmc3_bank_switch_chr_2k0
  INX
  INX
  mmc3_bank_switch_chr_2k1
.endmacro


.macro mmc3_bank_switch_chr_1k0
  LDA MMC3_SELECT_CHR_1K_0
  mmc3_write_reg
.endmacro

.macro mmc3_bank_switch_chr_1k1
  LDA MMC3_SELECT_CHR_1K_1
  mmc3_write_reg
.endmacro

.macro mmc3_bank_switch_chr_1k2
  LDA MMC3_SELECT_CHR_1K_2
  mmc3_write_reg
.endmacro

.macro mmc3_bank_switch_chr_1k3
  LDA MMC3_SELECT_CHR_1K_3
  mmc3_write_reg
.endmacro

; set the first two to successive banks
.macro mmc3_bank_switch_chr_1k01
  mmc3_bank_switch_chr_1k0
  INX
  mmc3_bank_switch_chr_1k1
.endmacro

; set the second two to successive banks
.macro mmc3_bank_switch_chr_1k23
  mmc3_bank_switch_chr_1k2
  INX
  mmc3_bank_switch_chr_1k3
.endmacro

; set all 4 at once to successive banks
.macro mmc3_bank_switch_chr_1k
  mmc3_bank_switch_chr_1k01
  INX
  mmc3_bank_switch_chr_1k23
.endmacro


; this will acknowledge the current irq
; and reload continue with the value in latch
.macro mmc3_ack_irq
  mmc3_disable_irq
  mmc3_enable_irq
.endmacro

; any value is acceptable
.macro mmc3_enable_irq
  STA MMC3_REG_IRQ_ENABLE
.endmacro

; also acknowledges pending interrupts
.macro mmc3_disable_irq
  STA MMC3_REG_IRQ_DISABLE
.endmacro

; any value is acceptable
.macro mmc3_reload_irq
  STA MMC3_REG_IRQ_RELOAD
.endmacro

; any value is acceptable for reload
.macro mmc3_set_irq val
  mmc3_disable_irq
  .ifnblank val
  LDA val
  .endif
  STA MMC3_REG_IRQ_LATCH
  mmc3_reload_irq
  mmc3_enable_irq
.endmacro
