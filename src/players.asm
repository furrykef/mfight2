; Gravity is 0.8 fixed point
GRAVITY = $40

; Jump velocity is 8.8 fixed point
JUMP_VELOCITY = -$0600

; Acceleration is 0.8 fixed point
WALK_ACCEL = $30

; Maximum speed is 8.8 fixed point
WALK_MAX_SPEED = $0180


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


Accel:              .res 1


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

        ; Collide, but only if we're not rising
        jsr     CheckPlayerBGCollision
        sta     PlayerIsGrounded,x
        beq     @in_midair

        ; Player is on ground; snap to tile boundary
        lda     PlayerY,x
        and     #$f8
        ;add     #7
        sta     PlayerY,x
        ; Kill vertical velocity
        lda     #0
        sta     PlayerYFrac,x
        sta     PlayerDY,x
        sta     PlayerDYFrac,x

        ; Is player jumping?
        lda     JoyDown,x
        and     #JOY_A
        beq     @check_horizontal_movement

        ; Jumping
        lda     #FALSE
        sta     PlayerIsGrounded,x
        lda     #>JUMP_VELOCITY
        sta     PlayerDY,x
        lda     #<JUMP_VELOCITY
        sta     PlayerDYFrac,x
        jmp     @check_horizontal_movement

@in_midair:
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
        jmp     @check_horizontal_movement

@no_extra_gravity:
        lda     PlayerDYFrac,x
        add     #GRAVITY
        sta     PlayerDYFrac,x
        inc_cs  {PlayerDY,x}
        jmp     @check_horizontal_movement

@terminal_velocity:
        lda     #8
        sta     PlayerDY,x
        lda     #0
        sta     PlayerDYFrac,x
        jmp     @check_horizontal_movement

@check_horizontal_movement:
        lda     PlayerIsGrounded,x
        sta     T0
        lda     #WALK_ACCEL
        bit     T0
        bmi     :+
        lsr                                 ; halve acceleration while in midair
:
        sta     Accel

        lda     JoyState,x
        and     #JOY_LEFT
        beq     @try_right
        ; Moving left
        lda     PlayerAttrs,x
        ora     #$40                        ; flip horizontal
        sta     PlayerAttrs,x
        jmp     ApplyAccelLeft
@try_right:
        ; Moving right
        lda     JoyState,x
        and     #JOY_RIGHT
        beq     @stop
        lda     PlayerAttrs,x
        and     #~$40                       ; do not flip horizontal
        sta     PlayerAttrs,x
        jmp     ApplyAccelRight
@stop:
        lda     #0
        sta     PlayerDX,x
        sta     PlayerDXFrac,x
        rts


; @TODO@ decelerate if exceeding min velocity
ApplyAccelLeft:
        ; Don't accelerate if our horizontal velocity <= minimum
        ; (This is a signed comparison; result is in N flag instead of C flag)
        lda     PlayerDXFrac,x
        cmp     #<(-WALK_MAX_SPEED)
        lda     PlayerDX,x
        sbc     #>(-WALK_MAX_SPEED)
        bvc     @dont_flip_sign
        eor     #$80
@dont_flip_sign:
        bmi     @end                        ; bail if our speed's already maxed out

        ; Apply acceleration
        lda     PlayerDXFrac,x
        sub     Accel
        sta     PlayerDXFrac,x
        dec_cc  {PlayerDX,x}

        ; If we exceed min velocity, clamp it.
        cmp     #<-(WALK_MAX_SPEED)
        lda     PlayerDX,x
        sbc     #>-(WALK_MAX_SPEED)
        bvc     @dont_flip_sign2
        eor     #$80
@dont_flip_sign2:
        bpl     @end                        ; we're done if speed is less than max

        ; Exceeded min; clamp
        lda     #<(-WALK_MAX_SPEED)
        sta     PlayerDXFrac,x
        lda     #>(-WALK_MAX_SPEED)
        sta     PlayerDX,x

@end:
        rts


; @TODO@ decelerate if exceeding max velocity
ApplyAccelRight:
        ; Don't accelerate if our horizontal velocity >= maximum
        ; (This is a signed comparison; result is in N flag instead of C flag)
        lda     PlayerDXFrac,x
        cmp     #<WALK_MAX_SPEED
        lda     PlayerDX,x
        sbc     #>WALK_MAX_SPEED
        bvc     @dont_flip_sign
        eor     #$80
@dont_flip_sign:
        bpl     @end                        ; bail if our speed's already maxed out

        ; Apply acceleration
        lda     PlayerDXFrac,x
        add     Accel
        sta     PlayerDXFrac,x
        inc_cs  {PlayerDX,x}

        ; If we exceed max velocity, clamp it.
        cmp     #<WALK_MAX_SPEED
        lda     PlayerDX,x
        sbc     #>WALK_MAX_SPEED
        bvc     @dont_flip_sign2
        eor     #$80
@dont_flip_sign2:
        bmi     @end                        ; we're done if speed is less than max

        ; Exceeded max; clamp
        lda     #<WALK_MAX_SPEED
        sta     PlayerDXFrac,x
        lda     #>WALK_MAX_SPEED
        sta     PlayerDX,x

@end:
        rts


CheckPlayerBGCollision:
        jsr     GetBGTileAtPlayer
        cmp     #1
        beq     @yes
        lda     #FALSE
        rts
@yes:
        lda     #TRUE
        rts


GetBGTileAtPlayer:
        ; T0 will point to the start of the row in the Arena array
        ; IOW, T0 = Arena + PlayerTileY*32
        lda     #<Arena
        sta     T0
        lda     #>Arena
        sta     T1

        lda     #0
        sta     T2                          ; MSB of addend
        lda     PlayerY,x                   ; A will be the LSB

        ; Divide by 8 to convert pixels to tiles, then multiply by 32 to convert to array index.
        ; This is equivalent to shifting right by three, then left by five, or (as here)
        ; clearing the three least significant bits, then shifting left by two.
        and     #$f8
        asl
        rol     T2
        asl
        rol     T2

        ; Add to the pointer
        add     T0
        sta     T0
        lda     T2
        adc     T1
        sta     T1

        ; T0 now points to the start of the row we're on
        lda     PlayerX,x
        lsr                                 ; convert from pixels to tiles
        lsr
        lsr
        tay
        lda     (T0),y
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
        sta     ObjBottom
        sub     #16
        sta     ObjTop

        ; @FIXME@ duplicate code
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
        sta     ObjBottom+1
        sub     #16
        sta     ObjTop+1

        ldx     #0
        ldy     #1
        jsr     CheckObjCollision

        beq     :+
        ; Make checkmark visible
        lda     #32
        sta     MyOAM+60
:
        rts


; X = object 1 index
; Y = object 2 index
CheckObjCollision:
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
