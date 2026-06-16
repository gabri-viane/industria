local fnresult = Industria.commons.fnresult;

--- Binds am Interpreter to a Unit.
---@return Result #It's completed if the the serialization succedees
function Industria.controllers:serialize()
    local data = {
        ids = self.ids,
        units = self.units
    };
    local text = core.serialize(data);
    -- Scrivi il file con i dati dei controllori
    local f, err = io.open(Industria.datapath .. "/controllers.dt", "w+");
    if err or f == nil then
        return fnresult(false, err, nil);
    end
    f:write(text);
    f:flush();
    f:close();
    return fnresult(true, "World Controllers saved", nil);
end

---Deserialize the file "controllers.dt" in the mod's folder of the world and loads the ids and units saved.
---@return Result #It's completed if the the deserialization succedees and the field "data" is set to point to Industria.controllers
function Industria.controllers:deserialize()
    -- Carica il file con i dati dei controllori
    local f, err = io.open(Industria.datapath .. "/controllers.dt", "r");
    if err or f == nil then
        return fnresult(false, err, nil);
    end

    local text = f:read("a");
    f:close();
    local data = core.deserialize(text, true);
    if data == nil then
        core.dump(data);
        return fnresult(false, "Data not loaded", nil);
    end
    self.ids = data.ids;
    self.units = data.units;
    return fnresult(true, nil, self);
end

--- Creates and binds a new unit to a player if the player doesn't already have a unit with the same id associated
---@param unit_id string The unit id, must be unique
---@param owner string The player name
---@return Result<Unit|nil> #In the filed "data" the value is the newly created Unit
function Industria.controllers:addUnit(unit_id, owner)
    -- Crea il codice del plc: idunità_nomeproprietario
    local unit_code = unit_id .. "_" .. owner;
    -- Se esiste già un'unità allora ritorna un'errore
    if self.units[unit_code] ~= nil then
        return fnresult(false, "Unit already exists");
    end
    --Se non esiste la tabella di id associata al giocatore allora generale
    if self.ids[owner] == nil then
        self.ids[owner] = {};
    end

    --Inserisci nella tabella il nuovo ID: in questo modo è incrementale
    table.insert(self.ids[owner], unit_code);

    --Creazione dell'unità: contiene questi dati oltre che l'ultimo environment generato dall'esecuzione dell'interprete
    local unit = {
        unitd_id = unit_id,
        owner = owner,                          -- owner of the unit
        reference_program = unit_code .. ".st", -- refrenced code file
        last_env = {}                           -- last env used
    };
    --Aggiungi l'unità
    self.units[unit_code] = unit;
    --L'interprete deve essere inizializzato ad ogni avvio del gioco/mondo
    self.interpreters[unit_code] = {}; -- interpreted code

    return fnresult(true, "Unit created with code " .. unit_code, unit);
end

--- Returns a Unit, if present, binded to a player, knowing the unit's ID.
---@param unit_id string The unit id, must be unique
---@param owner string The player name
---@return Result<Unit|nil> #If the function is completed then the field "data" contains the Unit
function Industria.controllers:getUnit(unit_id, owner)
    --Se sono nulli allora non provare nemmeno a cercarla
    if not unit_id or not owner then
        return fnresult(false, "Owner or UnitID is null");
    end
    --Costruisce la stringa di come è salvata l'unità
    local unit_code = unit_id .. "_" .. owner;
    --Se non esiste allora esci
    if self.units[unit_code] == nil then
        return fnresult(false, "Unit doesn't exists");
    end

    return fnresult(true, nil, self.units[unit_code]);
end

--- Binds an Interpreter to a Unit.
---@param unit Unit The unit id, must be unique
---@param interpreter Interpreter The interpreter to bind to the unit
---@return Result<nil> #It's completed if the interpreted has been binded to the unit_code
function Industria.controllers:setUnitInterpreter(unit, interpreter)
    if unit.unit_id == nil or unit.owner == nil then
        return fnresult(false, "Not a unit");
    end

    local unit_code = unit.unit_id .. "_" .. unit.owner;
    if self.units[unit_code] == nil then
        return fnresult(false, "Unit doesn't exists");
    end

    self.interpreters[unit_code] = interpreter or {};

    return fnresult(true, nil, nil);
end

--- Initialize the Control Unit parsing the ST file associated (reference_program) and
--- building the interpreter for future usage. The interpreter is stored in
--- Industria.ST.interpreters and associated with the Control Unit by the ID.
---
---@param unit Unit {unitd_id, owner, reference_program, last_env}
---@param load_init boolean if true tries to load the environment from the save file ".st.env"
---@return Result #true/false based on success or error
function Industria.controllers:initUnitEnvironment(unit, load_init)
    --Check for fields
    if unit == nil or unit.reference_program == nil or unit.last_env == nil then
        return fnresult(false, "Code not loaded", nil);
    end

    --Load the ST code from the file using the reference_program parameter
    local programcode = Industria.ST.loadCode(Industria.datapath .. "/" .. unit.reference_program);
    if not programcode.completed then
        return fnresult(false, "Code not loaded:\n" .. programcode.msg, nil); --Code not loaded
    end
    --Genera l'interprete
    local interpreter = Industria.ST.interpCode(programcode.data);
    if interpreter == nil then
        return fnresult(false, "Interpreter not generated", nil); --L'interprete non è stato generato
    end

    --Imposta l'interprete associandolo alla Control Unit
    self:setUnitInterpreter(unit, interpreter);
    interpreter:init(); --Inizializza l'interprete

    if load_init then   --Se devo caricare le variabili dal salvataggio
        local f, err = io.open(Industria.datapath .. "/" .. unit.reference_program .. ".env", "r");
        if err or f == nil then
            return fnresult(false, err, nil);
        end
        --Deserializza le variabili
        unit.last_env = core.deserialize(f:read("a"), true);
        f:close();
        --Imposta l'environment caricato
        interpreter:setEnv(unit.last_env);
    end
    return fnresult(true, nil, interpreter);
end

---Removes completly a unit: removse also files and saves.
---@param unit_id string unit id to be removed
---@param owner string owner of the unit 
---@return Result<nil>
function Industria.controllers:removeController(unit_id, owner)
    --Se sono nulli allora non provare nemmeno a cercarla
    if not unit_id or not owner then
        return fnresult(false, "Owner or UnitID is null");
    end
    --Costruisce la stringa di come è salvata l'unità
    local unit_code = unit_id .. "_" .. owner;
    --Se non esiste allora esci
    if self.units[unit_code] == nil then
        return fnresult(false, "Unit doesn't exists");
    end

    local unit = self.units[unit_code];

    --Elimina il file del codice
    Industria.files.deleteUnitCode(unit);
    --Elimina il file dell'environment
    Industria.files.deleteUnitEnvironment(unit);

    --Rimuovi dagli id delle unità del giocatore quella corrente
    local indx = Industria.commons.indexof(self.ids[owner], unit_code);
    table.remove(self.ids[owner], indx);

    --Rimuove l'interprete
    self.interpreters[unit_code] = nil;
    --Rimuove la unit
    self.units[unit_code] = nil;

    return fnresult(true, "Unit removed");
end
