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
;THIS CODE IS FOR THE PROTEUS SIMULATION
; add your code here
         jmp     st1 
         nop
         db 	159 dup(0)
		 dw 	auto_isr	;isr is 40h, 40h*4 = 100h interupt 0 for auto mode
		 dw 	0000
		 dw 	0000 
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
		mov 	al,00010000b ; counter 0, 8 bit count, mode 0 counting in binary
		out 	0eh,al		
		
		mov 	al,01010110b ; counter 1, 8 bit count, mode 3 counting in binary
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
		
		
;waiting for start to be pressed
		mov dx,0 ; dx will store whatever we give as output to the DAC 
		
x0:		mov 	al,00h	;check for key release
		out 	04h,al
x1:		in 		al,04h
		and 	al,0f0h
		cmp 	al,0f0h
		jnz 	x1
		
		call 	delay_20ms	; debounce.
		
		mov 	al,00h
		out 	04h,al	;**note that this will disable timer 1
x2:		in 		al,04h	;checking for key press
		and 	al,0f0h	
		cmp 	al,0f0h
		jz 		x2
		
		call 	delay_20ms
		
		mov 	al,00h
		out 	04h,al	;**note that this will disable timer 1
		in 		al,04h	;checking if valid key press - if key is still pressed after a small delay_20ms 
		and 	al,0f0h
		cmp 	al,0f0h
		jz 		x2
		
		mov 	al,0eh	; checking only first column, as "start" is key 0 which is in the first column
		out 	04h,al	;**this will enable timer1
		in 		al,04h	
		and 	al,0f0h
		cmp		al,0f0h
		jz 		x0		;if a key in some other column is pressed, start over from x0
		
						;if key pressed is in 1st column 
		cmp 	al,0e0h ;if key pressed is 0, al will have e0h
		jnz 	x0		;if some other key in column 0 is pressed we start over from x0
		
		;if control of program is here, it means that start has been pressed
		;now we wait for a key press	
		;---------------------------------------------------------------
		mov ah,0 ;ah is used to differentiate if the input is taken for regular or time for auto mode or disabling auto mode
					;ah=0 =>regular  ah=1 =>input for auto ah=>we are in auto and user can toggle

		
y0:		mov dl,0   ;make dl 8 if in auto mode
        cmp ah,2
        jl g0
        add dl,08h
g0:     mov 	al,00h	;check for key release
        add     al,dl
		out 	04h,al	;
y1:		in 		al,04h
		and 	al,0f0h
		cmp 	al,0f0h
		jnz 	y1
		call 	delay_20ms	; debounce.
		
		mov 	al,00h
		add     al,dl
		out 	04h,al	;
y2:		in 		al,04h	;checking for key press
		and 	al,0f0h
		cmp 	al,0f0h
		jz 		y2
		
		call 	delay_20ms
		
		mov 	al,00h
		add     al,dl
		out 	04h,al	;
		in 		al,04h	;checking if valid key press - if key is still pressed after a small delay_20ms 
		and 	al,0f0h
		cmp 	al,0f0h
		jz 		y2
		 
		mov al,06h ; column 0
		add al,dl
		mov bl,al
		out 04h,al
		in al,04h
		and al,0f0h	
		cmp al,0f0h
		jnz y3
		
		mov al,05h ; column 1
		add al,dl
		mov bl,al
		out 04h,al
		in al,04h
		and al,0f0h
		cmp al,0f0h
		jnz y3
		
		mov al,03h ; column 2
		add al,dl
		mov bl,al
		out 04h,al
		in al,04h
		and al,0f0h
		cmp al,0f0h
		jz y0
		    
		
y3:		or al,bl	;decoding
		;bh will store the current speed
		;**assuming PC3 was taken to be 0
		and al,11110111b
		
		cmp al,0e6h		;0 start is pressed again after the initial start. No effect
		jz y0
		
		cmp al,0e5h ;1 speed 1 is set
		jnz y4
		mov bh,1
		jz set
		
y4:		cmp al,0e3h ;2 speed 2 is set
		jnz y5
		mov bh,2
		jz set
		
y5:		cmp al,0d6h ;3 speed 3 is set
		jnz y6
		mov bh,3
		jz set
		
y6:		cmp al,0d5h ;4 speed 4 is set
		jnz y7
		mov bh,4
		jz set
		
y7:		cmp al,0d3h ;5 speed 5 is set
		jnz y8
		mov bh,5
		jz set
		
y8:		cmp al,0b6h ;6 speed inc by one
		jz up
		
		cmp al,0b5h ;7 speed dec by one
		jz down
		
		cmp al,0b3h ;8 stop
		jz stop
		
		cmp al,76h ;9 auto
		jz auto
		
		cmp al,75h ;10 diable auto
		jz disauto
		
set:	cmp ah,1 ;checks if the number given was for auto mode or regular mode
		jz auto2
		cmp ah,2
		jz y0
		
		mov al,bh	;writing speed setting to 7-seg display
		out 02h,al
		
		;I am assuming here that interupts wont be raised before writing the count. i.e interrupts only start when you give the count
		;If they start before giving count then, connect OUT2 and PB8 to an and gate and make PB8 as 1 *here*
		
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
		
		;manully setting output to dac
		mov dx,00h
		mov cl,bh
		mov ch,00h
		
lp:		add dx,33h
		loop lp
		
		mov al,dl
		out 00h,al
		
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
		out 02h,al	;move zero to display
		out 04h,al  ;PC3 made 0
		mov ah,00h  ;when restarting, go to regular mode
		;disable timer 2 ??
		jmp x0
		
auto:	cli
		cmp ah,2
		jz disauto

		;now we get the input for no. of hours
		mov ah,1
		jmp y0

auto2:	;bh has number of hours
		;now we set PC3 to enable timer 1
		sti
		
		mov al,08h ; make pc3 high
		out 04h,al ;
		
		mov al,64h ; counter 1, 64h = 100d
		out 0ah,al	; clk = 10kHz out=100Hz
		
		mov al,0f4h ; counter 2  1F4h=500d
		out 0ch,al ; clk=100Hz out = 100/500 = 1/5 Hz => 1 every 5 seconds
		mov al,01h
		out 0ch,al
		
		
		mov al,bh
		out 08h,al
		
		sti
		mov ah,2
		jmp y0
		

disauto:
		cli
		mov ah,00h ; as we are going back to normal mode
		mov al,00h
		mov al,00000000b ; make pc3 low
		out 04h,al ;PC3 made 0 
		jmp y0	;go back to regular mode and wait for input
		
auto_isr:
	; when time period is over we switch off everything
	mov al,00h 	
	out 00h,al	;Vout = 0V
	out 02h,al	;move zero to display
	out 04h,al  ;PC3 made 0
	
	;disable timer 2 using PB???
	
	mov ah,0 ; making ah 0 so that in loop l2, it will go back to start of program
	jmp x0   ; return to start of program
	iret
	
delay_20ms:
    	mov		  	cx,2000 ; delay generated will be approx 20msecs
xn:		loop	  	xn
        ret 
		
hlt ;halt!