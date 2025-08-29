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
    
    ;Buffers temporales
    full_name_buff DB NAME_REC_LEN DUP(0) ;almacena el nombre y los apellidos hasta que llegue a la ubicacion final 
    
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
   
    
    ; Mensajes de stub (temporal) (mas abajo digo que es stub)
    msgStub2        DB '<< Stub >> Mostrar estadisticas (pendiente)$'
    msgStub3        DB '<< Stub >> Buscar estudiante (pendiente)$'
    msgStub4        DB '<< Stub >> Ordenar calificaciones (pendiente)$' 
    
    ; Buffers de entrada, al usar el interruptor INT 21h AH=0Ah
    ; Los buffers trabajan de la siguiente manera, dependiendo de la entrada
    ; se le indica a DX que hacer (0 tamano max permitido, 1 longitud de la cadena
    ; realmente y 2 los caracteres escritos por el usuario)
    nameBuff        DB  NAME_REC_LEN, 0, NAME_REC_LEN DUP(0)
    noteBuff        DB  NOTE_REC_LEN, 0, NOTE_REC_LEN DUP(0)  
    
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


; ----------------- STUBS (temporal) ----------------- 
; Por cultura general xd, un stub es como un adelanto que simula lo que debe hacer 
; el codigo para ver que todo funciona bien de momento, por lo que no hay logica
; solo las entradas al hacer click en una de las opciones 


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


CODE ENDS
END START
