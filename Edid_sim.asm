;//*************************************************************************#
;// Edid_sim.asm - simulate HDMI monitor on an Arduino.                     #
;// This program simulates a HDMI monitor for a headless PC.  It will		#
;// emulate the slave side I2C communication that will return the EDID		#        ####
;// blocks to the PC.  The EDID block used has been downloaded from a LG	#        #######
;// television set, but it can be replaced by any other EDID block.			#        #########
;// The original idea was to use the "wire"-library of the Arduino.  This	#    ##############
;// did not work because the "repeated start" was not recognized by the		#        ###########
;// current version of the "wire"-library.  This program uses software I2C	#    ###############
;// communication.  It can easily handle the 100 kHz clock frequency.		#        ###########
;// An Arduino Pro Mini is used for this project.  Power is suplied by the	#    ##############
;// PC through the HDMI plug.  The source code is compiled by ATmelStudio.	#        #########
;// The resulting HEX-file is uploaded using the XLoader program.			#        #######
;//*************************************************************************#        ####
;// History:                                                                #
;// Date        Author			Change										#
;// ----------- ------			-----------------------------------------	#
;// 12-may-2015 Ed Smallenburg	Original version.							#
;//*************************************************************************#

		.EQU	CLKPIN = 3		; PIN3 is CLK (PORTD)
		.EQU	SDAPIN = 4		; PIN4 is SDA (PORTD)
		.EQU	HOTPLUGPIN = 5	; PIN5 for hotplug (PORTD)
		.EQU	TSTPIN = 7		; PIN7 for test (PORTD).  Was used during debugging phase.
		.EQU	PIN13 = 5		; PIN13 for test (PORTB).  ON when data is being transferred to master.
		.EQU	EDIDADDR = 0x50	; Address of simulates EDID
		.DEF	ACC = R16		; General register used for input or output data and temporary storage
		.DEF	T8 = R17		; Tally 8 bits
		.DEF	T128 = R18		; Tally 128 bytes
		.DEF	BLKSEL = R19	; Offset of block to be transferred (0 or 128) 
		.DEF	DLY1 = R20		; Tally for delay
		.DEF	DLY2 = R21		; Tally for delay
		.DEF	DLY3 = R22		; Tally for delay
		.ORG	0

MAIN:
		LDI		ACC, HIGH(RAMEND)		; Setup stack
		OUT		SPH, ACC
		LDI		ACC, LOW(RAMEND)
		OUT		SPL, ACC
		CLR		ACC 
		OUT		DDRD, ACC				; PORTD mostly input
		SER		ACC
		OUT		DDRB, ACC				; PORTB all output
		CBI		PORTB, PIN13			; PIN13 LOW initially
		CBI		PORTD, SDAPIN			; Causes LOW when switched to output
		CBI		PORTD, HOTPLUGPIN		; Causes LOW when switched to output
		SBI		DDRD, HOTPLUGPIN		; HOTPLUGPIN is output
		SBI		DDRD, TSTPIN			; TSTPIN is output
		RCALL	DELAY_1_SEC				; Wait one second
		SBI		PORTD, HOTPLUGPIN		; Switch HOTPLUGPIN to HIGH

LOOP:
		RCALL	WSTART					; Wait for startbit
		RCALL	READ8BITS				; Read 8 bits (7 bits port address plus one write bit )
		LSR		ACC						; Address to bits 0-7, Write bit to carry
		BRCS	READ					; W-bit zero means write
WRITE:
		CPI		ACC, EDIDADDR			; Is this the address we are simulating?
		BRNE	LOOP					; No data for us
		RCALL	SENDACK					; Data for us, send ACK 
		RCALL	READ8BITS				; Read data byte
		MOV		BLKSEL, ACC				; Remember block to select
		RCALL	SENDACK					; Another ACK to confirm DATA read
		RJMP	LOOP					; Wait for next input

READ:
		CPI		ACC, EDIDADDR			; Is this the address we are simulating?
		BRNE	LOOP					; No data for us
		RCALL	SENDACK					; Data for us, send ACK 
		TST		BLKSEL					; Prepare to send right block
		BRNE	TR2						; Second block
		INC		BLKSEL					; Force 2nd block next read request
		LDI		ZL, LOW(E_B1*2)			; Let Z point to first EDID block
		LDI		ZH, HIGH(E_B1*2)		; Load one byte with LPM
		RJMP	TRLOOP
TR2:
		LDI		ZL, LOW(E_B2*2)			; Let Z point to second EDID block
		LDI		ZH, HIGH(E_B2*2)		; Load one byte with LPM
TRLOOP:
		SBI		PORTB, PIN13			; Show write action on PIN13
		LPM		ACC, Z+					; Get a byte from EDID block
		RCALL	SEND8BITS				; Send one byte
		RCALL	READACK					; Expect ACK
		BREQ	TRLOOP					; Result is ACK: continue sending
		CBI		PORTB, PIN13			; PIN13 LOW again
		RJMP	LOOP					; Prepare for next data from master


; Subroutine TESTPULS
; Generates a short testpuls on TSTPIN
TESTPULS:
		SBI		PORTD, TSTPIN			; Set testbit
		NOP
		CBI		PORTD, TSTPIN			; Clear testbit
		RET

; Subroutine WSTART
; Wait for startbit: CLK is high and SDA goes low.
; Returns when CLK is low again
WSTART:
		SBIS	PIND, SDAPIN			; First wait for SDA HIG and CLK HIGH
		RJMP	WSTART
		SBIS	PIND, CLKPIN			; SDA is HIGH, what about CLK
		RJMP	WSTART
W1:		SBIC	PIND, SDAPIN			; Now wait for SDA to go LOW
		RJMP	W1						; SDA still HIGH
		SBIS	PIND, CLKPIN
		RJMP	WSTART					; CLK also LOW, start all over
		SBIC	PIND, CLKPIN			; Startbit seen, wait for end of clockpulse
		RJMP	PC - 1
		RET								; Start bit seeen!

; Subroutine READ8BITS
; Read 8 bits.  Could be address + R/W or data
; Returns when CLK is low again.  Result in ACC.
READ8BITS:
		LDI		ACC, 1					; 8 bits reached when bit left shifted out 
R8B1:
		LSL		ACC						; Shift previous bits		
		SBIS	PIND, CLKPIN			; Wait for raising edge of clock
        RJMP	PC - 1					; Still LOW
		SBIC	PIND, SDAPIN			; Skip if LOW, do not shif a 1 in
		ORI		ACC, 1					; Set LSB to on if SDA is HIGH
		SBIC	PIND, CLKPIN			; Wait unitil CLK is LOW again
		RJMP	PC - 1					; CLK still HIGH
		BRCC	R8B1					; Next loop till 8 bits read
		RET

; Subroutine SEND8BITS
; Send 8 bits.  Byte to send in ACC.  Uses R18 for tally
; Returns when CLK is low again.
SEND8BITS:
		LDI		T8, 8					; Tally for 8 bits 
S8B1:
		LSL		ACC						; Shift previous bits		
		BRCS	S8B2					; Branch for a HIGH bit
		SBI		DDRD, SDAPIN			; SDAPIN to output causes LOW level
S8B2:
		SBIS	PIND, CLKPIN			; Wait for raising edge of clock
        RJMP	PC - 1					; Still LOW
		SBIC	PIND, CLKPIN			; Wait unitil CLK is LOW again
		RJMP	PC - 1					; CLK still HIGH
		CBI		DDRD, SDAPIN			; SDAPIN to input causes TRIstate
		DEC		T8
		BRNE	S8B1					; Next loop till 8 bits send
		RET

READACK:
; Subroutine to read an ACK (one bit LOW ) from master
; Result is in ACC.  0 = ACK, 1 = NACK
; Returns when CLK is low again
		CLR		ACC
		SBIS	PIND, CLKPIN			; Wait for raising edge of clock
	    RJMP	PC - 1					; Still LOW
		SBIC	PIND, SDAPIN			; Skip if LOW, do not shif a 1 in
		ORI		ACC, 1					; Set LSB to on if SDA is HIGH
		SBIC	PIND, CLKPIN			; Wait unitil CLK is LOW again
		RJMP	PC - 1					; CLK still HIGH
		RET



SENDACK:
; Subroutine to send ACK (one bit LOW ) to master
; Returns when CLK is low again
		SBI		DDRD, SDAPIN			; SDAPIN to output causes LOW level
		SBIS	PIND, CLKPIN			; Wait for raising edge of clock
	    RJMP	PC - 1					; Still LOW
		SBIC	PIND, CLKPIN			; Wait unitil CLK is LOW again
		RJMP	PC - 1					; CLK still HIGH
		CBI		DDRD, SDAPIN			; SDAPIN to input causes TRIstate
		RET

DELAY_1_SEC:							; For CLK(CPU) = 16 MHz
; Subroutine to delay for 1 second
		LDI		DLY1, 128				; One clock cycle
DELAY1:
		LDI		dly2, 125				; One clock cycle
DELAY2:
		LDI		dly3, 250				; One clock cycle
DELAY3:
		DEC		dly3					; One clock cycle
		NOP								; One clock cycle
		BRNE	Delay3					; Two clock cycles when jumping to Delay3, 1 clock when continuing to DEC
		DEC		dly2					; One clock cycle
		BRNE	Delay2					; Two clock cycles when jumping to Delay2, 1 clock when continuing to DEC
		DEC		dly1					; One clock Cycle
		BRNE	Delay1					; Two clock cycles when jumping to Delay1, 1 clock when continuing to RET
		RET

; 2 datablocks describing LG monitor
;
E_B1:	.DB		0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00, 0x1e, 0x6d, 0x01, 0x00, 0x01, 0x01, 0x01, 0x01
		.DB		0x02, 0x13, 0x01, 0x03, 0x80, 0x73, 0x41, 0x78, 0x0a, 0xcf, 0x74, 0xa3, 0x57, 0x4c, 0xb0, 0x23
		.DB		0x09, 0x48, 0x4c, 0xa1, 0x08, 0x00, 0x81, 0x80, 0x61, 0x40, 0x45, 0x40, 0x31, 0x40, 0x01, 0x01
		.DB		0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x02, 0x3a, 0x80, 0x18, 0x71, 0x38, 0x2d, 0x40, 0x58, 0x2c
		.DB		0x45, 0x00, 0x7e, 0x8a, 0x42, 0x00, 0x00, 0x1e, 0x01, 0x1d, 0x00, 0x72, 0x51, 0xd0, 0x1e, 0x20
		.DB		0x6e, 0x28, 0x55, 0x00, 0x7e, 0x8a, 0x42, 0x00, 0x00, 0x1e, 0x00, 0x00, 0x00, 0xfd, 0x00, 0x3a
		.DB		0x3e, 0x1e, 0x53, 0x10, 0x00, 0x0a, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x00, 0x00, 0x00, 0xfc
		.DB		0x00, 0x4c, 0x47, 0x20, 0x54, 0x56, 0x0a, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x01, 0x04

E_B2:	.DB		0x02, 0x03, 0x2c, 0xf1, 0x4e, 0x10, 0x1f, 0x84, 0x13, 0x05, 0x14, 0x03, 0x02, 0x12, 0x20, 0x21
		.DB		0x22, 0x15, 0x01, 0x2c, 0x09, 0x1f, 0x07, 0x0f, 0x1f, 0x07, 0x15, 0x07, 0x50, 0x3d, 0x07, 0xc0
		.DB		0x83, 0x4f, 0x00, 0x00, 0x67, 0x03, 0x0c, 0x00, 0x12, 0x00, 0x80, 0x1e, 0x01, 0x1d, 0x80, 0x18
		.DB		0x71, 0x1c, 0x16, 0x20, 0x58, 0x2c, 0x25, 0x00, 0x7e, 0x8a, 0x42, 0x00, 0x00, 0x9e, 0x01, 0x1d
		.DB		0x00, 0x80, 0x51, 0xd0, 0x0c, 0x20, 0x40, 0x80, 0x35, 0x00, 0x7e, 0x8a, 0x42, 0x00, 0x00, 0x1e
		.DB		0x02, 0x3a, 0x80, 0x18, 0x71, 0x38, 0x2d, 0x40, 0x58, 0x2c, 0x45, 0x00, 0x7e, 0x8a, 0x42, 0x00
		.DB		0x00, 0x1e, 0x66, 0x21, 0x50, 0xb0, 0x51, 0x00, 0x1b, 0x30, 0x40, 0x70, 0x36, 0x00, 0x7e, 0x8a
		.DB		0x42, 0x00, 0x00, 0x1e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4b


		.EXIT						; End of source







