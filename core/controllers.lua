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
        local th = coroutine.create(function()
            local res = Industria.runtime:registerToRuntime(unit);
            if not res.completed then
                core.log("warning", "Registration to runtime of: '" .. unit_code .. "' was not completed:\n" .. res.msg);
            end
        end)
        coroutine.resume(th);
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
        protected = false,                      -- solo l'owner del PLC può aprirlo
        io_units = {}                           -- array di id delle unità di IO
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

--#region
-- TODO: codice per rimuovere "DELETE" l'unità, ovvero rimuovere file e unità senza che il blocco sia rimosso:
-- è necessario anche togliere le tag meta dal nodo
--#endregion


---Removes completly a unit: removse also files and saves.
---@param unit_id string unit id to be removed
---@param owner string owner of the unit
---@return Result<nil>
function Industria.controllers:removeController(unit_id, owner)
    --Costruisce la stringa di come è salvata l'unità
    local unit_code = Industria.units.toUnitCode(unit_id, owner);
    --Se è nullo allora non provare nemmeno a cercarla
    if not unit_code then
        return fnresult(false, "Owner or UnitID is null");
    end
    --Se non esiste allora esci
    if self.units[unit_code] == nil then
        return fnresult(false, "Unit doesn't exists");
    end

    local unit = self.units[unit_code];

    --Rimuovi dagli id delle unità del giocatore quella corrente
    local idx = table.indexof(self.ids[owner], unit_code);
    if idx == -1 then
        return fnresult(false, "Owner doesn't have permissions on this unit");
    end

    --Elimino tutte le unità di IO che sono state collegate a questo PLC
    for _, iounit_code in ipairs(unit.io_units) do
        local idx_ = table.indexof(unit.io_units, iounit_code);
        if idx_ == -1 then
            return fnresult(false, "Unit dosen't contain the IOUnit specified");
        end
        --Devo eliminare anche l'unità IO allora chiamo la funzione che lo gestisce
        Industria.iounits:removeIOUnit(iounit_code, unit.owner);
    end

    table.remove(self.ids[owner], idx);
    --Elimina il file del codice
    Industria.files.deleteUnitCode(unit);
    --Elimina il file dell'environment
    Industria.files.deleteUnitEnvironment(unit);
    --Rimuove la unit
    self.units[unit_code] = nil;
    --Rimuove l'interprete/unità dal RT
    Industria.runtime:removeUnit(unit);

    return fnresult(true, "Unit removed");
end

---Removes a previously associated IOUnit to an Unit. This function should be called when an IOUnit is removed or
---rebound to a different Unit.
---@param unit_code unit_code The Unit code of the Unit from which the IOUnit has to be removed
---@param io_unit_code io_unit_code The IOUnit code to remove from the Unit
---@param deleteUnit boolean This parameters is used to call the function Industria.iounits.removeIOUnit to prevent cicrular calls.
---@return Result<nil|Unit>
function Industria.controllers:removeIOUnitFromController(unit_code, io_unit_code, deleteUnit)
    --Se il codice è nullo allora faccio finta di averla rimossa
    if io_unit_code == nil then
        return fnresult(true, "No IOUnit was removed");
    end

    local res_unit = self:getUnit(unit_code);
    if not res_unit.completed then
        return res_unit;
    end
    --Unità da cui rimuovere il codice
    local unit = res_unit.data;
    if unit == nil or unit.io_units == nil then
        return fnresult(false, "Unit dosen't contain the IOUnit specified");
    end

    local idx = table.indexof(unit.io_units, io_unit_code);
    if idx == -1 then
        return fnresult(false, "Unit dosen't contain the IOUnit specified");
    end

    --Se devo eliminare anche l'unità IO allora chiamo la funzione che lo gestisce
    if deleteUnit then
        Industria.iounits:removeIOUnit(io_unit_code, unit.owner);
    end

    table.remove(unit.io_units, idx);

    return fnresult(true, nil, unit);
end
