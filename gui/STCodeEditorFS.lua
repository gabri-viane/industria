------------------------------------------ Definition of the code editor ---------------------------------------

local FSKeyCode = "Industria:Unit:Editor";
local coreCloseFormSpec = core.close_formspec;
local sendPlayerMsg = core.chat_send_player;

--- Generate the formspec for code editor.
---@param text string #The content to display in the editor
---@return string #The formspec editor
local STCodeEditor = function(text)
    return table.concat({ "formspec_version[6]",
        "size[10.5,11]",
        "textarea[0.1,1;10.3,9;CodeEditor;Program Code:;", core.formspec_escape(text), "]",
        "button[7.4,10.1;3,0.8;saveCode;Save]",
        "button[4.2,10.1;3,0.8;cancelEdits;Undo]",
        "button_exit[8.9,0;1.6,0.8;exitForm;Exit]",
        "button[0.1,10.1;3,0.8;compileCode;Compile]" }, "");
end

--Funzione di callback per l'editor di codice ST
function Industria.formspecs.callbacks:STEditorCallback(player_name, fields)
    local unitcode = Industria.formspecs:getPlayerStatus(player_name).data;

    local closeFS = function()
        Industria.formspecs:setPlayerStatus(player_name, nil, nil);
        coreCloseFormSpec(player_name, FSKeyCode);
        if Industria.formspecs:getPlayerStatus(player_name).fallbackto ~= nil then
            Industria.formspecs:getPlayerStatus(player_name).fallbackto(); --Esegui il callback se presente
            Industria.formspecs:setPlayerStatusFallback(player_name, nil); --Consuma il callback
        end
    end

    ---Controlla di chi è l'unità
    ---@param unit Unit
    ---@return boolean #Se true allora il giocatore può gestire l'unità
    local checkOwnership = function(unit)
        if unit.protected and unit.owner ~= player_name then
            return false;
        end
        return true;
    end

    if unitcode == nil or not (type(unitcode) == "string") then
        core.chat_send_player(player_name, "No Unit Code");
        closeFS();
        return;
    end

    if fields.saveCode then
        local unit = Industria.controllers:getUnit(unitcode);
        --Controllo se il giocatore può accedere all'unità
        if not checkOwnership(unit.data) then
            closeFS();
            return;
        end
        --Salvo il codice
        if Industria.files.saveUnitCode(unit.data, fields.CodeEditor) then
            --Chiudo il formspec
            closeFS();
        else
            sendPlayerMsg(player_name, "Not saved");
        end
        return;
    end
    if fields.compileCode then
        local unit = Industria.controllers:getUnit(unitcode);
        --Controllo se il giocatore può accedere all'unità
        if not checkOwnership(unit.data) then
            closeFS();
            return;
        end
        --Salvo il codice
        if Industria.files.saveUnitCode(unit.data, fields.CodeEditor) then
            --Compilo
            Industria.runtime:createInterpreter(unit.data, false);
            --Chiudo il formspec
            closeFS();
        else
            sendPlayerMsg(player_name, "Not saved");
        end
        return;
    end


    if fields.exitForm then
        --Chiudo il formspec
        coreCloseFormSpec(player_name, FSKeyCode);
        Industria.formspecs:setPlayerStatus(player_name, nil, nil);
        return;
    end
end

--- Displays the Code Editor Formspec to the player if the player can edit or view the Unit.
---@param player_name owner Name of the user to show the formspec to.
---@param unit_code unit_code The UnitCode
function Industria.formspecs:showEditor(player_name, unit_code)
    local res = Industria.controllers:getUnit(unit_code);

    if res.completed then
        --Controllo se il giocatore può accedere all'unità
        if res.data.protected and res.data.owner ~= player_name then
            return;
        end

        local code = Industria.ST.loadCode(Industria.datapath .. "/" .. res.data.reference_program);
        if not code.completed then
            --non ho trovato il codice/file: lo devo creare
            if not Industria.files.saveUnitCode(res.data, "") then
                return; -- Se non sono riuscito a crearlo esco
            end
            --riprovo ad aprirlo:
            code = Industria.ST.loadCode(Industria.datapath .. "/" .. res.data.reference_program);
            -- Se non sono riuscito di nuovo ad aprirlo
            if not code.completed then
                return;
            end
        end
        self:setCurrentCallback(player_name,
            function(pname, fields)
                Industria.formspecs.callbacks:STEditorCallback(pname, fields);
            end);
        self:setPlayerStatus(player_name, FSKeyCode, unit_code);
        coreCloseFormSpec(player_name, FSKeyCode, STCodeEditor(code.data));
    else
        sendPlayerMsg(player_name, "No Unit found with Code: '" .. unit_code .. "'");
    end
end
