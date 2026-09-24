---@meta
---@alias Result<T> {completed:boolean, msg:string, data:T}

---@alias Position any Posizione

---@alias ControllerID string Codice dell'unità
---@alias owner string Nome del giocatore/proprietario
---@alias ControllerCODE string è formarto da unitid.."_"..owner

---@alias IOUnitCODE string è formato da "io_"..unitid.."_"..owner
---@alias IOUnitName string Nome dell'unità di IO (pulsante, leva, lampada, ...)

---@alias reference_program string Nome del file in cui è contenuto il codice ST

---@alias varname string Nome della variabile dichiarata nell'ambiente
---@alias IOPropertyName string Nome della proprietà di Input/Output della IOUnit
---@alias IOType 0|1|2 0:Input 1:Output 2:Input/Output
---@alias DType "INT" | "REAL" | "BOOL" | "STRING" Available data types for the ST programs

---@alias VarEnv {value: any, dtype: any} Variabile d'ambiente: valore e tipo (usata in interprete)
---@alias Environment table<varname,VarEnv> Tabella di variabili-valori
---@alias IOLinks table<varname,IOUnitCODE | nil> Tabella di nome variabili-unità io collegata
---@alias IOPort {linked_var: varname | nil, iotype: IOType} Tabella che rappresenta la variabile collegata (se nil allora non è collegata) e la direzione del collegamento
---@alias IOProperty {value: any, iotype: IOType, dtype: DType} Valore dello stato del Nodo, tipo di stato (input, output, i/o), tipo di variabile (BOOL, REAL, INT, ...)
---@alias IOPropertyList table<IOPropertyName, IOProperty> Tabella nome stato - attributi stato

---@alias Controller {controller_id : ControllerID, pos: Position, owner : owner, reference_program : reference_program, last_env : Environment, enabled : boolean, protected : boolean, linked_iounits:IOLinks} Unità/Controllore
---@alias IOUnit {iounit_name: IOUnitName, iounit_code : IOUnitCODE, owner : owner, reference_controller : ControllerCODE | nil, pos_block: any, io_ports: table<IOPropertyName,IOPort>, linked_properties: table<varname,IOPropertyName>} Unità/Controllore

---@alias RTInfo {enabled:boolean,interp: Interpreter|nil,errors:string[]}
