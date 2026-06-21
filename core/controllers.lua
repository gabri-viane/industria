local fnresult = Industria.commons.fnresult;

--- Serialize the content of Industria.controllers (only ids and units) to the file "controllers.dt" in the world's folder.
---@return Result<nil> #It's completed if the the serialization succedees
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
---@return Result<table|nil> #It's completed if the the deserialization succedees and the field "data" is set to point to Industria.controllers
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
        return fnresult(false, "Data not loaded", nil);
    end
    if data.ids == nil or data.units == nil then
        return fnresult(false, "Data doesn't contain the required fields", nil);
    end
    self.ids = data.ids;
    self.units = data.units;

    --Carica le unità in runtime
    for unit_code, unit in pairs(self.units) do
        local res = Industria.runtime:registerToRuntime(unit);
        --[[if res.completed then
            core.chat_send_all("Loaded unit: \'"..unit_code.."\'");
        else
            core.chat_send_all("Failed to load unit: \'"..unit_code.."\'");
        end]] --
    end

    return fnresult(true, nil, self);
end

--- Creates and binds a new unit to a player if the player doesn't already have a unit with the same id associated
---@param unit_id string The unit id, must be unique
---@param owner string The player name
---@return Result<Unit|nil> #In the filed "data" the value is the newly created Unit
function Industria.controllers:addUnit(unit_id, owner)
    -- Crea il codice del plc: idunità_nomeproprietario
    local unit_code = Industria.units.toUnitCode(unit_id, owner);
    -- Controllo se non ho generato il codice
    if unit_code == nil then
        return fnresult(false, "UnitCode not valid");
    end
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
    ---@type Unit
    local unit = {
        unit_id = unit_id,
        owner = owner,                          -- owner of the unit
        reference_program = unit_code .. ".st", -- refrenced code file
        last_env = {},                          -- last env used
        enabled = false,
        protected = false                       --solo l'owner del PLC può aprirlo
    };
    --Aggiungi l'unità
    self.units[unit_code] = unit;

    return fnresult(true, "Unit created with code " .. unit_code, unit);
end

--- Returns a Unit, if present, binded to a player, knowing the unit's Code (ID+Owner name).
---@param unit_code unit_code|nil The unit id, must be unique
---@return Result<Unit|nil> #If the function is completed then the field "data" contains the Unit
function Industria.controllers:getUnit(unit_code)
    --Se sono nulli allora non provare nemmeno a cercarla
    if not unit_code then
        return fnresult(false, "Owner or UnitID is null");
    end
    --Se non esiste allora esci
    if self.units[unit_code] == nil then
        return fnresult(false, "Unit doesn't exists: '" .. unit_code .. "'");
    end

    return fnresult(true, nil, self.units[unit_code]);
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

    --Rimuove la unit
    self.units[unit_code] = nil;

    --Rimuove l'interprete/unità dal RT
    Industria.runtime:removeUnit(unit);

    return fnresult(true, "Unit removed");
end
