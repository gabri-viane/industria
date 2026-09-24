------------------------------------------ Definition of the Main Form for Controllers ---------------------------------------

local FSKeyCode = "Industria:Controller:ControllerMainForm";
local coreCloseFormSpec = core.close_formspec;
local coreShowFormSpec = core.show_formspec;
local sendPlayerMsg = core.chat_send_player;

--- Main form for a Controller, displays infos and settings.
---@param controller Controller
---@param playername string
---@return string #The formspec
local ControllerMainForm = function(controller, playername)
    local strstatus = "Enabled";
    local straction = "Disable";
    local color = "green";
    if not controller.enabled then
        strstatus = "Disabled";
        straction = "Enable";
        color = "orange";
    end

    local stractionProtect = "Protect";
    local strstatusProtect = "Not protected";
    if controller.protected then
        stractionProtect = "Open access";
        strstatusProtect = "Protected";
    end

    local errors = {};
    local res = Industria.runtime:getErrors(controller.controller_id .. "_" .. controller.owner);
    if res.completed then
        errors = res.data;
    end

    local protected_section = "";
    if playername == controller.owner then
        protected_section = table.concat({
            "button[0.2,2.4;3,0.8;protectToggleButton;", stractionProtect, "]",
            "label[3.4,2.8;Current status: ", strstatusProtect, "]" }, "");
    end

    local form = { "formspec_version[6]",
        "size[8,8]",
        "label[0.3,0.5;Owner:]",
        "label[1.6,0.5;", controller.owner or "unknown", "]",
        "label[0.3,1.1;Controller ID:]",
        "label[1.6,1.1;", controller.controller_id or "unknown", "]",
        "box[7.1,1.7;0.5,0.5;", color, "]",
        "label[3.4,1.9;Current status: ", strstatus, "]",
        "button[0.2,1.5;3,0.8;enableToggleButton;", straction, "]",
        protected_section, --La sezione di protezione è visibile solo per il proprietario dell'unità
        "button[0.2,7;3,0.8;deleteController;Delete Controller]",
        "button[4.8,7;3,0.8;editCodeController;Edit Controller Code]",
        "textlist[0.2,3.8;7.5,3;;", table.concat(errors, ","), ";1;false]",
        "label[0.2,3.5;Last errors:]"
    };
    return table.concat(form, "");
end

--- Callback function to handle fields of the Main Unit Form.
---@param player_name string Player name
---@param fields any The fields of the formspec
function Industria.formspecs.callbacks:ControllerMainFormCallback(player_name, fields)
    local cntrl_code = Industria.formspecs:getPlayerStatus(player_name).data;

    local closeFS = function(message)
        if message ~= nil then
            sendPlayerMsg(player_name, message);
        end
        Industria.formspecs:setPlayerStatus(player_name, nil, nil);
        coreCloseFormSpec(player_name, FSKeyCode);
    end

    if cntrl_code == nil or not (type(cntrl_code) == "string") then
        closeFS("No Controller ID to handle");
        return;
    end

    --Devo fare il toggle del valore di enable
    if fields.enableToggleButton then
        local unit = Industria.controllers:getController(cntrl_code);
        --Controllo di avere la unit
        if not unit.completed then
            closeFS("No Unit found");
            return;
        end
        local res;
        --Inverti lo stato corrente
        if unit.data.enabled then
            res = Industria.runtime:disableController(unit.data);
        else
            res = Industria.runtime:enableController(unit.data);
        end
        if not res.completed then
            sendPlayerMsg(player_name, core.colorize("orange", res.msg));
        end
        --Aggiorna il formspec
        Industria.formspecs:showControllerMainForm(player_name, cntrl_code);
        return;
    end

    --Devo fare il toggle del valore di protected solo se è il proprietario
    if fields.protectToggleButton then
        local cntrl = Industria.controllers:getController(cntrl_code);
        --Controllo di avere la unit
        if not cntrl.completed then
            closeFS("No Unit found");
            return;
        end
        --Se non è il proprietario allora non può modificare il livello di protezione
        if cntrl.data.owner ~= player_name then
            return;
        end
        --Inverti lo stato corrente
        cntrl.data.protected = not cntrl.data.protected;
        --Aggiorna il formspec
        Industria.formspecs:showControllerMainForm(player_name, cntrl_code);
        return;
    end

    if fields.editCodeController then
        --Chiudo il formspec e apro quello di editing
        coreCloseFormSpec(player_name, FSKeyCode);
        Industria.formspecs:showEditor(player_name, cntrl_code);
        Industria.formspecs:setPlayerStatusFallback(player_name, function()
            --Una volta chiuso l'editor torna alla pagina principale
            Industria.formspecs:showControllerMainForm(player_name, cntrl_code);
        end);
        return;
    end

    if fields.deleteController then
        local unit = Industria.controllers:getController(cntrl_code);
        --Controllo di avere la unit
        if not unit.completed then
            closeFS("No Unit found");
            return;
        end
        local res = Industria.controllers:removeController(unit.data.controller_id, unit.data.owner)
        if res.completed then
            Industria.controllers.deleteMeta(unit.data)
        end
    end
end

--- Shows the Main formspec to handle a Controller. The formspec is showed to all players
--- only if the unit is not protected: if it's protected than the formspec is showed
--- only to the owner.
---@param playername string Name of the player to show to unit to
---@param unit_code ControllerCODE The id of the plc to be handled
function Industria.formspecs:showControllerMainForm(playername, unit_code)
    local res = Industria.controllers:getController(unit_code);
    if res.completed then
        --Devo controllare se l'unità è protetta
        if res.data.protected and playername ~= res.data.owner then
            sendPlayerMsg(playername, core.color("red", "You have no access to the unit."));
            return;
        end

        self:setCurrentCallback(playername,
            function(pname, fields)
                Industria.formspecs.callbacks:ControllerMainFormCallback(pname, fields);
            end);
        self:setPlayerStatus(playername, FSKeyCode, unit_code);
        coreShowFormSpec(playername, FSKeyCode, ControllerMainForm(res.data, playername));
    else
        sendPlayerMsg(playername, "No Controller found with Code: '" .. tostring(unit_code) .. "'");
    end
end
