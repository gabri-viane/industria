---@meta
---@alias Result<T> {completed:boolean, msg:string, data:T}


---@alias unit_id string Codice dell'unità
---@alias owner string Nome del giocatore/proprietario
---@alias unit_code string è formarto da unitid.."_"..owner
---@alias reference_program string Nome del file in cui è contenuto il codice ST

---@alias VarEnv {value: any, dtype: any} Variabile d'ambiente: valore e tipo (usata in interprete)
---@alias Environment table<string,VarEnv> Tabella di variabili-valori

---@alias Unit {unit_id : unit_id, owner : owner, reference_program : reference_program, last_env : Environment} Unità/Controllore


