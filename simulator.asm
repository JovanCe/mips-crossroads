.8086

.model small
.stack 512

.data
;graphic mode values
DCOLOR EQU 09h ;print on screen with attributes
DNORMAL EQU 0ah ;print on screen normal
SETCUR EQU 2h ;set cursor position
GETCUR EQU 3h ;get cursor position

;ascii codes for drawing
HLINE EQU 0cdh
DRJUNC EQU 0c9h
URJUNC EQU 0c8h
ULJUNC EQU 0bch
DLJUNC EQU 0bbh
VLINE EQU 0bah
VSEP EQU 0b3h
HSEP EQU 0c4h
PEDCROSS EQU 0b1h
LIGHTV EQU 0dfh
LIGHTH EQU 0ddh

;keyboard constants
EXIT EQU 1bh
CROSSINGA EQU '1'
CROSSINGB EQU '2'
CROSSINGC EQU '3'
CROSSINGD EQU '4'
SYS_PAUSE EQU 'p'
SET_CYCLE EQU 'b'
SET_MULTIPLIER EQU 'n'

;colors
RED EQU 0ch
YELLOW EQU 0eh
GREEN EQU 0ah
CYAN EQU 03h
GREY EQU 07h
WHITE EQU 0fh
LBLUE EQU 09h

;messages
msg_commands db "Commands:",0
msg_a db "Q - Al  A - Af  Z - Ar",0
msg_b db "W - Bl  S - Bf  X - Br",0
msg_c db "E - Cl  D - Cf  C - Cr",0
msg_d db "R - Dl  F - Df  V - Dr",0
msg_crossings db "1,2,3,4 - crossings",0
msg_pause db "P - pause/unpause",0
msg_exit db "Esc - exit system",0
msg_current_cycle db "Cycle time: ",0
msg_current_multiplier db "Multiplier: ",0
msg_set_cycle db "B - set",0
msg_set_multiplier db "N - set",0
msg_authors_title db "Authors: ",0
msg_authors1 db "Jovan Cejovic",0
msg_authors2 db "Ivan Gavrilovic",0
msg_status_paused db "SYSTEM PAUSED ",0
msg_status_running db "SYSTEM RUNNING",0

;cursor positions
aleft db 25,21
aforw db 29,21
aright db 33,21
bleft db 38,12
bforw db 38,10
bright db 38,8
cleft db 21,5
cforw db 17,5
cright db 13,5
dleft db 8,14
dforw db 8,16
dright db 8,18

;semaphore cursor positions
alsem db 25,17,25,18,25,19
afsem db 29,17,29,18,29,19
arsem db 33,17,33,18,33,19
blsem db 33,12,34,12,35,12
bfsem db 33,10,34,10,35,10
brsem db 33,8,34,8,35,8
clsem db 21,9,21,8,21,7
cfsem db 17,9,17,8,17,7
crsem db 13,9,13,8,13,7
dlsem db 13,14,12,14,11,14
dfsem db 13,16,12,16,11,16
drsem db 13,18,12,18,11,18
semaphore_cursors db 25,17,25,18,25,19,29,17,29,18,29,19,33,17,33,18,33,19,33,12,34,12,35,12,33,10,34,10,35,10,33,8,34,8,35,8,21,9,21,8,21,7,17,9,17,8,17,7,13,9,13,8,13,7,13,14,12,14,11,14,13,16,12,16,11,16,13,18,12,18,11,18


;pedestrian semaphore cursor positions
aped db 37,20,36,20
bped db 36,5,36,6
cped db 9,6,10,6
dped db 10,21,10,20
crossing_sem_cursors db 37,20,36,20,36,5,36,6,9,6,10,6,10,21,10,20

;pedestrian display positions
adispcur db 38,20,39,20
bdispcur db 37,5,38,5
cdispcur db 7,6,8,6
ddispcur db 8,21,9,21
crossing_disp_cursors db 38,20,39,20,37,5,38,5,7,6,8,6,8,21,9,21

;timer values
second db 10
new_second EQU 10
seventh_part db 7
new_seventh_part EQU 7

;car counters
car_counters db 12 dup(0)

;pedestrian display values
displays db 4 dup(0)

;lane combination sets, masks and flags
lane_sets dw 39 dup(0)
lane_sets_heuristics dw 39 dup(0)
lane_masks dw 12 dup(0)
lane_green_flags db 12 dup(0)
lane_wait_counters dw 12 dup(0)
pedestrian_green_flags db 4 dup(0)
pedestrian_requests db 4 dup(0)
pedestrian_queue db 4 dup(0)
pedestrian_skip_counters db 4 dup(0)
pedestrian_blink_counters db 4 dup(15)

pedestrian_closure db 39 dup(0)

next_cycle_red db 12 dup(1)
next_cycle_red_crossing db 4 dup(1)
next_cycle_blink_counter db 5

;system values
cycle_time db 30
new_cycle_time db 0
new_pedestrian_wait_multiplier db 0
cycle_changed db 0
current_time db 0
pedestrian_wait_multiplier db 2
CYCLE_NEGATIVE_OFFSET EQU 7
system_paused db 0

;helper variables
current_hmax dw 0
current_hmax_index db 0
current_closure_index db 0
old_hmax_index db 0

.code
SET_CURSOR macro
	mov ah,SETCUR
	int 10h
endm
PRINT_CHAR macro value ;prints a character passed through value on the screen
	mov al,value
	mov ah,DNORMAL
	int 10h
endm

PRINT_CHAR_COLOR macro value,color ;prints a character passed through value on the screen with the given color
	mov al,value
	mov bl,color
	mov ah,DCOLOR
	int 10h
endm

DRAW_SEMAPHORE macro char,x,y,color
	push char
	mov al,x
	mov ah,y
	push ax
	push color
	call draw_sem
	pop ax
	pop ax
	pop ax
endm

REDRAW_CHAR macro x,y,color
	mov cx,1
	mov dl,x
	mov dh,y
	SET_CURSOR
	mov ah,08h
	int 10h
	mov bl,color
	mov ah,DCOLOR
	int 10h
endm

clrscr proc ;clear the screen
	push ax
	push bx
	push cx
	push dx
	mov dl,0
	mov dh,0
	SET_CURSOR
	MOV bl, 7h
	MOV al, ' '
	MOV ah, 09h
	MOV	cx, 2000h ;clear screen sub routine
	INT 10H
	pop dx
	pop cx
	pop bx
	pop ax
	ret
clrscr endp

draw_info proc
	push ax
	push bx
	push cx
	push dx
	mov dl,49
	mov dh,0
	mov cx,1
	mov bl,0
	SET_CURSOR
	print_info_line1:
	PRINT_CHAR 0dbh
	inc bl
	mov dh,bl
	SET_CURSOR
	cmp bl,25
	jne print_info_line1
	mov dl,51
	mov dh,1
	SET_CURSOR
	mov bl,0
	lea si,msg_commands
	print_info_commands:
	mov al,[si]
	inc si
	inc bl
	mov ah,0eh
	int 10h
	cmp bl,9
	jne print_info_commands
	
	mov dl,51
	mov dh,3
	SET_CURSOR
	lea si,msg_a
	print_msg_a:
	mov al,[si]
	cmp al,0
	je print_msg_b
	inc si
	mov ah,0eh
	mov bl,LBLUE
	int 10h
	jmp print_msg_a
	
	print_msg_b:
	mov dl,51
	mov dh,4
	SET_CURSOR
	lea si,msg_b
	print_msg_b1:
	mov al,[si]
	cmp al,0
	je print_msg_c
	inc si
	mov ah,0eh
	mov bl,LBLUE
	int 10h
	jmp print_msg_b1
	
	print_msg_c:
	mov dl,51
	mov dh,5
	SET_CURSOR
	lea si,msg_c
	print_msg_c1:
	mov al,[si]
	cmp al,0
	je print_msg_d
	inc si
	mov ah,0eh
	mov bl,LBLUE
	int 10h
	jmp print_msg_c1
	
	print_msg_d:
	mov dl,51
	mov dh,6
	SET_CURSOR
	lea si,msg_d
	print_msg_d1:
	mov al,[si]
	cmp al,0
	je print_info_line2
	inc si
	mov ah,0eh
	mov bl,LBLUE
	int 10h
	jmp print_msg_d1
	
	print_info_line2:
	mov cx,30
	mov dl,50
	mov dh,7
	SET_CURSOR
	PRINT_CHAR 0cdh
	
	mov dl,51
	mov dh,8
	SET_CURSOR
	lea si,msg_crossings
	print_info_crossings:
	mov al,[si]
	mov ah,0eh
	int 10h
	inc si
	cmp al,0
	jne print_info_crossings
	
	mov dl,51
	mov dh,10
	SET_CURSOR
	lea si,msg_pause
	print_info_pause:
	mov al,[si]
	mov ah,0eh
	int 10h
	inc si
	cmp al,0
	jne print_info_pause
	
	mov dl,51
	mov dh,12
	SET_CURSOR
	lea si,msg_exit
	print_info_exit:
	mov al,[si]
	mov ah,0eh
	int 10h
	inc si
	cmp al,0
	jne print_info_exit
	
	mov cx,30
	mov dl,50
	mov dh,13
	SET_CURSOR
	PRINT_CHAR 0cdh
	
	mov cx,30
	mov dl,50
	mov dh,17
	SET_CURSOR
	PRINT_CHAR 0cdh
	
	mov dl,51
	mov dh,18
	SET_CURSOR
	lea si,msg_status_running
	print_info_status_running:
	mov al,[si]
	inc si
	mov ah,0eh
	int 10h
	cmp al,0
	jne print_info_status_running
	
	mov cx,30
	mov dl,50
	mov dh,19
	SET_CURSOR
	PRINT_CHAR 0cdh
	
	mov dl,51
	mov dh,20
	SET_CURSOR
	lea si,msg_authors_title
	print_info_authors_title:
	mov al,[si]
	inc si
	mov ah,0eh
	int 10h
	cmp al,0
	jne print_info_authors_title
	
	mov dl,51
	mov dh,22
	SET_CURSOR
	lea si,msg_authors1
	print_info_authors1:
	mov al,[si]
	inc si
	mov ah,0eh
	int 10h
	cmp al,0
	jne print_info_authors1
	
	mov dl,51
	mov dh,23
	SET_CURSOR
	lea si,msg_authors2
	print_info_authors2:
	mov al,[si]
	inc si
	mov ah,0eh
	int 10h
	cmp al,0
	jne print_info_authors2
	
	;lane labels
	mov cx,1
	mov dl,29
	mov dh,24
	SET_CURSOR
	PRINT_CHAR_COLOR 'A',CYAN
	
	mov dl,25
	mov dh,22
	SET_CURSOR
	PRINT_CHAR 'l'
	
	mov dl,29
	mov dh,22
	SET_CURSOR
	PRINT_CHAR 'f'
	
	mov dl,33
	mov dh,22
	SET_CURSOR
	PRINT_CHAR 'r'

	mov dl,42
	mov dh,10
	SET_CURSOR
	PRINT_CHAR_COLOR 'B',CYAN
	
	mov dl,40
	mov dh,8
	SET_CURSOR
	PRINT_CHAR 'r'
	
	mov dl,40
	mov dh,10
	SET_CURSOR
	PRINT_CHAR 'f'
	
	mov dl,40
	mov dh,12
	SET_CURSOR
	PRINT_CHAR 'l'
	
	mov dl,17
	mov dh,2
	SET_CURSOR
	PRINT_CHAR_COLOR 'C',CYAN
	
	mov dl,13
	mov dh,4
	SET_CURSOR
	PRINT_CHAR 'r'
	
	mov dl,17
	mov dh,4
	SET_CURSOR
	PRINT_CHAR 'f'
	
	mov dl,21
	mov dh,4
	SET_CURSOR
	PRINT_CHAR 'l'
	
	mov dl,4
	mov dh,16
	SET_CURSOR
	PRINT_CHAR_COLOR 'D',CYAN
	
	mov dl,6
	mov dh,14
	SET_CURSOR
	PRINT_CHAR 'l'
	
	mov dl,6
	mov dh,16
	SET_CURSOR
	PRINT_CHAR 'f'
	
	mov dl,6
	mov dh,18
	SET_CURSOR
	PRINT_CHAR 'r'
	
	mov dl,51
	mov dh,14
	SET_CURSOR
	lea si,msg_current_cycle
	print_cycle_info:
	mov al,[si]
	inc si
	mov ah,0eh
	int 10h
	cmp al,0
	jne print_cycle_info
	
	mov dl,51
	mov dh,16
	SET_CURSOR
	lea si,msg_current_multiplier
	print_cycle_multiplier:
	mov al,[si]
	inc si
	mov ah,0eh
	int 10h
	cmp al,0
	jne print_cycle_multiplier
	
	mov dl,69
	mov dh,14
	SET_CURSOR
	lea si,msg_set_cycle
	print_cycle_set:
	mov al,[si]
	inc si
	mov ah,0eh
	int 10h
	cmp al,0
	jne print_cycle_set
	
	mov dl,67
	mov dh,13
	SET_CURSOR
	mov cx,1
	mov al,0cbh
	mov ah,0eh
	int 10h
	
	mov dl,67
	mov dh,17
	SET_CURSOR
	mov al,0cah
	mov ah,0eh
	int 10h
	
	mov dl,67
	mov dh,14
	SET_CURSOR
	mov al,0bah
	mov ah,0eh
	int 10h
	mov dl,67
	mov dh,15
	SET_CURSOR
	mov al,0bah
	mov ah,0eh
	int 10h
	mov dl,67
	mov dh,16
	SET_CURSOR
	mov al,0bah
	mov ah,0eh
	int 10h
	
	mov dl,69
	mov dh,16
	SET_CURSOR
	lea si,msg_set_multiplier
	print_set_multiplier:
	mov al,[si]
	inc si
	mov ah,0eh
	int 10h
	cmp al,0
	jne print_set_multiplier
		
	pop dx
	pop cx
	pop bx
	pop ax
	ret
draw_info endp

draw_cycle_info proc
	push ax
	push bx
	push cx
	push dx
	mov dl,63
	mov dh,14
	SET_CURSOR
	mov al,cycle_time
	mov ah,00
	mov bl,10
	div bl
	add al,48
	mov bh,ah
	mov ah,0eh
	int 10h
	mov al,bh
	add al,48
	int 10h
	
	mov dl,63
	mov dh,16
	SET_CURSOR
	mov al,pedestrian_wait_multiplier
	add al,48
	mov ah,0eh
	int 10h
	pop dx
	pop cx
	pop bx
	pop ax
	ret
draw_cycle_info endp

draw_crossroad proc
	push ax
	push bx
	push cx
	push dx
	;below, horizontal lines and junctions are drawn
	mov dl,0
	mov dh,7
	SET_CURSOR
	mov cx,11
	PRINT_CHAR HLINE
	mov cx,1
	mov dl,11
	SET_CURSOR
	PRINT_CHAR ULJUNC
	mov dl,35
	SET_CURSOR
	PRINT_CHAR URJUNC
	mov cx,13
	mov dl,36
	SET_CURSOR
	PRINT_CHAR HLINE
	mov dl,0
	mov dh,19
	SET_CURSOR
	mov cx,11
	PRINT_CHAR HLINE
	mov cx,1
	mov dl,11
	SET_CURSOR
	PRINT_CHAR DLJUNC
	mov dl,35
	SET_CURSOR
	PRINT_CHAR DRJUNC
	mov cx,13
	mov dl,36
	SET_CURSOR
	PRINT_CHAR HLINE
	;vertical lines
	mov bl,0
	mov cx,1
	draw_crossroad_print1:
	mov dl,11
	mov dh,bl
	SET_CURSOR
	PRINT_CHAR VLINE
	inc bl
	cmp bl,07h
	jne draw_crossroad_print1
	
	mov bl,0
	draw_crossroad_print2:
	mov dl,35
	mov dh,bl
	SET_CURSOR
	PRINT_CHAR VLINE
	inc bl
	cmp bl,07h
	jne draw_crossroad_print2
	
	mov bl,20
	draw_crossroad_print3:
	mov dl,11
	mov dh,bl
	SET_CURSOR
	PRINT_CHAR VLINE
	inc bl
	cmp bl,27h
	jne draw_crossroad_print3
	
	mov bl,20
	draw_crossroad_print4:
	mov dl,35
	mov dh,bl
	SET_CURSOR
	PRINT_CHAR VLINE
	inc bl
	cmp bl,27h
	jne draw_crossroad_print4
	
	;pedestrian crossings
	;c
	mov cx,23
	mov dl,12
	mov dh,6
	SET_CURSOR
	PRINT_CHAR_COLOR PEDCROSS,WHITE
	;a
	mov cx,23
	mov dl,12
	mov dh,20
	SET_CURSOR
	PRINT_CHAR_COLOR PEDCROSS,WHITE
	;d
	mov cx,1
	mov bl,8
	draw_crossroad_pedstrian1:
	mov dl,10
	mov dh,bl
	SET_CURSOR
	push bx
	PRINT_CHAR_COLOR PEDCROSS,WHITE
	pop bx
	inc bl
	cmp bl,13h
	jne draw_crossroad_pedstrian1
	;b
	mov bl,8
	draw_crossroad_pedstrian2:
	mov dl,36
	mov dh,bl
	SET_CURSOR
	push bx
	PRINT_CHAR_COLOR PEDCROSS,WHITE
	pop bx
	inc bl
	cmp bl,13h
	jne draw_crossroad_pedstrian2
	
	;direction separators
	mov cx,10
	mov dl,0
	mov dh,13
	SET_CURSOR
	PRINT_CHAR HSEP
	
	mov cx,12
	mov dl,37
	mov dh,13
	SET_CURSOR
	PRINT_CHAR HSEP
	
	mov cx,1
	mov bl,0
	draw_crossroad_vsep1:
	mov dl,23
	mov dh,bl
	SET_CURSOR
	PRINT_CHAR VSEP
	inc bl
	cmp bl,6h
	jne draw_crossroad_vsep1
	
	mov bl,21
	draw_crossroad_vsep2:
	mov dl,23
	mov dh,bl
	SET_CURSOR
	PRINT_CHAR VSEP
	inc bl
	cmp bl,26
	jne draw_crossroad_vsep2
	
	;lane separators
	;horizontal
	mov cx,1
	mov bl,0
	draw_crossroad_lanhsep1:
	mov dl,bl
	mov dh,9
	SET_CURSOR
	PRINT_CHAR HSEP
	inc bl
	mov dl,bl
	SET_CURSOR
	PRINT_CHAR ' '
	inc bl
	cmp bl,9
	jle draw_crossroad_lanhsep1
	
	mov bl,0
	draw_crossroad_lanhsep2:
	mov dl,bl
	mov dh,11
	SET_CURSOR
	PRINT_CHAR HSEP
	inc bl
	mov dl,bl
	SET_CURSOR
	PRINT_CHAR ' '
	inc bl
	cmp bl,9
	jle draw_crossroad_lanhsep2
	
	mov bl,0
	draw_crossroad_lanhsep3:
	mov dl,bl
	mov dh,15
	SET_CURSOR
	PRINT_CHAR HSEP
	inc bl
	mov dl,bl
	SET_CURSOR
	PRINT_CHAR ' '
	inc bl
	cmp bl,9
	jle draw_crossroad_lanhsep3
	
	mov bl,0
	draw_crossroad_lanhsep4:
	mov dl,bl
	mov dh,17
	SET_CURSOR
	PRINT_CHAR HSEP
	inc bl
	mov dl,bl
	SET_CURSOR
	PRINT_CHAR ' '
	inc bl
	cmp bl,9
	jle draw_crossroad_lanhsep4
	
	mov bl,37
	draw_crossroad_lanhsep5:
	mov dl,bl
	mov dh,9
	SET_CURSOR
	PRINT_CHAR ' '
	inc bl
	mov dl,bl
	SET_CURSOR
	PRINT_CHAR HSEP
	inc bl
	cmp bl,47
	jle draw_crossroad_lanhsep5
	
	mov bl,37
	draw_crossroad_lanhsep6:
	mov dl,bl
	mov dh,11
	SET_CURSOR
	PRINT_CHAR ' '
	inc bl
	mov dl,bl
	SET_CURSOR
	PRINT_CHAR HSEP
	inc bl
	cmp bl,47
	jle draw_crossroad_lanhsep6
	
	mov bl,37
	draw_crossroad_lanhsep7:
	mov dl,bl
	mov dh,15
	SET_CURSOR
	PRINT_CHAR ' '
	inc bl
	mov dl,bl
	SET_CURSOR
	PRINT_CHAR HSEP
	inc bl
	cmp bl,47
	jle draw_crossroad_lanhsep7
	
	mov bl,37
	draw_crossroad_lanhsep8:
	mov dl,bl
	mov dh,17
	SET_CURSOR
	PRINT_CHAR ' '
	inc bl
	mov dl,bl
	SET_CURSOR
	PRINT_CHAR HSEP
	inc bl
	cmp bl,47
	jle draw_crossroad_lanhsep8
	
	;vertical
	mov bl,1
	draw_crossroad_lanvsep1:
	mov dl,15
	mov dh,bl
	SET_CURSOR
	PRINT_CHAR VSEP
	add bl,2
	cmp bl,5
	jle draw_crossroad_lanvsep1
	
	mov bl,1
	draw_crossroad_lanvsep2:
	mov dl,19
	mov dh,bl
	SET_CURSOR
	PRINT_CHAR VSEP
	add bl,2
	cmp bl,5
	jle draw_crossroad_lanvsep2
	
	mov bl,1
	draw_crossroad_lanvsep3:
	mov dl,27
	mov dh,bl
	SET_CURSOR
	PRINT_CHAR VSEP
	add bl,2
	cmp bl,5
	jle draw_crossroad_lanvsep3
	
	mov bl,1
	draw_crossroad_lanvsep4:
	mov dl,31
	mov dh,bl
	SET_CURSOR
	PRINT_CHAR VSEP
	add bl,2
	cmp bl,5
	jle draw_crossroad_lanvsep4
	
	mov bl,21
	draw_crossroad_lanvsep5:
	mov dl,15
	mov dh,bl
	SET_CURSOR
	PRINT_CHAR VSEP
	add bl,2
	cmp bl,25
	jle draw_crossroad_lanvsep5
	
	mov bl,21
	draw_crossroad_lanvsep6:
	mov dl,19
	mov dh,bl
	SET_CURSOR
	PRINT_CHAR VSEP
	add bl,2
	cmp bl,25
	jle draw_crossroad_lanvsep6
	
	mov bl,21
	draw_crossroad_lanvsep7:
	mov dl,27
	mov dh,bl
	SET_CURSOR
	PRINT_CHAR VSEP
	add bl,2
	cmp bl,25
	jle draw_crossroad_lanvsep7
	
	mov bl,21
	draw_crossroad_lanvsep8:
	mov dl,31
	mov dh,bl
	SET_CURSOR
	PRINT_CHAR VSEP
	add bl,2
	cmp bl,25
	jle draw_crossroad_lanvsep8
	
	pop dx
	pop cx
	pop bx
	pop ax
	ret
draw_crossroad endp

;print car counter procedures
al_print proc
	push ax
	push cx
	push dx
	mov cx,1
	mov dl,aleft[0]
	mov dh,aleft[1]
	SET_CURSOR
	mov al,car_counters[0]
	cmp al,9
	jge al_print_nine
	add al,48
	PRINT_CHAR_COLOR al,CYAN
	jmp al_print_end
	al_print_nine:
	PRINT_CHAR_COLOR '9',CYAN
	al_print_end:
	pop dx
	pop cx
	pop ax
	ret
al_print endp

af_print proc
	push ax
	push cx
	push dx
	mov cx,1
	mov dl,aforw[0]
	mov dh,aforw[1]
	SET_CURSOR
	mov al,car_counters[1]
	cmp al,9
	jge af_print_nine
	add al,48
	PRINT_CHAR_COLOR al,CYAN
	jmp af_print_end
	af_print_nine:
	PRINT_CHAR_COLOR '9',CYAN
	af_print_end:
	pop dx
	pop cx
	pop ax
	ret
af_print endp

ar_print proc
	push ax
	push cx
	push dx
	mov cx,1
	mov dl,aright[0]
	mov dh,aright[1]
	SET_CURSOR
	mov al,car_counters[2]
	cmp al,9
	jge ar_print_nine
	add al,48
	PRINT_CHAR_COLOR al,CYAN
	jmp ar_print_end
	ar_print_nine:
	PRINT_CHAR_COLOR '9',CYAN
	ar_print_end:
	pop dx
	pop cx
	pop ax
	ret
ar_print endp

bl_print proc
	push ax
	push cx
	push dx
	mov cx,1
	mov dl,bleft[0]
	mov dh,bleft[1]
	SET_CURSOR
	mov al,car_counters[3]
	cmp al,9
	jge bl_print_nine
	add al,48
	PRINT_CHAR_COLOR al,CYAN
	jmp bl_print_end
	bl_print_nine:
	PRINT_CHAR_COLOR '9',CYAN
	bl_print_end:
	pop dx
	pop cx
	pop ax
	ret
bl_print endp

bf_print proc
	push ax
	push cx
	push dx
	mov cx,1
	mov dl,bforw[0]
	mov dh,bforw[1]
	SET_CURSOR
	mov al,car_counters[4]
	cmp al,9
	jge bf_print_nine
	add al,48
	PRINT_CHAR_COLOR al,CYAN
	jmp bf_print_end
	bf_print_nine:
	PRINT_CHAR_COLOR '9',CYAN
	bf_print_end:
	pop dx
	pop cx
	pop ax
	ret
bf_print endp

br_print proc
	push ax
	push cx
	push dx
	mov cx,1
	mov dl,bright[0]
	mov dh,bright[1]
	SET_CURSOR
	mov al,car_counters[5]
	cmp al,9
	jge br_print_nine
	add al,48
	PRINT_CHAR_COLOR al,CYAN
	jmp br_print_end
	br_print_nine:
	PRINT_CHAR_COLOR '9',CYAN
	br_print_end:
	pop dx
	pop cx
	pop ax
	ret
br_print endp

cl_print proc
	push ax
	push cx
	push dx
	mov cx,1
	mov dl,cleft[0]
	mov dh,cleft[1]
	SET_CURSOR
	mov al,car_counters[6]
	cmp al,9
	jge cl_print_nine
	add al,48
	PRINT_CHAR_COLOR al,CYAN
	jmp cl_print_end
	cl_print_nine:
	PRINT_CHAR_COLOR '9',CYAN
	cl_print_end:
	pop dx
	pop cx
	pop ax
	ret
cl_print endp

cf_print proc
	push ax
	push cx
	push dx
	mov cx,1
	mov dl,cforw[0]
	mov dh,cforw[1]
	SET_CURSOR
	mov al,car_counters[7]
	cmp al,9
	jge cf_print_nine
	add al,48
	PRINT_CHAR_COLOR al,CYAN
	jmp cf_print_end
	cf_print_nine:
	PRINT_CHAR_COLOR '9',CYAN
	cf_print_end:
	pop dx
	pop cx
	pop ax
	ret
cf_print endp

cr_print proc
	push ax
	push cx
	push dx
	mov cx,1
	mov dl,cright[0]
	mov dh,cright[1]
	SET_CURSOR
	mov al,car_counters[8]
	cmp al,9
	jge cr_print_nine
	add al,48
	PRINT_CHAR_COLOR al,CYAN
	jmp cr_print_end
	cr_print_nine:
	PRINT_CHAR_COLOR '9',CYAN
	cr_print_end:
	pop dx
	pop cx
	pop ax
	ret
cr_print endp

dl_print proc
	push ax
	push cx
	push dx
	mov cx,1
	mov dl,dleft[0]
	mov dh,dleft[1]
	SET_CURSOR
	mov al,car_counters[9]
	cmp al,9
	jge dl_print_nine
	add al,48
	PRINT_CHAR_COLOR al,CYAN
	jmp dl_print_end
	dl_print_nine:
	PRINT_CHAR_COLOR '9',CYAN
	dl_print_end:
	pop dx
	pop cx
	pop ax
	ret
dl_print endp

df_print proc
	push ax
	push cx
	push dx
	mov cx,1
	mov dl,dforw[0]
	mov dh,dforw[1]
	SET_CURSOR
	mov al,car_counters[10]
	cmp al,9
	jge df_print_nine
	add al,48
	PRINT_CHAR_COLOR al,CYAN
	jmp df_print_end
	df_print_nine:
	PRINT_CHAR_COLOR '9',CYAN
	df_print_end:
	pop dx
	pop cx
	pop ax
	ret
df_print endp

dr_print proc
	push ax
	push cx
	push dx
	mov cx,1
	mov dl,dright[0]
	mov dh,dright[1]
	SET_CURSOR
	mov al,car_counters[11]
	cmp al,9
	jge dr_print_nine
	add al,48
	PRINT_CHAR_COLOR al,CYAN
	jmp dr_print_end
	dr_print_nine:
	PRINT_CHAR_COLOR '9',CYAN
	dr_print_end:
	pop dx
	pop cx
	pop ax
	ret
dr_print endp

paint_crossing proc ;paints the pedestrian crossing given in al yellow if ah is 1, or white if it is 0
	push bx
	push cx
	push dx
	;a
	mov cx,23
	mov dl,12
	mov dh,20
	SET_CURSOR
	cmp pedestrian_requests[0],1
	jne a_print_white
	mov ah,YELLOW
	jmp a_ped_print
	a_print_white:
	mov ah,WHITE
	a_ped_print:
	PRINT_CHAR_COLOR PEDCROSS,ah
	
	paint_crossing_b:
	cmp pedestrian_requests[1],1
	jne b_print_white
	mov ah,YELLOW
	jmp b_ped_print
	b_print_white:
	mov ah,WHITE
	b_ped_print:
	mov cx,1
	mov bl,8
	paint_crossing_b_1:
	mov dl,36
	mov dh,bl
	push ax
	SET_CURSOR
	pop ax
	push ax
	push bx
	PRINT_CHAR_COLOR PEDCROSS,ah
	pop bx
	pop ax
	inc bl
	cmp bl,13h
	jne paint_crossing_b_1
	paint_crossing_c:
	cmp pedestrian_requests[2],1
	jne c_print_white
	mov ah,YELLOW
	jmp c_ped_print
	c_print_white:
	mov ah,WHITE
	c_ped_print:
	mov cx,23
	mov dl,12
	mov dh,6
	push ax
	SET_CURSOR
	pop ax
	PRINT_CHAR_COLOR PEDCROSS,ah
	paint_crossing_d:
	cmp pedestrian_requests[3],1
	jne d_print_white
	mov ah,YELLOW
	jmp d_ped_print
	d_print_white:
	mov ah,WHITE
	d_ped_print:
	mov cx,1
	mov bl,8
	paint_crossing_d_1:
	mov dl,10
	mov dh,bl
	push ax
	SET_CURSOR
	pop ax
	push ax
	push bx
	PRINT_CHAR_COLOR PEDCROSS,ah
	pop bx
	pop ax
	inc bl
	cmp bl,13h
	jne paint_crossing_d_1
	
	paint_crossing_end:
	pop dx
	pop cx
	pop bx
	ret
paint_crossing endp

draw_sem proc ;procedure to draw semaphores, takes params on stack. Params to pass are orientation (vert, hor), coordinates of the light and color.
	push bp
	mov bp,sp
	push ax
	push bx
	push cx
	push dx
	mov cx,1
	mov bl,byte ptr[bp+4]
	mov dl,byte ptr[bp+6]
	mov dh,byte ptr[bp+7]
	SET_CURSOR
	mov al,byte ptr[bp+8]
	PRINT_CHAR_COLOR al,bl
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret
draw_sem endp

paint_displays proc ;paint pedestrian displays
	push ax
	push bx
	push cx
	push dx
	mov cx,1
	;a
	mov dl,adispcur[0]
	mov dh,adispcur[1]
	SET_CURSOR
	mov ah,00
	mov al,displays[0]
	mov bl,10
	div bl
	add al,48
	PRINT_CHAR al
	mov dl,adispcur[2]
	mov dh,adispcur[3]
	SET_CURSOR
	mov ah,00
	mov al,displays[0]
	mov bl,10
	div bl
	mov al,ah
	add al,48
	PRINT_CHAR al
	;b
	mov dl,bdispcur[0]
	mov dh,bdispcur[1]
	SET_CURSOR
	mov ah,00
	mov al,displays[1]
	mov bl,10
	div bl
	add al,48
	PRINT_CHAR al
	mov dl,bdispcur[2]
	mov dh,bdispcur[3]
	SET_CURSOR
	mov ah,00
	mov al,displays[1]
	mov bl,10
	div bl
	mov al,ah
	add al,48
	PRINT_CHAR al
	;c
	mov dl,cdispcur[0]
	mov dh,cdispcur[1]
	SET_CURSOR
	mov ah,00
	mov al,displays[2]
	mov bl,10
	div bl
	add al,48
	PRINT_CHAR al
	mov dl,cdispcur[2]
	mov dh,cdispcur[3]
	SET_CURSOR
	mov ah,00
	mov al,displays[2]
	mov bl,10
	div bl
	mov al,ah
	add al,48
	PRINT_CHAR al
	;d
	mov dl,ddispcur[0]
	mov dh,ddispcur[1]
	SET_CURSOR
	mov ah,00
	mov al,displays[3]
	mov bl,10
	div bl
	add al,48
	PRINT_CHAR al
	mov dl,ddispcur[2]
	mov dh,ddispcur[3]
	SET_CURSOR
	mov ah,00
	mov al,displays[3]
	mov bl,10
	div bl
	mov al,ah
	add al,48
	PRINT_CHAR al
	
	pop dx
	pop cx
	pop bx
	pop ax
	ret
paint_displays endp

swap_timer proc
	push ax
	push bx
	push dx
	push ds
	push es
	cli
	mov al,1ch
	mov ah,35h
	int 21h
	push es
	pop ds
	mov dx,bx
	mov al,30h
	mov ah,25h
	int 21h
	mov ax,seg new_timer_routine
	mov ds,ax
	mov dx,offset new_timer_routine
	mov al,1ch
	mov ah,25h
	int 21h
	sti
	pop es
	pop ds
	pop dx
	pop bx
	pop ax
	ret
swap_timer endp

restore_timer proc
	push ax
	push bx
	push dx
	push ds
	push es
	mov al,30h
	mov ah,35h
	int 21h
	push es
	pop ds
	mov dx,bx
	mov al,1ch
	mov ah,25h
	int 21h
	pop es
	pop ds
	pop dx
	pop bx
	pop ax
	ret
restore_timer endp

new_timer_routine proc far
	push ax
	push bx
	push cx
	push dx
	push ds
	mov ax,@data
	mov ds,ax
	dec seventh_part
	cmp seventh_part,0
	jne decrease_second
	mov seventh_part,new_seventh_part
	call blink_pedestrian
	decrease_second:
	dec second
	cmp second,0
	je timer_continue0
	jmp timer_end
	
	timer_continue0:
	mov second,new_second	
	call decrease_displays
	
	;increase wait counter for each lane
	mov cx,12
	lane_wait_time_increase:
	mov bx,12
	sub bx,cx
	cmp lane_green_flags[bx],1
	je continue_lane_wait
	shl bx,1
	inc lane_wait_counters[bx]
	continue_lane_wait:
	loop lane_wait_time_increase

	;increase wait counter for each crossing
	call pedestrian_wait_handler
	
	call decrease_car_counters
	
	mov al,current_time
	mov bl,cycle_time
	cmp al,bl
	jne timer_continue1
	mov current_time,0
	
	timer_continue1:
	call change_cycle
	mov al,cycle_time
	sub al,CYCLE_NEGATIVE_OFFSET
	cmp al,current_time
	je timer_next_cycle
	jmp timer_continue_misc
	
	timer_next_cycle:
	call next_cycle
	;check pedestrian queue for requests. If there are more than three, turn all car sems red.
	mov cx,4
	mov ax,0
	pedestrian_request_loop1:
	mov bx,4
	sub bx,cx
	add al,pedestrian_queue[bx]
	loop pedestrian_request_loop1
	cmp al,3
	jl timer_find_max
	jmp all_sems_red
	
	timer_find_max:
	call find_max_index
	mov al,current_hmax_index
	mov ah,00
	mov bl,2
	div bl
	mov current_closure_index,al
	mov ah,00
	mov si,ax
	mov bl,current_hmax_index
	mov bh,00
	mov cl,pedestrian_closure[si]
	examine_pedestrian_reqs_a:
	cmp pedestrian_queue[0],0
	je examine_pedestrian_reqs_b
	mov al,00001000b
	and al,cl
	cmp al,0
	je examine_pedestrian_reqs_b
	mov bl,current_hmax_index
	mov bh,00
	mov lane_sets_heuristics[bx],00
	jmp timer_find_max
	examine_pedestrian_reqs_b:
	cmp pedestrian_queue[1],0
	je examine_pedestrian_reqs_c
	mov al,00000100b
	and al,cl
	cmp al,0
	je examine_pedestrian_reqs_c
	mov bl,current_hmax_index
	mov bh,00
	mov lane_sets_heuristics[bx],00
	jmp timer_find_max
	examine_pedestrian_reqs_c:
	cmp pedestrian_queue[2],0
	je examine_pedestrian_reqs_d
	mov ax,00000010b
	and al,cl
	cmp al,0
	je examine_pedestrian_reqs_d
	mov bl,current_hmax_index
	mov bh,00
	mov lane_sets_heuristics[bx],00
	jmp timer_find_max
	examine_pedestrian_reqs_d:
	cmp pedestrian_queue[3],0
	je timer_continue2
	mov al,00000001b
	and al,cl
	cmp al,0
	je timer_continue2
	mov bl,current_hmax_index
	mov bh,00
	mov lane_sets_heuristics[bx],00
	jmp timer_find_max
	
	all_sems_red:
	mov current_hmax_index,76
	mov current_closure_index,38
	
	timer_continue2:
	;find lanes that should go red in next cycle
	mov bl,current_hmax_index
	mov bh,00
	mov ax,lane_sets[bx]
	mov cx,12
	find_next_cycle_red:
	mov si,12
	sub si,cx
	mov next_cycle_red[si],0
	shl si,1
	mov dx,lane_masks[si]
	shr si,1
	and dx,ax
	cmp dx,0
	jne find_next_cycle_red_continue
	mov next_cycle_red[si],1
	find_next_cycle_red_continue:
	loop find_next_cycle_red
	
	;find crossings that should go red in next cycle
	mov bl,current_closure_index
	mov bh,00
	mov al,pedestrian_closure[bx]
	mov next_cycle_red_crossing[0],0
	mov cl,00001000b
	and cl,al
	cmp cl,0
	je examine_closure_b
	mov next_cycle_red_crossing[0],1
	examine_closure_b:
	mov next_cycle_red_crossing[1],0
	mov cl,00000100b
	and cl,al
	cmp cl,0
	je examine_closure_c
	mov next_cycle_red_crossing[1],1
	examine_closure_c:
	mov next_cycle_red_crossing[2],0
	mov cl,00000010b
	and cl,al
	cmp cl,0
	je examine_closure_d
	mov next_cycle_red_crossing[2],1
	examine_closure_d:
	mov next_cycle_red_crossing[3],0
	mov cl,00000001b
	and cl,al
	cmp cl,0
	je timer_continue_misc
	mov next_cycle_red_crossing[3],1
		
	timer_continue_misc:	
	;paint displays yellow if needed
	call yellow_displays
	;blink green lights before going red
	call green_to_red
	call pedestrian_green
	call pedestrian_red
	call red_to_green
	inc current_time
	timer_end:
	int 30h
	pop ds
	pop dx
	pop cx
	pop bx
	pop ax
	iret
new_timer_routine endp

decrease_displays proc
	push ax
	push cx
	mov cx,4
	decrease_displays_loop:
	mov bx,4
	sub bx,cx
	cmp displays[bx],0
	je decrease_displays_continue
	dec displays[bx]
	decrease_displays_continue:
	loop decrease_displays_loop
	
	call paint_displays
	pop cx
	pop ax
	ret
decrease_displays endp

yellow_displays proc
	push ax
	push bx
	push cx
	push dx
	
	cmp pedestrian_green_flags[0],1
	jne yellow_displays_b
	cmp displays[0],11
	jge yellow_displays_b
	REDRAW_CHAR adispcur[0],adispcur[1],YELLOW
	REDRAW_CHAR adispcur[2],adispcur[3],YELLOW
	yellow_displays_b:
	cmp pedestrian_green_flags[1],1
	jne yellow_displays_c
	cmp displays[1],11
	jge yellow_displays_c
	REDRAW_CHAR bdispcur[0],bdispcur[1],YELLOW
	REDRAW_CHAR bdispcur[2],bdispcur[3],YELLOW
	yellow_displays_c:
	cmp pedestrian_green_flags[2],1
	jne yellow_displays_d
	cmp displays[2],11
	jge yellow_displays_d
	REDRAW_CHAR cdispcur[0],cdispcur[1],YELLOW
	REDRAW_CHAR cdispcur[2],cdispcur[3],YELLOW
	yellow_displays_d:
	cmp pedestrian_green_flags[3],1
	jne yellow_displays_end
	cmp displays[3],11
	jge yellow_displays_end
	REDRAW_CHAR ddispcur[0],ddispcur[1],YELLOW
	REDRAW_CHAR ddispcur[2],ddispcur[3],YELLOW
	yellow_displays_end:
	pop dx
	pop cx
	pop bx
	pop ax
	ret
yellow_displays endp

blink_pedestrian proc
	push ax
	push bx
	push cx
	push dx
	mov cx,4
	blink_pedestrian_loop:
	mov si,4
	sub si,cx
	cmp pedestrian_green_flags[si],1
	je compare_displays
	jmp blink_pedestrian_loop_continue
	compare_displays:
	cmp displays[si],11
	jl blink_pedestrian_loop1
	jmp blink_pedestrian_loop_continue
	blink_pedestrian_loop1:
	shl si,2
	push cx
	REDRAW_CHAR crossing_sem_cursors[si+2],crossing_sem_cursors[si+3],GREY
	pop cx
	shr si,2
	dec pedestrian_blink_counters[si]
	cmp pedestrian_blink_counters[si],0
	je blink_pedestrian_loop_continue
	mov al,pedestrian_blink_counters[si]
	mov dl,00000001b
	and dl,al
	cmp dl,00000001b	
	je blink_odd
	shl si,2
	push cx
	REDRAW_CHAR crossing_sem_cursors[si],crossing_sem_cursors[si+1],RED
	pop cx
	shr si,2
	jmp blink_pedestrian_loop_continue
	blink_odd:
	shl si,2
	push cx
	REDRAW_CHAR crossing_sem_cursors[si],crossing_sem_cursors[si+1],GREY
	pop cx
	shr si,2
	blink_pedestrian_loop_continue:
	loop blink_pedestrian_trigger
	jmp blink_pedestrian_end
	
	blink_pedestrian_trigger:
	jmp blink_pedestrian_loop
	
	blink_pedestrian_end:
	pop dx
	pop cx
	pop bx
	pop ax
	ret
blink_pedestrian endp

green_to_red proc
	push ax
	push bx
	push cx
	push dx
	mov al,cycle_time
	sub al,CYCLE_NEGATIVE_OFFSET
	cmp al,current_time
	je blink0
	inc al
	cmp current_time,al
	je blink1
	inc al
	cmp current_time,al
	je blink0
	inc al
	cmp current_time,al
	je blink1
	inc al
	cmp current_time,al
	je blink0
	inc al
	cmp current_time,al
	je jump_yellow
	inc al
	cmp current_time,al
	je jump_red
	jmp blink_end
	
	jump_red:
	jmp light_red
	
	jump_yellow:
	jmp light_yellow
	
	blink0:	
	mov cx,12
	blink0_loop:
	mov si,12
	sub si,cx
	cmp lane_green_flags[si],1
	jne blink0_loop_continue
	cmp next_cycle_red[si],1
	jne blink0_loop_continue
	mov bx,si
	shl si,2
	add si,bx
	add si,bx
	push cx
	REDRAW_CHAR semaphore_cursors[si+4],semaphore_cursors[si+5],GREY
	pop cx
	blink0_loop_continue:
	loop blink0_loop
	jmp blink_end
	
	blink1:
	mov cx,12
	blink1_loop:
	mov si,12
	sub si,cx
	cmp lane_green_flags[si],1
	jne blink1_loop_continue
	cmp next_cycle_red[si],1
	jne blink1_loop_continue
	mov bx,si
	shl si,2
	add si,bx
	add si,bx
	push cx
	REDRAW_CHAR semaphore_cursors[si+4],semaphore_cursors[si+5],GREEN
	pop cx
	blink1_loop_continue:
	loop blink1_loop
	jmp blink_end
	
	light_yellow:
	mov cx,12
	light_yellow_loop:
	mov si,12
	sub si,cx
	cmp lane_green_flags[si],1
	jne light_yellow_loop_continue
	cmp next_cycle_red[si],1
	jne light_yellow_loop_continue
	mov bx,si
	shl si,2
	add si,bx
	add si,bx
	push cx
	REDRAW_CHAR semaphore_cursors[si+4],semaphore_cursors[si+5],GREY
	REDRAW_CHAR semaphore_cursors[si+2],semaphore_cursors[si+3],YELLOW
	pop cx
	light_yellow_loop_continue:
	loop light_yellow_loop
	jmp blink_end
	
	light_red:
	mov cx,12
	light_red_loop:
	mov si,12
	sub si,cx
	cmp lane_green_flags[si],1
	jne light_red_loop_continue
	cmp next_cycle_red[si],1
	jne light_red_loop_continue
	mov lane_green_flags[si],0
	mov bx,si
	shl si,2
	add si,bx
	add si,bx
	push cx
	REDRAW_CHAR semaphore_cursors[si+2],semaphore_cursors[si+3],GREY
	REDRAW_CHAR semaphore_cursors[si],semaphore_cursors[si+1],RED
	pop cx
	light_red_loop_continue:
	loop light_red_loop
	jmp blink_end
	
	blink_end:
	pop dx
	pop cx
	pop bx
	pop ax
	ret
green_to_red endp

red_to_green proc
	push ax
	push bx
	push cx
	push dx	
	mov al,0
	cmp al,current_time
	je red_yellow
	mov al,1
	cmp al,current_time
	je yellow_green
	jmp red_to_green_end
	
	red_yellow:
	mov cx,12
	red_yellow_loop:
	mov si,12
	sub si,cx
	cmp next_cycle_red[si],0
	jne red_yellow_loop_continue
	cmp lane_green_flags[si],1
	je red_yellow_loop_continue
	mov bx,si
	shl si,2
	add si,bx
	add si,bx
	push cx
	REDRAW_CHAR semaphore_cursors[si+2],semaphore_cursors[si+3],YELLOW
	pop cx
	red_yellow_loop_continue:
	loop red_yellow_loop
	jmp red_to_green_end
	
	yellow_green:
	mov cx,12
	yellow_green_loop:
	mov si,12
	sub si,cx
	cmp next_cycle_red[si],0
	jne yellow_green_loop_continue
	cmp lane_green_flags[si],1
	je yellow_green_loop_continue
	mov lane_green_flags[si],1
	shl si,1
	mov lane_wait_counters[si],0
	shr si,1
	mov bx,si
	shl si,2
	add si,bx
	add si,bx
	push cx
	REDRAW_CHAR semaphore_cursors[si],semaphore_cursors[si+1],GREY
	REDRAW_CHAR semaphore_cursors[si+2],semaphore_cursors[si+3],GREY
	REDRAW_CHAR semaphore_cursors[si+4],semaphore_cursors[si+5],GREEN
	pop cx
	yellow_green_loop_continue:
	loop yellow_green_loop
	
	red_to_green_end:
	pop dx
	pop cx
	pop bx
	pop ax
	ret
red_to_green endp

decrease_car_counters proc
	push ax
	push bx
	push cx
	push dx
	mov cx,12
	decrease_counters_loop:
	mov bx,12
	sub bx,cx
	cmp lane_green_flags[bx],1
	jne decrease_counters_continue
	cmp car_counters[bx],0
	je decrease_counters_continue
	dec car_counters[bx]
	call al_print
	call af_print
	call ar_print
	call bl_print
	call bf_print
	call br_print
	call cl_print
	call cf_print
	call cr_print
	call dl_print
	call df_print
	call dr_print
	decrease_counters_continue:
	loop decrease_counters_loop
	pop dx
	pop cx
	pop bx
	pop ax
	ret
decrease_car_counters endp

pedestrian_wait_handler proc
	push ax
	push bx
	push cx
	push dx
	mov cx,4
	pedestrian_wait_time_increase:
	mov bx,4
	sub bx,cx
	cmp pedestrian_green_flags[bx],1
	je continue_pedestrian_wait
	cmp displays[bx],CYCLE_NEGATIVE_OFFSET
	jne continue_pedestrian_wait
	mov al,pedestrian_requests[bx]
	mov pedestrian_queue[bx],al
	
	continue_pedestrian_wait:
	loop pedestrian_wait_time_increase
	pop dx
	pop cx
	pop bx
	pop ax
	ret
pedestrian_wait_handler endp

pedestrian_green proc
	push ax
	push bx
	push cx
	push dx
	mov al,0
	cmp al,current_time
	je pedestrian_green_begin
	jmp pedestrian_green_end
	
	pedestrian_green_begin:
	mov cx,4
	pedestrian_green_loop:
	mov si,4
	sub si,cx
	inc pedestrian_skip_counters[si]
	cmp displays[si],0
	je pedestrian_green_cmp1
	jmp pedestrian_green_loop_continue
	pedestrian_green_cmp1:
	cmp next_cycle_red_crossing[si],0
	je pedestrian_green_loop1
	jmp pedestrian_green_loop_continue
	pedestrian_green_loop1:
	mov pedestrian_green_flags[si],1
	mov pedestrian_queue[si],0
	mov pedestrian_requests[si],0
	mov pedestrian_skip_counters[si],0
	call paint_crossing
	shl si,2
	push cx
	REDRAW_CHAR crossing_sem_cursors[si],crossing_sem_cursors[si+1],GREY
	REDRAW_CHAR crossing_sem_cursors[si+2],crossing_sem_cursors[si+3],GREEN
	pop cx
	shr si,2
	handle_displays_green:
	mov pedestrian_blink_counters[si],15
	mov al,cycle_time
	mov displays[si],al
	shl si,2
	push cx
	REDRAW_CHAR crossing_disp_cursors[si],crossing_disp_cursors[si+1],GREEN
	REDRAW_CHAR crossing_disp_cursors[si+2],crossing_disp_cursors[si+3],GREEN
	pop cx
	shr si,2
	pedestrian_green_loop_continue:
	mov al,pedestrian_wait_multiplier
	cmp pedestrian_skip_counters[si],al
	jle pedestrian_green_loop_continue2
	mov pedestrian_requests[si],1
	call paint_crossing
	pedestrian_green_loop_continue2:
	loop pedestrian_green_loop_trigger
	jmp pedestrian_green_end
	
	pedestrian_green_loop_trigger:
	jmp pedestrian_green_loop
	
	pedestrian_green_end:
	pop dx
	pop cx
	pop bx
	pop ax
	ret
pedestrian_green endp

pedestrian_red proc
	push ax
	push bx
	push cx
	push dx
	mov al,0
	cmp al,current_time
	je pedestrian_red_begin
	jmp pedestrian_red_end
	
	pedestrian_red_begin:
	mov cx,4
	pedestrian_red_loop:
	mov si,4
	sub si,cx
	cmp displays[si],0
	je pedestrian_red_loop1
	jmp pedestrian_red_loop_continue
	cmp next_cycle_red_crossing[si],1
	je pedestrian_red_loop1
	jmp pedestrian_red_loop_continue
	pedestrian_red_loop1:
	cmp pedestrian_green_flags[si],0
	je handle_displays_red
	mov pedestrian_green_flags[si],0
	shl si,2
	push cx
	REDRAW_CHAR crossing_sem_cursors[si+2],crossing_sem_cursors[si+3],GREY
	REDRAW_CHAR crossing_sem_cursors[si],crossing_sem_cursors[si+1],RED
	pop cx
	shr si,2
	handle_displays_red:
	mov al,cycle_time
	mul pedestrian_wait_multiplier
	mov displays[si],al
	shl si,2
	push cx
	REDRAW_CHAR crossing_disp_cursors[si],crossing_disp_cursors[si+1],RED
	REDRAW_CHAR crossing_disp_cursors[si+2],crossing_disp_cursors[si+3],RED
	pop cx
	pedestrian_red_loop_continue:
	loop pedestrian_red_loop_trigger
	jmp pedestrian_red_end
	
	pedestrian_red_loop_trigger:
	jmp pedestrian_red_loop
	
	pedestrian_red_end:
	pop dx
	pop cx
	pop bx
	pop ax
	ret
pedestrian_red endp

next_cycle proc
	push ax
	push bx
	push cx
	push dx
	mov cx,38
	next_cycle_loop1:
	mov bx,38
	sub bx,cx
	shl bx,1
	mov lane_sets_heuristics[bx],0000
	mov ax,lane_sets[bx]
	mov si,0
	next_cycle_inner_loop1:
	shl si,1
	mov dx,ax
	and dx,lane_masks[si]
	cmp dx,0000000000000000b
	je next_cycle_inner_loop1_continue
	shr si,1
	mov dl,car_counters[si]
	shl si,1
	cmp dl,0
	je next_cycle_inner_loop1_continue
	mov dx,lane_wait_counters[si]
	add lane_sets_heuristics[bx],dx
	next_cycle_inner_loop1_continue:
	shr si,1
	inc si
	cmp si,12
	jne next_cycle_inner_loop1
	
	loop next_cycle_loop1
	
	pop dx
	pop cx
	pop bx
	pop ax
	ret
next_cycle endp

find_max_index proc ;finds lane combination with highest heuristic and returns its index
	push ax
	push bx
	push cx
	push dx
	mov al,current_hmax_index
	mov old_hmax_index,al
	
	mov cx,38
	mov current_hmax_index,0
	mov current_hmax,0000
	find_max_loop:
	mov bx,38
	sub bx,cx
	shl bx,1
	mov ax,lane_sets_heuristics[bx]
	cmp ax,current_hmax
	jle find_max_loop_continue
	mov current_hmax,ax
	mov current_hmax_index,bl
	find_max_loop_continue:
	loop find_max_loop
	cmp current_hmax,0000
	jne find_max_end
	mov cx,4
	mov al,0
	find_max_loop_ped_queue:
	mov bx,4
	sub bx,cx
	add al,pedestrian_queue[bx]
	loop find_max_loop_ped_queue
	cmp al,0
	je find_max_choose_old
	mov current_hmax_index,76
	jmp find_max_end
	find_max_choose_old:
	mov al,old_hmax_index
	mov current_hmax_index,al
	find_max_end:
	pop dx
	pop cx
	pop bx
	pop ax
	ret
find_max_index endp

init_structures proc
	cli	
	mov lane_sets[0],0000010000001101b
	mov lane_sets[2],0000011001001101b
	mov lane_sets[4],0000101010000001b
	mov lane_sets[6],0000101011001001b
	mov lane_sets[8],0000001101010000b
	mov lane_sets[10],0000001101011001b
	mov lane_sets[12],0000000001101010b
	mov lane_sets[14],0000001001101011b
	mov lane_sets[16],0000110000001001b
	mov lane_sets[18],0000111001001001b
	mov lane_sets[20],0000001110000001b
	mov lane_sets[22],0000001111001001b
	mov lane_sets[24],0000001001110000b
	mov lane_sets[26],0000001001111001b
	mov lane_sets[28],0000000001001110b
	mov lane_sets[30],0000001001001111b
	mov lane_sets[32],0000010000010000b
	mov lane_sets[34],0000011001010000b
	mov lane_sets[36],0000010000011001b
	mov lane_sets[38],0000011001011001b
	mov lane_sets[40],0000000010000010b
	mov lane_sets[42],0000000011001010b
	mov lane_sets[44],0000001010000011b
	mov lane_sets[46],0000001011001011b
	mov lane_sets[48],0000100000000001b
	mov lane_sets[50],0000101010000001b
	mov lane_sets[52],0000101011001001b
	mov lane_sets[54],0000001100000000b
	mov lane_sets[56],0000001101010000b
	mov lane_sets[58],0000001101011001b
	mov lane_sets[60],0000000001100000b
	mov lane_sets[62],0000000001101010b
	mov lane_sets[64],0000001001101011b
	mov lane_sets[66],0000000000001100b
	mov lane_sets[68],0000010000001101b
	mov lane_sets[70],0000011001001101b
	mov lane_sets[72],0000101001101001b
	mov lane_sets[74],0000001101001101b
	mov lane_sets[76],0000000000000000b
	
	mov lane_masks[0],0000100000000000b
	mov lane_masks[2],0000010000000000b
	mov lane_masks[4],0000001000000000b
	mov lane_masks[6],0000000100000000b
	mov lane_masks[8],0000000010000000b
	mov lane_masks[10],0000000001000000b
	mov lane_masks[12],0000000000100000b
	mov lane_masks[14],0000000000010000b
	mov lane_masks[16],0000000000001000b
	mov lane_masks[18],0000000000000100b
	mov lane_masks[20],0000000000000010b
	mov lane_masks[22],0000000000000001b
	
	mov next_cycle_red[1],0
	mov next_cycle_red[7],0
	
	mov pedestrian_closure[0],00001011b
	mov pedestrian_closure[1],00001111b
	mov pedestrian_closure[2],00001101b
	mov pedestrian_closure[3],00001111b
	mov pedestrian_closure[4],00001110b
	mov pedestrian_closure[5],00001111b
	mov pedestrian_closure[6],00000111b
	mov pedestrian_closure[7],00001111b
	mov pedestrian_closure[8],00001011b
	mov pedestrian_closure[9],00001111b
	mov pedestrian_closure[10],00001101b
	mov pedestrian_closure[11],00001111b
	mov pedestrian_closure[12],00001110b
	mov pedestrian_closure[13],00001111b
	mov pedestrian_closure[14],00000111b
	mov pedestrian_closure[15],00001111b
	mov pedestrian_closure[16],00001010b
	mov pedestrian_closure[17],00001110b
	mov pedestrian_closure[18],00001011b
	mov pedestrian_closure[19],00001111b
	mov pedestrian_closure[20],00000101b
	mov pedestrian_closure[21],00000111b
	mov pedestrian_closure[22],00001101b
	mov pedestrian_closure[23],00001111b
	mov pedestrian_closure[24],00001001b
	mov pedestrian_closure[25],00001101b
	mov pedestrian_closure[26],00001111b
	mov pedestrian_closure[27],00001100b
	mov pedestrian_closure[28],00001110b
	mov pedestrian_closure[29],00001111b
	mov pedestrian_closure[30],00000110b
	mov pedestrian_closure[31],00000111b
	mov pedestrian_closure[32],00001111b
	mov pedestrian_closure[33],00000011b
	mov pedestrian_closure[34],00001011b
	mov pedestrian_closure[35],00001111b
	mov pedestrian_closure[36],00001111b
	mov pedestrian_closure[37],00001111b
	mov pedestrian_closure[38],00000000b
	
	mov next_cycle_red_crossing[1],0
	mov next_cycle_red_crossing[3],0
	
	mov current_hmax_index,32
	mov current_closure_index,16
	sti
	ret
init_structures endp

pause_system proc
	cmp system_paused,0
	jne unpause
	
	mov dl,51
	mov dh,18
	SET_CURSOR
	lea si,msg_status_paused
	mov bl,51
	mov cx,1
	pause_system_status_paused:
	mov al,[si]
	inc si
	inc bl
	push bx
	PRINT_CHAR_COLOR al,RED
	pop bx
	mov dl,bl
	SET_CURSOR
	cmp al,0
	jne pause_system_status_paused
	call restore_timer
	mov system_paused,1
	jmp pause_system_end
	unpause:
	mov dl,51
	mov dh,18
	SET_CURSOR
	lea si,msg_status_running
	mov bl,51
	mov cx,1
	pause_system_status_running:
	mov al,[si]
	inc si
	inc bl
	push bx
	PRINT_CHAR_COLOR al,GREY
	pop bx
	mov dl,bl
	SET_CURSOR
	cmp al,0
	jne pause_system_status_running
	call swap_timer
	mov system_paused,0
	pause_system_end:
	ret
pause_system endp

input_cycle proc
	push ax
	push bx
	push cx
	push dx
	mov dl,63
	mov dh,14
	SET_CURSOR
	mov al, ' '
	mov ah,0eh
	int 10h
	int 10h
	
	mov	ah,0h
	int	16h
	mov dl,63
	mov dh,14
	SET_CURSOR
	mov ah,0eh
	int 10h
	sub al,48
	mov bl,10
	mul bl
	mov new_cycle_time,al
	
	mov	ah,0h
	int	16h
	mov dl,63
	mov dh,14
	SET_CURSOR
	mov ah,0eh
	int 10h
	sub al,48
	add new_cycle_time,al
	
	mov al,new_cycle_time
	cmp al,10
	jle input_cycle_print
	mov ah,00
	mov bl,pedestrian_wait_multiplier
	mul bl
	cmp ax,100
	jge input_cycle_print
	mov cycle_changed,1
	mov dl,63
	mov dh,14
	SET_CURSOR
	mov al,new_cycle_time
	mov ah,00
	mov bl,10
	div bl
	add al,48
	mov bh,ah
	mov ah,0eh
	int 10h
	mov al,bh
	add al,48
	int 10h
	jmp input_cycle_exit
	input_cycle_print:
	call draw_cycle_info
	
	input_cycle_exit:
	pop dx
	pop cx
	pop bx
	pop ax
	ret
input_cycle endp

change_cycle proc
	push ax
	push bx
	push cx
	push dx
	cmp current_time,0
	je cycle_changed_cmp_changed
	jmp change_cycle_exit
	cycle_changed_cmp_changed:
	cmp cycle_changed,1
	jne change_cycle_exit
	mov al,new_cycle_time
	cmp al,cycle_time
	jge change_cycle_new_greater
	mov bl,cycle_time
	sub bl,al
	mov cx,4
	change_cycle_loop1:
	mov si,4
	sub si,cx
	cmp pedestrian_green_flags[si],0
	jne change_cycle_loop1_continue
	cmp displays[si],0
	je change_cycle_loop1_continue
	push ax
	push cx
	mov al,displays[si]
	mov ah,00
	mov dl,cycle_time
	div dl
	mul bl
	sub displays[si],al
	pop cx
	pop ax
	change_cycle_loop1_continue:
	loop change_cycle_loop1
	jmp change_cycle_switch
	change_cycle_new_greater:
	mov bl,al
	sub bl,cycle_time
	mov cx,4
	change_cycle_loop2:
	mov si,4
	sub si,cx
	cmp pedestrian_green_flags[si],0
	jne change_cycle_loop2_continue
	cmp displays[si],0
	je change_cycle_loop2_continue
	push ax
	push cx
	mov al,displays[si]
	mov ah,00
	mov dl,cycle_time
	div dl
	mul bl
	add displays[si],bl
	pop cx
	pop ax
	change_cycle_loop2_continue:
	loop change_cycle_loop2
	
	change_cycle_switch:
	mov cycle_time,al
	mov cycle_changed,0
	change_cycle_exit:
	pop dx
	pop cx
	pop bx
	pop ax
	ret
change_cycle endp

input_multiplier proc
	push ax
	push bx
	push cx
	push dx
	mov dl,63
	mov dh,16
	SET_CURSOR
	mov al, ' '
	mov ah,0eh
	int 10h
	int 10h
	
	mov	ah,0h
	int	16h
	sub al,48
	mov new_pedestrian_wait_multiplier,al
	cmp new_pedestrian_wait_multiplier,0
	jle input_multiplier_print
	mov ah,00
	mov bl,cycle_time
	mul bl
	cmp ax,100
	jge input_multiplier_print
	mov al,new_pedestrian_wait_multiplier
	mov pedestrian_wait_multiplier,al
	input_multiplier_print:
	call draw_cycle_info
	
	pop dx
	pop cx
	pop bx
	pop ax
	ret
input_multiplier endp

hide_cursor proc
	push ax
	push cx
	mov cx,2607h
	mov ah,1h
    int 10h
	pop cx
	pop ax
	ret
hide_cursor endp

show_cursor proc
	push ax
	push cx
	mov cx,0007h
	mov ah,1h
    int 10h
	pop cx
	pop ax
	ret
show_cursor endp

main:
	mov ax,@data
	mov ds,ax
	call clrscr
	;hide cursor
	call hide_cursor
	;drawing procedures
	call draw_crossroad
	call al_print
	call af_print
	call ar_print
	call bl_print
	call bf_print
	call br_print
	call cl_print
	call cf_print
	call cr_print
	call dl_print
	call df_print
	call dr_print
	call draw_info
	call draw_cycle_info
	
	;al sem
	DRAW_SEMAPHORE LIGHTV,alsem[0],alsem[1],RED
	DRAW_SEMAPHORE LIGHTV,alsem[2],alsem[3],GREY
	DRAW_SEMAPHORE LIGHTV,alsem[4],alsem[5],GREY
	
	;af sem
	DRAW_SEMAPHORE LIGHTV,afsem[0],afsem[1],RED
	DRAW_SEMAPHORE LIGHTV,afsem[2],afsem[3],GREY
	DRAW_SEMAPHORE LIGHTV,afsem[4],afsem[5],GREY
	
	;ar sem
	DRAW_SEMAPHORE LIGHTV,arsem[0],arsem[1],RED
	DRAW_SEMAPHORE LIGHTV,arsem[2],arsem[3],GREY
	DRAW_SEMAPHORE LIGHTV,arsem[4],arsem[5],GREY
	
	;bl sem
	DRAW_SEMAPHORE LIGHTH,blsem[0],blsem[1],RED
	DRAW_SEMAPHORE LIGHTH,blsem[2],blsem[3],GREY
	DRAW_SEMAPHORE LIGHTH,blsem[4],blsem[5],GREY
	
	;bf sem
	DRAW_SEMAPHORE LIGHTH,bfsem[0],bfsem[1],RED
	DRAW_SEMAPHORE LIGHTH,bfsem[2],bfsem[3],GREY
	DRAW_SEMAPHORE LIGHTH,bfsem[4],bfsem[5],GREY
	
	;br sem
	DRAW_SEMAPHORE LIGHTH,brsem[0],brsem[1],RED
	DRAW_SEMAPHORE LIGHTH,brsem[2],brsem[3],GREY
	DRAW_SEMAPHORE LIGHTH,brsem[4],brsem[5],GREY
	
	;cl sem
	DRAW_SEMAPHORE LIGHTV,clsem[0],clsem[1],RED
	DRAW_SEMAPHORE LIGHTV,clsem[2],clsem[3],GREY
	DRAW_SEMAPHORE LIGHTV,clsem[4],clsem[5],GREY
	
	;cf sem
	DRAW_SEMAPHORE LIGHTV,cfsem[0],cfsem[1],RED
	DRAW_SEMAPHORE LIGHTV,cfsem[2],cfsem[3],GREY
	DRAW_SEMAPHORE LIGHTV,cfsem[4],cfsem[5],GREY
	
	;cr sem
	DRAW_SEMAPHORE LIGHTV,crsem[0],crsem[1],RED
	DRAW_SEMAPHORE LIGHTV,crsem[2],crsem[3],GREY
	DRAW_SEMAPHORE LIGHTV,crsem[4],crsem[5],GREY
	
	;dl sem
	DRAW_SEMAPHORE LIGHTH,dlsem[0],dlsem[1],RED
	DRAW_SEMAPHORE LIGHTH,dlsem[2],dlsem[3],GREY
	DRAW_SEMAPHORE LIGHTH,dlsem[4],dlsem[5],GREY
	
	;df sem
	DRAW_SEMAPHORE LIGHTH,dfsem[0],dfsem[1],RED
	DRAW_SEMAPHORE LIGHTH,dfsem[2],dfsem[3],GREY
	DRAW_SEMAPHORE LIGHTH,dfsem[4],dfsem[5],GREY
	
	;dr sem
	DRAW_SEMAPHORE LIGHTH,drsem[0],drsem[1],RED
	DRAW_SEMAPHORE LIGHTH,drsem[2],drsem[3],GREY
	DRAW_SEMAPHORE LIGHTH,drsem[4],drsem[5],GREY
	
	;pedestrian sems
	;aped
	DRAW_SEMAPHORE LIGHTH,aped[0],aped[1],RED
	DRAW_SEMAPHORE LIGHTH,aped[2],aped[3],GREY
	
	;bped
	DRAW_SEMAPHORE LIGHTV,bped[0],bped[1],RED
	DRAW_SEMAPHORE LIGHTV,bped[2],bped[3],GREY
	
	;cped
	DRAW_SEMAPHORE LIGHTH,cped[0],cped[1],RED
	DRAW_SEMAPHORE LIGHTH,cped[2],cped[3],GREY
	
	;dped
	DRAW_SEMAPHORE LIGHTV,dped[0],dped[1],RED
	DRAW_SEMAPHORE LIGHTV,dped[2],dped[3],GREY
	
	call paint_displays
	REDRAW_CHAR adispcur[0],adispcur[1],RED
	REDRAW_CHAR adispcur[2],adispcur[3],RED
	REDRAW_CHAR bdispcur[0],bdispcur[1],GREEN
	REDRAW_CHAR bdispcur[2],bdispcur[3],GREEN
	REDRAW_CHAR cdispcur[0],cdispcur[1],RED
	REDRAW_CHAR cdispcur[2],cdispcur[3],RED	
	REDRAW_CHAR ddispcur[0],ddispcur[1],GREEN
	REDRAW_CHAR ddispcur[2],ddispcur[3],GREEN	
	
	call init_structures
	call swap_timer
	;keyboard handlers
	keyboard:
	;lane a
	mov	ah,0h
	int	16h
	cmp al,'q'
	jne alanef
	inc car_counters[0]
	call al_print
	jmp keyboard
	alanef:
	cmp al,'a'
	jne alaner
	inc car_counters[1]
	call af_print
	jmp keyboard
	alaner:
	cmp al,'z'
	jne blanel
	inc car_counters[2]
	call ar_print
	jmp keyboard
	;lane b
	blanel:
	cmp al,'w'
	jne blanef
	inc car_counters[3]
	call bl_print
	jmp keyboard
	blanef:
	cmp al,'s'
	jne blaner
	inc car_counters[4]
	call bf_print
	jmp keyboard
	blaner:
	cmp al,'x'
	jne clanel
	inc car_counters[5]
	call br_print
	jmp keyboard
	;lane c
	clanel:
	cmp al,'e'
	jne clanef
	inc car_counters[6]
	call cl_print
	jmp keyboard
	clanef:
	cmp al,'d'
	jne claner
	inc car_counters[7]
	call cf_print
	jmp keyboard
	claner:
	cmp al,'c'
	jne dlanel
	inc car_counters[8]
	call cr_print
	jmp keyboard
	;lane d
	dlanel:
	cmp al,'r'
	jne dlanef
	inc car_counters[9]
	call dl_print
	jmp keyboard
	dlanef:
	cmp al,'f'
	jne dlaner
	inc car_counters[10]
	call df_print
	jmp keyboard
	dlaner:
	cmp al,'v'
	jne pedestrian_a
	inc car_counters[11]
	call dr_print
	jmp keyboard
	
	pedestrian_a:
	cmp al,CROSSINGA
	jne pedestrian_b
	cmp pedestrian_green_flags[0],1
	je pedestrian_b
	mov pedestrian_requests[0],1
	call paint_crossing
	jmp keyboard
	
	pedestrian_b:
	cmp al,CROSSINGB
	jne pedestrian_c
	cmp pedestrian_green_flags[1],1
	je pedestrian_c
	mov pedestrian_requests[1],1
	call paint_crossing
	jmp keyboard
	
	pedestrian_c:
	cmp al,CROSSINGC
	jne pedestrian_d
	cmp pedestrian_green_flags[2],1
	je pedestrian_d
	mov pedestrian_requests[2],1
	call paint_crossing
	jmp keyboard
	
	pedestrian_d:
	cmp al,CROSSINGD
	jne chk_pause
	cmp pedestrian_green_flags[3],1
	je chk_pause
	mov pedestrian_requests[3],1
	call paint_crossing
	jmp keyboard
	
	chk_pause:
	cmp al,SYS_PAUSE
	jne chk_input_cycle
	call pause_system
	jmp keyboard
	
	chk_input_cycle:
	cmp al,SET_CYCLE
	jne chk_input_multi
	call input_cycle
	jmp keyboard
	
	chk_input_multi:
	cmp al,SET_MULTIPLIER
	jne chk_exit
	call input_multiplier
	jmp keyboard
	
	;check if esc to exit
	chk_exit:
	cmp al,EXIT
	je finish
	jmp keyboard
	
	finish:
	call restore_timer
	mov dl,0
	mov dh,25
	SET_CURSOR
	mov ax, 4c00h
	int 21h
end main
