(* ============================================================
   Esempio avanzato: simulazione controllo motore + utilities
   ============================================================ *)

PROGRAM ProvaEsempio

VAR
    (* Stato motore *)
    test      : INT   := 0;
    testR      : REAL   := 0;
    Sensor :  BOOL := 0;
END_VAR

test := test +1;
testR := testR +0.1;

IF (test-(2*(test/2))) > 0 THEN
    PRINT('DISPARI');
ELSE
    PRINT('PARI');
END_IF

IF Sensor THEN
    PRINT('Acceso');
END_IF

//PRINT('TestR: ');
//PRINT(testR);

END_PROGRAM
