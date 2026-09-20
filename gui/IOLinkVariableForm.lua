------------------------------------------ Definition of the IO Link Variable Form ---------------------------------------

local FSKeyCode = "Industria:Unit:IOLinkVariableForm";
local coreCloseFormSpec = core.close_formspec;
local coreShowFormSpec = core.show_formspec;
local sendPlayerMsg = core.chat_send_player;

---Generate the states and variables lists
---@param unit Unit
---@param iounit IOUnit
local generateDataLists = function(unit, iounit)
    local node_name = Industria.iounits.getIOUnitNodeName(iounit);
    if not node_name then
        return Industria.formspecs.errorFormspec("Invalid Node");
    end
    local states = Industria.iounits.getAvailableStates(node_name);
    if not states.completed then
        return Industria.formspecs.errorFormspec("IOUnit doesn't contain any state");
    end
    local unit_code = Industria.units.getUnitCode(unit);
    if not unit_code then
        return Industria.formspecs.errorFormspec("Can't find Unit");
    end

    local variables = {}
    local unit_rt = Industria.runtime.units[unit_code]
    local env = nil

    if not unit_rt or not unit_rt.interp then
        if not unit.last_env then
            return Industria.formspecs.errorFormspec("Unit doesn't have any available environment");
        else
            env = unit.last_env
        end
    else
        env = unit_rt.interp:getEnv()
    end

    for key, _ in pairs(env) do
        table.insert(variables, key)
    end
    return { variables = variables, states = states.data, ionode_name = node_name }
end

--- Form for a IOLinker, displays the link's variable options.

---@return string #The formspec
local IOLinkVariableForm = function(states, variables, error)
    local err_label = ""
    if error then
        err_label = table.concat({ "label[0.5,1.0;", core.colorize("red", core.formspec_escape(error)), "]" })
    end
    local form = { "formspec_version[6]",
        "size[9,6.5]",
        "label[0.5,0.5;Link the IOUnit's properties to the Unit's variables]",
        err_label,
        "textlist[0.25,2;2.5,4;availstates;", table.concat(states, ","), ";0;false]",
        "button[3,2.75;2.75,0.5;linkbtn;← Link →]",
        "button[3,3.5;2.75,0.5;unlinkbtn;↚ Unlink↛]",
        "label[0.25,1.5;IOUnit's states]",
        "textlist[6,2;2.5,4;availvariables;", table.concat(variables, ","), ";0;false]",
        "label[6,1.5;Unit's variables]",
    }
    return table.concat(form, "");
end


--- Callback function to handle fields of the Main Unit Form.
---@param player_name string Player name
---@param fields any The fields of the formspec
function Industria.formspecs.callbacks:IOLinkVariableFormCallback(player_name, fields)
    local playerdata = Industria.formspecs:getPlayerStatus(player_name).data;
    local unit = playerdata.unit
    local iounit = playerdata.iounit

    local closeFS = function(message)
        if message ~= nil then
            sendPlayerMsg(player_name, message);
        end
        Industria.formspecs:setPlayerStatus(player_name, nil, nil);
        coreCloseFormSpec(player_name, FSKeyCode);
    end

    if unit == nil or iounit == nil then
        closeFS("No Unit or IOUnit to handle");
        return;
    end

    if fields.unlinkbtn then
        return;
    end

    if fields.linkbtn then
        if unit.owner ~= player_name then
            closeFS("Selected Unit is not owned by the player");
            return;
        end
        if iounit.owner ~= player_name then
            closeFS("Selected IOUnit is not owned by the player");
            return;
        end

        if not playerdata.selected_state then
            --Aggiorno il formspec mostrando l'errore
            Industria.formspecs:showIOLinkVariableForm(player_name, unit, iounit, "Select an IOUnit's state before link");
            return;
        end

        if not playerdata.selected_variable then
            --Aggiorno il formspec mostrando l'errore
            Industria.formspecs:showIOLinkVariableForm(player_name, unit, iounit, "Select an Unit's variable before link");
            return;
        end
        local result_state = Industria.iounits.getStateData(playerdata.ionode_name, playerdata.selected_state)
        if not result_state.completed then
            Industria.formspecs:showIOLinkVariableForm(player_name, unit, iounit, result_state.msg);
            return;
        end
        local state = result_state.data
        if not state then
            Industria.formspecs:showIOLinkVariableForm(player_name, unit, iounit, "Can't retrive selected node state");
            return;
        end

        local result = Industria.runtime.iounits:link(unit, iounit,
            playerdata.selected_state,
            playerdata.selected_variable,
            state.iotype)
        closeFS(result.msg);
        return;
    end

    if fields.availstates then
        local result = core.explode_textlist_event(fields.availstates)
        if result.type == "CHG" then
            playerdata.selected_state = playerdata.states[result.index]
        end
        Industria.formspecs:setPlayerStatus(player_name, FSKeyCode, playerdata)
    end

    if fields.availvariables then
        local result = core.explode_textlist_event(fields.availvariables)
        if result.type == "CHG" then
            playerdata.selected_variable = playerdata.variables[result.index]
        end
        Industria.formspecs:setPlayerStatus(player_name, FSKeyCode, playerdata)
    end
end

--- Shows the Main formspec to handle a Unit. The formspec is showed to all players
--- only if the unit is not protected: if it's protected than the formspec is showed
--- only to the owner.
---@param playername string Name of the player to show to unit to
---@param unit Unit
---@param iounit IOUnit
---@param error string|nil
function Industria.formspecs:showIOLinkVariableForm(playername, unit, iounit, error)
    self:setCurrentCallback(playername,
        function(pname, fields)
            Industria.formspecs.callbacks:IOLinkVariableFormCallback(pname, fields);
        end);

    local result = generateDataLists(unit, iounit)
    if type(result) == "string" then
        coreShowFormSpec(playername, FSKeyCode, result);
        return;
    end

    local current_status = self:getPlayerStatus(playername);
    -- Controllo se sto mostrando questo form, in questo caso non elimino le variabili salvate nello stato
    if not current_status or current_status.showing ~= FSKeyCode then
        self:setPlayerStatus(playername, FSKeyCode,
            {
                unit = unit,
                iounit = iounit,
                states = result.states,
                variables = result.variables,
                ionode_name = result.ionode_name
            });
    end
    coreShowFormSpec(playername, FSKeyCode,
        IOLinkVariableForm(result.states, result.variables, error)
    );
end
