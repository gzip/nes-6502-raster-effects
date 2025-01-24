
; this is like a x = y call
; clobbers A
.macro set var, val
  LDA val
  STA var
.endmacro

.macro if_zero expr
  .local not_zero
  BNE not_zero
    expr
  not_zero:
.endmacro

.macro if_not_zero expr
  .local is_zero
  BEQ is_zero
    expr
  is_zero:
.endmacro


; clobbers X
.macro set_addr addr, loc
  LDX #>addr
  STX loc+1
  LDX #<addr
  STX loc
.endmacro

; clobbers A and X
.macro setup_mem_loop addr, ct
  set_addr addr, addr_lo
  LDX ct
  STX loop_ct
.endmacro


; max 128 bytes, avoids CPX
; clobbers A and X
; ct is optional if Y is already set
.macro mem_copy_quick src, dest, ct
  .local copy_loop
  .ifblank ct
  LDX ct-1
  .endif
  copy_loop:
    LDA src,X
    STA dest,X
    DEX
  BPL copy_loop
.endmacro

; max 256 bytes
; clobbers A and X
.macro mem_copy src, dest, ct, dont_init_x
  .local copy_loop
  .ifblank dont_init_x
  LDX #$00
  .endif
  copy_loop:
    LDA src,X
    STA dest,X
    INX
    CPX ct
    BNE copy_loop
.endmacro


; clobbers Y
; loop_ct delays 5 cycles per loop + 2 cycles for assignment
; nop_ct delays 2 addtl cycles per count
; bit delays 3 addtl cycles
.macro delay loop_ct, nop_ct, bit
  .local delay_loop
  LDY loop_ct
  delay_loop:
  DEY
  BNE delay_loop
  .ifnblank nop_ct
    .repeat nop_ct
      NOP
    .endrepeat
  .endif
  .ifnblank bit
  BIT $FF
  .endif
.endmacro


; clear out ram on reset
; clobbers A and X
.macro clear_ram
  LDA #0
  LDX #0
  clear_ram_loop:
    STA $0000, X
    STA $0100, X
    STA $0200, X
    STA $0300, X
    STA $0400, X
    STA $0500, X
    STA $0600, X
    STA $0700, X
    INX
    BNE clear_ram_loop
.endmacro

.macro save_cpu_regs
  ; save cpu registers
  PHA
  TXA
  PHA
  TYA
  PHA
.endmacro

.macro restore_cpu_regs
  ; restore cpu registers
  PLA
  TAY
  PLA
  TAX
  PLA
.endmacro


; jump to address stored at addr+X
; https://www.nesdev.org/wiki/Synthetic_instructions#JMP_(addr,X)
; clobbers A
.macro JMPX addr, x_val
  LDA addr+1,x_val
  PHA
  LDA addr,x_val
  PHA
  PHP
  RTI
.endmacro
