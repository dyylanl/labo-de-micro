; ***********************************************
		; LA RAYA DURA 300 MS
		; EL PUNTO DURA 100 MS
; ***********************************************

.equ USART_BAUDRATE = 57600		; velocidad de datos de puerto serie (bits por segundo)
.equ F_CPU = 16000000			; Frecuencia de oscilador, Hz (Arduino UNO: 16MHz, Oscilador interno: 8MHz)
.equ div = 64
.equ timer_freq = F_CPU/div
.equ nnnn = timer_freq / 10 ; /10 equals .1 sec
.equ xxxx1 = 65536 - nnnn

.equ VALUE = 5000
.include "m328Pdef.inc"
.include "usart.inc"

; PORTC -> PORTA
; PORTD -> PORTD

; SENSOR EN PUERTO D2
; ********* SENSOR 1 *********
.equ SENSOR_PUERTO_DIR = DDRD
.equ SENSOR_ENTRADA = PORTD
.equ SENSOR_VALOR = PIND
.equ SENSOR_PIN = 2
; ********* SENSOR 1 *********

.def contador = r21
.def letra_reg = r22
.dseg
letra_ram: .byte 1

.cseg
.org 0x0000
	rjmp	onReset
;**************************************************************
;* Punto de entrada al programa 
;**************************************************************

.org 0x0100  ; agregado para evitar solapamiento con usart.inc

onReset:
; Inicializa el "stack pointer"
	ldi		r16, LOW(RAMEND)   
  	out		spl, r16
	ldi    	r16, HIGH(RAMEND)   
	out    	sph, r16

; Inicializa el puerto serie (USART)
  	rcall  	usart_init                   
  	
; Habilitaci�n global de interrupciones
	sei

main:
	rcall configuracion_de_puertos
	LDI XL, LOW(letra_ram)
	LDI XH, HIGH(letra_ram)		; Puntero X a una posicion de memoria reservada en ram
	chequeo_sensor:
		clr r22		; usado para el sonido
		clr r23		; usado para el silencio
		CLR contador
		sbis SENSOR_VALOR, SENSOR_PIN	; si ruido = 0 -> vuelvo a chequear | si ruido = 1 -> voy a ver cuanto dura el pulso
		rjmp chequeo_sensor				; si hay silencio no hago nada

		rcall timer_sonido				; se detecto ruido
		rcall timer_silencio			; se detecto silencio
		rjmp chequeo_sensor


timer_silencio:
	rcall init_timer
	loop_silencio:						 ; si vine aca es pq habia ruido y se detecto silencio
		sbic SENSOR_VALOR, SENSOR_PIN	 ; si ruido = 1 -> voy a ver cuanto duro el silencio | si ruido = 0 voy a incrementar el tiempo del silencio
		rjmp ruido

		; si viene para aca es porque sigue habiendo silencio
		in r20, TIFR1					; cargo en r20 los flags del timer
		sbrs r20, TOV1					; chequeo el flag de overflow
		rjmp loop_silencio				; no dio overflow sigo chequeando los flags y el sensor

		; si sigue por aca es porque el timer dio overflow
		inc r23
		ldi r20, (1<<TOV1)				; Limpio el flag de overflow
		out TIFR1, r20
		rjmp timer_silencio

		; si se ejecuta esta parte es porque dejo de haber silencio y se detecto ruido
		ruido:
			cpi r23, 50
			brlo decodificar_letra
			call espacio
			ret
			decodificar_letra:
				ret

timer_sonido:
	rcall init_timer
	loop_sonido:						; si vine aca es pq habia silencio y se detecto sonido
		sbis SENSOR_VALOR, SENSOR_PIN	; si ruido = 0 -> voy a ver cuanto duro el ruido | si ruido = 1 voy a incrementar el tiempo del ruido
		rjmp silencio
		
		; si viene aca es porque sigue viendo ruido
		in r20, TIFR1					; r20 = flags
		sbrs r20, TOV1					; chequeo el flag de overflow
		rjmp loop_sonido				; si no dio overflow sigo mirando el flag

		; si sigue por aca es pq el flag dio overflow
		inc r22
		ldi r20, (1<<TOV1)
		out TIFR1, r20				; limpio el flag de overflow
		rjmp timer_sonido
		
		; si viene aca es porque habia ruido y se detecto silencio
		silencio:
			cpi r22, 50		; de aca manejo la sensibilidad para detectar raya o punto
			brlo punto
			call raya
			ret
			; Agarro la posicion de memoria a la que apunta X, la shifteo y la vuelvo a guardar
			punto:
				INC contador
				ld letra_reg, X		; Guardo *X en letra_reg
				LSL letra_reg		; Preparo el espacio para la siguiente '.' o '-'
				ST X, letra_reg		
				ret


; Se termino de detectar un caracter y hay que decodificarlo y enviarlo por serial
espacio:

	; Chequeo la longitud del caracter recibido
	CPI contador, 1
	BREQ caracter_en_tabla1
	
	CPI contador, 2
	BREQ caracter_en_tabla2

	CPI contador, 3
	BREQ caracter_en_tabla3

	CPI contador, 4
	BREQ caracter_en_tabla4

	CPI contador, 5
	BREQ caracter_en_tabla5

	rjmp chequeo_sensor

; se detecto un caracter de tamanio 1
caracter_en_tabla1:
	LDI ZH, HIGH(tabla_conversion_1 << 1)
	LDI ZL, LOW(tabla_conversion_1 << 1)
	rjmp get_caracter_de_tabla


caracter_en_tabla2:
	LDI ZH, HIGH(tabla_conversion_2 << 1)
	LDI ZL, LOW(tabla_conversion_2 << 1)
	rjmp get_caracter_de_tabla

caracter_en_tabla3:
	LDI ZH, HIGH(tabla_conversion_3 << 1)
	LDI ZL, LOW(tabla_conversion_3 << 1)
	rjmp get_caracter_de_tabla

caracter_en_tabla4:
	LDI ZH, HIGH(tabla_conversion_4 << 1)
	LDI ZL, LOW(tabla_conversion_4 << 1)
	rjmp get_caracter_de_tabla

caracter_en_tabla5:
	LDI ZH, HIGH(tabla_conversion_5 << 1)
	LDI ZL, LOW(tabla_conversion_5 << 1)
	rjmp get_caracter_de_tabla


get_caracter_de_tabla:
	;sabemos que el tamanio esta en contador y que la tabla esta en Z
	ldi r25, 0
	ADD ZL, letra_reg		; Movemos el puntero de la tabla de caracteres en offset correspondiente (letra_Reg tiene el offset)
	ADC ZH, r25				; Z = 0000-LETRA
	LPM letra_reg, Z		; letra = ZL

	MOV r16, letra_reg
	rcall usart_tx			; Transmito el caracter decodificado

	CLR contador
	CLR letra_reg			; Limpio los registros auxiliares

	rjmp chequeo_sensor
raya:
	INC contador
	LD letra_reg, X
	LSL letra_reg
	ORI letra_reg, 1
	ST X, letra_reg
	ret

init_timer:
	ldi r20, high(VALUE)
	sts TCNT1H, r20
	ldi r20, low(VALUE)
	sts TCNT1L, r20						; timer1 cargado con el valor 0

	ldi r20, 0x01
	sts TCCR1B, r20						; timer en modo normal
	
	ldi r20, 1<<ICF1
	out TIFR1, r20						; clear ICF1 flag
	ldi r20, 1<<TOV1
	out TIFR1, r20						; clear TOV1 flag
	ret


; Esta subrutina se invoca cada vez que se recibe un dato por puerto serie
usart_callback_rx:
	ldi r16, ' '
	call usart_tx
	ret


configuracion_de_puertos:
	ldi r16, 0x00
	out SENSOR_PUERTO_DIR, r16			; Puerto D como entrada del SENSOR
	clr r16
	out SENSOR_VALOR, r16		    	; Valor inicial de la entrada del SENSOR

	ret

tabla_conversion_1:
	.db		'E','T'

tabla_conversion_2:
	.db		'I', 'A', 'N', 'M'
	;		00	 01	   10  11
tabla_conversion_3:
	.db		'S', 'U', 'R', 'W', 'D', 'K', 'G', 'O'
	;       000  001 010
tabla_conversion_4:
	.db		'H', 'V', 'F', '*', 'L', '*', 'P', 'J', 'B', 'X', 'C', 'Y', 'Z', 'Q' 
	;	   0000 0001
tabla_conversion_5:
	.db		'5', '4', '*', '3', '*', '*', '*', '2', '*', '*', '*', '*', '*', '*', '*', '1', '6', '*', '*', '*', '*', '*', '*', '*', '7', '*', '*', '*', '8', '*', '9', '0'
