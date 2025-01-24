; based on nes-starter-kit and nerdy nights

.define GAMEPAD         $4016

.define BUTTON_A        #%10000000
.define BUTTON_B        #%01000000
.define BUTTON_SELECT   #%00100000
.define BUTTON_START    #%00010000
.define BUTTON_UP       #%00001000
.define BUTTON_DOWN     #%00000100
.define BUTTON_LEFT     #%00000010
.define BUTTON_RIGHT    #%00000001


.macro read_button_state button, state, action
  .local no_action
  LDA button
  BIT state
  .ifnblank action
    BEQ no_action
    action
    no_action:
  .endif
.endmacro

.macro check_button button, action
  read_button_state button, buttons, action
.endmacro

.macro check_button_press button, action
  read_button_state button, buttons_press, action
.endmacro

.macro check_button_release button, action
  read_button_state button, buttons_release, action
.endmacro


.segment "ZEROPAGE"
    buttons: .res 1
    buttons_prev: .res 1
    buttons_press: .res 1
    buttons_release: .res 1

.segment "CODE"

; initialize and set the gamepad values
.proc poll_gamepad

    ; save previous buttons
    set buttons_prev, buttons

    ; latch gamepad for read
    set GAMEPAD, #1
    set GAMEPAD, #0

    LDX #$08
  : LDA GAMEPAD
    LSR A
    ROL buttons
    DEX
    BNE :-

    ; to find out if this is a newly pressed button, load the last buttons pressed, and
    ; flip all the bits with an EOR #$FF.  Then you can AND the results with current
    ; gamepad pressed.  This will give you what wasn't pressed previously, but what is
    ; pressed now.  Then store that value in the buttons_press
    LDA buttons_prev
    EOR #$FF
    AND buttons

    STA buttons_press ; all these buttons are new presses and not existing presses

    ; in order to find what buttons were just released, we load and flip the buttons that
    ; are currently pressed  and and it with what was pressed the last time.
    ; that will give us a button that is not pressed now, but was pressed previously
    LDA buttons       ; reload original buttons flags
    EOR #$FF                ; flip the bits so we have 1 everywhere a button is released

    ; anding with last press shows buttons that were pressed previously and not pressed now
    AND buttons_prev

    ; then store the results in buttons_release
    STA buttons_release  ; a 1 flag in a button position means a button was just released
    RTS

.endproc
