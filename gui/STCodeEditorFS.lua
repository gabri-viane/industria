------------------------------------------ Definition of the code editor ---------------------------------------

local FSKeyCode = "Industria:Unit:Editor";

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
    local plcid = Industria.formspecs:getPlayerStatus(player_name).data;

    local closeFS = function()
        Industria.formspecs:setPlayerStatus(player_name, nil, nil);
        core.close_formspec(player_name, FSKeyCode);
        if Industria.formspecs:getPlayerStatus(player_name).fallbackto ~= nil then
            Industria.formspecs:getPlayerStatus(player_name).fallbackto(); --Esegui il callback se presente
            Industria.formspecs:setPlayerStatusFallback(player_name, nil); --Consuma il callback
        end
    end

    if plcid == nil or not (type(plcid) == "string") then
        core.chat_send_player(player_name, "No Unit ID");
        closeFS();
        return;
    end

    if fields.saveCode then
        local unit = Industria.controllers:getUnit(plcid, player_name);
        --Salvo il codice
        if Industria.files.saveUnitCode(unit.data, fields.CodeEditor) then
            --Chiudo il formspec
            closeFS();
        else
            core.chat_send_player(player_name, "Not saved");
        end
        return;
    end
    if fields.compileCode then
        local unit = Industria.controllers:getUnit(plcid, player_name);
        --Salvo il codice
        if Industria.files.saveUnitCode(unit.data, fields.CodeEditor) then
            --Compilo
            Industria.runtime:createInterpreter(unit.data, false);
            --Chiudo il formspec
            closeFS();
        else
            core.chat_send_player(player_name, "Not saved");
        end
        return;
    end


    if fields.exitForm then
        --Chiudo il formspec
        core.close_formspec(player_name, FSKeyCode);
        Industria.formspecs:setPlayerStatus(player_name, nil, nil);
        return;
    end
end

--- Displays the Code Editor Formspec to the player
---@param playername owner Name of the user
---@param unit_id unit_id The UnitID
function Industria.formspecs:showEditor(playername, unit_id)
    local res = Industria.controllers:getUnit(unit_id, playername);

    if res.completed then
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
        self:setCurrentCallback(playername,
            function(pname, fields)
                Industria.formspecs.callbacks:STEditorCallback(pname, fields);
            end);
        self:setPlayerStatus(playername, FSKeyCode, unit_id);
        core.show_formspec(playername, FSKeyCode, STCodeEditor(code.data));
    else
        core.chat_send_player(playername, "No Unit found with ID: '" .. unit_id .. "'");
    end
end
