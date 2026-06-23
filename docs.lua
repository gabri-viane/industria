---@meta
---@alias Result<T> {completed:boolean, msg:string, data:T}


---@alias unit_id string Codice dell'unità
---@alias owner string Nome del giocatore/proprietario
---@alias unit_code string è formarto da unitid.."_"..owner
---@alias io_unit_code string è formato da "io_"..unitid.."_"..owner
---@alias reference_program string Nome del file in cui è contenuto il codice ST

---@alias varname string Nome della variabile dichiarata nell'ambiente
---@alias IOType "IN"|"OUT"

---@alias VarEnv {value: any, dtype: any} Variabile d'ambiente: valore e tipo (usata in interprete)
---@alias Environment table<varname,VarEnv> Tabella di variabili-valori
---@alias IOPort {linked_var: varname, pos_block: any, type: IOType}

---@alias Unit {unit_id : unit_id, owner : owner, reference_program : reference_program, last_env : Environment, enabled : boolean, protected : boolean, io_units:io_unit_code[]|nil} Unità/Controllore
---@alias IOUnit {iounit_code : io_unit_code, owner : owner, reference_unit : unit_code, io_ports: IOPort[]} Unità/Controllore

---@alias RTInfo {enabled:boolean,interp: Interpreter|nil,errors:string[]}
