 ; How to use this USART library:
; 1) Define baudrate on the main file, for example:
; .equ USART_BAUDRATE = 9600
; 2) Include this file into the main file, for example:
; .include "usart.inc"
; 3) Initialize the uart  by calling the routine usart_init, for example:
; rcall uartInit
; 4) On the main file, define the subroutine usart_callback_rx.
; This subroutine this will be called every time a new character got received. 
; That character will be available at r16. Example:
; usart_callback_rx:
;   mov r17,r16
;	  ret

.equ USART_BPS = (F_CPU/16/USART_BAUDRATE) - 1    ; prescaler

.cseg

; USART interrupt vector
.org UDREaddr
  rjmp	usart_onUDREaddr


;**************************************************************
;* usart_init
;* Configure the USART for reception and transmission.
;*
;* input: USART_BAUDRATE  - baudrate
;* outputs: None 
;* modifies:  None
;**************************************************************
usart_init:
  push  r16
;prescaler (baudrate)
  ldi   r16, LOW(USART_BPS) 
  sts   UBRR0L, r16
  ldi   r16, HIGH(USART_BPS)                   
  sts   UBRR0H, r16
; enable transmission and reception
  ldi   r16,(1<<RXEN0)|(1<<TXEN0)
  sts   UCSR0B,r16                   
; (8N1) 8 data bits, no parity, one stop bit
  ldi   r16, (1<<UCSZ00)|(1<<UCSZ01)|(1<<USBS0)
  sts   UCSR0C, r16
  rcall usart_interruptEnable
  pop   r16
  ret

;**************************************************************
;* usart_interruptEnable
;* Enables the USART interrupt
;* inputs: None
;* outputs: None
;* modifies: None 
;**************************************************************
usart_interruptEnable:
  push	r16
  lds   r16, UCSR0B       
  sbr   r16, (1<<UDRIE0)
  sts   UCSR0B, r16
  pop   r16
  ret

;**************************************************************
;* usart_interruptDisable
;* Disables the USART interrupt
;* inputs: None
;* outputs: None
;* modifies: None 
;**************************************************************
usart_interruptDisable:
  push  r16
  lds   r16, UCSR0B
  cbr   r16, (1<<UDRIE0)
  sts   UCSR0B, r16
  pop   r16
  ret

;**************************************************************
;* usart_onUDREaddr
;* USART Interrupt Service Routine. 
;* usart_callback_rx must be implemented as a routine
;* inputs: N/A
;* outputs: N/A
;* modifies: None
;**************************************************************
usart_onUDREaddr:
  push	r16
  in    r16,sreg
  push  r16
        
; check Rx flag
  lds 	r16, UCSR0A
  sbrs	r16, RXC0
  rjmp	usart_onUDREaddr_end
  lds   r16, UDR0
  call	usart_callback_rx
usart_onUDREaddr_end:
  pop   r16
  out   sreg, r16
  pop   r16
  reti

;**************************************************************
;* usart_tx
;* Transmits one character through the USART
;* inputs: r16: character to transmit
;* outputs: None
;* modifies: None 
;**************************************************************
usart_tx:
  sts   UDR0, r16
  ret
