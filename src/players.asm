; Gravity is 0.8 fixed point
GRAVITY = $40

; Jump velocity is 8.8 fixed point
JUMP_VELOCITY = -$0600


.segment "ZEROPAGE"

PlayerX:
MarioX:             .res 1
LuigiX:             .res 1

PlayerXFrac:
MarioXFrac:         .res 1
LuigiXFrac:         .res 1

PlayerDX:
MarioDX:            .res 1
LuigiDX:            .res 1

PlayerDXFrac:
MarioDXFrac:        .res 1
LuigiDXFrac:        .res 1

PlayerY:
MarioY:             .res 1
LuigiY:             .res 1

PlayerDY:
MarioDY:            .res 1
LuigiDY:            .res 1

PlayerYFrac:
MarioYFrac:         .res 1
LuigiYFrac:         .res 1

PlayerDYFrac:
MarioDYFrac:        .res 1
LuigiDYFrac:        .res 1

PlayerAttrs:
MarioAttrs:         .res 1
LuigiAttrs:         .res 1

PlayerIsGrounded:
MarioIsGrounded:    .res 1
LuigiIsGrounded:    .res 1


ObjLeft:            .res 2
ObjTop:             .res 2
ObjRight:           .res 2
ObjBottom:          .res 2
ObjLeftPlusShift:   .res 2
ObjRightPlusShift:  .res 2


.segment "CODE"

InitPlayers:
        lda     #64
        sta     MarioX
        lda     #192
        sta     LuigiX
        lda     #0
        sta     MarioXFrac
        sta     LuigiXFrac
        sta     MarioY
        sta     LuigiY
        sta     MarioYFrac
        sta     LuigiYFrac
        sta     MarioDX
        sta     LuigiDX
        sta     MarioDXFrac
        sta     LuigiDXFrac
        sta     MarioDY
        sta     LuigiDY
        sta     MarioDYFrac
        sta     LuigiDYFrac
        lda     #0
        sta     MarioAttrs
        lda     #$41
        sta     LuigiAttrs

        lda     #FALSE
        sta     MarioIsGrounded
        sta     LuigiIsGrounded

        rts


MovePlayers:
        ldx     #0                          ; Mario
        jsr     MoveOnePlayer
        inx                                 ; Luigi
        jmp     MoveOnePlayer

MoveOnePlayer:
        lda     PlayerXFrac,x
        add     PlayerDXFrac,x
        sta     PlayerXFrac,x
        lda     PlayerX,x
        adc     PlayerDX,x
        sta     PlayerX,x

        lda     PlayerYFrac,x
        add     PlayerDYFrac,x
        sta     PlayerYFrac,x
        lda     PlayerY,x
        adc     PlayerDY,x
        sta     PlayerY,x

        lda     PlayerIsGrounded,x
        bne     @grounded

        ; Player is in midair
        lda     PlayerY,x
        cmp     #129
        blt     @not_landing
        ; Player has landed
        lda     #129                        ; snap player to the ground
        sta     PlayerY,x
        lda     #0
        sta     PlayerYFrac,x
        sta     PlayerDY,x
        sta     PlayerDYFrac,x
        lda     #TRUE
        sta     PlayerIsGrounded,x
        rts
@not_landing:
        lda     PlayerDY,x
        bmi     @rising
        cmp     #8
        bge     @terminal_velocity
        ; We're falling
        jmp     @no_extra_gravity
@rising:
        ; Apply extra gravity if A button is not held
        lda     JoyState,x
        and     #JOY_A
        bne     @no_extra_gravity
        ; A button not held; use high gravity (1 px/frame)
        inc     PlayerDY,x
        rts

@no_extra_gravity:
        lda     PlayerDYFrac,x
        add     #GRAVITY
        sta     PlayerDYFrac,x
        inc_cs  {PlayerDY,x}
        rts

@terminal_velocity:
        lda     #8
        sta     PlayerDY,x
        lda     #0
        sta     PlayerDYFrac,x
        rts


@grounded:
        lda     JoyDown,x
        and     #JOY_A
        beq     @not_jumping

        ; Jumping
        lda     #FALSE
        sta     PlayerIsGrounded,x
        lda     #>JUMP_VELOCITY
        sta     PlayerDY,x
        lda     #<JUMP_VELOCITY
        sta     PlayerDYFrac,x
        rts

@not_jumping:
        lda     JoyState,x
        and     #JOY_LEFT
        beq     @try_right
        ; Walking left
        lda     PlayerAttrs,x
        ora     #$40                        ; flip horizontal
        sta     PlayerAttrs,x
        lda     #-1
        sta     PlayerDX,x
        lda     #0
        sta     PlayerDXFrac,x
        rts
@try_right:
        ; Walking right
        lda     JoyState,x
        and     #JOY_RIGHT
        beq     @stop
        lda     PlayerAttrs,x
        and     #~$40                       ; do not flip horizontal
        sta     PlayerAttrs,x
        lda     #1
        sta     PlayerDX,x
        lda     #0
        sta     PlayerDXFrac,x
        rts
@stop:
        lda     #0
        sta     PlayerDX,x
        sta     PlayerDXFrac,x
        rts


CheckPlayerCollisions:
        ; Checkmark
        lda     #$ff
        sta     MyOAM+60
        lda     #$18
        sta     MyOAM+61
        lda     #0
        sta     MyOAM+62
        lda     #128
        sta     MyOAM+63

        lda     MarioX
        sub     #5
        sta     ObjLeft
        eor     #$80
        sta     ObjLeftPlusShift
        eor     #$80
        add     #8
        sta     ObjRight
        eor     #$80
        sta     ObjRightPlusShift
        lda     MarioY
        sub     #17
        sta     ObjTop
        add     #16
        sta     ObjBottom

        lda     LuigiX
        sub     #5
        sta     ObjLeft+1
        eor     #$80
        sta     ObjLeftPlusShift+1
        eor     #$80
        add     #8
        sta     ObjRight+1
        eor     #$80
        sta     ObjRightPlusShift+1
        lda     LuigiY
        sub     #17
        sta     ObjTop+1
        add     #16
        sta     ObjBottom+1

        ldx     #0
        ldy     #1
        jsr     CheckCollisions

        beq     :+
        ; Make checkmark visible
        lda     #32
        sta     MyOAM+60
:
        rts


; X = object 1 index
; Y = object 2 index
CheckCollisions:
        ; Check vertical collision first
        lda     ObjTop,x
        cmp     ObjBottom,y
        beq     :+
        bge     @no
:
        lda     ObjBottom,x
        cmp     ObjTop,y
        blt     @no

        ; Vertical collision matched
        ; Check simple horizontal collision
        lda     ObjLeft,x
        cmp     ObjRight,y
        beq     :+
        bge     @try_shifted
:
        lda     ObjRight,x
        cmp     ObjLeft,y
        bge     @yes
@try_shifted:
        ; Naive horizontal collision did not match
        ; Shift objects horizontally and try again
        ; (This compensates for any objects wrapping around the edges)
        lda     ObjLeftPlusShift,x
        cmp     ObjRightPlusShift,y
        beq     :+
        bge     @no
:
        lda     ObjRightPlusShift,x
        cmp     ObjLeftPlusShift,y
        blt     @no
@yes:
        lda     #TRUE
        rts

@no:
        lda     #FALSE
        rts
