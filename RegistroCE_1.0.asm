; ============================================
; RegistroCE
; Intento de hacer el menu interactivo
; Hecho en emu8086, utilizar el siguiente link para descargar el emulador
; https://emu8086.waxoo.com/descargar
; Solo muestra el menu, lee opcion 1..5 y salta a stubs
; ============================================

DATA SEGMENT
    ; Todas tienen al final el simbolo $ para luego poder ser leidas por una subfuncion definida mas adelante
    titleMsg        DB  13,10, '==== Sistema de Gestion de Calificaciones (RegistroCE) ====$'
    menuMsg1        DB  13,10, '[1] Ingresar calificaciones$'
    menuMsg2        DB  13,10, '[2] Mostrar estadisticas$'
    menuMsg3        DB  13,10, '[3] Buscar estudiante por posicion (indice)$'
    menuMsg4        DB  13,10, '[4] Ordenar calificaciones (asc/desc)$'
    menuMsg5        DB  13,10, '[5] Salir$'
    promptMsg       DB  13,10, 'Seleccione una opcion (1-5): $'
    invalidMsg      DB  13,10, 'Opcion invalida. Intente de nuevo.$'
    byeMsg          DB  13,10, 'Saliendo...$'
    crlf            DB  13,10, '$'
DATA ENDS

CODE SEGMENT
    ASSUME CS:CODE, DS:DATA

START:
    ; Inicializar DS (Si no me equivoco es como un puntero que empieza en AX)
    MOV     AX, DATA
    MOV     DS, AX

MAIN_MENU:
    ; Limpiar pantalla (modo texto 80x25)
    MOV     AX, 0003h      ; INT 10h AH=00h, AL=03h -> modo 03h y limpia
    INT     10h

    ; Mostrar titulo y opciones
    LEA     DX, titleMsg   ; PrintStr es una subfuncion que muestra cadenas terminadas en $ 
    CALL    PrintStr
    LEA     DX, menuMsg1
    CALL    PrintStr
    LEA     DX, menuMsg2
    CALL    PrintStr
    LEA     DX, menuMsg3
    CALL    PrintStr
    LEA     DX, menuMsg4
    CALL    PrintStr
    LEA     DX, menuMsg5
    CALL    PrintStr

    ; Prompt y lectura de opcion
    LEA     DX, promptMsg
    CALL    PrintStr

    CALL    ReadKeyEcho        ; Subfuncion que definimos mas abajo
    ; Validar rango '1'..'5 de las entradas del usuario'
    CMP     AL, '1'
    JB      INVALID_OPTION
    CMP     AL, '5'
    JA      INVALID_OPTION

    ; Lo siguiente es un listado de las opciones que se mostraran, del 1 al 5
    CMP     AL, '1'
    JE      OPT_1
    CMP     AL, '2'
    JE      OPT_2
    CMP     AL, '3'
    JE      OPT_3
    CMP     AL, '4'
    JE      OPT_4
    ; Si no fue 1..4 y esta en rango, es '5'
    JMP     OPT_5

INVALID_OPTION:
    LEA     DX, invalidMsg
    CALL    PrintStr
    LEA     DX, crlf
    CALL    PrintStr
    ; Esperar una tecla para continuar
    CALL    PressAnyKey
    JMP     MAIN_MENU

; ------- STUBS (solo mensajes por ahora) --------

OPT_1:  ; Ingresar calificaciones
    CALL    ClearBelow
    ; Aqui luego: logica para aceptar el nombre y nota (hasta 5 decimales)
    ; Stub:
    LEA     DX, crlf
    CALL    PrintStr
    MOV     DX, OFFSET msgStub1
    CALL    PrintStr
    CALL    PressAnyKey
    JMP     MAIN_MENU

OPT_2:  ; Mostrar estadisticas
    CALL    ClearBelow
    LEA     DX, crlf
    CALL    PrintStr
    MOV     DX, OFFSET msgStub2
    CALL    PrintStr
    CALL    PressAnyKey
    JMP     MAIN_MENU

OPT_3:  ; Buscar por indice
    CALL    ClearBelow
    LEA     DX, crlf
    CALL    PrintStr
    MOV     DX, OFFSET msgStub3
    CALL    PrintStr
    CALL    PressAnyKey
    JMP     MAIN_MENU

OPT_4:  ; Ordenar calificaciones
    CALL    ClearBelow
    LEA     DX, crlf
    CALL    PrintStr
    MOV     DX, OFFSET msgStub4
    CALL    PrintStr
    CALL    PressAnyKey
    JMP     MAIN_MENU

OPT_5:  ; Salir
    LEA     DX, byeMsg
    CALL    PrintStr
    ; Terminar a DOS
    MOV     AH, 4Ch
    INT     21h

; ------- Mensajes de stub ------- 
; Un stub es un marcador de posicion
; Es como parte temporal del codigo que solo muestra mensajes
msgStub1 DB '<< Stub >> Ingresar calificaciones (pendiente de implementar)$'
msgStub2 DB '<< Stub >> Mostrar estadisticas (pendiente de implementar)$'
msgStub3 DB '<< Stub >> Buscar por indice (pendiente de implementar)$'
msgStub4 DB '<< Stub >> Ordenar calificaciones (pendiente de implementar)$'

; ============================================
; Subfunciones
; ============================================

; PrintStr: imprime cadena $-terminada en DS:DX
; destruye AX
PrintStr PROC NEAR
    MOV     AH, 09h
    INT     21h
    RET
PrintStr ENDP

; ReadKeyEcho: lee una tecla (eco por DOS). Devuelve AL=caracter.
ReadKeyEcho PROC NEAR
    MOV     AH, 01h
    INT     21h
    RET
ReadKeyEcho ENDP

; PressAnyKey: muestra "Presione una tecla..." y espera
PressAnyKey PROC NEAR
    PUSH    DX
    MOV     DX, OFFSET pressMsg
    CALL    PrintStr
    MOV     AH, 08h      ; leer tecla sin eco (tambien sirve AH=01h si prefieres eco)
    INT     21h
    POP     DX
    RET
PressAnyKey ENDP

pressMsg DB 13,10,'[Presione una tecla para continuar]$'

; ClearBelow: salta de linea para "separar" area de trabajo
ClearBelow PROC NEAR
    PUSH    DX
    MOV     DX, OFFSET crlf
    CALL    PrintStr
    POP     DX
    RET
ClearBelow ENDP

; ============================================

CODE ENDS
END START
