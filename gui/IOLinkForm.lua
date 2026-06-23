------------------------------------------ Definition of the IO Link Form ---------------------------------------
--[[
local FSKeyCode = "Industria:Unit:IOLinkForm";
local coreCloseFormSpec = core.close_formspec;

--- Main form for a Unit, displays infos and settings.
---@param unit Unit
---@param playername string
---@return string #The formspec
local IOLinkForm = function(unit, playername)
    local strstatus = "Enabled";
    local straction = "Disable";
    local color = "green";
    if not unit.enabled then
        strstatus = "Disabled";
        straction = "Enable";
        color = "orange";
    end

    local stractionProtect = "Protect";
    local strstatusProtect = "Not protected";
    if unit.protected then
        stractionProtect = "Open access";
        strstatusProtect = "Protected";
    end

    local errors = {};
    local res = Industria.runtime:getErrors(unit.unit_id .. "_" .. unit.owner);
    if res.completed then
        errors = res.data;
    end

    local protected_section = "";
    if playername == unit.owner then
        protected_section = table.concat({
            "button[0.2,2.4;3,0.8;protectToggleButton;", stractionProtect, "]",
            "label[3.4,2.8;Current status: ", strstatusProtect, "]" }, "");
    end

    local form = { "formspec_version[6]",
        "size[8,8]",
        "label[0.3,0.5;Owner:]",
        "label[1.6,0.5;", unit.owner or "unknown", "]",
        "label[0.3,1.1;Unit ID:]",
        "label[1.6,1.1;", unit.unit_id or "unknown", "]",
        "box[7.1,1.7;0.5,0.5;", color, "]",
        "label[3.4,1.9;Current status: ", strstatus, "]",
        "button[0.2,1.5;3,0.8;enableToggleButton;", straction, "]",
        protected_section, --La sezione di protezione è visibile solo per il proprietario dell'unità
        "button[0.2,7;3,0.8;deleteUnit;Delete Unit]",
        "button[4.8,7;3,0.8;editCodeUnit;Edit Unit Code]",
        "textlist[0.2,3.8;7.5,3;;", table.concat(errors, ","), ";1;false]",
        "label[0.2,3.5;Last errors:]"
    };
    return table.concat(form, "");
end

--- Callback function to handle fields of the Main Unit Form.
---@param player_name string Player name
---@param fields any The fields of the formspec
function Industria.formspecs.callbacks:IOLinkFormCallback(player_name, fields)
    local unitcode = Industria.formspecs:getPlayerStatus(player_name).data;

    local closeFS = function(message)
        if message ~= nil then
            core.chat_send_player(player_name, message);
        end
        Industria.formspecs:setPlayerStatus(player_name, nil, nil);
        core.close_formspec(player_name, FSKeyCode);
    end

    if unitcode == nil or not (type(unitcode) == "string") then
        closeFS("No Unit ID to handle");
        return;
    end

    --Devo fare il toggle del valore di enable
    if fields.enableToggleButton then
        local unit = Industria.controllers:getUnit(unitcode);
        --Controllo di avere la unit
        if not unit.completed then
            closeFS("No Unit found");
            return;
        end
        local res;
        --Inverti lo stato corrente
        if unit.data.enabled then
            res = Industria.runtime:disableUnit(unit.data);
        else
            res = Industria.runtime:enableUnit(unit.data);
        end
        if not res.completed then
            core.chat_send_player(player_name, core.colorize("orange", res.msg));
        end
        --Aggiorna il formspec
        Industria.formspecs:showUnitMainForm(player_name, unitcode);
        return;
    end

    --Devo fare il toggle del valore di protected solo se è il proprietario
    if fields.protectToggleButton then
        local unit = Industria.controllers:getUnit(unitcode);
        --Controllo di avere la unit
        if not unit.completed then
            closeFS("No Unit found");
            return;
        end
        --Se non è il proprietario allora non può modificare il livello di protezione
        if unit.data.owner ~= player_name then
            return;
        end
        --Inverti lo stato corrente
        unit.data.protected = not unit.data.protected;
        --Aggiorna il formspec
        Industria.formspecs:showUnitMainForm(player_name, unitcode);
        return;
    end

    if fields.editCodeUnit then
        --Chiudo il formspec e apro quello di editing
        core.close_formspec(player_name, FSKeyCode);
        Industria.formspecs:showEditor(player_name, unitcode);
        Industria.formspecs:setPlayerStatusFallback(player_name, function()
            --Una volta chiuso l'editor torna alla pagina principale
            Industria.formspecs:showUnitMainForm(player_name, unitcode);
        end);
        return;
    end
end

--- Shows the Main formspec to handle a Unit. The formspec is showed to all players
--- only if the unit is not protected: if it's protected than the formspec is showed
--- only to the owner.
---@param playername string Name of the player to show to unit to
---@param unit_code unit_code The id of the plc to be handled
function Industria.formspecs:showIOLinkForm(playername, unit_code)
    local res = Industria.controllers:getUnit(unit_code);
    if res.completed then
        --Devo controllare se l'unità è protetta
        if res.data.protected and playername ~= res.data.owner then
            core.chat_send_player(playername, core.color("red", "You have no access to the unit."));
            return;
        end

        self:setCurrentCallback(playername,
            function(pname, fields)
                Industria.formspecs.callbacks:UnitMainFormCallback(pname, fields);
            end);
        self:setPlayerStatus(playername, FSKeyCode, unit_code);
        core.show_formspec(playername, FSKeyCode, UnitMainForm(res.data, playername));
    else
        core.chat_send_player(playername, "No Unit found with Code: '" .. tostring(unit_code) .. "'");
    end
end
]]--