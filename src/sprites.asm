OAM_IDX_MARIO = 0
OAM_IDX_LUIGI = 16


.segment "ZEROPAGE"

SprX:           .res 1
SprY:           .res 1
SprTileIdx:     .res 1
SprAttrs:       .res 1


.segment "CODE"

RenderSprites:
        ldx     #0
        jsr     RenderOnePlayer
        inx
        jmp     RenderOnePlayer


; X = player ID
RenderOnePlayer:
        lda     PlayerX,x
        sta     SprX
        lda     PlayerY,x
        sta     SprY
        lda     #0
        lda     PlayerIsWalking,x
        beq     @not_walking

        ; Player is walking
        lda     PlayerX,x
        and     #$0c
        lsr
        lsr
        tay
        lda     WalkCycle,y

@not_walking:
        sta     SprTileIdx
        lda     PlayerAttrs,x
        sta     SprAttrs
        txa
        asl
        asl
        asl
        asl
        tay
        jmp     Render16x16

WalkCycle:
        .byte   0, 4, 0, 8


; Input:
;   Y = OAM index
Render16x16:
        ; Attributes
        lda     SprAttrs
        sta     MyOAM+2,y
        sta     MyOAM+6,y
        sta     MyOAM+10,y
        sta     MyOAM+14,y

        ; Tile indexes
        lda     SprTileIdx
        bit     SprAttrs                    ; is the sprite flipped horizontally?
        bvs     @flipped
        sta     MyOAM+1,y
        add     #1
        sta     MyOAM+5,y
        adc     #1
        sta     MyOAM+9,y
        adc     #1
        sta     MyOAM+13,y
        jmp     @not_flipped

@flipped:
        ; Sprite is flipped horizontally, so we have to flip the halves
        sta     MyOAM+9,y
        add     #1
        sta     MyOAM+13,y
        adc     #1
        sta     MyOAM+1,y
        adc     #1
        sta     MyOAM+5,y

@not_flipped:
        ; X coordinates
        lda     SprX
        sta     MyOAM+11,y
        sta     MyOAM+15,y
        sub     #8
        sta     MyOAM+3,y
        sta     MyOAM+7,y

        ; Y coordinates
        lda     SprY
        sub     #18
        sta     MyOAM,y
        sta     MyOAM+8,y
        add     #8
        sta     MyOAM+4,y
        sta     MyOAM+12,y

        rts
