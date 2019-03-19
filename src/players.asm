.segment "ZEROPAGE"

PlayerX:
MarioX:             .res 1
LuigiX:             .res 1

PlayerY:
MarioY:             .res 1
LuigiY:             .res 1

PlayerAttrs:
MarioAttrs:         .res 1
LuigiAttrs:         .res 1

PlayerIsWalking:
MarioIsWalking:     .res 1
LuigiIsWalking:     .res 1

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
        sta     MarioY
        sta     LuigiY
        lda     #0
        sta     MarioAttrs
        lda     #$41
        sta     LuigiAttrs

        lda     #FALSE
        sta     MarioIsWalking
        sta     LuigiIsWalking
        sta     MarioIsGrounded
        sta     LuigiIsGrounded

        rts


MovePlayers:
        ldx     #0                          ; Mario
        jsr     MoveOnePlayer
        inx                                 ; Luigi
        jmp     MoveOnePlayer

MoveOnePlayer:
        lda     #FALSE
        sta     PlayerIsWalking,x

        lda     PlayerIsGrounded,x
        bne     @grounded

        ; Player is in midair
        lda     PlayerY,x
        add     #4
        sta     PlayerY,x
        cmp     #129
        blt     :+
        ; Player has landed
        lda     #129                        ; snap player to the ground
        sta     PlayerY,x
        lda     #TRUE
        sta     PlayerIsGrounded,x
:
        rts


@grounded:
        lda     JoyState,x
        and     #JOY_LEFT
        beq     @try_right
        ; Walking left
        lda     #TRUE
        sta     PlayerIsWalking,x
        lda     PlayerAttrs,x
        ora     #$40                        ; flip horizontal
        sta     PlayerAttrs,x
        dec     PlayerX,x
        rts
@try_right:
        ; Walking right
        lda     JoyState,x
        and     #JOY_RIGHT
        beq     @end
        lda     #TRUE
        sta     PlayerIsWalking,x
        lda     PlayerAttrs,x
        and     #~$40                       ; do not flip horizontal
        sta     PlayerAttrs,x
        inc     PlayerX,x
@end:
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
