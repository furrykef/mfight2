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

; Temp variables
T0:                 .res 1
T1:                 .res 1
T2:                 .res 1
T3:                 .res 1

FrameCounter:       .res 1

; One byte per player
JoyState:           .res 2
JoyPrevState:       .res 2
JoyDown:            .res 2


.include "players.asm"
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
        jsr     InitPlayers
        jsr     RenderOff
        jsr     LoadPalette
        jsr     LoadArenaIntoVram
        jsr     RenderOn
MainLoop:
        jsr     MovePlayers
        jsr     CheckPlayerCollisions
        jsr     RenderSprites
        jsr     EndFrame
        jmp     MainLoop


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


LoadArenaIntoVram:
        lda     #$20
        sta     PPUADDR
        lda     #$00
        sta     PPUADDR

        ldx     #0
.repeat 4, I
:
        lda     Arena+I*256,x
        sta     PPUDATA
        inx
        bne     :-
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


Arena:
.incbin "../assets/arena.nam"


.segment "VECTORS"

        .addr   HandleVblank                ; NMI
        .addr   Main                        ; RESET
        .addr   Main                        ; IRQ/BRK


.segment "CHR"
.incbin "../assets/mfight.chr"
