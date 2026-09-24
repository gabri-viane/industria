local fnresult = Industria.commons.fnresult;


Industria.runtime.iounits = {
    ---@type table<ControllerCODE,IOUnitCODE[]>
    inputs = {},
    ---@type table<ControllerCODE,IOUnitCODE[]>
    outputs = {},
    ---@type table<IOUnitName, IOPropertyList>
    definitions = {}
}

---Registra nel runtime di Input e Output "Industria.iounits.ios" il controllore (Unit) affinché gli possano essere
---registrate le IOUnit
---@param ctrl_code ControllerCODE L'unità da registrare
function Industria.runtime.iounits:registerUnitToIORuntime(ctrl_code)
    if not self.inputs[ctrl_code] or not self.outputs[ctrl_code] then
        self.inputs[ctrl_code] = {};
        self.outputs[ctrl_code] = {};
    end
end

---Toglie la registrazione dal runtime di Input e Output "Industria.iounits.ios" il controllore (Unit). Così facendo rimuove
---anche tutte le IOUnit collegate.
---@param ctrl_code ControllerCODE L'unità da rimuovere dal IORuntime
function Industria.runtime.iounits:unregisterControllerFromIORuntime(ctrl_code)
    --Se sono presenti segnali di IOUnits in input rimuove la IOUnit dall'input della Unit
    if self.inputs[ctrl_code] then
        for _, value in ipairs(self.inputs[ctrl_code]) do
            local result = Industria.iounits:getIOUnit(value);
            if result.completed and result.data ~= nil then
                self:unlink(result.data);
            end
        end
    end
    --Se sono presenti segnali di IOUnits in output rimuove la IOUnit dall'output della Unit
    if self.outputs[ctrl_code] then
        for _, value in ipairs(self.outputs[ctrl_code]) do
            local result = Industria.iounits:getIOUnit(value);
            if result.completed and result.data ~= nil then
                self:unlink(result.data);
            end
        end
    end
    self.inputs[ctrl_code] = nil;
    self.outputs[ctrl_code] = nil;
end

---Prova ad associare (SE NON E' GIA' ASSOCIATO) la IOUnit agli input o output del IORuntime dell'Unit
---@param ctrl_code ControllerCODE Codice dell'unità a cui registrare la IOUnit
---@param iounit IOUnit IOUnit da registrare
---@param type IOType Input o Output da registrare
---@return Result<nil>
function Industria.runtime.iounits:tryRegisterIOUnitToRuntime(ctrl_code, iounit, type)
    -- Segno nell'IORuntime che per la Unit è collegata la IOUnit (INPUT)
    if type == 0 or type == 2 then
        if self.inputs[ctrl_code] == nil then
            return fnresult(false, Industria.translate("unit_not_registerd_ioruntime"), nil)
        end
        --Se l'ho già registrata negli input non la registro di nuovo
        local index = table.indexof(self.inputs[ctrl_code], iounit.iounit_code)
        if index < 0 then
            table.insert(self.inputs[ctrl_code], iounit.iounit_code);
        end
    end
    -- Segno nell'IORuntime che per la Unit è collegata la IOUnit (OUTPUT)
    if type == 1 or type == 2 then
        if self.outputs[ctrl_code] == nil then
            return fnresult(false, Industria.translate("unit_not_registerd_ioruntime"), nil)
        end
        --Se l'ho già registrata negli output non la registro di nuovo
        local index = table.indexof(self.outputs[ctrl_code], iounit.iounit_code)
        if index < 0 then
            table.insert(self.outputs[ctrl_code], iounit.iounit_code);
        end
    end
    return fnresult(true, nil, nil)
end

---Prova ad rimuovre (SE E' GIA' ASSOCIATO) la IOUnit agli input o output del IORuntime dell'Unit. Se la IOUnit non ha più collegamenti
---alla Unit allora viene rimossa l'associaziona anche alla IOUnit.reference_unit
---@param controller Controller L'unità a cui controllare l'IORuntime
---@param iounit IOUnit IOUnit da controllare per rimuovere dall'IORuntime della Unit
function Industria.runtime.iounits:tryUnregisterIOUnitToRuntime(controller, iounit)
    local ctrl_code = Industria.controllers.getControllerCode(controller)
    local n_inputs  = 0
    local n_outputs = 0
    for _, ioport in pairs(iounit.io_ports) do
        --Se la variabile è collegata allora la conto
        if ioport.linked_var then
            if ioport.iotype == 0 or ioport.iotype == 2 then
                n_inputs = n_inputs + 1;
            end
            if ioport.iotype == 1 or ioport.iotype == 2 then
                n_outputs = n_outputs + 1;
            end
        end
    end
    -- Se non ci sono più input dell'IOUnit associati alla Unit allora rimuove l'IOUnit dall'IORuntime della Unit
    if n_inputs == 0 and ctrl_code and self.inputs[ctrl_code] then
        local index = table.indexof(self.inputs[ctrl_code], iounit.iounit_code)
        if index > -1 then
            table.remove(self.inputs[ctrl_code], index);
        end
    end
    -- Se non ci sono più output dell'IOUnit associati alla Unit allora rimuove l'IOUnit dall'IORuntime della Unit
    if n_outputs == 0 and ctrl_code and self.outputs[ctrl_code] then
        local index = table.indexof(self.outputs[ctrl_code], iounit.iounit_code)
        if index > -1 then
            table.remove(self.outputs[ctrl_code], index);
        end
    end
    -- Se non ho più nessun input o output associati allora rimuovo
    if n_outputs == 0 and n_inputs == 0 then
        iounit.reference_controller = nil
    end
end

---Links the IOUnit to a Unit's variable. To be correctly linked the IOUnit must be linked to a single Unit.
---@param unit Controller Unit to which the IOUnit will be linked
---@param iounit IOUnit IOUnit to link to the Unit
---@param iounitStateName string The state name to use of the IOUnit to link to the env variable
---@param envVarName string Variable name contained in the Unit
---@param type IOType Direction of the binding
---@return Result<IOUnit|nil>
function Industria.runtime.iounits:link(unit, iounit, iounitStateName, envVarName, type)
    --Controllo il nome della variabile dell'ambiente da collegare
    if not envVarName or #envVarName < 1 then
        return fnresult(false, Industria.translate("st_variable_invalid"), nil);
    end
    --Controllo se la Unit esiste
    local ctrl_code = Industria.controllers.getControllerCode(unit);
    if not ctrl_code then
        return fnresult(false, Industria.translate("unitcode_is_invalid"), nil);
    end
    --Controllo se la IOUnit è già collegata ad unità differente
    if iounit.reference_controller and iounit.reference_controller ~= ctrl_code then
        return fnresult(false, Industria.translate("iounit_alreay_bound_to_another_unit"))
    end
    --Controllo se l'interprete della Unit esiste
    local data = Industria.runtime.runtime_units[ctrl_code]
    if not data or not data.interp then
        return fnresult(false, Industria.translate("unit_no_interp"), nil)
    end
    --Controllo se l'environment dell'interprete è stato creato
    local env = data.interp:getEnv()
    if not env then
        return fnresult(false, Industria.translate("unit_interp_no_env"), nil)
    end
    --Controllo se l'environment contiene la variabile da collegare
    if not env[envVarName] then
        return fnresult(false, Industria.translate("unit_no_st_variable @1", envVarName), nil)
    end
    -- Controllo se la iounit contiene tra le porte disponibili la variabile da collegare
    if not iounit.io_ports[iounitStateName] then
        return fnresult(false, Industria.translate("iounit_no_state @1", iounitStateName), nil)
    end

    local res = self:tryRegisterIOUnitToRuntime(ctrl_code, iounit, type)
    if not res.completed then
        return res
    end

    --Se ho già collegato la variabile della Unit a un'altra IOUnit allora la rimuovo prima di collegarla a questa
    if unit.linked_iounits[envVarName] then
        local result = Industria.iounits:getIOUnit(unit.linked_iounits[envVarName])
        local _iounit = result.data
        if result.completed and _iounit then
            local state_name = Industria.iounits.getLinkedState(_iounit, envVarName)
            self:unlink(_iounit, state_name)
        end
    end

    --Imposto per la variabile dell'IOUnit la variabile della Unit collegata
    iounit.io_ports[iounitStateName].linked_var = envVarName;
    iounit.io_ports[iounitStateName].iotype       = type;
    --Nella iounit segno che per una determinata variabile è collegata quale porta di IO
    iounit.linked_properties[envVarName]            = iounitStateName
    --Registro nell'unità che la variabile è stata collegata
    unit.linked_iounits[envVarName]                   = iounit.iounit_code;
    iounit.reference_controller                       = ctrl_code

    return fnresult(true, nil, iounit)
end

---Unlinks the IOUnit from the Unit
---@param iounit IOUnit Code of the IOUnit to unlink from the Unit
---@param iounitStateName string|nil Name of the state to unlink, otherwise if not provided all states will be unlinked
---@return Result<nil>
function Industria.runtime.iounits:unlink(iounit, iounitStateName)
    local unit_code = iounit.reference_controller
    if not unit_code then
        return fnresult(true, "", nil);
    end
    --Controllo se la Unit esiste
    if not unit_code then
        return fnresult(false, Industria.translate("unitcode_is_invalid"), nil);
    end
    local unit = Industria.controllers.registered_controllers[unit_code]
    if unit == nil then
        return fnresult(false, Industria.translate("unit_not_exists @1", unit_code), nil)
    end

    --Devo gestire se l'unlink è di tutti gli stati o solo uno
    if iounitStateName then
        -- Controllo se la iounit contiene tra le porte disponibili la variabile da collegare
        if not iounit.io_ports[iounitStateName] then
            return fnresult(false, Industria.translate("iounit_no_state @1", iounitStateName), nil)
        end
        -- Rimuovo il collegamento
        if unit.linked_iounits[iounit.io_ports[iounitStateName].linked_var] then
            --Rimuovo l'associazione nella IOUnit di EnvVarName <-> IOName
            iounit.linked_properties[unit.linked_iounits[iounit.io_ports[iounitStateName].linked_var]] = nil
            unit.linked_iounits[iounit.io_ports[iounitStateName].linked_var] = nil
        end

        iounit.io_ports[iounitStateName].linked_var = nil
    else
        --Se non viene specificata nessuno stato allora vengono rimossi tutti gli stati
        for ioname, ioport in pairs(iounit.io_ports) do
            -- Rimuovo il collegamento
            if unit.linked_iounits[ioport.linked_var] then
                --Rimuovo l'associazione nella IOUnit di EnvVarName <-> IOName
                iounit.linked_properties[unit.linked_iounits[ioport.linked_var]] = nil
                unit.linked_iounits[ioport.linked_var] = nil
            end
            iounit.io_ports[ioname].linked_var = nil
        end
    end
    --Controllo se rimuovere l'IOUnit dall'IORuntime
    self:tryUnregisterIOUnitToRuntime(unit, iounit);
    return fnresult(true, nil, nil)
end

---Controlla se ci sono variabili eliminate che erano connesse a IOUnit
---@param unit Controller
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
            local iounit_code = unit.linked_iounits[varname]
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
---@param unit Controller
---@param direction IOType
function Industria.runtime.iounits:executeCopy(interp, unit, direction)
    local unit_code = Industria.controllers.getControllerCode(unit);
    if not unit_code then
        return
    end
    local res = nil
    local iounit = nil
    local states = nil
    local state_name = nil
    local env = interp:getEnv()

    for varname, iounit_code in pairs(unit.linked_iounits) do
        res = Industria.iounits:getIOUnit(iounit_code)
        iounit = res.data
        if res.completed and iounit then
            states = Industria.iounits.getIOUnitStates(iounit)
            state_name = iounit.linked_properties[varname]
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
