------------------------------------------ Definition of the Main IDE editor ---------------------------------------
local sendPlayerMsg = core.chat_send_player;


--Funzione di callback per l'editor di codice ST
function Industria.formspecs.IDE.callbacks:STMainIDECallback(player_name, fields)
    local playerdata = Industria.formspecs:getPlayerStatus(player_name).data;
    local unitcode = playerdata.ctrl_code
    local variables = playerdata.variables or {}

    ---Controlla di chi è l'unità
    ---@param unit Controller
    ---@return boolean #Se true allora il giocatore può gestire l'unità
    local checkOwnership = function(unit)
        if unit.protected and unit.owner ~= player_name then
            return false;
        end
        return true;
    end

    if unitcode == nil or not (type(unitcode) == "string") then
        Industria.formspecs.IDE:coreCloseFormSpec(player_name, "Controller Code not provided");
        return;
    end

    local res = Industria.controllers:getController(playerdata.ctrl_code)
    if not res.completed then
        Industria.formspecs.IDE:coreCloseFormSpec(player_name, res.msg);
        return;
    end
    if not checkOwnership(res.data) then
        Industria.formspecs.IDE:coreCloseFormSpec(player_name, "Player doesn't own the Controller");
        return;
    end

    --Chiamo tutti i callback dell'IDE
    Industria.formspecs.IDE.callbacks:VariableFormCallback(player_name, fields, playerdata);
    Industria.formspecs.IDE.callbacks:OutputFormCallback(player_name, fields, playerdata);
    Industria.formspecs.IDE.callbacks:CodeFormCallback(player_name, fields, playerdata);

    --Aggiorno il formspec
    Industria.formspecs.IDE:refresh(player_name);

    if fields.quit then
        Industria.files.saveControllerCode(res.data, playerdata);
        Industria.formspecs.IDE:coreCloseFormSpec(player_name)
    end
end

--- Displays the Code Editor Formspec to the player if the player can edit or view the Unit.
---@param player_name owner Name of the user to show the formspec to.
---@param unit_code ControllerCODE The UnitCode
function Industria.formspecs.IDE:showIDE(player_name, unit_code)
    local ref = Industria.formspecs;
    local res = Industria.controllers:getController(unit_code);

    --Devo controllare se esiste l'unità richiesta
    if res.completed then
        --Controllo se il giocatore può accedere all'unità
        if res.data.protected and res.data.owner ~= player_name then
            return;
        end

        --Controllo se il giocatore stava già mostrando il Formspec dell'IDE, in tal caso non ricarico tutto il programma da zero
        if not ref:getPlayerStatus(player_name).showing
            or not (ref:getPlayerStatus(player_name).showing == self.FSKeyCode) then
            local code = Industria.files.getControllerCode(res.data) --Industria.ST.loadCode(Industria.datapath .. "/" .. res.data.reference_program);
            if not code.completed then
                --non ho trovato il codice/file: lo devo creare
                if not Industria.files.saveControllerCode(res.data, nil) then
                    return; -- Se non sono riuscito a crearlo esco
                end
                --riprovo ad aprirlo:
                code = Industria.files.getControllerCode(res.data) --Industria.ST.loadCode(Industria.datapath .. "/" .. res.data.reference_program);
                -- Se non sono riuscito di nuovo ad aprirlo
                if not code.completed then
                    return;
                end
            end
            self:updateIDEData(player_name, code.data);
        end
        self:refresh(player_name);
    else
        sendPlayerMsg(player_name, "No Unit found with Code: '" .. unit_code .. "'");
    end
end
