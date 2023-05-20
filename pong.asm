; "EVELYN PONG"

STACK SEGMENT PARA STACK
    DB 64 DUP (' ')
STACK ENDS

DATA SEGMENT PARA 'DATA'

    WINDOW_WIDTH DW 140h                         ; Ancho de la ventana (320 pixels)                                       
    WINDOW_HEIGHT DW 0c8h                        ; Altura de la ventana (200 pixeles)
    WINDOW_BOUNDS DW 6                           ; Variable para checkear colisiones antes de ocurridas. 

    TIME_AUX DB 0                                ; Variale utilizada para verificar si el tiempo ha cambiado. DB = Defined Byte variable (8 bits)
    GAME_ACTIVE DB 1                           ; El juego esta activo si es 1 y no esta activo si es 0.  
    EXITING_GAME DB 0
    WINNER_INDEX DB 0  
    CURRENT_SCENE DB 0 

    TEXT_PLAYER_ONE_POINTS DB '0','$'
    TEXT_PLAYER_TWO_POINTS DB '0','$'
    TEXT_GAME_OVER_TITLE DB 'GAME OVER','$'
    TEXT_GAME_OVER_WINNER DB 'Player 0 won','$'
    TEXT_GAME_OVER_PLAY_AGAIN DB 'Press R to play again','$' 
    TEXT_GAME_OVER_MAIN_MENU DB 'Press E to exit to the main menu','$'
    TEXT_MAIN_GAME_NAME DB 'EVELYN PONG','$'
    TEXT_MAIN_MENU_TITLE DB 'MAIN MENU','$'
    TEXT_MAIN_MENU_SIGLEPLAYER DB 'SINGLEPLAYER - S KEY','$'
    TEXT_MAIN_MENU_MULTIPLAYER DB 'MULTIPLAYER - M KEY','$'
    TEXT_MAIN_MENU_EXIT DB 'EXIT GAME - E KEY','$'

    BALL_ORIGINAL_X DW 0A0h                      ; Posiciones X e Y al inicio del juego. 
    BALL_ORIGINAL_Y DW 64h
    BALL_X DW 0A0h                               ; Posiciones actuales X (columna) e Y (fila) de la pelota.
    BALL_Y DW 64h                               
    BALL_SIZE DW 04h                             ; Tamanio de la pelota. 4 pixeles en x y en y. 16 pixeles en total. 
    BALL_VELOCITY_X DW 04h                       ; Velocidades de la pelota X (horizontal) e Y (vertical).
    BALL_VELOCITY_Y DW 02h

    PADDLE_LEFT_X DW 0Ah                         ; Posiciones actuales X e Y de la paleta izquierda. 
    PADDLE_LEFT_Y DW 55h
    PLAYER_ONE_POINTS DB 0                      ; Puntos actuales del jugador de la izquierda. (Player 1)

    PADDLE_RIGHT_X DW 130h                       ; Posiciones actuales X e Y de la paleta derecha.  
    PADDLE_RIGHT_Y DW 55h
    PLAYER_TWO_POINTS DB 0                     ; Puntos actuales del jugador de la derecha. (Player 2)
    AI_CONTROLLED DB 0

    PADDLE_WIDTH DW 05h                          ; Ancho por defecto de la paleta.
    PADDLE_HEIGHT DW 1Fh                         ; Altura por defecto de la paleta.
    PADDLE_VELOCITY DW 05h                       ; Velocidad por defecto de la paleta. 

DATA ENDS

CODE SEGMENT PARA 'CODE'

    MAIN PROC FAR
    ASSUME CS:CODE,DS:DATA,SS:STACK
    PUSH DS
    SUB AX,AX
    PUSH AX
    MOV AX,DATA
    MOV DS,AX
    POP AX
    POP AX

        CALL CLEAR_SCREEN                        ; Establecer las configuraciones iniciales del modo de video. 

        CHECK_TIME:

            CMP EXITING_GAME,01h
            JE START_EXIT_PROCESS

            CMP CURRENT_SCENE,00h
            JE SHOW_MAIN_MENU

            CMP GAME_ACTIVE,00h
            JE SHOW_GAME_OVER

            MOV AH,2ch                           ; Obtener el tiempo del sistema.       
            INT 21h                              ; CH = hora CL = minutos DH = segundos DL = 1/100 segundos 

            CMP DL,TIME_AUX                      ; Es la hora actual igual a la anterior (TIME_AUX)?
            JE CHECK_TIME                        ; Si es igual, comparamos nuevamente.
            
            ; Si llegamos a este punto, es porque el tiempo ha pasado.

            MOV TIME_AUX,DL                      ; Actualizamos el tiempo.
            
            CALL CLEAR_SCREEN                    ; Limpiamos la pantalla reiniciando en modo de video. 
            
            CALL MOVE_BALL
            CALL DRAW_BALL

            CALL MOVE_PADDLES
            CALL DRAW_PADDLES

            CALL DRAW_UI                         ; Dibuja todo la interfaz de usuario del juego. 

            JMP CHECK_TIME                       ; Repetimos el proceso.

            SHOW_GAME_OVER:
                CALL DRAW_GAME_OVER_MENU
                JMP CHECK_TIME
                RET 

            SHOW_MAIN_MENU:
                CALL DRAW_MAIN_MENU
                JMP CHECK_TIME

            START_EXIT_PROCESS:
                CALL CONCLUDE_EXIT_GAME

        RET


    MAIN ENDP

    MOVE_BALL PROC NEAR                     

        MOV AX,BALL_VELOCITY_X                   ; Mover la pelota horizontalmente 
        ADD BALL_X,AX
        MOV AX,WINDOW_BOUNDS
        CMP BALL_X,AX                            ; BALL_X < 0 + WINDOW_BOUNDS (Y -> choca con el limite izquierdo, reiniciamos su posicion)
        JL GIVE_POINT_TO_PLAYER_TWO              ; Si es menos, otorgarle un punto al player 2 y llevar la pelora a su posicion original. 
        
        MOV AX,WINDOW_WIDTH
        SUB AX,BALL_SIZE
        SUB AX,WINDOW_BOUNDS
        CMP BALL_X,AX                            ; BALL_X > WINDOW_WIDTH - BALL_SIZE - WINDOW_BOUNDS (Y -> choca con el limite derecho)
        JG GIVE_POINT_TO_PLAYER_ONE              ; Si es menos, otorgarle un punto al player 1 y llevar la pelora a su posicion original.
        JMP MOVE_BALL_VERTICALLY

        GIVE_POINT_TO_PLAYER_ONE:
            INC PLAYER_ONE_POINTS
            CALL RESET_BALL_POSITION

            CALL UPDATE_TEXT_PLAYER_ONE_POINTS 
            
            CMP PLAYER_ONE_POINTS,05h
            JGE GAME_OVER
            RET

        GIVE_POINT_TO_PLAYER_TWO:
            INC PLAYER_TWO_POINTS
            CALL RESET_BALL_POSITION

            CALL UPDATE_TEXT_PLAYER_TWO_POINTS 

            CMP PLAYER_TWO_POINTS,05h
            JGE GAME_OVER
            RET

        GAME_OVER:                                ; Someone has reached 5 points. Reiniciar el conteo de puntos 
            CMP PLAYER_ONE_POINTS,05h
            JNL WINNER_IS_PLAYER_ONE
            JMP WINNER_IS_PLAYER_TWO

            WINNER_IS_PLAYER_ONE:
                MOV WINNER_INDEX,01h
                JMP CONTINUE_GAME_OVER

            WINNER_IS_PLAYER_TWO:
                MOV WINNER_INDEX,02h
                JMP CONTINUE_GAME_OVER

            CONTINUE_GAME_OVER:
                MOV PLAYER_ONE_POINTS,00h
                MOV PLAYER_TWO_POINTS,00h
                CALL UPDATE_TEXT_PLAYER_ONE_POINTS
                CALL UPDATE_TEXT_PLAYER_TWO_POINTS
                MOV GAME_ACTIVE,00h                    ; Se para el juego.
                RET

        MOVE_BALL_VERTICALLY:
            MOV AX,BALL_VELOCITY_Y
            ADD BALL_Y,AX

        MOV AX,WINDOW_BOUNDS
        CMP BALL_Y,AX                            ; BALL_Y < 0 + WINDOW_BOUNDS (Y -> choca con el limite superior)
        JL NEG_VELOCITY_Y

        MOV AX,WINDOW_HEIGHT
        SUB AX,BALL_SIZE
        SUB AX,WINDOW_BOUNDS
        CMP BALL_Y,AX                            ; BALL_Y > WINDOW_HEIGH - BALL_SIZE -  (Y -> choca con el limite inferior)
        JG NEG_VELOCITY_Y          

;       Verificamos si la pelota esta colisionando con la paleta derecha. 
        ; BALL_X + BALL_SIZE > PADDLE_RIGHT_X && BALL_X < PADDLE_RIGHT_X + PADDLE_WIDTH 
        ; && BALL_Y + BALL_SIZE > PADDLE_RIGHT_Y && BALL_Y < PADDLE_RIGHT_Y + PADDLE_HEIGHT

        MOV AX,BALL_X
        ADD AX,BALL_SIZE
        CMP AX,PADDLE_RIGHT_X
        JNG CHECK_COLLISION_WITH_LEFT_PADDLE 
        
        MOV AX,PADDLE_RIGHT_X
        ADD AX,PADDLE_WIDTH
        CMP BALL_X,AX
        JNL CHECK_COLLISION_WITH_LEFT_PADDLE

        MOV AX,BALL_Y
        ADD AX,BALL_SIZE
        CMP AX,PADDLE_RIGHT_Y
        JNG CHECK_COLLISION_WITH_LEFT_PADDLE

        MOV AX,PADDLE_RIGHT_Y
        ADD AX,PADDLE_HEIGHT
        CMP BALL_Y,AX
        JNL CHECK_COLLISION_WITH_LEFT_PADDLE

        ; Si llega a este punto, la pelota colisiona con la paleta derecha.

        JMP NEG_VELOCITY_X

;       Verificamos si la pelota esta colisionando con la paleta izquierda.
        
        CHECK_COLLISION_WITH_LEFT_PADDLE:
        
        ; BALL_X + BALL_SIZE > PADDLE_RIGHT_X && BALL_X < PADDLE_RIGHT_X + PADDLE_WIDTH 
        ; && BALL_Y + BALL_SIZE > PADDLE_RIGHT_Y && BALL_Y < PADDLE_RIGHT_Y + PADDLE_HEIGHT

        MOV AX,BALL_X
        ADD AX,BALL_SIZE
        CMP AX,PADDLE_LEFT_X
        JNG EXIT_COLLISION_CHECK
    
        MOV AX,PADDLE_LEFT_X
        ADD AX,PADDLE_WIDTH
        CMP BALL_X,AX
        JNL EXIT_COLLISION_CHECK

        MOV AX,BALL_Y
        ADD AX,BALL_SIZE
        CMP AX,PADDLE_LEFT_Y
        JNG EXIT_COLLISION_CHECK

        MOV AX,PADDLE_LEFT_Y
        ADD AX,PADDLE_HEIGHT
        CMP BALL_Y,AX
        JNL EXIT_COLLISION_CHECK

;       Si llega a este punto, la pelota colisiona con la paleta izquierda. 

        JMP NEG_VELOCITY_X

        NEG_VELOCITY_Y:
            NEG BALL_VELOCITY_Y                  ; BALL_VELOCITY_Y = - BALL_VELOCITY_Y
            RET

        NEG_VELOCITY_X:
            NEG BALL_VELOCITY_X
            RET

        EXIT_COLLISION_CHECK:
            RET

    MOVE_BALL ENDP

    RESET_BALL_POSITION PROC NEAR

        MOV AX,BALL_ORIGINAL_X
        MOV BALL_X,AX

        MOV AX,BALL_ORIGINAL_Y
        MOV BALL_Y,AX

        RET
    RESET_BALL_POSITION ENDP

    DRAW_BALL PROC NEAR                          ; Procedimiento

        MOV CX,BALL_X                            ; Columna inicial (X)
        MOV DX,BALL_Y                            ; Linia inicial (Y)

        DRAW_BALL_HORIZONTAL:    
                                                ; Dibujamos el pixel.
            MOV AH,0Ch                          ; Establece la configuracion para escribir un pixel
            MOV AL,0Fh                          ; elijo blanco como color
            MOV BH,00h                          ; establecemos el numero de pagina
            INT 10h

            INC CX                              ; CX = CX + 1.
            MOV AX,CX                           ; CX - BALL_X > BALL_SIZE (Y-> Vamos a la siguiente linea, N-> Vamos a la siguiente columna)
            SUB AX,BALL_X
            CMP AX,BALL_SIZE
            JNG DRAW_BALL_HORIZONTAL            ; Si llega a este punto significa que la condicion anterior no es verdadera y pasamos el BALL_SIZE.
            
            MOV CX,BALL_X                       ; El registro CX vuelve a la columna inicial.
            INC DX                              ; Avanzamos una linea.
            
            MOV AX,DX                           ; DX - BALL_Y > BALL_SIZE (Y -> salimos de este procedimiento, N-> Continuamos a la proxima linea)
            SUB AX,BALL_Y
            CMP AX,BALL_SIZE
            JNG DRAW_BALL_HORIZONTAL
        RET
    DRAW_BALL ENDP

    MOVE_PADDLES PROC NEAR

        ;Movimiento de la left_paddle

        ;Verificar si se presiona alguna tecla (sino verificar la otra paleta) 

        MOV AH,01h
        INT 16h
        JZ CHECK_RIGHT_PADDLE_MOVEMENT          ; ZF = 1, JZ -> Saltamos si es cero. 

        ;Verificar que tecla se esta presionando. (AL = ASCII character)
        MOV AH,00h
        INT 16h

        ;Si es 'w' o 'W' nos movemos para arriba. 
        CMP AL,77h ; 'w'
        JE MOVE_LEFT_PADDLE_UP
        CMP AL,57h ; 'W'
        JE MOVE_LEFT_PADDLE_UP

        ;Si es 's' o 'S' nos movemos para abajo.
        CMP AL,73h ; 's'
        JE MOVE_LEFT_PADDLE_DOWN
        CMP AL,53h ; 'S'
        JE MOVE_LEFT_PADDLE_DOWN

        JMP CHECK_RIGHT_PADDLE_MOVEMENT

        MOVE_LEFT_PADDLE_UP:
            MOV AX,PADDLE_VELOCITY
            SUB PADDLE_LEFT_Y,AX

            MOV AX,WINDOW_BOUNDS
            CMP PADDLE_LEFT_Y,AX
            JL FIX_PADDLE_LEFT_TOP_POSITION
            JMP CHECK_RIGHT_PADDLE_MOVEMENT

            FIX_PADDLE_LEFT_TOP_POSITION:
                MOV PADDLE_LEFT_Y,AX
                JMP CHECK_RIGHT_PADDLE_MOVEMENT

        MOVE_LEFT_PADDLE_DOWN:
            MOV AX,PADDLE_VELOCITY
            ADD PADDLE_LEFT_Y,AX

            MOV AX,WINDOW_HEIGHT
            SUB AX,WINDOW_BOUNDS
            SUB AX,PADDLE_HEIGHT
            CMP PADDLE_LEFT_Y,AX
            JG FIX_PADDLE_LEFT_BOTTOM_POSITION
            JMP CHECK_RIGHT_PADDLE_MOVEMENT

            FIX_PADDLE_LEFT_BOTTOM_POSITION:
                MOV PADDLE_LEFT_Y,AX
                JMP CHECK_RIGHT_PADDLE_MOVEMENT

        ;Movimiento de la right_paddle

        CHECK_RIGHT_PADDLE_MOVEMENT:

            CMP AI_CONTROLLED,01h
            JE CONTROL_BY_AI

;           La paleta es controlada por el usuario.
            CHECK_FOR_KEYS:
                ;Si es 'o' o 'O' nos movemos para arriba. 
                CMP AL,6Fh ; 'o'
                JE MOVE_RIGHT_PADDLE_UP
                CMP AL,4Fh ; 'O'
                JE MOVE_RIGHT_PADDLE_UP

                ;Si es 'l' o 'L' nos movemos para abajo.
                CMP AL,6Ch ; 'l'
                JE MOVE_RIGHT_PADDLE_DOWN
                CMP AL,4Ch ; 'L'
                JE MOVE_RIGHT_PADDLE_DOWN

                JMP EXIT_PADDLE_MOVEMENT

;           La paleta es controlada por el AI.
            CONTROL_BY_AI:

                MOV AX,BALL_Y
                ADD AX,BALL_SIZE
                CMP AX,PADDLE_RIGHT_Y
                JL MOVE_RIGHT_PADDLE_UP

                MOV AX,PADDLE_RIGHT_Y
                ADD AX,PADDLE_HEIGHT
                CMP AX,BALL_Y
                JL MOVE_RIGHT_PADDLE_DOWN

                JMP EXIT_PADDLE_MOVEMENT
            
            MOVE_RIGHT_PADDLE_UP:
                MOV AX,PADDLE_VELOCITY
                SUB PADDLE_RIGHT_Y,AX

                MOV AX,WINDOW_BOUNDS
                CMP PADDLE_RIGHT_Y,AX
                JL FIX_PADDLE_RIGHT_TOP_POSITION
                JMP EXIT_PADDLE_MOVEMENT

                FIX_PADDLE_RIGHT_TOP_POSITION:
                    MOV PADDLE_RIGHT_Y,AX
                    JMP EXIT_PADDLE_MOVEMENT

            MOVE_RIGHT_PADDLE_DOWN:
                MOV AX,PADDLE_VELOCITY
                ADD PADDLE_RIGHT_Y,AX

                MOV AX,WINDOW_HEIGHT
                SUB AX,WINDOW_BOUNDS
                SUB AX,PADDLE_HEIGHT
                CMP PADDLE_RIGHT_Y,AX
                JG FIX_PADDLE_RIGHT_BOTTOM_POSITION
                JMP EXIT_PADDLE_MOVEMENT

                FIX_PADDLE_RIGHT_BOTTOM_POSITION:
                    MOV PADDLE_RIGHT_Y,AX
                    JMP EXIT_PADDLE_MOVEMENT

                EXIT_PADDLE_MOVEMENT:

                    RET

    MOVE_PADDLES ENDP
    
    DRAW_PADDLES PROC NEAR
        
        MOV CX,PADDLE_LEFT_X
        MOV DX,PADDLE_LEFT_Y

        DRAW_PADDLE_LEFT_HORIZONTAL:
            MOV AH,0Ch 
            MOV AL,0Fh 
            MOV BH,00h 
            INT 10h

            INC CX                              ; CX = CX + 1.
            MOV AX,CX                           ; CX - PADDLE_LEFT_X > PADDLE_WIDTH (Y-> Vamos a la siguiente linea, N-> Vamos a la siguiente columna)
            SUB AX,PADDLE_LEFT_X
            CMP AX,PADDLE_WIDTH
            JNG DRAW_PADDLE_LEFT_HORIZONTAL     ; Si llega a este punto significa que la condicion anterior no es verdadera y pasamos el PADDLE_WIDTH.

            MOV CX,PADDLE_LEFT_X                ; El registro CX vuelve a la columna inicial.
            INC DX                              ; Avanzamos una linea.
            
            MOV AX,DX                           ; DX - PADDLE_LEFT_Y > PADDLE_HEIGHT (Y -> salimos de este procedimiento, N-> Continuamos a la proxima linea)
            SUB AX,PADDLE_LEFT_Y
            CMP AX,PADDLE_HEIGHT
            JNG DRAW_PADDLE_LEFT_HORIZONTAL

        MOV CX,PADDLE_RIGHT_X
        MOV DX,PADDLE_RIGHT_Y

        DRAW_PADDLE_RIGHT_HORIZONTAL:
            MOV AH,0Ch 
            MOV AL,0Fh 
            MOV BH,00h 
            INT 10h

            INC CX                              ; CX = CX + 1.
            MOV AX,CX                           ; CX - PADDLE_RIGHT_X > PADDLE_WIDTH (Y-> Vamos a la siguiente linea, N-> Vamos a la siguiente columna)
            SUB AX,PADDLE_RIGHT_X
            CMP AX,PADDLE_WIDTH
            JNG DRAW_PADDLE_RIGHT_HORIZONTAL    ; Si llega a este punto significa que la condicion anterior no es verdadera y pasamos el PADDLE_WIDTH.

            MOV CX,PADDLE_RIGHT_X               ; El registro CX vuelve a la columna inicial.
            INC DX                              ; Avanzamos una linea.
            
            MOV AX,DX                           ; DX - PADDLE_RIGHT_Y > PADDLE_HEIGHT (Y -> salimos de este procedimiento, N-> Continuamos a la proxima linea)
            SUB AX,PADDLE_RIGHT_Y
            CMP AX,PADDLE_HEIGHT
            JNG DRAW_PADDLE_RIGHT_HORIZONTAL

        RET
    DRAW_PADDLES ENDP

    DRAW_UI PROC NEAR

;       Dibujar los puntos del jugador de la izquierda (Player 1)

        MOV AH,02h ; Establecer la posicion del cursor.
        MOV BH,00h ; Establecer el numero de pagina.
        MOV DH,04h ; Establecer fila. 
        MOV DL,06h ; Establecer columna. 
        INT 10h
        
        MOV AH,09h                      ; Escribir el string.
        LEA DX,TEXT_PLAYER_ONE_POINTS   ; Le da a DX Un puntero al string.
        INT 21h                         ; Imprime el string. 

;       Dibujar los puntos del jugador de la derecha (Player 2)

        MOV AH,02h ; Establecer la posicion del cursor.
        MOV BH,00h ; Establecer el numero de pagina.
        MOV DH,04h ; Establecer fila. 
        MOV DL,1Fh ; Establecer columna. 
        INT 10h
        
        MOV AH,09h                      ; Escribir el string.
        LEA DX,TEXT_PLAYER_TWO_POINTS   ; Le da a DX Un puntero al string.
        INT 21h                         ; Imprime el string. 

        RET
    DRAW_UI ENDP

    UPDATE_TEXT_PLAYER_ONE_POINTS PROC NEAR

        XOR AX,AX
        MOV AL,PLAYER_ONE_POINTS 
        
        ; Convertimos el numero decimal al codigo ascii del caracter. Esto lo hacemos sumandole 30h (numero a ASCII)

        ADD AL,30h
        MOV [TEXT_PLAYER_ONE_POINTS],AL

        RET
    UPDATE_TEXT_PLAYER_ONE_POINTS ENDP

        
    UPDATE_TEXT_PLAYER_TWO_POINTS PROC NEAR

        XOR AX,AX
        MOV AL,PLAYER_TWO_POINTS 
        
        ; Convertimos el numero decimal al codigo ascii del caracter. Esto lo hacemos sumandole 30h (numero a ASCII)

        ADD AL,30h
        MOV [TEXT_PLAYER_TWO_POINTS],AL

        RET
    UPDATE_TEXT_PLAYER_TWO_POINTS ENDP

    DRAW_GAME_OVER_MENU PROC NEAR

        CALL CLEAR_SCREEN

;       Muestra el titulo del menu

        MOV AH,02h ; Establecer la posicion del cursor.
        MOV BH,00h ; Establecer el numero de pagina.
        MOV DH,04h ; Establecer fila. 
        MOV DL,04h ; Establecer columna. 
        INT 10h
        
        MOV AH,09h                      ; Escribir el string.
        LEA DX,TEXT_GAME_OVER_TITLE     ; Le da a DX Un puntero al string.
        INT 21h                         ; Imprime el string. 

;       Muestra el ganador 

        MOV AH,02h ; Establecer la posicion del cursor.
        MOV BH,00h ; Establecer el numero de pagina.
        MOV DH,06h ; Establecer fila. 
        MOV DL,04h ; Establecer columna. 
        INT 10h
        
        CALL UPDATE_WINNER_TEXT

        MOV AH,09h                      ; Escribir el string.
        LEA DX,TEXT_GAME_OVER_WINNER    ; Le da a DX Un puntero al string.
        INT 21h                         ; Imprime el string.

        
;       Muestra el mensaje de jugar denuevo.  
        MOV AH,02h ; Establecer la posicion del cursor.
        MOV BH,00h ; Establecer el numero de pagina.
        MOV DH,08h ; Establecer fila. 
        MOV DL,04h ; Establecer columna. 
        INT 10h

        MOV AH,09h                          ; Escribir el string.
        LEA DX,TEXT_GAME_OVER_PLAY_AGAIN    ; Le da a DX Un puntero al string.
        INT 21h                             ; Imprime el string. 

;       Muestra el mensaje de jugar denuevo.  
        MOV AH,02h ; Establecer la posicion del cursor.
        MOV BH,00h ; Establecer el numero de pagina.
        MOV DH,0Ah ; Establecer fila. 
        MOV DL,04h ; Establecer columna. 
        INT 10h

        MOV AH,09h                          ; Escribir el string.
        LEA DX,TEXT_GAME_OVER_MAIN_MENU     ; Le da a DX Un puntero al string.
        INT 21h                             ; Imprime el string. 
    
;       Esperar por que se presione una tecla 
        MOV AH,00h
        INT 16h

        CMP AL,'R'
        JE RESTART_GAME
        CMP AL,'r'
        JE RESTART_GAME
        
;       Si la tecla es 'E' o 'e', salir del menu. 
        CMP AL,'E'
        JE EXIT_TO_MAIN_MENU
        CMP AL,'e'
        JE EXIT_TO_MAIN_MENU        
        RET

        RESTART_GAME:
            MOV GAME_ACTIVE,01h
            RET
        
        EXIT_TO_MAIN_MENU:
            MOV GAME_ACTIVE,00h
            MOV CURRENT_SCENE,00h
            RET

    DRAW_GAME_OVER_MENU ENDP

    DRAW_MAIN_MENU PROC NEAR

        CALL CLEAR_SCREEN

;       Nombre del juego.
        MOV AH,02h ; Establecer la posicion del cursor.
        MOV BH,00h ; Establecer el numero de pagina.
        MOV DH,04h ; Establecer fila. 
        MOV DL,04h ; Establecer columna. 
        INT 10h
        
        MOV AH,09h                      ; Escribir el string.
        LEA DX,TEXT_MAIN_GAME_NAME     ; Le da a DX Un puntero al string.
        INT 21h                         ; Imprime el string. 


;       Mostrar el titulo del menu.
        MOV AH,02h ; Establecer la posicion del cursor.
        MOV BH,00h ; Establecer el numero de pagina.
        MOV DH,06h ; Establecer fila. 
        MOV DL,04h ; Establecer columna. 
        INT 10h
        
        MOV AH,09h                      ; Escribir el string.
        LEA DX,TEXT_MAIN_MENU_TITLE     ; Le da a DX Un puntero al string.
        INT 21h                         ; Imprime el string. 

;       Mostrar la opcion de unico jugador. 
        MOV AH,02h ; Establecer la posicion del cursor.
        MOV BH,00h ; Establecer el numero de pagina.
        MOV DH,08h ; Establecer fila. 
        MOV DL,04h ; Establecer columna. 
        INT 10h
        
        MOV AH,09h                          ; Escribir el string.
        LEA DX,TEXT_MAIN_MENU_SIGLEPLAYER   ; Le da a DX Un puntero al string.
        INT 21h                             ; Imprime el string. 

;       Mostrar la opcion de multiples jugadores.
        MOV AH,02h ; Establecer la posicion del cursor.
        MOV BH,00h ; Establecer el numero de pagina.
        MOV DH,0Ah ; Establecer fila. 
        MOV DL,04h ; Establecer columna. 
        INT 10h
        
        MOV AH,09h                          ; Escribir el string.
        LEA DX,TEXT_MAIN_MENU_MULTIPLAYER   ; Le da a DX Un puntero al string.
        INT 21h                             ; Imprime el string. 

;       Mostrar el mensaje para salir. 
        MOV AH,02h ; Establecer la posicion del cursor.
        MOV BH,00h ; Establecer el numero de pagina.
        MOV DH,0Ch ; Establecer fila. 
        MOV DL,04h ; Establecer columna. 
        INT 10h
        
        MOV AH,09h                      ; Escribir el string.
        LEA DX,TEXT_MAIN_MENU_EXIT      ; Le da a DX Un puntero al string.
        INT 21h                         ; Imprime el string. 

        MAIN_MENU_WAIT_FOR_KEY:

;           Esperamos a que una tecla sea presionada. 
            MOV AH,00h
            INT 16h

;           Verificamos que tecla fue presionada. 
            CMP AL,'S'
            JE START_SIGLEPLAYER
            CMP AL,'s'
            JE START_SIGLEPLAYER

            CMP AL,'M'
            JE START_MULTIPLAYER
            CMP AL,'m'
            JE START_MULTIPLAYER

            CMP AL,'E'
            JE EXIT_GAME
            CMP AL,'e'
            JE EXIT_GAME
            JMP MAIN_MENU_WAIT_FOR_KEY

        START_SIGLEPLAYER:
            MOV CURRENT_SCENE,01h
            MOV GAME_ACTIVE,01h
            MOV AI_CONTROLLED,01h
            RET
        
        START_MULTIPLAYER:
            MOV CURRENT_SCENE,01h
            MOV GAME_ACTIVE,01h
            MOV AI_CONTROLLED,00h
            RET

        EXIT_GAME:
            MOV EXITING_GAME,01h
            RET

    DRAW_MAIN_MENU ENDP

    UPDATE_WINNER_TEXT PROC NEAR

        MOV AL,WINNER_INDEX
        ADD AL,30h
        MOV [TEXT_GAME_OVER_WINNER+7],AL

        RET
    UPDATE_WINNER_TEXT ENDP

    CLEAR_SCREEN PROC NEAR                      ; Limpia la pantalla reiniciando el modo de video.    
            
        MOV AH,00h                              ; Configurar el modo de video
        MOV AL,13h                              ; Elegir el modo de video 
        INT 10h                                 ; Ejecutar la configuracion

        MOV AH,0Bh                              ; Establecer la configuracion
        MOV BH,00h                              ; al color de fondo
        MOV BL,00h                              ; elijo magenta como color de fondo
        INT 10h

        RET
    CLEAR_SCREEN ENDP

    CONCLUDE_EXIT_GAME PROC NEAR                ; Vuelve al modo texto 
            
        MOV AH,00h                              ; Configurar el modo de video
        MOV AL,02h                              ; Elegir el modo de video 
        INT 10h                                 ; Ejecutar la configuracion

        MOV AH,4Ch
        INT 21h

    CONCLUDE_EXIT_GAME ENDP

CODE ENDS
END