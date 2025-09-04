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
    
    ; 7,000,000 = 0x006ACFC0 
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
    msgDbgAvgHex    DB 13,10,'AVG HEX DX:AX ='
   
    
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
    indexBuff       DB  5, 0, 5 DUP(0) ; Buffer para leer el indice 

    
    ;Buffers de salida
    numBuf          DB 32 DUP(0)     ; armado de numero (terminado con $)  
    
     
    ;Contador donde iremos guardando la cantidad de estudiantes guardados
    studentCount    DB 0 
    ;Estructura donde almacenamos los nombres (nombre, apellido1, apellido2)
    names           DB MAX_STUDENTS*NAME_REC_LEN DUP('$')   
    ;Estructura donde almacenamos las notas
    notes           DB MAX_STUDENTS*NOTE_REC_LEN DUP('$')
    
    ; Mensajes de la opcion 3     
    msgEnterIndex   DB 13,10,'Ingrese indice de estudiante [0 - 14]: $'
    ; Errores
    msgNoStudents   DB 13,10,'No se han agregado estudiantes.$'
    msgInvalidIndex DB 13,10,'Indice invalido. Intentelo de nuevo.$' 
    ; Estudiante encontrado
    msgFoundStudent DB 13,10,'El estudiante se ha encontrado: $'
    msgName         DB 13,10,'Nombre: $'
    msgNote         DB 13,10,'Nota: $'
     
    
    ;Ciertas variables que use para hacer debug (jose)
    frac5           DB 5 DUP (?) ;Guarda los 5 digitos fraccionales
    div10_rem       DB 0 ; En teoria es para guardar los decimales restantes
    p_seen_dot    DB 0   ; puntero para el punto decimal
    p_dec_count   DB 0   ; Contador de decimales



DATA ENDS


CODE SEGMENT
    ASSUME CS:CODE, DS:DATA

START:
    ; Inicializar DS
    MOV AX, DATA
    MOV DS, AX
    MOV ES, AX
    CLD

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
    LEA DI, full_name_buff       ; DI = destino de concatenacion
                                  
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

    CALL PutSpaceIfRoom 
    LEA DX, msgEnterApell1
    CALL PrintStr
    LEA DX, nameBuff
    CALL ReadLine

    ; Verifica que se escriba algo
    MOV CL, [nameBuff+1]
    CMP CL, 0
    JE APELLIDO1_VACIO   ;funciona igual que el nombre
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
    ; Guardamos el nombre en arreglo 'names' (desde full_name_buff)
    XOR BX, BX
    MOV BL, studentCount

    LEA SI, full_name_buff
    LEA DI, names
    MOV AX, BX
    MOV CX, NAME_REC_LEN
    MUL CX                 ; AX = index * NAME_REC_LEN
    ADD DI, AX
    MOV CX, NAME_REC_LEN-1
    CLD
    REP MOVSB
    MOV BYTE PTR [DI], '$' ; terminador

; ======= GUARDAR NOTA + DEBUG =======


    PUSH BX

    ; -- Dump rápido del buffer (ASCII) --
    LEA  DX, noteBuff+2
    MOV  DL, '<'           ; usamos PrintChar; luego recargamos DX
    CALL PrintChar
    LEA  DX, noteBuff+2
    CALL PrintStr          ; requiere '$' temporal
    MOV  DL, '>'
    CALL PrintChar
    CALL PrintCRLF
    
    ; ---- Debug del buffer ---- 
    LEA  SI, noteBuff+2
    MOV  DL, '<'
    CALL PrintChar
    MOV  AL, [SI]
    CALL PrintHexByte
    MOV  DL, ' '
    CALL PrintChar
    MOV  AL, [SI+1]
    CALL PrintHexByte
    MOV  DL, ' '
    CALL PrintChar
    MOV  AL, [SI+2]
    CALL PrintHexByte
    MOV  DL, '>'
    CALL PrintChar
    CALL PrintCRLF

    ; DI = &notes + idx*NOTE_REC_LEN 
    LEA  DI, notes
    XOR  BH, BH
    MOV  CX, BX
    JCXZ gdst_ready
gdst_add:
        ADD  DI, NOTE_REC_LEN
        LOOP gdst_add
gdst_ready:

    PUSH DI     ; Se usa para el debug que hacemos despues
    
    
    ;Copiar desde noteBuff+2 hasta CR (0Dh)
    LEA  SI, noteBuff+2
    CLD
gcpy_loop:
    LODSB
    CMP  AL, 13         ; CR?
    JE   gcpy_end
    STOSB
    JMP  gcpy_loop
gcpy_end:
    MOV  BYTE PTR [DI], '$' ; terminar campo
    
    ; Debug en el espacio de la nota HEX 
    POP  SI                 ; SI = INICIO del slot
    MOV  DL, '['
    CALL PrintChar
    MOV  AL, [SI]
    CALL PrintHexByte
    MOV  DL, ' '
    CALL PrintChar
    MOV  AL, [SI+1]
    CALL PrintHexByte
    MOV  DL, ' '
    CALL PrintChar
    MOV  AL, [SI+2]
    CALL PrintHexByte
    MOV  DL, ']'
    CALL PrintChar
    CALL PrintCRLF
    
    ;Imprimir la cadena tal cual
    MOV  DL, '{'
    CALL PrintChar
    MOV  DX, SI             ; En teoria aqui volves a cargar en DX
    CALL PrintStr           ; En este print deberia verse el valor ingresado
    MOV  DL, '}'
    CALL PrintChar
    CALL PrintCRLF
    
    POP  BX
; ======= FIN GUARDAR NOTA =======


    ; Incrementar contador
    INC studentCount

    ; Confirmacion
    LEA DX, msgStored
    CALL PrintStr
    CALL PressAnyKey
    JMP MAIN_MENU
    
;Si ya hay 15 estudiantes no guarda y se muestra mensaje
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
    MOV WORD PTR sum_hi,     0
    MOV WORD PTR sum_lo,     0
    MOV WORD PTR cntAprob,   0
    MOV WORD PTR cntReprob,  0

    ; i=0..studentCount-1
    XOR BX, BX                ; BX = i (usaremos BL)
    LEA DI, notes             ; DI = &notes[0]

 
    ; Se busca el primer espacio no vacio para empezar a hacer min, max y sum
FIND_FIRST_NONEMPTY:
    MOV AL, studentCount
    CMP BL, AL
    JAE NO_VALID_NOTES            ; todos vacíos => no hay datos válidos

    CMP BYTE PTR [DI], '$'
    JE  FF_NEXT

    ; Procesar primer no-vacio:
    PUSH DI
    CALL StrLenUntilDollar_NOTE   
    POP  DI
    
    ;--------Debug que muestra la nota antes de enviarla al convertidor
    PUSH DX
    MOV  DX, DI
    CALL PrintStr  
    CALL PrintCRLF
    POP  DX
    
                     
    MOV SI, DI
    CALL ParseNoteToScaled        ; Llamado al convertidor 
    
        ; --- Debug que muestra nota despues del convertidor ---
    PUSH AX
    PUSH DX
    ; imprime "DBG nota: "
    MOV  DL, 'D'     ; D
    CALL PrintChar
    MOV  DL, 'B'     ; B
    CALL PrintChar
    MOV  DL, 'G'     ; G
    CALL PrintChar
    MOV  DL, ' '     ; espacio
    CALL PrintChar
    MOV  DL, 'n'
    CALL PrintChar
    MOV  DL, 'o'
    CALL PrintChar
    MOV  DL, 't'
    CALL PrintChar
    MOV  DL, 'a'
    CALL PrintChar
    MOV  DL, ':'
    CALL PrintChar
    MOV  DL, ' '
    CALL PrintChar
    CALL PrintScaled5_FromDXAX   ; imprime DX:AX (×10^5)
    CALL PrintCRLF
    POP  DX
    POP  AX


    ; min = max = valor
    MOV min_hi, DX
    MOV min_lo, AX
    MOV max_hi, DX
    MOV max_lo, AX

    ; sum_lo += AX ; sum_hi += DX + carry
    MOV  BX, sum_lo
    ADD  BX, AX
    MOV  sum_lo, BX
    MOV  BX, sum_hi
    ADC  BX, DX
    MOV  sum_hi, BX  
    
        ; --- DBG: sum tras primera nota (sum_hi:sum_lo) ---
    PUSH AX
    PUSH DX
    MOV  DX, sum_hi
    MOV  AX, sum_lo
    MOV  DL, 'D'
    CALL PrintChar
    MOV  DL, 'B'
    CALL PrintChar
    MOV  DL, 'G'
    CALL PrintChar
    MOV  DL, ' '
    CALL PrintChar
    MOV  DL, 's'
    CALL PrintChar
    MOV  DL, 'u'
    CALL PrintChar
    MOV  DL, 'm'
    CALL PrintChar
    MOV  DL, '0'
    CALL PrintChar
    MOV  DL, ':'
    CALL PrintChar
    MOV  DL, ' '
    CALL PrintChar
    CALL PrintScaled5_FromDXAX  
    CALL PrintCRLF
    POP  DX
    POP  AX

   

    ; aprobar/reprobar
    ;Llama a funcion que verifica si es mayor o igual a 70
    PUSH DX
    PUSH AX
    CALL IsGE_70Scaled            ; AL=1 si >=70
    CMP  AL, 0
    JE   first_rep
    INC  WORD PTR cntAprob
    JMP  first_done
first_rep:
    INC  WORD PTR cntReprob
first_done:

    ; avanzar al siguiente para entrar al bucle general
    INC BL
    ADD DI, NOTE_REC_LEN
    JMP LOOP_NOTES

FF_NEXT:
    ; slot vacio: avanzar
    INC BL
    ADD DI, NOTE_REC_LEN
    JMP FIND_FIRST_NONEMPTY

NO_VALID_NOTES:
    ; Hay estudiantes pero todas las notas estan vacias
    LEA DX, msgNoData
    CALL PrintStr
    CALL PressAnyKey
    JMP MAIN_MENU

; ---- En teoria es un loop al que ingresa y hace de manera recursiva las estadisticas ----
LOOP_NOTES:
    MOV AL, studentCount
    CMP BL, AL
    JAE DONE_NOTES

    ; si el slot esta vacio, saltar sin contar
    CMP BYTE PTR [DI], '$'
    JE  LN_NEXT

    PUSH DI
    CALL StrLenUntilDollar_NOTE
    POP  DI

    MOV SI, DI
    CALL ParseNoteToScaled       

    ; sum_lo += AX ; sum_hi += DX + carry
    MOV  BX, sum_lo
    ADD  BX, AX
    MOV  sum_lo, BX
    MOV  BX, sum_hi
    ADC  BX, DX
    MOV  sum_hi, BX

    ; min ?  (CF=1 si DX:AX < BX:CX)
    MOV BX, min_hi
    MOV CX, min_lo
    CALL Cmp32_DXAX_vs_BXCX
    JNC no_new_min
    MOV min_hi, DX
    MOV min_lo, AX
no_new_min:

    ; max ?  (CF=1 si DX:AX < BX:CX) => si no es menor, puede ser nuevo max
    MOV BX, max_hi
    MOV CX, max_lo
    CALL Cmp32_DXAX_vs_BXCX
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

LN_NEXT:
    ; siguiente elemento
    INC BL
    ADD DI, NOTE_REC_LEN
    JMP LOOP_NOTES

DONE_NOTES:

    ; -------- Mostrar resultados --------
    LEA DX, msgStatsTitle
    CALL PrintStr

    ; -------- Promedio general (32/16 ? 32) --------
    LEA DX, msgProm  
    CALL PrintStr
    

    ; n = cntAprob + cntReprob  (solo notas validas)
    MOV AX, cntAprob
    ADD AX, cntReprob
    CMP AX, 0
    JE  AVG_ZERO

    ; BX = n
    MOV BX, AX

    ; q_hi = sum_hi / n, rem1 = sum_hi % n
    XOR DX, DX
    MOV AX, sum_hi
    DIV BX                 ; AX=q_hi, DX=rem1
    PUSH AX                ; guardar q_hi
    MOV CX, DX          

    ; q_lo = (rem1<<16 + sum_lo) / n
    MOV AX, sum_lo
    MOV DX, CX
    DIV BX                 ; AX=q_lo
    POP DX                 

    ; imprimir promedio 
    CALL PrintScaled5_FromDXAX
    CALL PrintCRLF
    JMP AVG_DONE

AVG_ZERO:
    ; si no hubo validas, imprimir 0.00000
    XOR DX, DX
    XOR AX, AX
    CALL PrintScaled5_FromDXAX
    CALL PrintCRLF

AVG_DONE:
    ; Maximo
    LEA DX, msgMax
    CALL PrintStr
    MOV DX, max_hi
    MOV AX, max_lo
    CALL PrintScaled5_NoDiv
    CALL PrintCRLF

    ; Minimo
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
    CALL PrintUInt0_255_NoDiv
    CALL PrintSpacePctTwo_NoDiv
    CALL PrintCRLF

    ; Reprobados
    LEA DX, msgReprob
    CALL PrintStr
    MOV AX, cntReprob
    CALL PrintUInt0_255_NoDiv
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


OPT_2:
    LEA DX, msgStub2
    CALL PrintStr
    CALL PressAnyKey
    JMP MAIN_MENU

; -----------------Opcion 3: Ingresar el indice del estudiante----------
OPT_3:
    MOV AL, studentCount
    CMP AL, 0
    JE NO_STUDENTS_YET ; Si no hay estudiantes muestra el mensaje de que no se han agregado
    
    ;Mensaje de prompt dinamico con el rango maximo
    PUSH DX ;Guarda el DX porque el PrintNum lo cambia
    MOV BL, studentCount
    DEC BL  ; studentCount - 1 para el indice mayor
    MOV AL, BL
    MOV AH, 0 ; Limpia el AH para luego ConvertByteToASCII
    CALL ConvertByteToASCII 
    
    LEA DX, msgEnterIndex
    CALL PrintStr
    POP DX ; Recupera el DX
    
    LEa DX, indexBuff
    CALL ReadLine ; Lee el indice ingresado 
    
    ; Validar que se haya ingresado algun dato
    MOV CL, [indexBuff+1]
    CMP CL, 0
    JE INVALID_INDEX_OPT3 ; No se metio nada 
    
    ; Convierte el string de entrada en un numero
    LEA SI, indexBuff+2
    MOV CH, [indexBuff+1] ; Longitud de la cadena a convertir
    Call ASCII_TO_BYTE ; Devuelve el numero en AL CF=0 si todo bien o CF=1 si hay error
    
    JC INVALID_INDEX_OPT3 ; Si hay un error en la conversion sale un indice invalido
    
    ; AL contiene el indice 
    CMP AL, studentCount
    JAE INVALID_INDEX_OPT3 ; Indice fuera de rango
    
    ; Si el indice es valido, busca y muestra al estudiante, Calcula la direccion del nombre
    XOR BX, BX
    MOV BL, AL ; BX es el indice del estudiante
    
    LEA SI, names
    MOV AX,BX
    MOV CX, NAME_REC_LEN
    MUL CX  ; AX = index * NAME_REC_LEN
    ADD SI, AX ; SI esta apuntando al nombre del estudiante
    
    LEA DX, msgName
    Call PrintStr
    MOV DX, SI
    CALL PrintStr ; Se imprime el nombre
    
    ; Se calcula la direccion de donde esta la nota 
    LEA SI, notes
    MOV AX, BX
    MOV CX, NOTE_REC_LEN
    MUL CX  ; AX = index*NOTE_REC_LEN
    ADD SI, AX ; SI esta apuntando a la nota del estudiante
    
    LEA DX, msgNote
    CALL PrintStr
    MOV DX, SI
    CALL PrintStr ; Se imprime la nota
    
    CALL PressAnyKey
    JMP MAIN_MENU
;----------Funciones auxiliares para opcion 3------------------    
NO_STUDENTS_YET:
    LEA DX, msgNoStudents
    Call PrintStr
    Call PressAnyKey
    JMP MAIN_MENU
    
INVALID_INDEX_OPT3:
    LEA DX, msgInvalidIndex
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
    JBE @len_okn
    MOV CL, DL
@len_okn:
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

; Imprime entero sin signo en AX
; Por restas de 10000,1000,100,10 y luego unidades
PrintUInt_NoDiv PROC NEAR

;------- Subrutinas para la opcion 3 -----------------------

; ASCII_TO_BYTE
; Convierte una cadena ASCII numérica a un byte.
; Entrada: SI = Puntero a la cadena ASCII (ej: '15', '0', '99')
;          CH = Longitud de la cadena
; Salida:  AL = Numero convertido (0-255)
;          CF = 0 si la conversion es exitosa, 1 si hay un error (no numorico, desbordamiento)
ASCII_TO_BYTE PROC NEAR
    PUSH BX
    PUSH CX
    PUSH DX

    XOR AX, AX   ; AL = resultado (acumulador)
    XOR BX, BX   ; BX = 10 (para multiplicaciones)
    MOV BL, 10
    CLD          ; Direccion de incremento para LODSB

ATB_LOOP:
    CMP CH, 0
    JE ATB_DONE  ; Si no quedan caracteres, terminamos

    LODSB        ; Carga el byte en AL, incrementa SI, decrementa CH

    CMP AL, '0'
    JB ATB_ERROR ; No es un digito
    CMP AL, '9'
    JA ATB_ERROR ; No es un digito

    SUB AL, '0'  ; Convertir ASCII a digito (0-9)

    PUSH AX      ; Guardar digito actual
    MOV AL, AH   ; Mover el acumulado temporal (AH es el acumulador antes de desbordar)
    MUL BL       ; AL = AL * 10 (resultado en AX)
    JO ATB_ERROR ; Comprobar desbordamiento (Overflow Flag)

    MOV AH, AL   ; Guardar el resultado en AH
    POP AX       ; Recuperar el digito actual
    ADD AH, AL   ; Sumar el digito actual
    JO ATB_ERROR ; Comprobar desbordamiento

    JMP ATB_LOOP

ATB_ERROR:
    STC ; Poner Carry Flag a 1 para indicar error
    JMP ATB_END

ATB_DONE:
    MOV AL, AH   ; Mover el resultado final de AH a AL
    CLC          ; Limpiar Carry Flag para indicar exito

ATB_END:
    POP DX
    POP CX
    POP BX
    RET
ASCII_TO_BYTE ENDP

; ConvertByteToASCII
; Convierte un byte (0-99) a su representacion ASCII y lo almacena en una parte de msgEnterIndex.
; Es para el mensaje: 'Ingrese el indice del estudiante a buscar (0-X): $'
; Donde X es studentCount - 1. Asume que X es como maximo un numero de 2 digitos.
; Entrada: AL = byte a convertir (ej. 14 para 0-14)
; Salida:  Modifica msgEnterIndex para mostrar el numero correctamente.
ConvertByteToASCII PROC NEAR

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
<<<<<<< HEAD
    PUSH DI

    ; Calcular el valor maximo (studentCount - 1)
    MOV AH, 0 ; Limpiar AH
    MOV BL, 10 ; Divisor

    ; Posicion para escribir el numero en el mensaje
    ; El mensaje es: 'Ingrese el indice del estudiante a buscar (0-', 0,'): $'
    ; El '0' esta en offset 49, seguido por el espacio para el numero y luego '): $'
    ; Deberiamos escribir el numero en la posicion del 0, y el '): $' se mueve si es de 2 digitos.
    ; Realmente, el 0 en '0-' es el inicio. El lugar para el max_index es despues del '-'.
    ; msgEnterIndex DB 13,10,'Ingrese el indice del estudiante a buscar (0-', 0,'): $'
    ; La posicion del 0 es msgEnterIndex + 49. El siguiente byte es el que vamos a modificar.
    LEA DI, msgEnterIndex + 50 ; Apunta al byte despues del '-'

    CMP AL, 10 ; Si es menor a 10, es un solo digito
    JB CVTA_ONE_DIGIT

    ; Dos digitos
    DIV BL ; AL = cociente (decenas), AH = resto (unidades)
    ADD AL, '0'
    MOV BYTE PTR [DI], AL ; Escribir decenas
    INC DI
    MOV AL, AH ; Unidades
    JMP CVTA_ONE_DIGIT_STORE

CVTA_ONE_DIGIT:
    ADD AL, '0'
CVTA_ONE_DIGIT_STORE:
    MOV BYTE PTR [DI], AL ; Escribir unidades
    INC DI

    ; Colocar los caracteres finales del mensaje
    MOV BYTE PTR [DI], ')'
    INC DI
    MOV BYTE PTR [DI], ':'
    INC DI
    MOV BYTE PTR [DI], ' '
    INC DI
    MOV BYTE PTR [DI], '$'
    
    POP DI
=======
    PUSH SI

    MOV DX, AX          ; DX = valor
    XOR BH, BH          ; BH = flag "ya imprime algo"

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
>>>>>>> origin/estadistic_josepa
    POP DX
    POP CX
    POP BX
    POP AX
    RET
    
ConvertByteToASCII ENDP
PrintUInt_NoDiv ENDP


; ----------------- Cadenas -----------------

; Devuelve en CL la longitud hasta '$' (max NOTE_REC_LEN-1)
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




; ----------------- Aritmetica 32-bit  -----------------

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
; parte entera por restas de 100000 y fracción por 10000/1000/100/10/1
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
    CALL PrintUInt0_255_NoDiv

    ; punto
    MOV DL, '.'
    CALL PrintChar

    ; ---- Fraccion: imprimir 5 digitos a partir de rem (DI:SI < 100000) ----
    ; d4: base 10000
    XOR CL, CL                  ; CL = digit
PS5_D4_LOOP:
    ; rem >= 10000? (si rem_hi>0 siempre si)
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



; Imprime sum_hi:sum_lo / (studentCount*100000) con 5 decimales
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
    JE  PA_AVG_ZERO               
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

    ; ---- parte entera: mientras rem >= denom entonces rem -= denom; entero++ ----
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
    CALL PrintUInt0_255_NoDiv

    
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
    ; n=0 improbable, pero imprimimos "0.00000", lo agregue por si falla la validacion (jose)
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


; Imprime AX en decimal (0..255)
PrintUInt0_255_NoDiv PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV BX, AX          ; BX = valor (0..255)
    XOR CH, CH          ;

    ; centenas
    XOR AL, AL
PU255_HUND_LOOP:
    CMP BX, 100
    JB  PU255_HUND_DONE
    SUB BX, 100
    INC AL
    JMP PU255_HUND_LOOP
PU255_HUND_DONE:
    CMP AL, 0
    JE  PU255_TENS
    MOV DL, '0'
    ADD DL, AL
    CALL PrintChar
    MOV CH, 1

PU255_TENS:
    XOR AL, AL
PU255_TENS_LOOP:
    CMP BX, 10
    JB  PU255_TENS_DONE
    SUB BX, 10
    INC AL
    JMP PU255_TENS_LOOP
PU255_TENS_DONE:
    CMP CH, 0
    JNE PU255_TENS_PRINT
    CMP AL, 0
    JE  PU255_UNITS
PU255_TENS_PRINT:
    MOV DL, '0'
    ADD DL, AL
    CALL PrintChar
    MOV CH, 1

PU255_UNITS:
    ; BX < 10   => BL es la unidad
    MOV DL, '0'
    ADD DL, BL
    CALL PrintChar

    POP DX
    POP CX
    POP BX
    POP AX
    RET
PrintUInt0_255_NoDiv ENDP



 


; Usa AX = conteo (aprob/reprob). Denominador n = studentCount
; Imprime: "  (XX.XX%)"
PrintSpacePctTwo_NoDiv PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    ; "  ("
    MOV DL, ' '
    CALL PrintChar
    MOV DL, ' '
    CALL PrintChar
    MOV DL, '('
    CALL PrintChar

    ; BX = n (denominador)
    XOR BX, BX
    MOV BL, studentCount
    CMP BL, 0
    JE  PSP_ZERO

    ; T = count * 100  (AX ya trae count)
    MOV SI, AX          ; SI = count
    XOR AX, AX
    MOV CX, 100
PSP_MUL100:
    ADD AX, SI
    LOOP PSP_MUL100      ; AX = T (<= 1500)

    ; Q = T / n (entero) por restas
    XOR DX, DX           ; DX = Q
PSP_DIV_INT:
    CMP AX, BX
    JB  PSP_INT_DONE
    SUB AX, BX
    INC DX
    JMP PSP_DIV_INT
PSP_INT_DONE:
    MOV AX, DX
    CALL PrintUInt0_255_NoDiv

    ; '.'
    MOV DL, '.'
    CALL PrintChar

    ; --- primer decimal ---
    ; AX = resto (0..n-1). r10 = AX * 10
    MOV SI, AX
    XOR AX, AX
    MOV CX, 10
PSP_MUL10_1:
    ADD AX, SI
    LOOP PSP_MUL10_1          ; AX = r*10

    ; d1 = AX / n por restas
    XOR DH, DH                ; DH = d1
PSP_D1_LOOP:
    CMP AX, BX
    JB  PSP_D1_OUT
    SUB AX, BX
    INC DH
    JMP PSP_D1_LOOP
PSP_D1_OUT:
    MOV DL, '0'
    ADD DL, DH
    CALL PrintChar

    ; --- segundo decimal ---
    ; AX = resto1. r10 = AX * 10
    MOV SI, AX
    XOR AX, AX
    MOV CX, 10
PSP_MUL10_2:
    ADD AX, SI
    LOOP PSP_MUL10_2          ; AX = r*10

    XOR DH, DH                ; DH = d2
PSP_D2_LOOP:
    CMP AX, BX
    JB  PSP_D2_OUT
    SUB AX, BX
    INC DH
    JMP PSP_D2_LOOP
PSP_D2_OUT:
    MOV DL, '0'
    ADD DL, DH
    CALL PrintChar

    ; "%)"
    MOV DL, '%'
    CALL PrintChar
    MOV DL, ')'
    CALL PrintChar
    JMP PSP_EXIT

PSP_ZERO:
    ; n = 0 (no deberia ocurrir aqui)
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

PSP_EXIT:
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
PrintSpacePctTwo_NoDiv ENDP


; Convierte cadena en [SI] a DX:AX 
; Se detiene en '$', NUL, CR(13) o espacio. Acepta un solo '.' y hasta 5 decimales.
ParseNoteToScaled PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH BP

    XOR AX, AX                      ; total_lo
    XOR DX, DX                      ; total_hi
    MOV BYTE PTR [p_seen_dot], 0
    MOV BYTE PTR [p_dec_count], 0

    MOV CL, NOTE_REC_LEN-1          ; Hasta donde debe llegar

PNS_LOOP:
    CMP CL, 0
    JE  PNS_END
    LODSB                            ; AL = *SI++
    DEC CL

    ; fin de campo
    CMP AL, '$'                      ; '$'
    JE  PNS_END
    CMP AL, 0                        ; NUL
    JE  PNS_END
    CMP AL, 13                       ; CR
    JE  PNS_END
    CMP AL, ' '                      ; espacio
    JE  PNS_END

    ; punto decimal
    CMP AL, '.'
    JE  PNS_DOT

    ; digito?
    CMP AL, '0'
    JB  PNS_LOOP
    CMP AL, '9'
    JA  PNS_LOOP
    SUB AL, '0'                      ; AL = 0..9

    ; total = total*10  (x8 + x2)
    ; t2 -> BX:DI
    MOV BX, AX
    MOV DI, DX
    SHL BX, 1
    RCL DI, 1
    ; t8 -> SI:BP
    MOV SI, AX
    MOV BP, DX
    SHL SI, 1
    RCL BP, 1
    SHL SI, 1
    RCL BP, 1
    SHL SI, 1
    RCL BP, 1
    ; total = t8 + t2
    ADD SI, BX
    ADC BP, DI
    MOV AX, SI
    MOV DX, BP

    ; total += digito
    MOV BL, AL
    XOR BH, BH
    ADD AX, BX
    ADC DX, 0

    ; si estamos en fraccion, contar decimales (recuerden que maximo 5)
    CMP BYTE PTR [p_seen_dot], 0
    JE  PNS_LOOP
    MOV BL, [p_dec_count]
    CMP BL, 5
    JAE PNS_LOOP
    INC BYTE PTR [p_dec_count]
    JMP PNS_LOOP

PNS_DOT:
    ; aceptar un solo '.'
    CMP BYTE PTR [p_seen_dot], 0
    JNE PNS_LOOP
    MOV BYTE PTR [p_seen_dot], 1
    JMP PNS_LOOP

PNS_END:
    ; completar con ceros faltantes: *10^(5 - p_dec_count)
    MOV AL, 5
    SUB AL, [p_dec_count]
    JBE PNS_DONE
    MOV CL, AL
PNS_SCALE:
    MOV BX, AX
    MOV DI, DX
    SHL BX, 1
    RCL DI, 1
    MOV SI, AX
    MOV BP, DX
    SHL SI, 1
    RCL BP, 1
    SHL SI, 1
    RCL BP, 1
    SHL SI, 1
    RCL BP, 1
    ADD SI, BX
    ADC BP, DI
    MOV AX, SI
    MOV DX, BP
    DEC CL
    JNZ PNS_SCALE

PNS_DONE:
    POP BP
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
ParseNoteToScaled ENDP


;---------Subrutinas usadas unicamente en debug-----------
; Imprime AL como dos digitos hex (usa PrintChar)
PrintHexByte PROC NEAR
    PUSH AX
    PUSH BX
    ; BL = copia del byte original
    MOV  BL, AL

    ; nibble alto
    MOV  AL, BL
    SHR  AL, 4
    CALL NibbleToHex

    ; nibble bajo
    MOV  AL, BL
    AND  AL, 0Fh
    CALL NibbleToHex

    POP  BX
    POP  AX
    RET
PrintHexByte ENDP

NibbleToHex PROC NEAR   ; AL = 0..15
    CMP  AL, 9
    JBE  @dec
    ADD  AL, 7
@dec:
    ADD  AL, '0'
    MOV  DL, AL
    CALL PrintChar
    RET
NibbleToHex ENDP

; Imprime AX en hex: 4 digitos (alto luego bajo)
PrintHexWord PROC NEAR
    push ax
    mov  al, ah         ; byte alto
    call PrintHexByte
    pop  ax             ; AX original, AL = byte bajo
    call PrintHexByte
    ret
PrintHexWord ENDP

; Imprime AL como 2 hex (usa tu PrintHexByte si ya la tienes)

; Imprime AX (0..99999) en 5 digitos con ceros a la izquierda
PrintDec5Padded PROC NEAR
    PUSH AX
    PUSH BX
    PUSH DX
    MOV  BX, 10000
    XOR  DX, DX
    DIV  BX          
    ADD  AL, '0'
    MOV  DL, AL
    CALL PrintChar
    MOV  AX, DX        ; resto

    MOV  BX, 1000
    XOR  DX, DX
    DIV  BX
    ADD  AL, '0'
    MOV  DL, AL
    CALL PrintChar
    MOV  AX, DX

    MOV  BX, 100
    XOR  DX, DX
    DIV  BX
    ADD  AL, '0'
    MOV  DL, AL
    CALL PrintChar
    MOV  AX, DX

    MOV  BX, 10
    XOR  DX, DX
    DIV  BX
    ADD  AL, '0'
    MOV  DL, AL
    CALL PrintChar

    ADD  DL, '0'       ; ultimo digito (AX tiene el resto)
    CALL PrintChar

    POP  DX
    POP  BX
    POP  AX
    RET
PrintDec5Padded ENDP

; Entrada:  DX:AX = valor (32 bits)
; Salida :  DX:AX = cociente (32 bits)
;           div10_rem = resto (0..9)
Div32By10 PROC NEAR
    PUSH BX
    PUSH SI
    PUSH BP

    MOV  BX, 10
    MOV  SI, AX          ; guarda bajo
    MOV  AX, DX
    XOR  DX, DX
    DIV  BX              ; AX = q_hi, DX = r_hi (0..9)
    MOV  BP, AX          ; BP = q_hi

    MOV  AX, SI          ; bajo original
   
    DIV  BX              ; AX = q_lo, DX = resto final (0..9)

    MOV  [div10_rem], DL ; guardar resto
    MOV  DX, BP          ; DX:AX = q_hi:q_lo

    POP  BP
    POP  SI
    POP  BX
    RET
Div32By10 ENDP

; Imprime DX:AX como entero
PrintScaled5_FromDXAX PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    ; Obtener 5 decimales (menos significativo primero)
    LEA  DI, frac5
    ADD  DI, 4           ; DI -> ultima posicion
    MOV  CX, 5
.ps5_get:
    CALL Div32By10       ; DX:AX = valor/10 ; div10_rem = resto
    MOV  AL, [div10_rem]
    ADD  AL, '0'
    MOV  [DI], AL
    DEC  DI
    LOOP .ps5_get

    ; DX:AX ahora contiene la PARTE ENTERA
    MOV  AX, AX          ; AX ya trae q_lo (entero)
    CALL PrintUInt0_255_NoDiv

    ; Punto decimal
    MOV  DL, '.'
    CALL PrintChar

    ; Imprimir los 5 decimales en orden
    LEA  DI, frac5
    MOV  CX, 5
.ps5_put:
    MOV  DL, [DI]
    CALL PrintChar
    INC  DI
    LOOP .ps5_put

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
PrintScaled5_FromDXAX ENDP




CODE ENDS
END START
