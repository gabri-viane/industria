local fnresult = Industria.commons.fnresult;

--- Serialize the content of Industria.iounits (only ids and iounits) to the file "iounits.dt" in the world's folder.
---@return Result<nil> #It's completed if the the serialization succedees
function Industria.iounits:serialize()
    local data = {
        ids = self.ids,
        registered = self.registered
    };
    local text = core.serialize(data);
    -- Scrivi il file con i dati dei controllori
    local f, err = io.open(Industria.datapath .. "/iounits.dt", "w+");
    if err or f == nil then
        return fnresult(false, err, nil);
    end
    f:write(text);
    f:flush();
    f:close();
    return fnresult(true, "World IOUnits saved", nil);
end

---Deserialize the file "iounits.dt" in the mod's folder of the world and loads the ids and iounits saved.
---@return Result<table|nil> #It's completed if the the deserialization succedees and the field "data" is set to point to Industria.iounits
function Industria.iounits:deserialize()
    -- Carica il file con i dati dei controllori
    local f, err = io.open(Industria.datapath .. "/iounits.dt", "r");
    if err or f == nil then
        return fnresult(false, err, nil);
    end

    local text = f:read("a");
    f:close();
    local data = core.deserialize(text, true);
    if data == nil then
        return fnresult(false, "Data not loaded", nil);
    end
    if data.ids == nil or data.registered == nil then
        return fnresult(false, "Data doesn't contain the required fields", nil);
    end
    self.ids = data.ids;
    self.registered = data.registered;

    return fnresult(true, nil, self);
end

---Register an IO Unit: registered units can be checkd during runtime to get or set their values/properites
---@param unit Unit The Unit that the IOUnit will be linked to
---@param owner owner Owner of the IO Unit
---@param pos any|nil Position of the node that is going to be registered as an IO Unit
---@return Result<IOUnit|nil> #Returns the newly created IOUnit
function Industria.iounits:addIOUnit(unit, owner, pos)
    if owner == nil or unit == nil then
        return fnresult(false, "Unit or Owner are invalid", nil);
    end
    local unit_code = Industria.units.getUnitCode(unit);
    if not unit_code then
        return fnresult(false, "Unit is invalid", nil);
    end
    --Genera l'ID da usare per l'unità di IO
    local iounit_code = Industria.commons.rndstr(20);
    local gen_limiter = 0;
    --Controlla che l'ID non sia presente
    while self.registered[iounit_code] and gen_limiter < 3 do
        iounit_code = Industria.commons.rndstr(20);
        gen_limiter = gen_limiter + 1;
    end
    if gen_limiter == 3 then
        return fnresult(false, "Couldn't generate unique ID for the IOUnit", nil);
    end

    --Se non esiste la tabella di id associata al giocatore allora generale
    if self.ids[owner] == nil then
        self.ids[owner] = {};
    end
    --Inserisci nella tabella il nuovo ID: in questo modo è incrementale
    table.insert(self.ids[owner], iounit_code);

    ---@type IOUnit
    local iounit = {
        iounit_code = iounit_code,
        owner = owner,
        reference_unit = unit_code,
        io_ports = {},
        position = pos
    };

    --Se non esiste la tabella allora creala
    if unit.io_units == nil then
        unit.io_units = {};
    end
    --Registra l'unità al PLC
    table.insert(unit.io_units, iounit_code);

    self.registered[iounit_code] = iounit;

    return fnresult(true, nil, iounit);
end

--- Returns an IOUnit, if present, binded to a player, knowing the iounit's Code.
---@param iounit_code io_unit_code|nil The iounit code, must be unique
---@return Result<IOUnit|nil> #If the function is completed then the field "data" contains the IOUnit
function Industria.iounits:getIOUnit(iounit_code)
    --Se sono nulli allora non provare nemmeno a cercarla
    if not iounit_code then
        return fnresult(false, "IOUnitCode is nil");
    end
    --Se non esiste allora esci
    if self.registered[iounit_code] == nil then
        return fnresult(false, "Unit doesn't exists: '" .. iounit_code .. "'");
    end

    return fnresult(true, nil, self.registered[iounit_code]);
end

---Removes completly an IO Unit. This will invalid remove the references to the previously binded variables.
---@param iounit_code io_unit_code IO Unit to be removed
---@param owner owner owner of the IO Unit
---@return Result<nil>
function Industria.iounits:removeIOUnit(iounit_code, owner)
    --Se sono nulli allora non provare nemmeno a cercarla
    if not iounit_code or not owner then
        return fnresult(false, "Owner or IOUnitCode are null");
    end
    --Se non esiste allora esci
    if self.registered[iounit_code] == nil then
        return fnresult(false, "IOUnit doesn't exists");
    end
    if self.ids[owner] == nil then
        return fnresult(false, "The owner is not valid");
    end
    --Cerca se il giocatore "owner" la possiede
    local idx = table.indexof(self.ids[owner], iounit_code);
    if idx == -1 then
        return fnresult(false, "The player doesn't own the IOUnit");
    end

    local iounit = self.registered[iounit_code];

    if iounit.reference_unit then
        --Per prevenire che la funzioni richiami a sua volta questa funzione per eliminare il
       Industria.controllers:removeIOUnitFromController(iounit.reference_unit, iounit_code,false);
    end

    --Elimina l'unità IO
    self.registered[iounit_code] = nil;

    return fnresult(true, "IOUnit removed");
end
