; Gravity is 0.8 fixed point
GRAVITY = $40

; Jump velocity is 8.8 fixed point
JUMP_VELOCITY = -$0600

; Acceleration is 0.8 fixed point
WALK_ACCEL = $30

; Maximum speed is 8.8 fixed point
WALK_MAX_SPEED = $0180


.segment "ZEROPAGE"

PlayerXH:
MarioXH:            .res 1
LuigiXH:            .res 1

PlayerXL:
MarioXL:            .res 1
LuigiXL:            .res 1

PlayerDXH:
MarioDXH:           .res 1
LuigiDXH:           .res 1

PlayerDXL:
MarioDXL:           .res 1
LuigiDXL:           .res 1

PlayerYH:
MarioYH:            .res 1
LuigiYH:            .res 1

PlayerYL:
MarioYL:            .res 1
LuigiYL:            .res 1

PlayerDYH:
MarioDYH:           .res 1
LuigiDYH:           .res 1

PlayerDYL:
MarioDYL:           .res 1
LuigiDYL:           .res 1

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
        sta     MarioXH
        lda     #192
        sta     LuigiXH
        lda     #0
        sta     MarioXL
        sta     LuigiXL
        sta     MarioYH
        sta     LuigiYH
        sta     MarioYL
        sta     LuigiYL
        sta     MarioDXH
        sta     LuigiDXH
        sta     MarioDXL
        sta     LuigiDXL
        sta     MarioDYH
        sta     LuigiDYH
        sta     MarioDYL
        sta     LuigiDYL
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
        lda     PlayerXL,x
        add     PlayerDXL,x
        sta     PlayerXL,x
        lda     PlayerXH,x
        adc     PlayerDXH,x
        sta     PlayerXH,x

        lda     PlayerYL,x
        add     PlayerDYL,x
        sta     PlayerYL,x
        lda     PlayerYH,x
        adc     PlayerDYH,x
        sta     PlayerYH,x

        ; If the player is too far down, flip his priority so he goes behind the lava tiles
        cmp     #200
        blt     @not_falling_into_lava
        lda     PlayerAttrs,x
        ora     #$20
        sta     PlayerAttrs,x
@not_falling_into_lava:

        ; Collide with BG (but only if we're not rising)
        lda     PlayerDYH,x
        bmi     @in_midair                  ; rising
        jsr     CheckPlayerBGCollision
        sta     PlayerIsGrounded,x
        beq     @in_midair

        ; Player is on ground; snap to tile boundary
        lda     PlayerYH,x
        and     #$f8
        sta     PlayerYH,x
        lda     #0
        sta     PlayerYL,x
        ; Kill vertical velocity
        sta     PlayerDYH,x
        sta     PlayerDYL,x

        ; Is player beginning a jump?
        lda     JoyDown,x
        and     #JOY_A
        beq     @check_horizontal_movement

        ; Jumping
        lda     #FALSE
        sta     PlayerIsGrounded,x
        lda     #>JUMP_VELOCITY
        sta     PlayerDYH,x
        lda     #<JUMP_VELOCITY
        sta     PlayerDYL,x
        jmp     @check_horizontal_movement

@in_midair:
        lda     PlayerDYH,x
        bmi     @rising
        cmp     #7
        bge     @terminal_velocity
        ; We're falling
        jmp     @no_extra_gravity
@rising:
        ; Apply extra gravity if A button is not held
        lda     JoyState,x
        and     #JOY_A
        bne     @no_extra_gravity
        ; A button not held; use high gravity (1 px/frame)
        inc     PlayerDYH,x
        jmp     @check_horizontal_movement

@no_extra_gravity:
        lda     PlayerDYL,x
        add     #GRAVITY
        sta     PlayerDYL,x
        inc_cs  {PlayerDYH,x}
        jmp     @check_horizontal_movement

@terminal_velocity:
        lda     #7
        sta     PlayerDYH,x
        lda     #0
        sta     PlayerDYL,x
        jmp     @check_horizontal_movement

@check_horizontal_movement:
        lda     PlayerIsGrounded,x
        sta     T0
        lda     #WALK_ACCEL
        bit     T0
        bmi     :+
        lsr                                 ; reduce acceleration while in midair
:
        sta     Accel

        lda     JoyState,x
        and     #JOY_LEFT
        beq     @try_right
        ; Moving left
        lda     PlayerIsGrounded,x          ; don't allow flipping if in midair
        beq     :+
        lda     PlayerAttrs,x
        ora     #$40                        ; flip horizontal
        sta     PlayerAttrs,x
:
        jmp     ApplyAccelLeft
@try_right:
        ; Moving right
        lda     JoyState,x
        and     #JOY_RIGHT
        beq     @stop
        lda     PlayerIsGrounded,x          ; don't allow flipping if in midair
        beq     :+
        lda     PlayerAttrs,x
        and     #~$40                       ; do not flip horizontal
        sta     PlayerAttrs,x
:
        jmp     ApplyAccelRight
@stop:
        lda     #0
        sta     PlayerDXH,x
        sta     PlayerDXL,x
        rts


; @TODO@ decelerate if exceeding min velocity
ApplyAccelLeft:
        ; Don't accelerate if our horizontal velocity <= minimum
        ; (This is a signed comparison; result is in N flag instead of C flag)
        lda     PlayerDXL,x
        cmp     #<(-WALK_MAX_SPEED)
        lda     PlayerDXH,x
        sbc     #>(-WALK_MAX_SPEED)
        bvc     @dont_flip_sign
        eor     #$80
@dont_flip_sign:
        bmi     @end                        ; bail if our speed's already maxed out

        ; Apply acceleration
        lda     PlayerDXL,x
        sub     Accel
        sta     PlayerDXL,x
        dec_cc  {PlayerDXH,x}

        ; If we exceed min velocity, clamp it.
        cmp     #<-(WALK_MAX_SPEED)
        lda     PlayerDXH,x
        sbc     #>-(WALK_MAX_SPEED)
        bvc     @dont_flip_sign2
        eor     #$80
@dont_flip_sign2:
        bpl     @end                        ; we're done if speed is less than max

        ; Exceeded min; clamp
        lda     #<(-WALK_MAX_SPEED)
        sta     PlayerDXL,x
        lda     #>(-WALK_MAX_SPEED)
        sta     PlayerDXH,x

@end:
        rts


; @TODO@ decelerate if exceeding max velocity
ApplyAccelRight:
        ; Don't accelerate if our horizontal velocity >= maximum
        ; (This is a signed comparison; result is in N flag instead of C flag)
        lda     PlayerDXL,x
        cmp     #<WALK_MAX_SPEED
        lda     PlayerDXH,x
        sbc     #>WALK_MAX_SPEED
        bvc     @dont_flip_sign
        eor     #$80
@dont_flip_sign:
        bpl     @end                        ; bail if our speed's already maxed out

        ; Apply acceleration
        lda     PlayerDXL,x
        add     Accel
        sta     PlayerDXL,x
        inc_cs  {PlayerDXH,x}

        ; If we exceed max velocity, clamp it.
        cmp     #<WALK_MAX_SPEED
        lda     PlayerDXH,x
        sbc     #>WALK_MAX_SPEED
        bvc     @dont_flip_sign2
        eor     #$80
@dont_flip_sign2:
        bmi     @end                        ; we're done if speed is less than max

        ; Exceeded max; clamp
        lda     #<WALK_MAX_SPEED
        sta     PlayerDXL,x
        lda     #>WALK_MAX_SPEED
        sta     PlayerDXH,x

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
        lda     PlayerYH,x                   ; A will be the LSB

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
        lda     PlayerXH,x
        lsr                                 ; convert from pixels to tiles
        lsr
        lsr
        tay
        lda     (T0),y
        rts


CheckPlayerCollisions:
        lda     MarioXH
        sub     #5
        sta     ObjLeft
        eor     #$80
        sta     ObjLeftPlusShift
        eor     #$80
        add     #8
        sta     ObjRight
        eor     #$80
        sta     ObjRightPlusShift
        lda     MarioYH
        sta     ObjBottom
        sub     #16
        sta     ObjTop

        ; @FIXME@ duplicate code
        lda     LuigiXH
        sub     #5
        sta     ObjLeft+1
        eor     #$80
        sta     ObjLeftPlusShift+1
        eor     #$80
        add     #8
        sta     ObjRight+1
        eor     #$80
        sta     ObjRightPlusShift+1
        lda     LuigiYH
        sta     ObjBottom+1
        sub     #16
        sta     ObjTop+1

        ldx     #0
        ldy     #1
        jsr     CheckObjCollision

        beq     @no_collision

        ; Swap velocity between Mario and Luigi
        swap MarioDXH, LuigiDXH
        swap MarioDXL, LuigiDXL
        swap MarioDYH, LuigiDYH
        swap MarioDYL, LuigiDYL

        ; Let's exaggerate horizontal collisions a bit
.repeat 2
        asl     MarioDXL
        rol     MarioDXH
        asl     LuigiDXL
        rol     LuigiDXH
.endrepeat

@no_collision:
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
