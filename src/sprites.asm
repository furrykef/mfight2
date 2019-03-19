OAM_IDX_MARIO = 0
OAM_IDX_LUIGI = 16


.segment "ZEROPAGE"

SprX:           .res 1
SprY:           .res 1
SprTileIdx:     .res 1
SprAttrs:       .res 1


.segment "CODE"

RenderMario:
        ldy     #OAM_IDX_MARIO
        lda     MarioX
        sta     SprX
        lda     MarioY
        sta     SprY
        lda     #0
        bit     MarioIsWalking
        bpl     @not_walking

        ; Player is walking
        lda     FrameCounter
        and     #$0c
        lsr
        lsr
        tax
        lda     WalkCycle,x

@not_walking:
        sta     SprTileIdx
        lda     MarioAttrs
        sta     SprAttrs
        jmp     Render16x16

RenderLuigi:
        ldy     #OAM_IDX_LUIGI
        lda     LuigiX
        sta     SprX
        lda     LuigiY
        sta     SprY
        lda     #4
        sta     SprTileIdx
        lda     #$41
        sta     SprAttrs
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
