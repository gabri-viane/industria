Industria.controllers = {
    ids = {},         -- {nome_owner={codice1, codice2, codice3}}
    units = {},       --{codice1={...},codice2={...}}
    interpreters = {} --{codice1={...}}
};

local function sugarResult(completed, message, data)
    return { completed = completed, msg = message, data = data };
end

function Industria.controllers:addUnit(unit_id, owner)
    local unit_code = unit_id .. "_" .. owner;
    if self.units[unit_code] ~= nil then
        return sugarResult(false, "Unit already exists");
    end

    if self.ids[owner] == nil then
        self.ids[owner] = {};
    end

    table.insert(self.ids[owner], unit_code);

    local unit = {
        unitd_id = unit_id,
        owner = owner,                          --owner of the unit
        reference_program = unit_code .. ".st", --refrenced code file
        last_env = {},                          --last env used
    };
    self.units[unit_code] = unit;
    self.interpreters[unit_code] = {}; --interpreted code

    return sugarResult(true, "Unit created with code " .. unit_code, unit);
end

function Industria.controllers:getUnit(unit_id, owner)
    local unit_code = unit_id .. "_" .. owner;
    if self.units[unit_code] == nil then
        return sugarResult(false, "Unit doesn't exists");
    end

    if self.ids[owner] == nil then
        self.ids[owner] = {};
    end

    return sugarResult(true, nil, self.units[unit_code]);
end

function Industria.controllers:setUnitInterpreter(unit, interpreter)
    if unit.unit_id == nil or unit.owner == nil then
        return sugarResult(false, "Not a unit");
    end

    local unit_code = unit.unit_id .. "_" .. unit.owner;
    if self.units[unit_code] == nil then
        return sugarResult(false, "Unit doesn't exists");
    end

    self.interpreters[unit_code] = interpreter or {};

    return sugarResult(true, nil, self.units[unit_code]);
end

function Industria.controllers:serialize()
    local data = { ids = self.ids, units = self.units };
    local text = core.serialize(data);
    --Scrivi il file con i dati dei controllori
    local f, err = io.open(Industria.datapath .. "/controllers.dt", "w+");
    if err or f == nil then
        return false;
    end
    f:write(text);
    f:flush();
    f:close();
    return true;
end

function Industria.controllers:deserialize()
    --Carica il file con i dati dei controllori
    local f, err = io.open(Industria.datapath .. "/controllers.dt", "r");
    if err or f == nil then
        return false;
    end

    local text = f:read("a");
    f:close();
    local data = core.deserialize(text,true);
    if data == nil then
        core.dump(data);
        return false;
    end
    self.ids = data.ids;
    self.units = data.units;
    return true;
end
