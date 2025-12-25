    device ZXSPECTRUM128
	
	org #6000
start_
	di
	ld hl,#5800
	ld de,#5801
	ld (hl),7
	ld bc,768-1
	ldir ;cls attr
	
	ld hl,msg_title
	call print
	call print_dump
wait_cl
	call pause
	ld a,#f7
	in a,(#fe)
	bit 0,a ;1
	call z,test_vram
	bit 1,a ;2
	call z,test_sdram
	bit 2,a ;3
	call z,show_tab
	bit 3,a ;4
	call z,load_pic
	bit 4,a ;5
	call z,move_pic_h
	
	ld a,#ef
	in a,(#fe)
	bit 4,a ;6
	call z,move_pic_v	
	jr wait_cl


	
pause	
	ld bc,1000 ;пауза
pause1
	dec bc
	ld a,b
	or c
	jr nz,pause1
	ret



	
scr_on_map_off
	ld bc,#005b
	ld a,%00000001 ;включить экран отключить маппинг
	out (c),a
	ret

scr_off_map_off
	ld bc,#005b
	ld a,%00000000 ;отключить экран и маппинг
	out (c),a
	ret

scr_off_map_sdram_on
	ld bc,#005b
	ld a,%00110000 ;включить мапинг sdram отключить экран
	out (c),a
	ret
	
scr_off_map_vram_on
	ld bc,#005b
	ld a,%00010000 ;включить мапинг vram отключить экран
	out (c),a
	ret
	
scr_no_map_sdram_on
	ld bc,#005b
	ld a,%00110001 ;включить мапинг sdram включить экран
	out (c),a
	ret
	
scr_on_map_vram_on
	ld bc,#005b
	ld a,%00010001 ;включить мапинг vram включить экран
	out (c),a
	ret

	
load_pic_addr equ #8000
load_pic
	;загрузить картинку
	call scr_on_map_off
	ld hl,file_pic_name
	ld      c,#13 ;move file info to syst var
    call    #3d13
	ld      a,c
	cp 		#ff
	jp 		z,read_cfg_err
    ld      c,#0a ;find file
    call    #3d13
    ld      a,c
	cp 		#ff
	jp 		z,read_cfg_err ;если не нашли файла
    ld      c,#08 ;read file title
    call    #3d13
	ld      a,c
	cp 		#ff
	jr 		z,read_cfg_err
    ld      hl,load_pic_addr ;куда
    ld      de,(#5ceb) ;начало файла сектор дорожка
    ld      bc,#6105 ;считать 32*3+1 сектора
    call    #3d13
	ld      a,c
	cp 		#ff
	jr 		z,read_cfg_err

	di
	;перекинуть
	;0	
	call scr_on_map_vram_on
	ld bc,#025b
	ld a,0 ;страница vram
	out (c),a
	ld hl,load_pic_addr
	ld de,#0000
	ld bc,32*256
	ldir
	;1
	ld bc,#025b
	ld a,1 ;страница vram
	out (c),a
	ld hl,load_pic_addr+8192
	ld de,#0000
	ld bc,32*256
	ldir
	;2
	ld bc,#025b
	ld a,2 ;страница vram
	out (c),a
	ld hl,load_pic_addr+8192+8192
	ld de,#0000
	ld bc,32*256
	ldir
	
	;загрузить палитру
	ld hl,load_pic_addr+#6000 ;в конце файла
	ld bc,#105b
	ld ixl,16
load_pic_pal_cl
	ld a,(hl)
	out (c),a
	inc hl
	inc b
	dec ixl
	jr nz,load_pic_pal_cl
	
	ld hl,msg_file_ok
	call print
	call print_dump
	
	call scr_on_map_off
	
	ld a,(file_pic_name+5) ;следующая картинка
	inc a
	cp "6"
	jr c,load_pic_next
	ld a,"1"
load_pic_next
	ld (file_pic_name+5),a
	
	
	ld a,255
	ret

read_cfg_err
	ld hl,msg_file_error
	call print
	call print_dump
	ld a,255
	ret






test_vram
	di
	call scr_off_map_vram_on
	
	ld hl,msg_write_ram
	call print
	call print_dump

	;запись
	ld a,255
	ld (flag),a
	ld ixl,3 ;станиц всего 3
vram_loop1	
	ld a,(flag)
	inc a
	call print_num
	ld (flag),a
	ld bc,#025b ;set page
	out (c),a
	
	in a,(c)
	out (254),a
	
	ld hl,0
	ld de,1
	ld bc,#2000-1 ;8192
	ld (hl),a
	ldir
	
	dec ixl
	jr nz,vram_loop1
	
	call pause
	;теперь чтение
	
	ld hl,msg_read_ram
	call print
	call print_dump
	
	ld a,255
	ld (flag),a
	ld ixl,3 ;станиц всего 3
vram_loop2	
	ld a,(flag)
	inc a
	call print_num
	ld (flag),a
	ld bc,#025b ;set page
	out (c),a
	
	in a,(c)
	out (254),a
	ld (vram_val),a
	
	ld hl,0
	ld bc,#2000 ;8192
vram_loop2_cl
	ld a,(vram_val)
	cp (hl)
	jr nz,vram_loop2_err
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,vram_loop2_cl
	

	dec ixl
	jr nz,vram_loop2

	ld hl,msg_ram_ok
	call print
	call print_dump
	call pause
	ld a,255
	ret
	
	
vram_loop2_err	
	ld hl,msg_ram_error
	call print
	ld hl,(vram_val)
	ld h,0
	call toDecimal
	call print ;где ошибка	
	call print_dump
	call pause
	ld a,255
	ret	
	
vram_val db 0; 





print_num
	push af
	ld l,a
	ld h,0
	call toDecimal
	call print ;где ошибка
	pop af
	ret





test_sdram
	di
	call scr_off_map_sdram_on
	
	ld hl,msg_write_ram
	call print
	call print_dump

	;запись
	ld a,255
	ld (flag),a
	ld ixl,0 ;станиц всего 256
sdram_loop1	
	ld a,(flag)
	inc a
	call print_num
	ld (flag),a
	ld bc,#015b ;set page
	out (c),a
	
	in a,(c)
	out (254),a
	
	ld hl,0
	ld de,1
	ld bc,#4000-1 ;16384
	ld (hl),a
	ldir
	
	dec ixl
	jr nz,sdram_loop1
	
	call pause
	;теперь чтение
	
	ld hl,msg_read_ram
	call print
	call print_dump
	
	ld a,255
	ld (flag),a
	ld ixl,0 ;станиц всего 256
sdram_loop2	
	ld a,(flag)
	inc a
	call print_num
	ld (flag),a
	ld bc,#015b ;set page
	out (c),a
	
	in a,(c)
	out (254),a
	ld (sdram_val),a
	
	ld hl,0
	ld bc,#4000 ;16384
sdram_loop2_cl
	ld a,(sdram_val)
	cp (hl)
	jr nz,sdram_loop2_err
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,sdram_loop2_cl
	

	dec ixl
	jr nz,sdram_loop2

	ld hl,msg_ram_ok
	call print
	call print_dump
	call pause
	ld a,255
	ret
	
	
sdram_loop2_err	
	ld hl,msg_ram_error
	call print
	ld hl,(sdram_val)
	ld h,0
	call toDecimal
	call print ;где ошибка	
	call print_dump
	call pause
	ld a,255
	ret	
	
sdram_val db 0; 












	
show_tab
	;сначала заполнить страницы
	di
	call scr_off_map_vram_on

	ld a,255
	ld (flag),a
	
	ld ixl,3
loop1	
	ld a,(flag)
	inc a
	call print_num
	ld (flag),a
	ld bc,#025b ;set page
	out (c),a
	
	in a,(c)
	out (254),a
	
	ld hl,0
	ld de,1
	ld bc,#2000-1
	ld (hl),a
	ldir
	
	dec ixl
	jr nz,loop1
	
	;заполнить первую страницу полосками
	xor a
	ld bc,#025b ;set page
	out (c),a
	
	ld hl,0
	ld de,4 ;шаг
	ld bc,#2000/4 ;сколько

fill_cl	
	ld (hl),%00010000 ;синий левый пиксель
	add hl,de
	dec bc
	ld a,b
	or c
	jr nz,fill_cl
	
	ld a,%00010010 ;добавить синюю слева и красную справа 
	ld (#0000),a
	;ld (#0009),a
	
	ld a,%00010100 ;добавить синюю слева и зелёную справа
	ld (#0004),a	
	
	
	call scr_on_map_off
	out (c),a
	

	call waitkey

	call scr_on_map_vram_on


	call pause
	
	
	call waitkey



	ld a,255
	ld (flag),a
	
loop2	
	call key_exit ;проверка на выход
		
	;теперь печатать по кругу значения
	ld a,(flag)
	inc a
	cp 3
	jr c,loop2_1
	xor a
	
loop2_1	
	ld (flag),a
	
	

	
	ld bc,#025b ;set page
	out (c),a
	
	in a,(c)
	out (254),a
	
loop3
	call print_dump
	
	XOR A:IN A,(#FE):CPL:AND #1F:
	JR nz,loop2
	jr loop3	
	
	
	;jr loop2
flag db 0;



waitkey
	push af
WAITKEY	XOR A:IN A,(#FE):CPL:AND #1F: JR z,WAITKEY ;нажать любую
WAITKEY1	XOR A:IN A,(#FE):CPL:AND #1F: JR nz,WAITKEY1 ;отпустить
	pop af
	ret



print_dump
	ld bc,42*(24-8) ;число букв
	ld hl,#0008 ;адрес
	ld (posit),hl
	ld (ytxt),hl
	call print_
	ret





move_pic_h ;скролл картинки горизонтальный
	call scr_on_map_off
	ei
	xor a

	ld bc,#035b
	out (c),a
	
move_pic_h1
	halt
	call key_exit
;	call waitkey
	out (c),a
	inc a	
	cp 255
	jr nz,move_pic_h1

move_pic_h2
	halt
	call key_exit
;	call waitkey
	out (c),a
	dec a
	jr nz,move_pic_h2
	jr move_pic_h1



	
move_pic_v ;скролл картинки вертикальный
	call scr_on_map_off
	ei
	xor a

	ld bc,#045b
	out (c),a
	
move_pic_v1
	halt
	call key_exit
	out (c),a
	inc a	
	cp 191
	jr nz,move_pic_v1

move_pic_v2
	halt
	call key_exit
	out (c),a
	dec a
	jr nz,move_pic_v2
	jr move_pic_v1



;печать до символа 0
;hl - text address
;13-enter
;16-color(атрибуты 128+64+pap*8+ink)
;20-inverse
;21-отступ от левого края
;22-at
print_  ;var 2: print text lenght in bc
        ld      a,(hl)
        call    prsym
        inc     hl
        dec     bc
        ld      a,b
        or      c
        jr      nz,print_
        ret
aupr    pop     hl
        call    print
        push    hl
        ret
;start print to 0
print   ld      a,(hl)
        inc     hl
        or      a
        ret     z
        cp      23
        jr      c,prin
        call    prsym
        jr      print
prin
        cp      13
        jr      nz,prin0
        ld      a,(space)
        ld      (xtxt),a
        ld      a,(ytxt)
        inc     a
        cp      23
        jr      c,pr13_0
        xor     a
pr13_0  ld      (ytxt),a
        jr      print
prin0   cp      16
        jr      nz,prin1
        ld      a,(hl)
        inc     hl
        ld      (23695),a
        jr      print
prin1   cp      20
        jr      nz,prin2
        ld      a,(hl)
        inc     hl
        or      a
        jr      z,pr20_0
        ld      a,#2f
        ld      (pr0),a
        ld      (pr1),a
        ld      (pr2),a
        ld      (pr3),a
        jr      print
pr20_0  ld      (pr0),a
        ld      (pr1),a
        ld      (pr2),a
        ld      (pr3),a
        jr      print
prin2   cp      22
        jr      nz,prin3
        ld      a,(hl)
        ld      (ytxt),a
        inc     hl
        ld      a,(hl)
        ld      (xtxt),a
        inc     hl
        jr      print
prin3   cp      21
        jr      nz,print
        ld      a,(hl)
        inc     hl
        ld      (space),a
        jr      print
prsym
        push    af
        push    bc
        push    de
        push    hl
        push    ix
        ld      de,(ytxt)
        inc     d
        ld      (ytxt),de
        dec     d
        ex      af,af'
        ld      a,d
        cp      41
        jr      c,prs
        ld      a,e
        inc     a
        cp      24
        jr      c,prs1
        xor     a
prs1    ld      (ytxt),a
        ld      a,(space)
        ld      (xtxt),a
prs     ex      af,af'
        ld      l,a
        ld      h,#00
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      bc,font
        add     hl,bc
        push    hl
        ld      a,d
        add     a,a
        ld      d,a
        add     a,a
        add     a,d
        add     a,#02
        ld      d,a
        and     #07
        ex      af,af'
        ld      a,d
        rrca
        rrca
        rrca
        and     #1F
        ld      d,a
        ld      a,e
        and     #18
        add     a,#40
        ld      h,a
        ld      a,e
        and     #07
        rrca
        rrca
        rrca
        add     a,d
        ld      l,a
        ld      (posit),hl
        pop     de
        ld      b,#08
        ex      af,af'
        jr      z,L73C7
        ld      xh,b
        cp      #02
        jr      z,L73D6
        cp      #04
        jr      z,L73E9
L73A7   ld      a,(hl)
        rrca
        rrca
        ld      b,a
        inc     hl
        ld      a,(hl)
        and     #0F
        ld      c,a
        ld      a,(de)
pr0     nop
        and     #FC
        sla     a
        rl      b
        sla     a
        rl      b
        or      c
        ld      (hl),a
        dec     hl
        ld      (hl),b
        inc     h
        inc     de
        dec     xh
        jr      nz,L73A7
        jr      prsc1
L73C7   ld      a,(hl)
        and     #03
        ld      c,a
        ld      a,(de)
pr1     nop
        and     #FC
        or      c
        ld      (hl),a
        inc     h
        inc     de
        djnz    L73C7
        jr      prsc
L73D6   ld      a,(hl)
        and     #C0
        ld      b,a
        ld      a,(de)
pr2     nop
        and     #FC
        rrca
        rrca
        or      b
        ld      (hl),a
        inc     h
        inc     de
        dec     xh
        jr      nz,L73D6
        jr      prsc
L73E9   ld      a,(hl)
        rrca
        rrca
        rrca
        rrca
        ld      b,a
        inc     hl
        ld      a,(hl)
        and     #3F
        ld      c,a
        ld      a,(de)
pr3     nop
        and     #FC
        sla     a
        rl      b
        sla     a
        rl      b
        sla     a
        rl      b
        sla     a
        rl      b
        or      c
        ld      (hl),a
        dec     hl
        ld      (hl),b
        inc     h
        inc     de
        dec     xh
        jr      nz,L73E9
        jr      prsc1
prsc    ld      hl,(posit)
        ld      a,h
        and     #18
        rrca
        rrca
        rrca
        add     a,#58
        ld      h,a
        ld      a,(23695)
        ld      (hl),a ;отключена раскраска
        jr      prse
prsc1   ld      hl,(posit)
        ld      a,h
        and     #18
        rrca
        rrca
        rrca
        add     a,#58
        ld      h,a
        ld      a,(23695)
        ld      (hl),a
        inc     hl
        ld      (hl),a
prse    pop     ix
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret
posit   dw      0
space   nop
ytxt    nop
xtxt    nop



toDecimal		;конвертирует 2 байта в 5 десятичных цифр
				;на входе в HL число
			ld de,10000 ;десятки тысяч
			ld a,255
toDecimal10k			
			and a
			sbc hl,de
			inc a
			jr nc,toDecimal10k
			add hl,de
			add a,48
			ld (decimalS),a
			ld de,1000 ;тысячи
			ld a,255
toDecimal1k			
			and a
			sbc hl,de
			inc a
			jr nc,toDecimal1k
			add hl,de
			add a,48
			ld (decimalS+1),a
			ld de,100 ;сотни
			ld a,255
toDecimal01k			
			and a
			sbc hl,de
			inc a
			jr nc,toDecimal01k
			add hl,de
			add a,48
			ld (decimalS+2),a
			ld de,10 ;десятки
			ld a,255
toDecimal001k			
			and a
			sbc hl,de
			inc a
			jr nc,toDecimal001k
			add hl,de
			add a,48
			ld (decimalS+3),a
			ld de,1 ;единицы
			ld a,255
toDecimal0001k			
			and a
			sbc hl,de
			inc a
			jr nc,toDecimal0001k
			add hl,de
			add a,48
			ld (decimalS+4),a		
			ld hl,decimalS_
			ret

decimalS_	db 22,6,0	
decimalS	ds 6 ;десятичные цифры	




key_exit ;выход если нажата 0
	push af
	ld a,#ef
	in a,(#fe)
	bit 0,a ;0
	jr nz,key_exit_ex
	pop af
	ld a,255
	pop hl
	ret
key_exit_ex
	pop af
	ret


msg_title
	db 22,0,0,"Test ESCR"	
	db 22,1,0,"1 - Test VRAM"
	db 22,2,0,"2 - Test SDRAM"
	db 22,3,0,"3 - Tuning table"
	db 22,4,0,"4 - Load pic"
	db 22,1,19,"5 - Scroll h."
	db 22,2,19,"6 - Scroll v."
	
	db 22,4,19,"0 - Stop test"
	db 0

file_pic_name db "pic001  d",0

msg_file_error
	db 22,5,0,16,2,"File error!",16,7,0
msg_write_ram
	db 22,5,0,"Write RAM..",0
msg_read_ram
	db 22,5,0,"Read RAM.. ",0
msg_ram_ok
	db 22,5,0,16,4,"RAM OK     ",16,7,0
msg_ram_error
	db 22,5,0,16,2,"RAM error! ",16,7,0
msg_file_ok
	db 22,5,0,16,4,"File OK    ",16,7,0


font    insert  "FONT.C" ;шрифт


end_
	SAVETRD "ESCR-Test.TRD",|"ESCR-Test.C",start_,end_-start_