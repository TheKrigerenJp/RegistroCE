; ============================================
; RegistroCE
; Intento de hacer el menu interactivo
; Hecho en emu8086, utilizar el siguiente link para descargar el emulador
; https://emu8086.waxoo.com/descargar
; Solo muestra el menu, lee opcion 1..5 y salta a stubs
; ============================================

DATA SEGMENT
    titleMsg        DB 13,10,'==== Sistema de Gestion de Calificaciones (RegistroCE) ====$'
    menuMsg1        DB 13,10,'[1] Ingresar calificaciones$'
    menuMsg2        DB 13,10,'[2] Mostrar estadisticas$'
    menuMsg3        DB 13,10,'[3] Buscar estudiante por posicion (indice)$'
    menuMsg4        DB 13,10,'[4] Ordenar calificaciones (asc/desc)$'
    menuMsg5        DB 13,10,'[5] Salir$'
    promptMsg       DB 13,10,'Seleccione una opcion (1-5): $'
    invalidMsg      DB 13,10,'Opcion invalida. Intente de nuevo.$'
    byeMsg          DB 13,10,'Saliendo...$'
    pressMsg        DB 13,10,'[Presione una tecla para continuar]$'
    crlf            DB 13,10,'$'

    ; Mensajes de stub (temporal) (mas abajo digo que es stub)
    msgStub1        DB '<< Stub >> Ingresar calificaciones (pendiente)$'
    msgStub2        DB '<< Stub >> Mostrar estadisticas (pendiente)$'
    msgStub3        DB '<< Stub >> Buscar estudiante (pendiente)$'
    msgStub4        DB '<< Stub >> Ordenar calificaciones (pendiente)$'
DATA ENDS


CODE SEGMENT
    ASSUME CS:CODE, DS:DATA

START:
    ; Inicializar DS
    MOV AX, DATA
    MOV DS, AX

; ----------------- MENU PRINCIPAL -----------------
MAIN_MENU: 
    ; Llamo a PrintStr que es una subrutina especificada mas abajo 
    LEA DX, titleMsg
    CALL PrintStr
    LEA DX, menuMsg1
    CALL PrintStr
    LEA DX, menuMsg2
    CALL PrintStr
    LEA DX, menuMsg3
    CALL PrintStr
    LEA DX, menuMsg4
    CALL PrintStr
    LEA DX, menuMsg5
    CALL PrintStr

    LEA DX, promptMsg
    CALL PrintStr

    CALL ReadKeyEcho        ; Subrutina especificada mas abajo

    CMP AL,'1'
    JB INVALID_OPTION
    CMP AL,'5'
    JA INVALID_OPTION

    CMP AL,'1'
    JE OPT_1
    CMP AL,'2'
    JE OPT_2
    CMP AL,'3'
    JE OPT_3
    CMP AL,'4'
    JE OPT_4
    JMP OPT_5

INVALID_OPTION:
    LEA DX, invalidMsg
    CALL PrintStr
    CALL PressAnyKey ; otra subrutina que se va a ver mas adelante
    JMP MAIN_MENU


; ----------------- STUBS (temporal) ----------------- 
; Por cultura general xd, un stub es como un adelanto que simula lo que debe hacer 
; el codigo para ver que todo funciona bien de momento, por lo que no hay logica
; solo las entradas al hacer click en una de las opciones 

OPT_1:
    LEA DX, msgStub1
    CALL PrintStr
    CALL PressAnyKey
    JMP MAIN_MENU

OPT_2:
    LEA DX, msgStub2
    CALL PrintStr
    CALL PressAnyKey
    JMP MAIN_MENU

OPT_3:
    LEA DX, msgStub3
    CALL PrintStr
    CALL PressAnyKey
    JMP MAIN_MENU

OPT_4:
    LEA DX, msgStub4
    CALL PrintStr
    CALL PressAnyKey
    JMP MAIN_MENU

OPT_5:
    LEA DX, byeMsg
    CALL PrintStr
    MOV AH,4Ch
    INT 21h


; ----------------- SUBRUTINAS -----------------  
; Para mayor conocimiento revisar lo que hacen los interruptores, al guardar un valor 
; diferente en AH y luego llamar a 21h hace diferentes cosas, adjunto link con que hace cada uno
; https://yassinebridi.github.io/asm-docs/8086_bios_and_dos_interrupts.html?utm_source=chatgpt.com#int21h_09h

; Imprimir cadena terminada en $
PrintStr PROC NEAR
    MOV AH,09h
    INT 21h
    RET
PrintStr ENDP

; Leer una tecla (eco). Devuelve AL=caracter
ReadKeyEcho PROC NEAR
    MOV AH,01h
    INT 21h
    RET
ReadKeyEcho ENDP

; Pausa: mostrar mensaje y esperar tecla
PressAnyKey PROC NEAR
    PUSH DX
    LEA DX, pressMsg
    CALL PrintStr
    MOV AH,08h      ; leer sin eco
    INT 21h
    POP DX
    RET
PressAnyKey ENDP

CODE ENDS
END START
