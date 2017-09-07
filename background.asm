  .inesprg 8   ; 8x 16KB PRG code
  .ineschr 0   ; 1x  8KB CHR data
  .inesmap $20   ; mapper 0 = NROM, no bank swapping
  .inesmir $08   ; background mirroring
  

;;;;;;;;;;;;;;;
;	Bank structure:
;	0: $0000 - $1FFF
;	1: $2000 - $3FFF
;	2: $4000 - $5FFF
;	3: $6000 - 
;
;
;
;
;
;;;;;;;;;;;;;;;

PPUMASK EQU $2001
PPUADDR EQU $2006
PPUDATA EQU $2007

   .rsset $0000
CUR_BG_TILE .rs 1   
NEXT_BG     .rs 1
BULK_DRAW_FLAG .rs 1
LAST_B		   .rs 1
CUR_B		   .rs 1
CUR_BANK	   .rs 1
chr_data_ptr   .rs 2
  .bank 14
  .org $C000
chr_data: .incbin "test_rows.chr"   ;includes 8KB graphics file
  .bank 15
  .org $E000 
RESET:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX $4017    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX $2000    ; disable NMI
  STX $2001    ; disable rendering
  STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT $2002
  BPL vblankwait1

clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x
  INX
  BNE clrmem
   
vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2


LoadPalettes:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006             ; write the high byte of $3F00 address
  LDA #$00
  STA $2006             ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA palette, x        ; load data from address (palette + the value in x)
                          ; 1st time through loop it will load palette+0
                          ; 2nd time through loop it will load palette+1
                          ; 3rd time through loop it will load palette+2
                          ; etc
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down
              
  LDA #$20
  STA CUR_BG_TILE  
  LDA #$00
  STA BULK_DRAW_FLAG
              
  JSR LoadBackground
  jsr copy_mytiles_chr
              
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000

  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA $2001

Forever:
LatchController:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016       ; tell both the controllers to latch buttons
  
ReadA: 
  LDA $4016       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadADone   ; branch to ReadADone if button is NOT pressed (0)
                  ; add instructions here to do something when button IS pressed (1)
ReadADone:        ; handling this button is done
  
ReadB: 
  LDA $4016       ; player 1 - B
  AND #%00000001  ; only look at bit 0
  BEQ ReadBNoPress   ; branch to ReadBDone if button is NOT pressed (0)
                  ; add instructions here to do something when button IS pressed (1)
  LDA #$1
  STA CUR_B
  JMP ReadBDone
ReadBNoPress:        ; handling this button is done
  LDA #$00
  STA CUR_B
  LDA LAST_B
  BEQ ReadBDone
  LDA CUR_BG_TILE
  CLC
  ADC #$10
  STA CUR_BG_TILE
  LDA #$1
  STA BULK_DRAW_FLAG
  LDA #%00000110
  STA $2001
  JSR LoadBackground
  LDA #$00
  STA BULK_DRAW_FLAG
  LDA #%00011110
  STA $2001
ReadBDone:
  LDA CUR_B
  STA LAST_B
  JMP Forever     ;jump back to Forever, infinite loop
  
 

NMI:
  ;LDA #$00
  ;STA $2003       ; set the low byte (00) of the RAM address
  ;LDA #$02
  ;STA $4014       ; set the high byte (02) of the RAM address, start the transfer
  LDA BULK_DRAW_FLAG
  BNE NMI_DONE

  ;;This is the PPU clean up section, so rendering the next frame starts properly.
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000
  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA $2001
  LDA #$00        ;;tell the ppu there is no background scrolling
  STA $2005
  STA $2005
NMI_DONE:
  RTI             ; return from interrupt
 
;;;;;;;;;;;;;;  
  
LoadBackground:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$20
  STA $2006             ; write the high byte of $2000 address
  LDA #$00
  STA $2006             ; write the low byte of $2000 address
  LDX #$1E              ; start out at 0
  LDY #$20
LoadBackgroundLoop:
  LDA CUR_BG_TILE     ; load data from address (background + the value in x)
  STA $2007             ; write to PPU
  DEY                   ; X = X + 1
  BNE LoadBackgroundLoop  ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
  LDY #$20
  DEX
  BNE LoadBackgroundLoop
  RTS  
  
bankswitch_y:
  sty CUR_BANK
bankswitch_nosave:
  lda banktable, y
  sta banktable, y
  rts
  
copy_mytiles_chr
  lda #$00
  sta chr_data_ptr
  lda #$C0
  sta chr_data_ptr+1
  
  ldy #0
  sty PPUMASK
  sty PPUADDR
  sty PPUADDR
  ldx #32
loop:
  lda [chr_data_ptr],y
  sta PPUDATA
  iny
  bne loop
  inc chr_data_ptr+1
  dex
  bne loop
  rts  
  
palette:
  .db $22,$29,$1A,$0F,  $22,$36,$17,$0F,  $22,$30,$21,$0F,  $22,$27,$17,$0F   ;;background palette
  .db $22,$1C,$15,$14,  $22,$02,$38,$3C,  $22,$1C,$15,$14,  $22,$02,$38,$3C   ;;sprite palette

banktable:
  .db $00, $01, $02, $03, $04, $05, $06
  .db $07, $08, $09, $0A, $0B, $0C, $0D, $0E

  .org $FFFA     ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial
  