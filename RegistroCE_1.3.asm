; ============================================
; RegistroCE
; Intento de hacer el menu interactivo
; Hecho en emu8086, utilizar el siguiente link para descargar el emulador
; https://emu8086.waxoo.com/descargar
; Solo muestra el menu, lee opcion 1..5 y salta a stubs
; ============================================

DATA SEGMENT                 
    
    ; Constantes (cuantos estudiantes se pueden ingresar, largo del nombre y nota)
    MAX_STUDENTS    EQU 15
    NAME_REC_LEN    EQU 50
    NOTE_REC_LEN    EQU 20  
    ten             DW  10 ;Nuevo contador para validar nota
    ; 7,000,000 = 0x006ACFC0  -> hi = 0x006A, lo = 0xCFC0
    thresh70_hi     DW 006Ah
    thresh70_lo     DW 0CFC0h
    
    ; ---------- Constantes decimales ----------
    const100k_hi    DW 0001h         ; 100000 = 0x0001:86A0
    const100k_lo    DW 86A0h
    const10000      DW 10000
    const1000       DW 1000
    const100        DW 100
    const10         DW 10
    const1          DW 1
    
    ; ---------- Acumuladores 32-bit y contadores ----------
    sum_hi          DW 0
    sum_lo          DW 0
    min_hi          DW 0
    min_lo          DW 0
    max_hi          DW 0
    max_lo          DW 0

    cntAprob        DW 0
    cntReprob       DW 0
    
    avg_den_hi      DW 0
    avg_den_lo      DW 0 
    
    
    
    ; Mensajes del menu
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
    
    ; Mensajes de la opcion 1
    msgEnterName    DB 13,10,'Ingrese Nombre: $'  
    msgInvalidName  DB 13,10,'Error: Ingrese un nombre valido.$'  
    msgEnterApell1  DB 13,10,'Ingrese Primer Apellido: $'       
    msgInvalidApell DB 13,10,'Error: Ingrese un apellido valido.$'
    msgEnterApell2  DB 13,10,'Ingrese Segundo Apellido: $'
    msgEnterNote    DB 13,10,'Ingrese Nota (0-100, hasta 5 decimales): $'
    msgStored       DB 13,10,'Datos almacenados correctamente.$'
    msgFull         DB 13,10,'Error: Capacidad maxima (15 estudiantes) alcanzada.$'
    msgInvalidNote  DB 13, 10, 'Error: Nota invalida. Ingrese valor entre 0-100 y maximo 5 decimales.$'
    
    ; ---------- Mensajes Estadísticas ----------
    msgNoData       DB 13,10,'No hay datos para mostrar.$'
    msgStatsTitle   DB 13,10,'---- Estadisticas ----$'
    msgProm         DB 13,10,'Promedio general: $'
    msgMax          DB 13,10,'Maximo: $'
    msgMin          DB 13,10,'Minimo: $'
    msgAprob        DB 13,10,'Aprobados: $'
    msgReprob       DB 13,10,'Reprobados: $'
   
    
    ; Mensajes de stub (temporal) (mas abajo digo que es stub)
    msgStub2        DB '<< Stub >> Mostrar estadisticas (pendiente)$'
    msgStub3        DB '<< Stub >> Buscar estudiante (pendiente)$'
    msgStub4        DB '<< Stub >> Ordenar calificaciones (pendiente)$'
    
    
    ;Buffers temporales
    full_name_buff DB NAME_REC_LEN DUP(0) ;almacena el nombre y los apellidos hasta que llegue a la ubicacion final  
    
    ; Buffers de entrada, al usar el interruptor INT 21h AH=0Ah
    ; Los buffers trabajan de la siguiente manera, dependiendo de la entrada
    ; se le indica a DX que hacer (0 tamano max permitido, 1 longitud de la cadena
    ; realmente y 2 los caracteres escritos por el usuario)
    nameBuff        DB  NAME_REC_LEN, 0, NAME_REC_LEN DUP(0)
    noteBuff        DB  NOTE_REC_LEN, 0, NOTE_REC_LEN DUP(0)
    
    ;Buffers de salida
    numBuf          DB 32 DUP(0)     ; armado de numero (terminado con $)  
    
    ; Estructuras de almacenamiento 
    studentCount    DB 0
    names           DB MAX_STUDENTS*NAME_REC_LEN DUP('$')
    notes           DB MAX_STUDENTS*NOTE_REC_LEN DUP('$')

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
    
; -----------------Opcion 1: Ingresar datos del estudiante----------
OPT_1 PROC NEAR
    ; Revisar capacidad
    MOV AL, studentCount
    CMP AL, MAX_STUDENTS
    JAE LIST_FULL 
    
    ; Reiniciar full_name_buff (limpiar) y apuntar DI al inicio
    LEA DI, full_name_buff
    MOV CX, NAME_REC_LEN
    MOV AL, 0
    REP STOSB
    LEA DI, full_name_buff       ; DI = destino de concatenación
                                  
GET_NOMBRE:
    ; pide el nombre
    LEA DX, msgEnterName
    CALL PrintStr
    LEA DX, nameBuff
    CALL ReadLine

    ;Verificar que se escriba algo
    MOV CL, [nameBuff+1] ;largo de lo escrito
    CMP CL, 0
    JE  NOMBRE_VACIO   ; si es 0 es porque esta vacio, no deberia continuar
    CALL CopyFromInput_Clamp ;Nueva subrutina 
    JMP GET_APELLIDO1     ; si se escribio algo se puede continuar   
    
    
NOMBRE_VACIO:   

    LEA DX, msgInvalidName  ; mensaje de error por no escribir nada
    CALL PrintStr
    JMP GET_NOMBRE

GET_APELLIDO1: 

    CALL PutSpaceIfRoom ;AQUIIIIIIII
    LEA DX, msgEnterApell1
    CALL PrintStr
    LEA DX, nameBuff
    CALL ReadLine

    ; Verifica que se escriba algo
    MOV CL, [nameBuff+1]
    CMP CL, 0
    JE APELLIDO1_VACIO   ; ;funciona igual que el nombre
    CALL CopyFromInput_Clamp
    JMP GET_APELLIDO2     

APELLIDO1_VACIO:
    LEA DX, msgInvalidApell 
    CALL PrintStr
    JMP GET_APELLIDO1      ; Vuelve a pedir el primer apellido

 
    
GET_APELLIDO2: 

    CALL PutSpaceIfRoom   
    LEA DX, msgEnterApell2
    CALL PrintStr
    LEA DX, nameBuff
    CALL ReadLine

    ; Verifica que se escriba algo
    MOV CL, [nameBuff+1]
    CMP CL, 0
    JE APELLIDO2_VACIO    ; 
    CALL CopyFromInput_Clamp      ; 
    JMP GET_NOTE
    
APELLIDO2_VACIO:
    LEA DX, msgInvalidApell  ; Reutilizamos el mismo mensaje de error en los dos apellidos
    CALL PrintStr
    JMP GET_APELLIDO2       ; si esta mal vuelve a pedir el segundo apellido


   

                                        
GET_NOTE:   
    ; bucle hasta que nota sea valida
    ; Terminar full_name_buff con '$' 
    MOV AX, DI
    SUB AX, OFFSET full_name_buff
    MOV DX, NAME_REC_LEN-1
    CMP AX, DX
    ; El nombre de estas subrutinas tienen un @ por seguir 
    ; una convencion basado en MASM/TASM 
    ; Lo que nos indica son subfunciones dentro de las funciones, como funciones locales
    JA  @no_room_dollar  
    MOV BYTE PTR [DI], '$'
    JMP @after_dollar
@no_room_dollar:
    MOV BYTE PTR [full_name_buff+NAME_REC_LEN-1], '$' ;forzamos a que el ultimo byte sea un $
@after_dollar: ;Esta etiqueta solo indica que el flujo sigue normal despues de agregar o no el $

ASK_NOTE:
    LEA DX, msgEnterNote
    CALL PrintStr
    LEA DX, noteBuff
    CALL ReadLine 
    
    ; Validar nota
    LEA SI, noteBuff+2
    MOV CL, [noteBuff+1]
    CALL ValidateNote
    CMP AL, 1
    JE  NOTE_OK

    LEA DX, msgInvalidNote
    CALL PrintStr
    JMP ASK_NOTE
    

NOTE_OK:
    ; ---- Guardar NOMBRE y NOTA ----
    ; Guardar NOMBRE en arreglo 'names' (desde full_name_buff)
    XOR BX, BX
    MOV BL, studentCount

    LEA SI, full_name_buff
    LEA DI, names
    MOV AX, BX
    MOV CX, NAME_REC_LEN
    MUL CX                 ; AX = index * NAME_REC_LEN
    ADD DI, AX
    MOV CX, NAME_REC_LEN-1
    REP MOVSB
    MOV BYTE PTR [DI], '$' ; terminador

    ; Guardar NOTA en arreglo 'notes'
    LEA SI, noteBuff+2
    LEA DI, notes
    MOV AX, BX
    MOV CX, NOTE_REC_LEN
    MUL CX
    ADD DI, AX

    MOV CL, [noteBuff+1]
    MOV AL, NOTE_REC_LEN-1
    CMP CL, AL
    JBE @note_len_ok
    MOV CL, AL
@note_len_ok:
    CMP CL, 0
    JE  SKIP_NOTE
    REP MOVSB
          
    
SKIP_NOTE:
    MOV BYTE PTR [DI], '$'

    ; Incrementar contador
    INC studentCount

    ; Confirmacion
    LEA DX, msgStored
    CALL PrintStr
    CALL PressAnyKey
    JMP MAIN_MENU

LIST_FULL:
    LEA DX, msgFull
    CALL PrintStr
    CALL PressAnyKey
    JMP MAIN_MENU
    
OPT_1 ENDP 


;-----ESTADISTICAS-------

OPT_2:
    ; Si no hay estudiantes, salir
    MOV AL, studentCount
    CMP AL, 0
    JE  NO_DATA_STATS

    ; Inicializar acumuladores
    MOV WORD PTR sum_hi, 0
    MOV WORD PTR sum_lo, 0
    MOV WORD PTR cntAprob, 0
    MOV WORD PTR cntReprob, 0

    ; i=0..studentCount-1
    XOR BX, BX                ; BX = i
    LEA DI, notes             ; DI apunta al primer registro de nota

    ; Procesar el primer elemento para min/max
    PUSH DI
    CALL StrLenUntilDollar_NOTE   ; CL = longitud
    POP DI
    LEA SI, [DI]
    CALL ParseNoteToScaled        ; DX:AX = valor (escala 10^5)

    ; min = max = valor
    MOV min_hi, DX
    MOV min_lo, AX
    MOV max_hi, DX
    MOV max_lo, AX

    ; sum += valor
    PUSH DX
    PUSH AX
    CALL Add32ToSum
    POP AX
    POP DX

    ; aprobar/reprobar
    PUSH DX
    PUSH AX
    CALL IsGE_70Scaled           ; AL=1 si >=70
    CMP AL, 0
    JE  first_rep
    INC WORD PTR cntAprob
    JMP first_done
first_rep:
    INC WORD PTR cntReprob
first_done:

    ; avanzar al siguiente
    INC BL
    ADD DI, NOTE_REC_LEN

; ---- loop para el resto ----
LOOP_NOTES:
    MOV AL, studentCount
    CMP BL, AL
    JAE DONE_NOTES

    PUSH DI
    CALL StrLenUntilDollar_NOTE
    POP DI
    LEA SI, [DI]
    CALL ParseNoteToScaled       ; DX:AX = valor actual

    ; sum += valor
    PUSH DX
    PUSH AX
    CALL Add32ToSum
    POP AX
    POP DX

    ; min ?
    MOV BX, min_hi
    MOV CX, min_lo
    CALL Cmp32_DXAX_vs_BXCX      ; CF=1 si actual < min
    JNC no_new_min
    MOV min_hi, DX
    MOV min_lo, AX
no_new_min:

    ; max ?
    MOV BX, max_hi
    MOV CX, max_lo
    CALL Cmp32_DXAX_vs_BXCX      ; CF=1 si actual < max
    JC  no_new_max
    MOV max_hi, DX
    MOV max_lo, AX
no_new_max:

    ; aprobar/reprobar
    PUSH DX
    PUSH AX
    CALL IsGE_70Scaled
    CMP AL, 0
    JE  add_rep
    INC WORD PTR cntAprob
    JMP after_cnt
add_rep:
    INC WORD PTR cntReprob
after_cnt:

    ; siguiente
    INC BL
    ADD DI, NOTE_REC_LEN
    JMP LOOP_NOTES

DONE_NOTES:

    ; -------- Mostrar resultados --------
    LEA DX, msgStatsTitle
    CALL PrintStr

    ; Promedio general (impresión por división larga sin DIV)
    LEA DX, msgProm
    CALL PrintStr
    ; Imprime sum_hi:sum_lo / (studentCount*100000) con 5 decimales
    CALL PrintAverage_NoDiv
    CALL PrintCRLF

    ; Máximo
    LEA DX, msgMax
    CALL PrintStr
    MOV DX, max_hi
    MOV AX, max_lo
    CALL PrintScaled5_NoDiv
    CALL PrintCRLF

    ; Mínimo
    LEA DX, msgMin
    CALL PrintStr
    MOV DX, min_hi
    MOV AX, min_lo
    CALL PrintScaled5_NoDiv
    CALL PrintCRLF

    ; Aprobados: "<cnt> (XX.XX%)"
    LEA DX, msgAprob
    CALL PrintStr
    MOV AX, cntAprob
    CALL PrintUInt0_999_NoDiv
    CALL PrintSpacePctTwo_NoDiv
    CALL PrintCRLF

    ; Reprobados
    LEA DX, msgReprob
    CALL PrintStr
    MOV AX, cntReprob
    CALL PrintUInt0_999_NoDiv
    CALL PrintSpacePctTwo_NoDiv
    CALL PrintCRLF

    CALL PressAnyKey
    JMP MAIN_MENU

NO_DATA_STATS:
    LEA DX, msgNoData
    CALL PrintStr
    CALL PressAnyKey
    JMP MAIN_MENU




; ----------------- STUBS (temporal) ----------------- 
; Por cultura general xd, un stub es como un adelanto que simula lo que debe hacer 
; el codigo para ver que todo funciona bien de momento, por lo que no hay logica
; solo las entradas al hacer click en una de las opciones 


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

; Leer una linea (buffer apuntado en DX)
ReadLine PROC NEAR
    MOV AH,0Ah
    INT 21h
    RET
ReadLine ENDP

; ---- Subrutinas para armar nombre completo en full_name_buff ----

; CopyFromInput_Clamp:
; Copia desde nameBuff (+2) hacia [DI] sin exceder (NAME_REC_LEN-1).
; Entrada: DI = destino (dentro de full_name_buff)
CopyFromInput_Clamp PROC NEAR
    PUSH AX
    PUSH CX
    PUSH SI
    PUSH DX

    MOV CL, [nameBuff+1]               ; longitud tecleada
    MOV AX, DI
    SUB AX, OFFSET full_name_buff      ; usados
    MOV DX, NAME_REC_LEN-1
    SUB DX, AX                         ; libres
    CMP CL, DL
    JBE @len_ok
    MOV CL, DL
@len_ok:
    LEA SI, nameBuff+2
    JCXZ @done
    REP MOVSB
@done:
    POP DX
    POP SI
    POP CX
    POP AX
    RET
CopyFromInput_Clamp ENDP

; PutSpaceIfRoom:
; Escribe un espacio si queda sitio antes del '$' final.
; Entrada: DI = posicion actual en full_name_buff
PutSpaceIfRoom PROC NEAR
    PUSH AX
    PUSH DX
    MOV AX, DI
    SUB AX, OFFSET full_name_buff
    MOV DX, NAME_REC_LEN-1
    CMP AX, DX
    JAE @nospace
    MOV BYTE PTR [DI], ' '
    INC DI
@nospace:
    POP DX
    POP AX
    RET
PutSpaceIfRoom ENDP

;----Subrutinas para la validacion de las notas (que se cumpla todos los filtros)----

ValidateNote PROC NEAR
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH BP

    MOV     AL, 0          ; invalida por defecto

    ; Si se ingresa un valor con longitud 0
    CMP     CL, 0
    JE      VN_FAIL

    ; --- TRIM de CR/LF/espacios finales ---  
    ; TRIM: Es una accion dedica a borrar caracteres indeseados de una cadena de texto
    ; CR es Carriage Return 
    ; LF es Line Feed
    ; Con el TRIM lo que hacemos es validar que si el usuario ingreso caracteres, espacios
    ; etc, tenemos que decirle que los borre y disminuya la memoria donde se estaba guardando
    ; Esto debido a que estuve teniendo errores (Jose) ya que a pesar de que si ingresaba 
    ; datos correctos, solo me indicaba error y era por esto mismo, el bucle no sabia 
    ; interpretar los datos ingresados porque no habia un filtro
    MOV     DI, SI
    ADD     DI, CX
    DEC     DI
VN_TRIM:
    CMP     CL, 0
    JE      VN_FAIL
    MOV     AL, [DI]
    CMP     AL, 13          ; CR
    JE      VN_TRIM_DEC
    CMP     AL, 10          ; LF
    JE      VN_TRIM_DEC
    CMP     AL, ' '         ; espacio
    JNE     VN_START
VN_TRIM_DEC:
    DEC     CL
    DEC     DI
    JMP     VN_TRIM

VN_START:
    XOR     DX, DX          ; DX = parte entera acumulada (0..100)
    XOR     BX, BX          ; BL = flag punto (0/1), BH = contador de decimales
    XOR     BP, BP          ; BP = 0 -> aun no hay digitos

VN_LOOP:
    CMP     CL, 0
    JE      VN_OK

    LODSB                   ; AL = char, SI++, CL--
    DEC     CL

    CMP     AL, '.'
    JE      VN_POINT

    ; Debe ser digito
    CMP     AL, '0'
    JB      VN_FAIL
    CMP     AL, '9'
    JA      VN_FAIL

    ; Convertir a 0..9 en DI
    MOV     AH, 0
    MOV     DI, AX
    SUB     DI, '0'
    MOV     BP, 1           ; vimos al menos un digito

    ; entero o decimal?
    CMP     BL, 0
    JNE     VN_DEC

    ; --- parte entera: DX = DX*10 + DI (sin tocar CL) ---
    MOV     AX, DX
    MUL     ten             ; DX:AX = AX * 10
    MOV     DX, AX
    ADD     DX, DI
    CMP     DX, 100
    JA      VN_FAIL
    JMP     VN_LOOP

VN_POINT:
    ; segundo '.' -> invalido
    CMP     BL, 0
    JNE     VN_FAIL
    MOV     BL, 1
    JMP     VN_LOOP

VN_DEC:
    ; si parte entera es 100, todos decimales deben ser 0
    CMP     DX, 100
    JNE     @count_dec
    CMP     DI, 0
    JNE     VN_FAIL
@count_dec:
    INC     BH
    CMP     BH, 5
    JA      VN_FAIL
    JMP     VN_LOOP

VN_OK:
    ; al menos un digito?
    CMP     BP, 0
    JE      VN_FAIL

    MOV     AL, 1
    JMP     VN_DONE

VN_FAIL:
    MOV     AL, 0

VN_DONE:
    POP     BP
    POP     DI
    POP     DX
    POP     CX
    POP     BX
    RET
ValidateNote ENDP

;--------NUEVAS SUBRUTINAS USADAS EN OPT_2-------

PrintCRLF PROC NEAR
    PUSH DX
    LEA DX, crlf
    CALL PrintStr
    POP DX
    RET
PrintCRLF ENDP

PrintChar PROC NEAR    ; DL = char
    PUSH AX
    MOV AH,02h
    INT 21h
    POP AX
    RET
PrintChar ENDP

; Imprime entero sin signo en AX (0..65535) sin usar DIV
; Por restas de 10000,1000,100,10 y luego unidades
PrintUInt_NoDiv PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    MOV DX, AX          ; DX = valor
    XOR BH, BH          ; BH = flag "ya imprimí algo"

    ; 10000
    MOV BX, 10000
    XOR AL, AL
PU_10000_LOOP:
    CMP DX, BX
    JB  PU_10000_DONE
    SUB DX, BX
    INC AL
    JMP PU_10000_LOOP
PU_10000_DONE:
    CMP BH, 0
    JNE PU_10000_PRINT
    CMP AL, 0
    JE  PU_1000_START
PU_10000_PRINT:
    MOV DL, '0'
    ADD DL, AL
    CALL PrintChar
    MOV BH, 1

PU_1000_START:
    MOV BX, 1000
    XOR AL, AL
PU_1000_LOOP:
    CMP DX, BX
    JB  PU_1000_DONE
    SUB DX, BX
    INC AL
    JMP PU_1000_LOOP
PU_1000_DONE:
    CMP BH, 0
    JNE PU_1000_PRINT
    CMP AL, 0
    JE  PU_100_START
PU_1000_PRINT:
    MOV DL, '0'
    ADD DL, AL
    CALL PrintChar
    MOV BH, 1

PU_100_START:
    MOV BX, 100
    XOR AL, AL
PU_100_LOOP:
    CMP DX, BX
    JB  PU_100_DONE
    SUB DX, BX
    INC AL
    JMP PU_100_LOOP
PU_100_DONE:
    CMP BH, 0
    JNE PU_100_PRINT
    CMP AL, 0
    JE  PU_10_START
PU_100_PRINT:
    MOV DL, '0'
    ADD DL, AL
    CALL PrintChar
    MOV BH, 1

PU_10_START:
    MOV BX, 10
    XOR AL, AL
PU_10_LOOP:
    CMP DX, BX
    JB  PU_10_DONE
    SUB DX, BX
    INC AL
    JMP PU_10_LOOP
PU_10_DONE:
    CMP BH, 0
    JNE PU_10_PRINT
    CMP AL, 0
    JE  PU_UNITS
PU_10_PRINT:
    MOV DL, '0'
    ADD DL, AL
    CALL PrintChar
    MOV BH, 1

PU_UNITS:
    ; DX < 10
    MOV AX, DX
    MOV DL, '0'
    ADD DL, AL
    CALL PrintChar

    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
PrintUInt_NoDiv ENDP


; ----------------- Cadenas -----------------

; Devuelve en CL la longitud hasta '$' (máx NOTE_REC_LEN-1)
; Entrada: DI = inicio del campo nota
StrLenUntilDollar_NOTE PROC NEAR
    PUSH AX
    PUSH DI
    XOR CX, CX
    MOV CX, NOTE_REC_LEN-1
    MOV SI, DI
SLUD_FIND:
    CMP BYTE PTR [SI], '$'
    JE  SLUD_LEN_OK
    INC SI
    LOOP SLUD_FIND
SLUD_LEN_OK:
    MOV AX, SI
    SUB AX, DI
    MOV CL, AL
    POP DI
    POP AX
    RET
StrLenUntilDollar_NOTE ENDP




; ----------------- Aritmética 32-bit básica -----------------

; Suma DX:AX al acumulador sum_hi:sum_lo
Add32ToSum PROC NEAR
    ADD sum_lo, AX
    ADC sum_hi, DX
    RET
Add32ToSum ENDP

; Compara (DX:AX) vs (BX:CX).
; CF=1 si (DX:AX) < (BX:CX)
Cmp32_DXAX_vs_BXCX PROC NEAR
    PUSH DX
    PUSH AX
    PUSH BX
    PUSH CX
    CMP DX, BX
    JB  Cmp_lt
    JA  Cmp_gt
    CMP AX, CX
    JB  Cmp_lt
    JA  Cmp_gt
    ; iguales -> CF=0
    CLC
    POP CX
    POP BX
    POP AX
    POP DX
    RET
Cmp_lt:
    STC
    POP CX
    POP BX
    POP AX
    POP DX
    RET
Cmp_gt:
    CLC
    POP CX
    POP BX
    POP AX
    POP DX
    RET
Cmp32_DXAX_vs_BXCX ENDP

; AL=1 si (DX:AX) >= 70.00000
IsGE_70Scaled PROC NEAR
    PUSH BX
    PUSH CX
    MOV BX, thresh70_hi
    MOV CX, thresh70_lo
    CALL Cmp32_DXAX_vs_BXCX
    JC  IG7S_no
    MOV AL, 1
    JMP IG7S_exit
IG7S_no:
    MOV AL, 0
IG7S_exit:
    POP CX
    POP BX
    RET
IsGE_70Scaled ENDP

; Imprime valor 32-bit (DX:AX) escalado x10^5 como X.YYYYY
; Sin usar DIV: parte entera por restas de 100000 y fracción por 10000/1000/100/10/1
PrintScaled5_NoDiv PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    ; Copiar a rem_hi:rem_lo = DI:SI
    MOV SI, AX
    MOV DI, DX

    ; ---- Parte entera por restas de 100000 ----
    XOR BX, BX                  ; BX = entero (0..100)
PS5_INT_LOOP:
    ; probar (rem - 100000)
    MOV AX, SI                  ; tmp_lo = rem_lo
    MOV DX, DI                  ; tmp_hi = rem_hi
    SUB AX, const100k_lo
    SBB DX, const100k_hi
    JC  PS5_INT_DONE
    ; aceptar resta
    MOV SI, AX
    MOV DI, DX
    INC BX
    JMP PS5_INT_LOOP
PS5_INT_DONE:
    ; imprimir entero (BX)
    MOV AX, BX
    CALL PrintUInt_NoDiv

    ; punto
    MOV DL, '.'
    CALL PrintChar

    ; ---- Fracción: imprimir 5 dígitos a partir de rem (DI:SI < 100000) ----
    ; d4: base 10000
    XOR CL, CL                  ; CL = digit
PS5_D4_LOOP:
    ; ¿rem >= 10000? (si rem_hi>0 siempre sí)
    CMP DI, 0
    JNE PS5_D4_CAN
    MOV AX, SI
    CMP AX, const10000
    JB  PS5_D4_OUT
PS5_D4_CAN:
    SUB SI, const10000
    SBB DI, 0
    INC CL
    JMP PS5_D4_LOOP
PS5_D4_OUT:
    MOV DL, '0'
    ADD DL, CL
    CALL PrintChar

    ; d3: base 1000
    XOR CL, CL
PS5_D3_LOOP:
    CMP DI, 0
    JNE PS5_D3_CAN
    MOV AX, SI
    CMP AX, const1000
    JB  PS5_D3_OUT
PS5_D3_CAN:
    SUB SI, const1000
    SBB DI, 0
    INC CL
    JMP PS5_D3_LOOP
PS5_D3_OUT:
    MOV DL, '0'
    ADD DL, CL
    CALL PrintChar

    ; d2: base 100
    XOR CL, CL
PS5_D2_LOOP:
    CMP DI, 0
    JNE PS5_D2_CAN
    MOV AX, SI
    CMP AX, const100
    JB  PS5_D2_OUT
PS5_D2_CAN:
    SUB SI, const100
    SBB DI, 0
    INC CL
    JMP PS5_D2_LOOP
PS5_D2_OUT:
    MOV DL, '0'
    ADD DL, CL
    CALL PrintChar

    ; d1: base 10
    XOR CL, CL
PS5_D1_LOOP:
    CMP DI, 0
    JNE PS5_D1_CAN
    MOV AX, SI
    CMP AX, const10
    JB  PS5_D1_OUT
PS5_D1_CAN:
    SUB SI, const10
    SBB DI, 0
    INC CL
    JMP PS5_D1_LOOP
PS5_D1_OUT:
    MOV DL, '0'
    ADD DL, CL
    CALL PrintChar

    ; d0: base 1  (resto < 10)
    MOV AX, SI
    MOV DL, '0'
    ADD DL, AL
    CALL PrintChar

    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
PrintScaled5_NoDiv ENDP



; Imprime sum_hi:sum_lo / (studentCount*100000) con 5 decimales, sin DIV
PrintAverage_NoDiv PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH BP

    ; ---- construir denom = n * 100000 en memoria ----
    XOR AX, AX
    XOR DX, DX
    MOV BL, studentCount
    CMP BL, 0
    JE  PA_AVG_ZERO                ; por seguridad
PA_BUILD_DEN:
    ADD AX, const100k_lo
    ADC DX, const100k_hi
    DEC BL
    JNZ PA_BUILD_DEN
    MOV avg_den_lo, AX
    MOV avg_den_hi, DX

    ; rem = sum
    MOV SI, sum_lo                 ; rem_lo
    MOV DI, sum_hi                 ; rem_hi

    ; ---- parte entera: while rem >= denom -> rem -= denom; entero++ ----
    XOR AX, AX                     ; AX = entero (0..100)
PA_ENT_LOOP:
    ; temp = rem - denom
    MOV BX, SI
    MOV BP, DI
    SUB BX, avg_den_lo
    SBB BP, avg_den_hi
    JC  PA_ENT_DONE
    ; aceptar
    MOV SI, BX
    MOV DI, BP
    INC AX
    JMP PA_ENT_LOOP
PA_ENT_DONE:
    ; imprimir entero (0..100) con rutina simple
    CALL PrintUInt0_999_NoDiv

    ; '.'
    MOV DL, '.'
    CALL PrintChar

    ; ---- 5 decimales: rem *= 10 ; digit = max d: rem - d*denom >= 0 ----
    MOV CL, 5
PA_FRAC_DIGIT:
    ; rem = rem * 10  (x8 + x2), usando sólo AX,BX,DX,BP como temporales
    ; t2 = rem*2  -> t2_lo:t2_hi = BX:BP
    MOV BX, SI
    MOV BP, DI
    SHL BX, 1
    RCL BP, 1
    ; t8 = rem*8  -> t8_lo:t8_hi = DX:AX
    MOV DX, SI
    MOV AX, DI
    SHL DX, 1
    RCL AX, 1
    SHL DX, 1
    RCL AX, 1
    SHL DX, 1
    RCL AX, 1
    ; rem = t8 + t2
    ADD DX, BX
    ADC AX, BP
    MOV SI, DX
    MOV DI, AX

    ; digit por restas de denom (0..9)
    XOR BL, BL                    ; BL = digit
PA_DIG_TRY:
    MOV DX, SI
    MOV AX, DI
    SUB DX, avg_den_lo
    SBB AX, avg_den_hi
    JC  PA_DIG_OUT
    MOV SI, DX
    MOV DI, AX
    INC BL
    CMP BL, 9
    JBE PA_DIG_TRY
PA_DIG_OUT:
    MOV DL, '0'
    ADD DL, BL
    CALL PrintChar

    DEC CL
    JNZ PA_FRAC_DIGIT
    JMP PA_AVG_END

PA_AVG_ZERO:
    ; n=0 improbable, pero imprimimos "0.00000"
    MOV DL, '0'
    CALL PrintChar
    MOV DL, '.'
    CALL PrintChar
    MOV DL, '0'
    CALL PrintChar
    CALL PrintChar
    CALL PrintChar
    CALL PrintChar
    CALL PrintChar

PA_AVG_END:
    POP BP
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
PrintAverage_NoDiv ENDP


; Imprime AX (0..999) sin DIV
PrintUInt0_999_NoDiv PROC NEAR
    PUSH AX
    PUSH BX
    PUSH DX

    MOV DX, AX          ; DX = valor
    XOR BH, BH          ; BH = flag "ya imprimí algo"

    ; centenas
    MOV BX, 100
    XOR AL, AL
PU3_HUND_LOOP:
    CMP DX, BX
    JB  PU3_HUND_DONE
    SUB DX, BX
    INC AL
    JMP PU3_HUND_LOOP
PU3_HUND_DONE:
    CMP AL, 0
    JE  PU3_TENS
    MOV DL, '0'
    ADD DL, AL
    CALL PrintChar
    MOV BH, 1

PU3_TENS:
    MOV BX, 10
    XOR AL, AL
PU3_TENS_LOOP:
    CMP DX, BX
    JB  PU3_TENS_DONE
    SUB DX, BX
    INC AL
    JMP PU3_TENS_LOOP
PU3_TENS_DONE:
    CMP BH, 0
    JNE PU3_TENS_PRINT
    CMP AL, 0
    JE  PU3_UNITS
PU3_TENS_PRINT:
    MOV DL, '0'
    ADD DL, AL
    CALL PrintChar
    MOV BH, 1

PU3_UNITS:
    ; DX < 10
    MOV AL, DL          ; (no usar DL: lo recargamos abajo)
    MOV AX, DX
    MOV DL, '0'
    ADD DL, AL          ; OJO: AL ahora no es el de arriba; recarguemos bien:
    ; corregimos: usar directamente DX como unidad
    MOV AX, DX
    MOV DL, '0'
    ADD DL, AL
    CALL PrintChar

    POP DX
    POP BX
    POP AX
    RET
PrintUInt0_999_NoDiv ENDP

 


; Usa AX = conteo (aprob/reprob). Denominador = studentCount.
; Imprime: espacio, espacio, '(', XX.XX, '%', ')'
PrintSpacePctTwo_NoDiv PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    ; "  ("
    MOV DL, ' '
    CALL PrintChar
    MOV DL, ' '
    CALL PrintChar
    MOV DL, '('
    CALL PrintChar

    ; T = count * 100
    MOV BX, AX              ; BX = count
    XOR AX, AX
    MOV CX, 100
PPCT_MUL100_LOOP:
    ADD AX, BX
    LOOP PPCT_MUL100_LOOP   ; AX = count*100 (<=1500)

    ; Q = T / n (entero) por restas
    XOR DX, DX              ; DX = Q
    MOV CL, studentCount
    CMP CL, 0
    JE  PPCT_ZERO
PPCT_INT_LOOP:
    CMP AX, CX
    JB  PPCT_INT_DONE
    SUB AX, CX
    INC DX
    JMP PPCT_INT_LOOP
PPCT_INT_DONE:
    ; imprimir entero Q (DX)
    MOV AX, DX
    CALL PrintUInt_NoDiv

    ; '.'
    MOV DL, '.'
    CALL PrintChar

    ; 1er decimal: AX = resto*10, d1 = AX/n por restas
    MOV BX, AX              ; BX=resto
    SHL BX, 1               ; *2
    MOV DX, AX
    SHL DX, 1
    SHL DX, 1               ; *8
    ADD BX, DX              ; *10
    MOV AX, BX
    XOR DL, DL
PPCT_D1_LOOP:
    CMP AX, CX
    JB  PPCT_D1_OUT
    SUB AX, CX
    INC DL
    JMP PPCT_D1_LOOP
PPCT_D1_OUT:
    MOV BL, DL
    MOV DL, '0'
    ADD DL, BL
    CALL PrintChar

    ; 2do decimal: AX = (resto)*10, d2 = AX/n
    MOV BX, AX
    SHL BX, 1
    MOV DX, AX
    SHL DX, 1
    SHL DX, 1
    ADD BX, DX
    MOV AX, BX
    XOR DL, DL
PPCT_D2_LOOP:
    CMP AX, CX
    JB  PPCT_D2_OUT
    SUB AX, CX
    INC DL
    JMP PPCT_D2_LOOP
PPCT_D2_OUT:
    MOV BL, DL
    MOV DL, '0'
    ADD DL, BL
    CALL PrintChar

    ; "%)"
    MOV DL, '%'
    CALL PrintChar
    MOV DL, ')'
    CALL PrintChar
    JMP PPCT_EXIT

PPCT_ZERO:
    ; n=0 improbable aquí, pero por seguridad imprime 0.00%) 
    MOV DL, '0'
    CALL PrintChar
    MOV DL, '.'
    CALL PrintChar
    MOV DL, '0'
    CALL PrintChar
    CALL PrintChar
    MOV DL, '%'
    CALL PrintChar
    MOV DL, ')'
    CALL PrintChar

PPCT_EXIT:
    POP DX
    POP CX
    POP BX
    POP AX
    RET
PrintSpacePctTwo_NoDiv ENDP





; Convierte nota cadena (SI, CL=len) a 32-bit DX:AX escala x10^5
; Sin DIV, usando (x8+x2) y completando decimales a 5
ParseNoteToScaled PROC NEAR
    PUSH BX
    PUSH CX
    PUSH SI
    PUSH DI

    XOR DX, DX
    XOR AX, AX
    XOR DH, DH       ; DH = flag punto
    XOR DL, DL       ; DL = #decimales vistos (0..5)

PNS_LOOP:
    CMP CL, 0
    JE  PNS_END
    LODSB
    DEC CL
    CMP AL, '.'
    JE  PNS_DOT
    CMP AL, '0'
    JB  PNS_LOOP
    CMP AL, '9'
    JA  PNS_LOOP
    SUB AL, '0'      ; AL = 0..9

    ; total = total*10 + AL  (x8+x2)
    ; t2 -> BX:BP
    MOV BX, AX
    MOV BP, DX
    SHL BX, 1
    RCL BP, 1
    ; t8 -> DI:SI
    MOV SI, AX
    MOV DI, DX
    SHL SI, 1
    RCL DI, 1
    SHL SI, 1
    RCL DI, 1
    SHL SI, 1
    RCL DI, 1
    ; total = t8 + t2 + dígito
    ADD SI, BX
    ADC DI, BP
    MOV BL, AL
    XOR BH, BH
    ADD SI, BX
    ADC DI, 0
    MOV AX, SI
    MOV DX, DI

    ; si estamos en parte fracc., contar decimales (máx 5)
    CMP DH, 0
    JE  PNS_LOOP
    INC DL
    CMP DL, 5
    JA  PNS_END
    JMP PNS_LOOP

PNS_DOT:
    CMP DH, 0
    JNE PNS_LOOP
    MOV DH, 1
    JMP PNS_LOOP

PNS_END:
    ; completar con ceros si DL<5 => *10^(5-DL)
    MOV AL, 5
    SUB AL, DL
    JBE PNS_DONE
    MOV CL, AL            ; usar CL como contador seguro

PNS_SCALE:
    ; total *= 10  (x8 + x2)
    MOV BX, AX
    MOV BP, DX
    SHL BX, 1
    RCL BP, 1
    MOV SI, AX
    MOV DI, DX
    SHL SI, 1
    RCL DI, 1
    SHL SI, 1
    RCL DI, 1
    SHL SI, 1
    RCL DI, 1
    ADD SI, BX
    ADC DI, BP
    MOV AX, SI
    MOV DX, DI

    DEC CL
    JNZ PNS_SCALE

PNS_DONE:
    POP DI
    POP SI
    POP CX
    POP BX
    RET
ParseNoteToScaled ENDP



CODE ENDS
END START
