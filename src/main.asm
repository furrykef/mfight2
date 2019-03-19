.include "nes.inc"
.include "header.inc"


MyOAM = $200


FALSE = 0
TRUE = $ff


; INC if carry set
.macro inc_cs foo
.local @skip
        bcc     @skip
        inc     foo
@skip:
.endmacro

; DEC if carry clear
.macro dec_cc foo
.local @skip
        bcs     @skip
        dec     foo
@skip:
.endmacro

; INC if zero set
.macro inc_z foo
.local @skip
        bne     @skip
        inc     foo
@skip:
.endmacro


.segment "ZEROPAGE"

FrameCounter:       .res 1

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

; One byte per player
JoyState:           .res 2
JoyPrevState:       .res 2
JoyDown:            .res 2


.include "sprites.asm"


.segment "CODE"

Main:
        sei
        cld
        ldx     #$40
        stx     $4017
        ldx     #$ff
        txs
        inx                                 ; X will now be 0
        stx     PPUCTRL                     ; no NMI
        stx     PPUMASK                     ; rendering off
        stx     DMCFREQ                     ; no DMC IRQs

        ; Wait for PPU to warm up
        bit     PPUSTATUS
@vblank1:
        bit     PPUSTATUS
        bpl     @vblank1
@vblank2:
        bit     PPUSTATUS
        bpl     @vblank2

        ; Init main RAM
        ; Value >= $ef should be used to clear OAM
        lda     #$ff
        ldx     #0
@init_ram:
        sta     $000,x
        sta     $100,x
        sta     $200,x
        sta     $300,x
        sta     $400,x
        sta     $500,x
        sta     $600,x
        sta     $700,x
        inx
        bne     @init_ram

        ; Init variables
        lda     #0
        sta     FrameCounter

        ; Clear VRAM ($2000-2fff)
        lda     #$20
        sta     PPUADDR
        lda     #0
        sta     PPUADDR
        lda     #' '
        ldx     #0
        ldy     #$10
@clear_vram:
        sta     PPUDATA
        inx
        bne     @clear_vram
        dey
        bne     @clear_vram

        jmp     BeginRound


BeginRound:
        lda     #64
        sta     MarioX
        lda     #192
        sta     LuigiX
        lda     #129
        sta     MarioY
        sta     LuigiY
        lda     #0
        sta     MarioAttrs
        lda     #$41
        sta     LuigiAttrs
        jsr     RenderOff
        jsr     LoadPalette
        jsr     LoadArenaBG
        jsr     RenderOn
MainLoop:
        jsr     RenderSprites
        jsr     EndFrame
        jsr     MovePlayers
        jmp     MainLoop


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


LoadPalette:
        ; Load palette
        lda     #$3f
        sta     PPUADDR
        lda     #$00
        sta     PPUADDR
        ldx     #0
@copy_palette:
        lda     Palette,x
        sta     PPUDATA
        inx
        cpx     #PaletteSize
        bne     @copy_palette
        rts


LoadArenaBG:
        lda     #$22
        sta     PPUADDR
        lda     #$00
        sta     PPUADDR
        lda     #1
.repeat 32
        sta     PPUDATA
.endrepeat
        rts


RenderOff:
        lda     #0
        sta     PPUCTRL
        sta     PPUMASK
        rts

RenderOn:
        lda     #$90
        sta     PPUCTRL
        rts


EndFrame:
        lda     FrameCounter
@loop:
        cmp     FrameCounter
        beq     @loop
        jsr     ReadJoys
        rts


ReadJoys:
        ldy     #0                          ; player 0 controller
        jsr     ReadOneJoy
        iny                                 ; player 1 controller
        jmp     ReadOneJoy

; Y = joy ID (0 = player 1)
ReadOneJoy:
        lda     JoyState,y
        sta     JoyPrevState,y
        jsr     ReadJoyImpl
@no_match:
        sta     JoyState,y
        jsr     ReadJoyImpl
        cmp     JoyState,y
        bne     @no_match
        eor     JoyPrevState,y             ; get buttons that have changed
        and     JoyState,y                 ; filter out buttons not currently pressed
        sta     JoyDown,y
        rts

ReadJoyImpl:
        ldx     #1
        stx     JOYSTROBE
        dex
        stx     JOYSTROBE
        txa
        ldx     #8
@loop:
        pha
        lda     JOY1,y
        and     #$03
        cmp     #$01                        ; carry will be set if A is nonzero
        pla                                 ; (i.e., if the button is pressed)
        ror
        dex
        bne     @loop
        rts


HandleVblank:
        bit     PPUSTATUS                   ; make sure vblank flag gets cleared
        pha
        txa
        pha
        tya
        pha

        lda     #$00
        sta     OAMADDR
        lda     #>MyOAM
        sta     OAMDMA

        lda     #$1e
        sta     PPUMASK

        lda     #0
        sta     PPUSCROLL
        sta     PPUSCROLL

        inc     FrameCounter
        pla
        tay
        pla
        tax
        pla
        rti


Palette:
.incbin "../assets/mfight.pal.dat"
PaletteSize = * - Palette


.segment "VECTORS"

        .addr   HandleVblank                ; NMI
        .addr   Main                        ; RESET
        .addr   Main                        ; IRQ/BRK


.segment "CHR"
.incbin "../assets/mfight.chr"
