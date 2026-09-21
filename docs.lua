---@meta
---@alias Result<T> {completed:boolean, msg:string, data:T}


---@alias unit_id string Codice dell'unità
---@alias owner string Nome del giocatore/proprietario
---@alias unit_code string è formarto da unitid.."_"..owner
---@alias io_unit_code string è formato da "io_"..unitid.."_"..owner
---@alias iounitname string Nome dell'unità di IO (pulsante, leva, lampada, ...)
---@alias reference_program string Nome del file in cui è contenuto il codice ST

---@alias varname string Nome della variabile dichiarata nell'ambiente
---@alias IOname string Nome della proprietà di Input/Output della IOUnit
---@alias IOType 0|1|2 0:Input 1:Output 2:Input/Output
---@alias DType "INT" | "REAL" | "BOOL" | "STRING" Available data types for the ST programs 

---@alias VarEnv {value: any, dtype: any} Variabile d'ambiente: valore e tipo (usata in interprete)
---@alias Environment table<varname,VarEnv> Tabella di variabili-valori
---@alias IOLinks table<varname,io_unit_code | nil> Tabella di nome variabili-unità io collegata
---@alias IOPort {linked_var: varname | nil, type: IOType} Tabella che rappresenta la variabile collegata (se nil allora non è collegata) e la direzione del collegamento
---@alias IOState {value: any, iotype: IOType, dtype: DType} Valore dello stato del Nodo, tipo di stato (input, output, i/o), tipo di variabile (BOOL, REAL, INT, ...)
---@alias IOUnitStats table<IOname, IOState> Tabella nome stato - attributi stato

---@alias Unit {unit_id : unit_id, owner : owner, reference_program : reference_program, last_env : Environment, enabled : boolean, protected : boolean, io_units:IOLinks} Unità/Controllore
---@alias IOUnit {iounitname: iounitname, iounit_code : io_unit_code, owner : owner, reference_unit : unit_code | nil, pos_block: any, io_ports: table<IOname,IOPort>, linked_states: table<varname,IOname>} Unità/Controllore

---@alias RTInfo {enabled:boolean,interp: Interpreter|nil,errors:string[]}
