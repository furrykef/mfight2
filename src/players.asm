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


.segment "CODE"

MovePlayers:
        ldx     #0
        jsr     MoveOnePlayer
        inx
        jmp     MoveOnePlayer

MoveOnePlayer:
        lda     #FALSE
        sta     PlayerIsWalking,x

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
