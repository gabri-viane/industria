------------------------------------------ Definition of the Main Form for Units ---------------------------------------

local FSKeyCode = "Industria:Unit:UnitMainForm";

--- Main form for a Unit, displays infos and settings.
---@param unit Unit
---@param owner owner
---@return string #The formspec
local UnitMainForm = function(unit, owner)
    local strstatus = "Enabled";
    local straction = "Disable";
    local color = "green";
    if not unit.enabled then
        strstatus = "Disabled";
        straction = "Enable";
        color = "orange";
    end
    local errors = {};
    local res = Industria.runtime:getErrors(unit.unit_id .. "_" .. unit.owner);
    if res.completed then
        errors = res.data;
    end

    local form = { "formspec_version[6]",
        "size[8,8]",
        "box[7.1,1.95;0.5,0.5;", color, "]",
        "label[3.4,2.2;Current status: ", strstatus, "]",
        "button[0.2,1.8;3,0.8;enableToggleButton;", straction, "]",
        "label[0.3,0.5;Owner:]",
        "label[1.6,0.5;", owner or "unknown", "]",
        "label[0.3,1.1;Unit ID:]",
        "label[1.6,1.1;", unit.unit_id or "unknown", "]",
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
function Industria.formspecs.callbacks:UnitMainFormCallback(player_name, fields)
    local plcid = Industria.formspecs:getPlayerStatus(player_name).data;

    local closeFS = function(message)
        if message ~= nil then
            core.chat_send_player(player_name, message);
        end
        Industria.formspecs:setPlayerStatus(player_name, nil, nil);
        core.close_formspec(player_name, FSKeyCode);
    end

    if plcid == nil or not (type(plcid) == "string") then
        closeFS("No Unit ID to handle");
        return;
    end

    --Devo fare il toggle del valore di enable
    if fields.enableToggleButton then
        local unit = Industria.controllers:getUnit(plcid, player_name);
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
            core.chat_send_player(player_name, res.msg);
        end
        --Aggiorna il formspec
        Industria.formspecs:showUnitMainForm(player_name, plcid);
        return;
    end

    if fields.editCodeUnit then
        --Chiudo il formspec e apro quello di editing
        core.close_formspec(player_name, FSKeyCode);
        Industria.formspecs:showEditor(player_name, plcid);
        Industria.formspecs:setPlayerStatusFallback(player_name, function()
            --Una volta chiuso l'editor torna alla pagina principale
            Industria.formspecs:showUnitMainForm(player_name, plcid);
        end);
        return;
    end
end

--- Shows the Main formspec to handle a Unit.
---@param playername owner Name of the player
---@param unit_id unit_id The id of the plc to be handled
function Industria.formspecs:showUnitMainForm(playername, unit_id)
    local res = Industria.controllers:getUnit(unit_id, playername);

    if res.completed then
        self:setCurrentCallback(playername,
            function(pname, fields)
                Industria.formspecs.callbacks:UnitMainFormCallback(pname, fields);
            end);
        self:setPlayerStatus(playername, FSKeyCode, unit_id);
        core.show_formspec(playername, FSKeyCode, UnitMainForm(res.data, playername));
    else
        core.chat_send_player(playername, "No Unit found with ID: '" .. tostring(unit_id) .. "'");
    end
end
