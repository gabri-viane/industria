local fnresult = Industria.commons.fnresult;


Industria.runtime.iounits = {
    ---@type table<unit_code,io_unit_code[]>
    inputs = {},
    ---@type table<unit_code,io_unit_code[]>
    outputs = {},
    ---@type table<iounitname, IOUnitStats>
    states = {}
}

---Registra nel runtime di Input e Output "Industria.iounits.ios" il controllore (Unit) affinché gli possano essere
---registrate le IOUnit
---@param unit_code unit_code L'unità da registrare
function Industria.runtime.iounits:registerUnitToIORuntime(unit_code)
    if not self.inputs[unit_code] or not self.outputs[unit_code] then
        self.inputs[unit_code] = {};
        self.outputs[unit_code] = {};
    end
end

---Toglie la registrazione dal runtime di Input e Output "Industria.iounits.ios" il controllore (Unit). Così facendo rimuove
---anche tutte le IOUnit collegate.
---@param unit_code unit_code L'unità da rimuovere dal IORuntime
function Industria.runtime.iounits:unregisterUnitToIORuntime(unit_code)
    --Se sono presenti segnali di IOUnits in input rimuove la IOUnit dall'input della Unit
    if self.inputs[unit_code] then
        for _, value in ipairs(self.inputs[unit_code]) do
            local result = Industria.iounits:getIOUnit(value);
            if result.completed and result.data ~= nil then
                self:unlink(result.data);
            end
        end
    end
    --Se sono presenti segnali di IOUnits in output rimuove la IOUnit dall'output della Unit
    if self.outputs[unit_code] then
        for _, value in ipairs(self.outputs[unit_code]) do
            local result = Industria.iounits:getIOUnit(value);
            if result.completed and result.data ~= nil then
                self:unlink(result.data);
            end
        end
    end
    self.inputs[unit_code] = nil;
    self.outputs[unit_code] = nil;
end

---Prova ad associare (SE NON E' GIA' ASSOCIATO) la IOUnit agli input o output del IORuntime dell'Unit
---@param unit_code unit_code Codice dell'unità a cui registrare la IOUnit
---@param iounit IOUnit IOUnit da registrare
---@param type IOType Input o Output da registrare
---@return Result<nil>
function Industria.runtime.iounits:tryRegisterIOUnitToRuntime(unit_code, iounit, type)
    -- Segno nell'IORuntime che per la Unit è collegata la IOUnit (INPUT)
    if type == 0 or type == 2 then
        if self.inputs[unit_code] == nil then
            return fnresult(false, "Unit is not registered to IORuntime: can't link the IOUnit", nil)
        end
        --Se l'ho già registrata negli input non la registro di nuovo
        local index = table.indexof(self.inputs[unit_code], iounit.iounit_code)
        if index < 0 then
            table.insert(self.inputs[unit_code], iounit.iounit_code);
        end
    end
    -- Segno nell'IORuntime che per la Unit è collegata la IOUnit (OUTPUT)
    if type == 1 or type == 2 then
        if self.outputs[unit_code] == nil then
            return fnresult(false, "Unit is not registered to IORuntime: can't link the IOUnit", nil)
        end
        --Se l'ho già registrata negli output non la registro di nuovo
        local index = table.indexof(self.outputs[unit_code], iounit.iounit_code)
        if index < 0 then
            table.insert(self.outputs[unit_code], iounit.iounit_code);
        end
    end
    return fnresult(true, nil, nil)
end

---Prova ad rimuovre (SE E' GIA' ASSOCIATO) la IOUnit agli input o output del IORuntime dell'Unit. Se la IOUnit non ha più collegamenti
---alla Unit allora viene rimossa l'associaziona anche alla IOUnit.reference_unit
---@param unit Unit L'unità a cui controllare l'IORuntime
---@param iounit IOUnit IOUnit da controllare per rimuovere dall'IORuntime della Unit
function Industria.runtime.iounits:tryUnregisterIOUnitToRuntime(unit, iounit)
    local unit_code = Industria.units.getUnitCode(unit)
    local n_inputs  = 0
    local n_outputs = 0
    for _, ioport in pairs(iounit.io_ports) do
        --Se la variabile è collegata allora la conto
        if ioport.linked_var then
            if ioport.type == 0 or ioport.type == 2 then
                n_inputs = n_inputs + 1;
            end
            if ioport.type == 1 or ioport.type == 2 then
                n_outputs = n_outputs + 1;
            end
        end
    end
    -- Se non ci sono più input dell'IOUnit associati alla Unit allora rimuove l'IOUnit dall'IORuntime della Unit
    if n_inputs == 0 and unit_code and self.inputs[unit_code] then
        local index = table.indexof(self.inputs[unit_code], iounit.iounit_code)
        if index > -1 then
            table.remove(self.inputs[unit_code], index);
        end
    end
    -- Se non ci sono più output dell'IOUnit associati alla Unit allora rimuove l'IOUnit dall'IORuntime della Unit
    if n_outputs == 0 and unit_code and self.outputs[unit_code] then
        local index = table.indexof(self.outputs[unit_code], iounit.iounit_code)
        if index > -1 then
            table.remove(self.outputs[unit_code], index);
        end
    end
    -- Se non ho più nessun input o output associati allora rimuovo
    if n_outputs == 0 and n_inputs == 0 then
        iounit.reference_unit = nil
    end
end

---Links the IOUnit to a Unit's variable. To be correctly linked the IOUnit must be linked to a single Unit.
---@param unit Unit Unit to which the IOUnit will be linked
---@param iounit IOUnit IOUnit to link to the Unit
---@param iounitStateName string The state name to use of the IOUnit to link to the env variable
---@param envVarName string Variable name contained in the Unit
---@param type IOType Direction of the binding
---@return Result<IOUnit|nil>
function Industria.runtime.iounits:link(unit, iounit, iounitStateName, envVarName, type)
    --Controllo il nome della variabile dell'ambiente da collegare
    if not envVarName or #envVarName < 1 then
        return fnresult(false, "Unit's variable is invalid.", nil);
    end
    --Controllo se la Unit esiste
    local unit_code = Industria.units.getUnitCode(unit);
    if not unit_code then
        return fnresult(false, "Unit is invalid.", nil);
    end
    --Controllo se la IOUnit è già collegata ad unità differente
    if iounit.reference_unit and iounit.reference_unit ~= unit_code then
        return fnresult(false, "IOUnit is already linked to a different Unit.")
    end
    --Controllo se l'interprete della Unit esiste
    local data = Industria.runtime.units[unit_code]
    if not data or not data.interp then
        return fnresult(false, "Unit doesn't have an interpreter associated", nil)
    end
    --Controllo se l'environment dell'interprete è stato creato
    local env = data.interp:getEnv()
    if not env then
        return fnresult(false, "Unit's interpreter doesn't have an environment associated", nil)
    end
    --Controllo se l'environment contiene la variabile da collegare
    if not env[envVarName] then
        return fnresult(false, "Unit doesn't define the variable '" .. envVarName .. "'", nil)
    end
    -- Controllo se la iounit contiene tra le porte disponibili la variabile da collegare
    if not iounit.io_ports[iounitStateName] then
        return fnresult(false, "IOUnit doesn't have the state '" .. iounitStateName .. "'", nil)
    end

    local res = self:tryRegisterIOUnitToRuntime(unit_code, iounit, type)
    if not res.completed then
        return res
    end

    --Imposto per la variabile dell'IOUnit la variabile della Unit collegata
    iounit.io_ports[iounitStateName].linked_var = envVarName;
    iounit.io_ports[iounitStateName].type       = type;
    --Nella iounit segno che per una determinata variabile è collegata quale porta di IO
    iounit.linked_states[envVarName]            = iounitStateName
    --Registro nell'unità che la variabile è stata collegata
    unit.io_units[envVarName]                   = iounit.iounit_code;
    iounit.reference_unit                       = unit_code

    return fnresult(true, nil, iounit)
end

---Unlinks the IOUnit from the Unit
---@param iounit IOUnit Code of the IOUnit to unlink from the Unit
---@param iounitStateName string|nil Name of the state to unlink, otherwise if not provided all states will be unlinked
---@return Result<nil>
function Industria.runtime.iounits:unlink(iounit, iounitStateName)
    local unit_code = iounit.reference_unit
    if not unit_code then
        return fnresult(true, "", nil);
    end
    --Controllo se la Unit esiste
    if not unit_code then
        return fnresult(false, "Unit is invalid.", nil);
    end
    local unit = Industria.controllers.units[unit_code]
    if unit == nil then
        return fnresult(false, "Unit doesn't exists", nil)
    end

    --Devo gestire se l'unlink è di tutti gli stati o solo uno
    if iounitStateName then
        -- Controllo se la iounit contiene tra le porte disponibili la variabile da collegare
        if not iounit.io_ports[iounitStateName] then
            return fnresult(false, "IOUnit doesn't have the state '" .. iounitStateName .. "'", nil)
        end
        -- Rimuovo il collegamento
        if unit.io_units[iounit.io_ports[iounitStateName].linked_var] then
            --Rimuovo l'associazione nella IOUnit di EnvVarName <-> IOName
            iounit.linked_states[unit.io_units[iounit.io_ports[iounitStateName].linked_var]] = nil
            unit.io_units[iounit.io_ports[iounitStateName].linked_var] = nil
        end

        iounit.io_ports[iounitStateName].linked_var = nil
    else
        --Se non viene specificata nessuno stato allora vengono rimossi tutti gli stati
        for ioname, ioport in pairs(iounit.io_ports) do
            -- Rimuovo il collegamento
            if unit.io_units[ioport.linked_var] then
                --Rimuovo l'associazione nella IOUnit di EnvVarName <-> IOName
                iounit.linked_states[unit.io_units[ioport.linked_var]] = nil
                unit.io_units[ioport.linked_var] = nil
            end
            iounit.io_ports[ioname].linked_var = nil
        end
    end
    --Controllo se rimuovere l'IOUnit dall'IORuntime
    self:tryUnregisterIOUnitToRuntime(unit, iounit);
    return fnresult(true, nil, nil)
end

---Controlla se ci sono variabili eliminate che erano connesse a IOUnit
---@param unit Unit
---@param newEnv Environment
---@param prevEnv Environment | nil
function Industria.runtime.iounits:checkEnvs(unit, newEnv, prevEnv)
    --Se non avevo un environment precedente allora non posso sicuramente confrontare
    if prevEnv == nil then
        return
    end

    for varname, value in pairs(prevEnv) do
        if newEnv[varname] == nil then
            --Non ho più una variabile che prima avevo
            local iounit_code = unit.io_units[varname]
            if iounit_code then
                local result = Industria.iounits:getIOUnit(iounit_code)
                if result.completed and result.data then
                    local state_name = Industria.iounits.getLinkedState(result.data, varname)
                    -- Se state_name è nil allora unlink tutta l'unità
                    self:unlink(result.data, state_name)
                end
            end
        end
    end
end

---Copies inputs or outputs of IOUnits to or from the Unit
---@param interp Interpreter
---@param unit Unit
---@param direction IOType
function Industria.runtime.iounits:executeCopy(interp, unit, direction)
    local unit_code = Industria.units.getUnitCode(unit);
    if not unit_code then
        return
    end
    local res = nil
    local iounit = nil
    local states = nil
    local state_name = nil
    local env = interp:getEnv()

    for varname, iounit_code in pairs(unit.io_units) do
        res = Industria.iounits:getIOUnit(iounit_code)
        iounit = res.data
        if res.completed and iounit then
            states = Industria.iounits.getIOUnitStates(iounit)
            state_name = iounit.linked_states[varname]
            if states and state_name and states[state_name] then
                if (direction == 0 and states[state_name].iotype == 0) then
                    if env[varname].dtype == states[state_name].dtype then
                        if type(states[state_name].value) == "function" then
                            env[varname].value = states[state_name].value(iounit)
                        else
                            env[varname].value = states[state_name].value
                        end
                    end
                elseif (direction == 1 and states[state_name].iotype == 1) then
                    if type(states[state_name].value) == "function" then
                        states[state_name].value(iounit, env[varname].value)
                    end
                end
            end
        end
    end
    interp:setEnv(env)
end
