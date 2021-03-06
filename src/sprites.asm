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
        lda     PlayerXH,x
        sta     SprX
        lda     PlayerYH,x
        sta     SprY
        lda     PlayerIsGrounded,x
        bne     @grounded

        ; Player is in midair
        lda     #$0c
        jmp     @not_walking

@grounded:
        lda     PlayerDXH,x
        bne     @walking
        lda     PlayerDXL,x
        beq     @not_walking                ; note the tile index will be 0
@walking:
        ; Player is walking
        ; Which frame of walk cycle is used is determined by player's X coordinate
        lda     PlayerXH,x
        and     #$0c
        lsr
        lsr
        tay
        lda     WalkCycle,y

@not_walking:
        sta     SprTileIdx
        lda     PlayerAttrs,x
        sta     SprAttrs
        txa                                 ; Convert player ID to OAM index (multiply by 16)
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
        ; Sprite is flipped horizontally, so we have to reverse the left and right halves
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
        sub     #17
        sta     MyOAM,y
        sta     MyOAM+8,y
        add     #8
        sta     MyOAM+4,y
        sta     MyOAM+12,y

        rts
