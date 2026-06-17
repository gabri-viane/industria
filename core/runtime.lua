---Function that can be called from within ST programs with the PRINT('text') function
---@param text string The text to print to the chat
Industria.runtime.print = function(text)
    core.chat_send_all(text);
end

local fnresult = Industria.commons.fnresult;

---Register an error (usually interpreter ones) to the Unit
---@param unit_code string The unit code to which add the error
---@param message string the error message
---@return Result<nil>
function Industria.runtime:registerError(unit_code, message)
    --Controllo se posso abilitare l'unità
    if unit_code == nil then
        return fnresult(false, "Can't register error to unit: the code is invalid.");
    end
    --Non ho ancora l'unità a runtime: non posso abilitarla sicuramente poiché non ho l'interprete
    if self.units[unit_code] == nil then
        return fnresult(true, "Unit wasn't registered to the runtime environment.");
    end
    --Se non ho ancora la lista errori allora la creo
    if self.units[unit_code].errors == nil then
        self.units[unit_code].errors = {};
    end
    --Rimuovo dal runtime
    table.insert(self.units[unit_code].errors, message);
    return fnresult(true, nil, nil);
end

---Returns the list of errors (usually interpreter ones) of the Unit
---@param unit_code string The unit code to which add the error
---@return Result<string[]>
function Industria.runtime:getErrors(unit_code)
    --Controllo se posso abilitare l'unità
    if unit_code == nil then
        return fnresult(false, "Can't register error to unit: the code is invalid.");
    end
    --Non ho ancora l'unità a runtime: non posso abilitarla sicuramente poiché non ho l'interprete
    if self.units[unit_code] == nil then
        return fnresult(false, "Unit wasn't registered to the runtime environment.");
    end
    --Se non ho ancora la lista errori allora la creo
    if self.units[unit_code].errors == nil then
        self.units[unit_code].errors = {};
    end
    return fnresult(true, nil, self.units[unit_code].errors);
end

---Removes an Unit from the runtime
---@param unit Unit The unit to be removed
---@return Result<nil>
function Industria.runtime:removeUnit(unit)
    --Controllo se posso abilitare l'unità
    if unit == nil or unit.unit_id == nil or unit.owner == nil then
        return fnresult(false, "Can't remove unit: it's invalid.");
    end
    local unit_code = unit.unit_id .. "_" .. unit.owner;
    --Non ho ancora l'unità a runtime: non posso abilitarla sicuramente poiché non ho l'interprete
    if self.units[unit_code] == nil then
        return fnresult(true, "Unit wasn't registered to the runtime environment.");
    end
    --Rimuovo dal runtime
    self.units[unit_code] = nil;
    return fnresult(true, "Unit removed from runtime environment.");
end

---Enables a unit: the unit will be called by the runtime-handler to perform operations.
---If no Interpreter is found than it tries to create a new one: because this function
---enables the unit it is assumed that a new environment for the execution is needed
---(it doesn't load it from .env file).
---WARNING: only if the unit is present in the runtime the parameter "enabled" in the Unit will be set to true.
---@param unit Unit
---@return Result<nil> #If the unit has been enabled then "completed" will be set to "true", "false" otherwise.
function Industria.runtime:enableUnit(unit)
    --Controllo se posso abilitare l'unità
    if unit == nil or unit.enabled == nil then
        return fnresult(false, "Can't enable unit: it's invalid.");
    end
    local unit_code = unit.unit_id .. "_" .. unit.owner;
    --Non ho ancora l'unità a runtime: non posso abilitarla sicuramente poiché non ho l'interprete
    if self.units[unit_code] == nil then
        return fnresult(false, "Unit wasn't registered to the runtime environment.");
    end

    if self.units[unit_code].interp == nil or next(self.units[unit_code].interp) == nil then
        local res = self:createInterpreter(unit, false); --Era disabilitata l'unità: inizia da capo (nuovo env)
        if not res.completed then
            self:registerError(unit_code, res.msg);
            res.data = nil;
            ---@type Result<nil>
            return res;
        end
    end

    --Abilito dal runtime
    self.units[unit_code].enabled = true;
    --Infine abilito l'unità se tutto è andato bene
    unit.enabled = true;

    return fnresult(true, nil, nil);
end

---Disables a unit: the unit will NOT be called anymore by the runtime-handler, so no operation will be performed.
---WARNING: even if the unit wasn't present in the runtime the parameter "enabled" in the Unit will be set to false.
---@param unit Unit
---@return Result<nil> #If the unit has been disabled then "completed" will be set to "true", "false" otherwise.
function Industria.runtime:disableUnit(unit)
    --Controllo se posso abilitare l'unità
    if unit == nil or unit.enabled == nil then
        return fnresult(false, "Can't enable unit: it's invalid.");
    end
    --Disabilito l'unità a priori
    unit.enabled = false;

    local unit_code = unit.unit_id .. "_" .. unit.owner;
    --Non ho ancora l'unità a runtime: non posso abilitarla sicuramente poiché non ho l'interprete
    if self.units[unit_code] == nil then
        return fnresult(false, "Unit wasn't registered to the runtime environment.");
    end
    --Abilito dal runtime
    self.units[unit_code].enabled = false;
    if self.units[unit_code].interp ~= nil and self.units[unit_code].interp.init ~= nil then --Resetto env
        self.units[unit_code].interp:init();
    end
    return fnresult(true, nil, nil);
end

--- Binds an Interpreter to a Unit.
---@param unit Unit The unit to which create the interpreter
---@param interpreter Interpreter The interpreter to bind to the unit
---@return Result<nil> #It's completed if the interpreted has been binded to the unit_code
function Industria.runtime:setUnitInterpreter(unit, interpreter)
    if unit == nil then
        return fnresult(false, "Unit must be not nil.");
    end

    if unit.unit_id == nil or unit.owner == nil then
        return fnresult(false, "Not a unit");
    end

    local unit_code = unit.unit_id .. "_" .. unit.owner;
    --Non ho ancora l'unità a runtime: la salvo e gli imposto i valori di default
    if self.units[unit_code] == nil then
        local res = self:registerToRuntime(unit);
        if not res.completed then
            self:registerError(unit_code, res.msg);
            return res;
        end
    end
    --Imposto l'interprete
    self.units[unit_code].interp = interpreter or nil;

    return fnresult(true, nil, nil);
end

--- Initialize the Control Unit parsing the ST file associated (reference_program) and
--- building the interpreter for future usage. The interpreter is stored in
--- Industria.runtime.units[unit_code].interp and associated with the Control Unit by the UnitCode.
---
---@param unit Unit {unitd_id, owner, reference_program, last_env}
---@param load_init boolean if true tries to load the environment from the save file ".st.env"
---@return Result<Interpreter|nil> #true/false based on success or error
function Industria.runtime:createInterpreter(unit, load_init)
    --Check for fields
    if unit == nil or unit.reference_program == nil then
        return fnresult(false, "Code not loaded", nil);
    end

    local unit_code = unit.unit_id .. "_" .. unit.owner;
    --Load the ST code from the file using the reference_program parameter
    local programcode = Industria.ST.loadCode(Industria.datapath .. "/" .. unit.reference_program);
    if not programcode.completed then
        self:registerError(unit_code, "Code not loaded:\n" .. programcode.msg);
        return fnresult(false, "Code not loaded:\n" .. programcode.msg, nil); --Code not loaded
    end
    --Genera l'interprete
    local res_interpreter = Industria.ST.interpCode(programcode.data, unit_code);
    if not res_interpreter.completed then
        self:registerError(unit_code, res_interpreter.msg);
        return fnresult(false, "Interpreter not generated: " .. res_interpreter.msg, nil); --L'interprete non è stato generato
    end

    --Imposta l'interprete associandolo alla Control Unit
    local res = self:setUnitInterpreter(unit, res_interpreter.data);
    if not res.completed then
        self:registerError(unit_code, res.msg);
        return res;
    end
    res_interpreter.data:init(); --Inizializza l'interprete

    if load_init then            --Se devo caricare le variabili dal salvataggio
        local f, err = io.open(Industria.datapath .. "/" .. unit.reference_program .. ".env", "r");
        if err or f == nil then
            self:registerError(unit_code, err or "ST File error");
            return fnresult(false, err, nil);
        end
        --Deserializza le variabili
        unit.last_env = core.deserialize(f:read("a"), true);
        f:close();
        --Imposta l'environment caricato
        res_interpreter.data:setEnv(unit.last_env);
    end
    return fnresult(true, nil, res_interpreter.data);
end

---Register an unit to the runtime. The Unit should be initialized then by creating
---the interpreter and loding the environment
---@param unit Unit
---@return Result<nil>
function Industria.runtime:registerToRuntime(unit)
    if unit == nil then
        return fnresult(false, "Unit must be not nil.");
    end

    if unit.unit_id == nil or unit.owner == nil then
        return fnresult(false, "Not a unit");
    end

    local unit_code = unit.unit_id .. "_" .. unit.owner;
    --Non ho ancora l'unità a runtime: la salvo e gli imposto i valori di default
    if self.units[unit_code] == nil then
        self.units[unit_code] = {};
        --Imposto lo stato di enabled
        self.units[unit_code].enabled = unit.enabled;
        --Imposto gli errori
        self.units[unit_code].errors = {};
        --Imposto l'interprete
        self.units[unit_code].interp = {};
    end

    if unit.enabled then
        local res = self:createInterpreter(unit, true);
        if not res.completed then
            core.debug(res.msg);
        end
    end
    return fnresult(true, nil, nil);
end

---Saves all the executing environments to the unit's last_env parameter
function Industria.runtime:saveCurrentEnv()
    for key, value in pairs(self.units) do
        if value ~= nil and value.enabled and value.interp ~= {} then
            local unit = Industria.controllers.units[key]; --Prendo l'unità
            if unit ~= nil then                            --Se esiste salvo
                unit.last_env = value.interp:getEnv();
                Industria.files.saveUnitEnvironment(unit);
            end
        end
    end
end

core.register_globalstep(function(dtime)
    for key, value in pairs(Industria.runtime.units) do
        if value ~= nil and value.enabled and value.interp ~= nil then
            if value.interp.cycle == nil then
                local unit = Industria.controllers.units[key]; --Prendo l'unità
                if unit ~= nil then                            --Se esiste la disabilito
                    Industria.runtime:disableUnit(unit);
                end
            else
                local ok, err3, cur_env, stats = value.interp:cycle();
                --TODO: cur_env deve essere passato a tutte le unità in ascolto per le uscite e input
                if not ok then                                     --Errore nell'esecuzione del ciclo dell'unità
                    local unit = Industria.controllers.units[key]; --Prendo l'unità
                    if unit ~= nil then                            --Se esiste la disabilito
                        Industria.runtime:disableUnit(unit);
                    end
                end
            end
        end
    end
end)
