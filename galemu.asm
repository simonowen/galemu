; Galaksija Emulator v1.0
;
; WWW: http://simonowen.com/sam/galemu/
;
; Original Spectrum version by Tomaz Kac
; SAM Coupe port and enhancements by Simon Owen

gal_screen: equ &2800   ; Galaksija display
sam_screen: equ &c000   ; SAM screen
sam_scrlen: equ &1800   ; SAM mode 2 data and attr size
sam_attrs:  equ sam_screen+&2000
bkg_colour: equ 0       ; 0 = black, 5 = teal

               org  sam_screen+sam_scrlen  ; &d800
               dump $
               autoexec

start:         di

               ld  a,%00100000      ; second black, as paper uses first one
               out (&fe),a          ; set border colour
               ld  a,&ff            ; non-screen line
               out (&f9),a          ; disable line interrupts
               in  a,(&fc)          ; read VMPR
               ld  (old_vmpr+1),a   ; save for return to BASIC
               ld  a,%00100010      ; mode 2 + page 2
               out (&fc),a          ; set VMPR
               ld  a,%00100100      ; ROM0 off + page 4
               out (&fa),a          ; set LMPR

               ld  bc,&00f8         ; palette position 0
               ld  a,bkg_colour     ; SAM palette colour
               out (c),a            ; set CLUT

               ld  (basic_sp+1),sp
restore_sp:    ld  sp,new_stack     ; safe on 1st run, ROM stack on subsequent runs
               jr  cold_start       ; JR patched to LD A,n on exit to SAM BASIC
               call wait_no_key     ; wait for Return to be released
               jp  resume

cold_start:    ld  hl,sam_attrs     ; mode 2 attributes
               ld  bc,&1838         ; 24 blocks of 256, black on white
attrlp:        ld  (hl),c
               inc l
               jp  nz,attrlp
               inc h
               djnz attrlp

               ld  h,&20            ; clear from &2000
               ld  bc,&a000         ; 160 blocks of 256, &00 fill
clearlp:       ld  (hl),c
               inc l
               jp  nz,clearlp
               inc h
               djnz clearlp

; Patch ROM IM1 handler
               ld  a,&c3            ; JP
               ld  (&0038),a        ; start of IM 1 handler, before PUSHes
               ld  hl,int_handler
               ld  (&0039),hl
               ld  a,&c9            ; RET
               ld  (&00fd),a        ; end of IM 1 handler, before POPs

; Patch ROM OLD (LOAD)
               ld  a,&c3            ; JP  (must be JP to avoid any stack use)
               ld  (&0e97),a
               ld  hl,old_handler
               ld  (&0e98),hl

; Patch RAM TEST to limit to 34K RAM after the 8K ROM
               ld  a,&21            ; LD HL,nn
               ld  (&03ea),a
               ld  hl,gal_screen+&8000   ; set RAMTOP at mirror screen
               ld  (&03eb),hl


; Create lookup table to fix swapped bits 6+7 in character values
               ld  hl,char_lookup
lookuplp:      ld  a,l
               and &bf
               rla                  ; double for lookup, and move bit 7 to carry
               jr  nc,not_7
               or  &80              ; set new bit 7 from old bit 7
not_7:         ld  (hl),a
               inc l
               jp  nz,lookuplp

; Create lookup table for each character address on the SAM screen
               ld  hl,char_addrs
               ld  de,sam_screen
               ld  a,16             ; 16 rows
chrlp1:        ld  b,32             ; 32 columns
chrlp2:        ld (hl),e
               inc hl
               ld (hl),d
               inc hl
               inc de
               djnz chrlp2
               ex  de,hl
               ld  bc,11*32         ; advance to start of next character
               add hl,bc
               ex  de,hl
               dec a
               jr  nz,chrlp1

; start the emulation
               im  1
               ei
               jp  &0000


old_handler:   di
               ld  a,&3e            ; LD A,n  (A doesn't need preserving here)
               ld  (old_jr),a

; Interrupt handler - update display & keyboard
int_handler:   ld  (int_sp+1),sp
               ld  sp,new_stack     ; we must use our own stack to avoid us losing
                        ; registers when loading over the existing stack
               push af
               push bc
               push de
               push hl
               ex  af,af'
               exx
               push af
               push bc
               push de
               push hl
               push ix
               push iy              ; IY used by Galaksija interrupt handler

old_jr:        jr  not_old
               ld  a,&18            ; JR
               ld  (old_jr),a       ; restore jump past this OLD handler
               ld  a,&3e            ; change JR to LD A,n to activate resume
               ld  (restore_sp+3),a
               ld  (restore_sp+1),sp
basic_sp:      ld  sp,0             ; BASIC stack, saved on entry
               ld  a,%00011111      ; page 31, ROM 0 on (always)
               out (&fa),a          ; set LMPR
old_vmpr:      ld  a,0              ; VMPR, saved on entry
               out (&fc),a
               ei
               ret                  ; return to SAM BASIC

not_old:       call &00c0           ; part of ROM IM 1 handler

               ld  (draw_sp+1),sp
               ld  sp,char_addrs    ; 512 addresses for each Gal character on screen
               ld  ix,0             ; 0 frames counted so far

; Marko's mode 2 screen drawing, modified to draw only changed characters
; plus using the stack for faster access to target address
               ld  de,32            ; 32 bytes to next line down in mode 2
               exx
               ld  hl,gal_screen
               ld  d,char_lookup/256
               ld  bc,&0480         ; 4 blocks of 128 = 512 display characters

               ld  a,&c0            ; starting HPEN value (border area)
               ex  af,af'

draw_lp:       res 7,h              ; select live screen
               ld  a,(hl)           ; fetch character
               set 7,h              ; select mirror screen
               cp  (hl)             ; same as last time
               jp  z,samesame       ; skip drawing if so
               ld  (hl),a           ; update changed character
               ld  e,a
               ld  a,(de)           ; map character to fix bits 6+7
               exx
               ld  c, a
               ld  b,gal_font/256

               pop hl               ; fetch next gal screen address to write

               ld  a, (bc)          ; 0
               ld  (hl),a
               add hl, de
               inc c
               ld  a, (bc)          ; 1
               ld  (hl),a
               add hl, de
               inc b
               ld  a, (bc)          ; 2
               ld  (hl),a
               add hl, de
               dec c
               ld  a, (bc)          ; 3
               ld  (hl),a
               add hl, de
               inc b
               ld  a, (bc)          ; 4
               ld  (hl),a
               add hl, de
               inc c
               ld  a, (bc)          ; 5
               ld  (hl),a
               add hl, de
               inc b
               ld  a, (bc)          ; 6
               ld  (hl),a
               add hl, de
               dec c
               ld  a, (bc)          ; 7
               ld  (hl),a
               add hl, de
               inc b
               ld  a, (bc)          ; 8
               ld  (hl),a
               add hl, de
               inc c
               ld  a, (bc)          ; 9
               ld  (hl),a
               add hl, de
               inc b
               ld  a, (bc)          ; 10
               ld  (hl),a
               add hl, de
               dec c
               ld  a, (bc)          ; 11
               ld  (hl),a
               exx
skip_draw:     inc hl               ; advance to next character to draw

               dec c
               jp  nz,draw_lp

               ex  af,af'           ; retrieve last HPEN
               ld  c,a
               ld  a,1
               in  a,(&f8)          ; read current HPEN (vertical screen line)
               cp  c                ; compare with last value
               jr  nc,same_hpen     ; >= means same frame
               inc ix               ; count an extra frame
same_hpen:     ex  af,af'           ; save current HPEN

               ld  c,&80            ; start next block of 128
               dec b
               jp  nz,draw_lp       ; loop for all 4 blocks
               jr  draw_sp

samesame:      pop af               ; junk unwanted screen address
               jp  skip_draw

draw_sp:       ld  sp,0             ; restore normal stack

               defb &dd
               ld  a,l              ; LD A,IXl
               cp  2                ; took 2+ frames?
               jr  nc,too_slow      ; too slow, so don't waste time waiting

               ld  bc,&01f8         ; HPEN port

wait_border:   in  a,(c)            ; read scan position
               cp  &c0
               jr  nz,wait_border   ; loop waiting for the border

wait_mid:      in  a,(c)
               cp  &50
               jr  nz,wait_mid      ; loop until we reach a specific line, so the native
                                    ; code doesn't have too much time to run (or too little)
too_slow:

; Resume point from tape load
resume:


; clear currently pressed keys
               call clear_kb

; Scan the full keymap
               ld  hl,keymap
               ld  d,&20            ; Gal keyboard mapped at &20xx
               ld  b,&fe            ; keyboard row mask
key_lp1:       ld  c,&f9            ; status port holding extended keys
               in  a,(c)
               and %11100000        ; only top 3 bits used for keys
               ld  e,a
               ld  c,&fe            ; Speccy keyboard port
               in  a,(c)
               and %00011111        ; only bottom 5 bits used for keys
               or  e                ; merge with extended keys
               inc a
               jr  z,no_row         ; jump if no keys on row are pressed
               dec a
               ld  c,8              ; 8 bits to scan in each byte
key_lp2:       rla                  ; shift next bit into carry
               jr  c,no_press       ; jump if not pressed
               ld  e,(hl)
               bit 7,e              ; check for unused map entry
               jr  nz,no_press
               ex  de,hl
               ld  (hl),&fe         ; flag Gal key as pressed
               ex  de,hl
no_press:      inc l                ; next key in map
               dec c
               jr  nz,key_lp2       ; complete row
next_row:      inc b                ; done the last row?
               jr  z,done_matrix
               dec b
               rlc b                ; move to next row to scan
               jr  c,key_lp1
               inc b                ; scan final row &ff
               jr  key_lp1
no_row:        ld  a,l
               add a,8              ; skip 1 row in keymap
               ld  l,a
               jr  next_row

; Check special keys
done_matrix:   ld  a,&7f
               in  a,(&fe)
               and %00000010        ; check for Symbol
               jr  nz,done_keys

               ld  a,&fb
               in  a,(&fe)
               and %00001000        ; check R
               jr  nz,done_keys
               call wait_no_key
               ld  sp,(int_sp+1)
               jp  0                ; reset

; todo: shift-minus = / (47), and more...

done_keys:     ld  hl,0
               ld  (&2bb0),hl       ; clear window offset?

               pop iy
               pop ix
               pop hl
               pop de
               pop bc
               pop af
               exx
               ex  af,af'
               pop hl
               pop de
               pop bc
               pop af

int_sp:        ld  sp,0
               ei
               reti


wait_no_key:   xor a
               in  a,(&fe)
               cpl
               and %00011111
               jr  nz,wait_no_key

               ; fall through to...

; Clear the keyboard buffer
clear_kb:      ld  hl,&2000         ; start of keyboard buffer
               ld  bc,&38ff         ; 56 positions to clear with &ff
clearkblp:     ld  (hl),c
               inc l
               djnz clearkblp
               ret


; Align to 256-bytes
               defs -$\256

; Mapping from 8x9 SAM matrix to native $20xx I/O address
keymap:
               defb 35,34,33, 22, 3,24,26,53   ; F3 F2 F1 V C X Z Shift
               defb 38,37,36,  7, 6, 4,19, 1   ; F6 F5 F4 G F D S A
               defb 41,40,39, 20,18, 5,23,17   ; F9 F8 F7 T R E W Q
               defb -1,49,49, 37,36,35,34,33   ; Caps Tab Esc 5 4 3 2 1
               defb 29,-1,-1, 38,39,40,41,32   ; DEL + - 6 7 8 9 0
               defb 32,-1,45, 25,21, 9,15,16   ; F0 " = Y U I O P
               defb 51,43,42,  8,10,11,12,48   ; Edit : ; H J K L Return
               defb 52,46,44,  2,14,13,53,31   ; Inv . , B N M Sym Space
               defb -1,-1,-1, 30,29,28,27,50   ; - - - Right Left Down Up Cntrl

end:
length: equ end-start


; Private stack space, as using the native one causes problems
               defs 64
new_stack:

; Table of addresses for each Gal character on the SAM display
char_addrs: defs 512*2


; Remaining data goes after SAM attributes
               org sam_attrs+sam_scrlen
               dump $
char_lookup:        ; &f800
               defs 256
gal_font:           ; &f900
MDAT "galfont.bin"

               dump 4,&0000     ; &14000
MDAT "rom1.bin"
               dump 4,&1000     ; &15000
MDAT "rom2.bin"
