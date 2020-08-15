#make_bin#

#LOAD_SEGMENT=FFFFh#
#LOAD_OFFSET=0000h#

#CS=0000h#
#IP=0000h#

#DS=0000h#
#ES=0000h#

#SS=0000h#
#SP=FFFEh#

#AX=0000h#
#BX=0000h#
#CX=0000h#
#DX=0000h#
#SI=0000h#
#DI=0000h#
#BP=0000h#
;THIS CODE IS FOR THE ACTIUAL DESIGN
; add your code here
         jmp     st1 
         nop
         db 	159 dup(0)
		 dw 	auto_isr	;isr is 40h, 40h*4 = 100h interupt 0 for auto mode
		 dw 	0000
		 dw 	rpmcheck_isr ;interrupt 1 for sensing and controlling rpm 
		 dw		0000
		 db     853 dup(0)
;main program
          
st1:      cli 
; intialize ds,es,ss to start of RAM
          mov       ax,2000h
          mov       ds,ax
          mov       es,ax
          mov       ss,ax
          mov       sp,0FFFEH 
		  
;initializing 8255 
;port A is output 
;C lower is output, C upper is input 
;Port B is output
		mov		al,10001000b
		out 	06h,al
		
;initializing timer 1 (for measuring time while in auto mode)
		mov 	al,00110000b ; counter 0, 16 bit count, mode 0 counting in binary
		out 	0eh,al		
		
		mov 	al,01110110b ; counter 1, 16 bit count, mode 3 counting in binary
		out 	0eh,al
		
		mov 	al,10110110b ; counter 2, 16 bit count, mode 3 counting in binary
		out 	0eh,al
		
;initializing timer 2 (for checking fan rpm)
		mov 	al,00010000b ; counter 0, 8 bit count, mode 0 counting in binary
		out 	16h,al
		
		mov		al,01110110b ; counter 1, 16 bit count, mode 3 counting in binary
		out 	16h,al
		
		mov 	al,10010110b ; counter 2, 8 bit count, mode 3 counting in binary
		out 	16h,al
		
;initializing 8259
		mov 	al,00010011b ; ic1 not sure if D4=1/0 tut 10 and slides conflict(doesn't matter, its don't care for x86 devices) 
		out 	18h,al
		
		mov 	al,01000000b ; icw2, Starting vector number is 40h
		out 	20h,al
		
		mov 	al,00000001b ; icw4
		out 	20h,al
		
		mov 	al,11111100b ; ocw1 only interrupts 0 and 1 are enabled
		out 	20h,al
		
;waiting for start to be pressed
		mov dx,0 ; dl will store whatever we give as output to the DAC 
		
x0:		mov 	al,00h	;check for key release
		out 	04h,al
x1:		in 		al,04h
		and 	al,0f0h
		cmp 	al,0f0h
		jnz 	x1
		
		call 	delay_20ms	; debounce.
		
		mov 	al,00h
		out 	04h,al	
x2:		in 		al,04h	;checking for key press
		and 	al,0f0h	
		cmp 	al,0f0h
		jz 		x2
		
		call 	delay_20ms
		
		mov 	al,00h
		out 	04h,al	
		in 		al,04h	;checking if valid key press - if key is still pressed after a small delay_20ms 
		and 	al,0f0h
		cmp 	al,0f0h
		jz 		x2
		
		mov 	al,0eh	; checking only first column, as "start" is key 0
		out 	04h,al	
		in 		al,04h	
		and 	al,0f0h
		cmp		al,0f0h
		jz 		x0		;if a key in some other column is pressed, start over from x0
		
						;if key pressed is in 1st column 
		cmp 	al,0e0h ;if key pressed is 0, al will have e0h
		jnz 	x0		;if some other key in column 0 is pressed we start over from x0
		
		;if control of program is here, it means that start has been pressed
		;now we wait for a key press	

		mov ah,0 ;ah is used to differentiate if the input is taken for regular or time for auto mode or disabling auto mode
					;ah=0 =>regular  ah=1 =>time input for auto ah=2 =>we are in auto and user can toggle back to regular mode
		
y0:		mov 	al,00h	;check for key release
		out 	04h,al	
y1:		in 		al,04h
		and 	al,0f0h
		cmp 	al,0f0h
		jnz 	y1
		call 	delay_20ms	; debounce.
		
		mov 	al,00h
		out 	04h,al	
y2:		in 		al,04h	;checking for key press
		and 	al,0f0h
		cmp 	al,0f0h
		jz 		y2
		
		call 	delay_20ms
		
		mov 	al,00h
		out 	04h,al	
		in 		al,04h	;checking if valid key press - if key is still pressed after a small delay_20ms 
		and 	al,0f0h
		cmp 	al,0f0h
		jz 		y2
		
		mov al,06h ; column 0
		mov bl,al
		out 04h,al
		in al,04h
		and al,0f0h	
		cmp al,0f0h
		jnz y3
		
		mov al,05h ; column 1
		mov bl,al
		out 04h,al
		in al,04h
		and al,0f0h
		cmp al,0f0h
		jnz y3
		
		mov al,03h ; column 2
		mov bl,al
		out 04h,al
		in al,04h
		and al,0f0h
		cmp al,0f0h
		jz y0
		    
		
y3:		or al,bl	;decoding
		;bh will store the current speed
		
		cmp al,0e6h		;0: start is pressed again after the initial start. No effect
		jz y0
		
		cmp al,0e5h ;1: speed 1 is set
		jnz y4
		mov bh,1
		jz set
		
y4:		cmp al,0e3h ;2: speed 2 is set
		jnz y5
		mov bh,2
		jz set
		
y5:		cmp al,0d6h ;3: speed 3 is set
		jnz y6
		mov bh,3
		jz set
		
y6:		cmp al,0d5h ;4: speed 4 is set
		jnz y7
		mov bh,4
		jz set
		
y7:		cmp al,0d3h ;5: speed 5 is set
		jnz y8
		mov bh,5
		jz set
		
y8:		cmp al,0b6h ;6: speed inc by one
		jz up
		
		cmp al,0b5h ;7: speed dec by one
		jz down
		
		cmp al,0b3h ;8: stop
		jz stop
		
		cmp al,76h ;9: auto
		jz auto
		
		cmp al,75h ;10 diable auto
		jz disauto
		
set:	cmp ah,1 ;checks if the number given was for auto mode or regular mode
		jz auto2
		cmp ah,2
		jz y0
		
		mov al,bh	;writing speed setting to 7-seg display
		out 02h,al
		
		sti
		mov al,64h;we move 100 into counter 0
		out 10h,al;after 1 sec we calculate the rpm
		
		mov al,0a8h ; counter 1, 61a8h = 25000d
		out 12h,al	; clk = 2.5MHz out=100Hz
		mov al,61h
		out 12h,al
		
		mov al,64h ; counter 2  64h=100d
		out 14h,al ; clk=100Hz out = 100/100 = 1 Hz
		
		;from here on interrupts are raised every second
		
		jmp y0
		
up:		cmp ah,1 ; if user presses 'up' after auto or while in auto mode, we wait for key press
		jae y0
		
		cmp bh,05h
		jz y0
		
		inc bh
		jmp set
		
down:	cmp ah,1 ; if user presses 'down' after auto or while in auto mode, we wait for key press
		jae y0
		
		cmp bh,01h
		jz y0
		
		dec bh
		jmp set
		
stop:
		mov al,00h 
		out 00h,al	;Vout = 0V
		out 02h,al	;write zero to display
		out 04h,al  ;timers are disabld
		mov ah,00h  ;when restarting, go to regular mode
		
		jmp x0
		
auto:	
		cmp ah,2	;if auto is pressed again while in auto mode we disable auto mode
		jz disauto
					;now we get the input for no. of hours
		mov ah,1
		jmp y0

auto2:	;here bh will have number of hours
		;now we set PC3 to enable timer 1
		
		mov al,08h ; make pc3 high
		out 04h,al 
		
		mov al,0a8h ; counter 1, 61a8h = 25000d
		out 0ah,al	; clk = 2.5MHz out=100Hz
		mov al,61h
		out 0ah,al
		
		mov al,70h ; counter 2  1770h=6000d
		out 0ch,al ; clk=100Hz out = 100/6000 = 1/60 Hz => 1 per minute
		mov al,17h
		out 0ch,al
		
		mov cl,bh
		mov bx,0
		
l1:		add bx,3ch ; 3ch=60d
		dec cl		; repeated addition to get total count
		jnz l1 
		
		mov al,bl
		out 08h,al
		mov al,bh
		out 08h,al
		
		sti
		mov ah,2
		jmp y0
		
disauto:
		cli
		mov ah,00h ; as we are going back to regular mode
		mov al,00h
		mov al,00000000b 
		out 04h,al ;PC3 made 0 
		jmp y0

auto_isr:
	; when time period is over we switch off everything
	mov al,00h 
	out 00h,al	;Vout = 0V
	out 02h,al	;move zero to display
	out 04h,al  ;PC3 made 0
	
	mov al,00100000b ;Non-specific EOI
	out 18h,al
	jmp x0	;return to start of program
	
	iret

rpmcheck_isr:
	;note that the comments are in decimal but the values stored in registers are all in hexadecimal
	
	mov al,11010010b	;reading count of only counter0. Read back mode is used here for timer 2
	out 16h,al
	in al,10h
	mov bl,65h ; 101d=65h
	sub bl,al ; RPS = 101 - x
	
	;bl has 3 times the rps
	;if we put a magnet on each blade of the fan, we get 3*rps. This results in more accurate reading of rpm
	
	;speed setting to rpm mapping
	;1 = 300 rpm = 15 3rps
	;2 = 360 rpm = 18 3rps
	;3 = 420 rpm = 21 3rps
	;4 = 480 rpm = 24 3rps
	;5 = 540 rpm = 27 3rps
	
	mov cl,15
	cmp bh,1
	jz t1
	
	mov cl,18
	cmp bh,2
	jz t1
	
	mov cl,21
	cmp bh,3
	jz t1
	
	mov cl,24
	cmp bh,4
	jz t1
	
	mov cl,27
	cmp bh,5
	jz t1
	
t1:	;we inc/dec input to DAC and voltage proportional to the change in rpm required
	;requred change in DAC input = (1/40)((desired rpm)-(actual rpm)) = (1/2) ((3rps desired)-(actual 3rps))
	
	mov ch,ah ;temporarily store ah in ch as we will be doing division
	
	cmp cl,bl
	
	ja z1
	jb z2
	jz z4
	
z2: sub bl,cl ; bl>cl
	mov al,bl
	mov ah,00h
	mov cl,2
	div cl
	
	sub dl,al
	mov ah,ch
	
	cmp dl,0
	jg zz
	mov dl,0 ; in case dl becomes negative
	
zz:	mov al,dl
	out 00h,al 
	jmp z4
	
z1:	sub cl,bl ; cl>bl 

	mov al,cl
	mov ah,00h
	mov bl,2	;value of bl not needed anymore as we already have difference of 3rps stored in cl
	div bl
				;now al will have the amount by which to change input to DAC
	
	add dl,al   
	mov ah,ch	;restore value of ah

	mov al,dl
	out 00h,al

z4:	mov al,64h;we load 100 back into counter 0
	out 10h,al;after 1 more sec we calculate the rpm
	
	mov al,00100000b ;Non-specific EOI
	out 18h,al
	
	iret
	
delay_20ms:
    	mov		  	cx,2000 ; delay generated will be approx 20msecs
xn:		loop	  	xn
        ret 
		
hlt ;halt!