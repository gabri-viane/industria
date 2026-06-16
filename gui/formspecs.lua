Industria.formspecs = {
    players_status = {}, --Contiene quale form viene mostrato a quale giocatore
};

function Industria.formspecs:setPlayerStatus(playername, formspecid, data)
    if self.players_status[playername] == nil then
        self.players_status[playername] = {};
    end
    self.players_status[playername] = { showing = formspecid, data = data };
end

function Industria.formspecs:getPlayerStatus(playername)
    if self.players_status[playername] == nil then
        self.players_status[playername] = {};
        return {};
    end
    return self.players_status[playername];
end

-- Generate the formspec for code editor.
--
-- Parameters:
-- text : string : code to display in the textarea
--
-- Returns: the formspec text
local STCodeEditor = function(text)
    return table.concat({ "formspec_version[6]",
        "size[10.5,11]",
        "textarea[0.1,1;10.3,9;CodeEditor;Program Code:;", core.formspec_escape(text),
        "]",
        "button[7.4,10.1;3,0.8;saveCode;Save]",
        "button[4.2,10.1;3,0.8;cancelEdits;Undo]",
        "button_exit[8.9,0;1.6,0.8;exitForm;Exit]",
        "button[0.1,10.1;3,0.8;compileCode;Compile]" }, "");
end


local PLCIDInput = function()
    return table.concat({ "formspec_version[6]", "size[7.5,2.8]",
        "label[0.2,0.4;Insert Unit ID (must be unique for the player):]",
        "field[0.2,1.1;7,0.8;unitID;Unit ID;]", "button[4.2,2;3,0.7;setid;Set ID]",
        "button[2.1,2;2,0.7;exit;Cancel]" });
end

--Shows the formspec for code editor.
--
-- Parameters:
-- name : string : the name of the player
--
-- plc_id : string : the id of the plc to show the code of
function Industria.formspecs:showEditor(name, plc_id)
    local res = Industria.controllers:getUnit(plc_id, name);

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
        self:setPlayerStatus(name, "Industria:PLC:Editor", plc_id);
        core.show_formspec(name, "Industria:PLC:Editor", STCodeEditor(code.data));
    else
        core.chat_send_player(name, "exists as '" .. plc_id .. "'");
    end
end

---Show the formspec for inputting the ID for the Unit, it also checks if the node has group "industria_controller" as only
---the controller units can be used.
---@param name string Name of the player
---@param node_position any Position of the node (should be the Unit)
function Industria.formspecs:showPLCInputID(name, node_position)
    if node_position == nil then
        return;
    end
    local node = core.get_node_or_nil(node_position);
    --Se non è un nodo caricato allora non permetterlo
    if node == nil then
        return;
    end
    local hasGroup = core.get_node_group(node.name, "industria_controller");
    if hasGroup == nil or hasGroup == 0 then
        return; -- non è un plc
    end
    self:setPlayerStatus(name, "Industria:PLC:SetIDInput", node_position);
    core.show_formspec(name, "Industria:PLC:SetIDInput", PLCIDInput());
end

-- Contiene i callbacks per le risposte dei Formspec
-- Le funzioni dovrebbero contenere due parametri: player, fields
Industria.formspecs.callbacks = {};

--Funzione di callback per l'editor di codice ST
function Industria.formspecs.callbacks:STEditorCallback(player_name, fields)
    local plcid = Industria.formspecs:getPlayerStatus(player_name).data;

    if plcid == nil or not (type(plcid) == "string") then
        core.chat_send_player(player_name, "No PLC ID");
        Industria.formspecs:setPlayerStatus(player_name, nil, nil);
        --if true then return end;
        core.close_formspec(player_name, "Industria:PLC:Editor");
        return;
    end

    if fields.saveCode then
        local unit = Industria.controllers:getUnit(plcid, player_name);
        --Salvo il codice
        if Industria.files.saveUnitCode(unit.data, fields.CodeEditor) then
            --Chiudo il formspec
            core.close_formspec(player_name, "Industria:PLC:Editor");
            Industria.formspecs:setPlayerStatus(player_name, nil, nil);
        else
            core.chat_send_player(player_name, "Not saved");
        end
        return;
    end

    if fields.exitForm then
        --Chiudo il formspec
        core.close_formspec(player_name, "Industria:PLC:Editor");
        Industria.formspecs:setPlayerStatus(player_name, nil, nil);
        return;
    end
end

---Callback function to handle fields of the
---@param player_name string Player name
---@param fields any The fields of the formspec
function Industria.formspecs.callbacks:PLCIDInputCallback(player_name, fields)
    local node_pos = Industria.formspecs:getPlayerStatus(player_name).data;

    if node_pos == nil then
        core.chat_send_player(player_name, "No Node Position");
        Industria.formspecs:setPlayerStatus(player_name, nil, nil);
        core.close_formspec(player_name, "Industria:PLC:SetIDInput");
        return;
    end
    --Richiesto di uscire dal form senza salvare oppure nodo non esiste
    local node = core.get_node_or_nil(node_pos);
    if node == nil or fields.exit then
        Industria.formspecs:setPlayerStatus(player_name, nil, nil);
        core.close_formspec(player_name, "Industria:PLC:SetIDInput");
        return;
    else

    end

    if fields.setid then
        --Devo salvare il la unit_id nel plc_id
        --La unit_id viene scritta dal giocatore nel form
        local meta = core.get_meta(node_pos);
        if meta == nil then
            return;
        end
        --Controllo che il testo inserito non sia vuoto
        if Industria.commons.isBlank(fields.unitID) then
            core.chat_send_player(player_name, "Empty ID not permitted.");
            return;
        end

        --unit_id senza spazi bianchi
        local trimmedID = Industria.commons.strtrim(fields.unitID);

        local res = Industria.controllers:addUnit(trimmedID, player_name);
        --Unità creata
        if res.completed then
            --Salvo il codice (il file vuoto)
            if Industria.files.saveUnitCode(res.data, "") then
                --Chiudo il formspec
                core.close_formspec(player_name, "Industria:PLC:SetIDInput");
                Industria.formspecs:setPlayerStatus(player_name, nil, nil);
            else
                core.chat_send_player(player_name, "ST File not generated");
            end
            meta:set_string("plc_id", trimmedID);
            meta:set_string("plc_owner", player_name);
        else
            core.chat_send_player(player_name, "Unit already exists or is invalid.");
        end
        --Se non ho creato l'unità chiudo comunque
        core.close_formspec(player_name, "Industria:PLC:SetIDInput");
        Industria.formspecs:setPlayerStatus(player_name, nil, nil);
    end
end

core.register_on_player_receive_fields(function(player, formname, fields)
    local pname = player:get_player_name();
    local pstatus = Industria.formspecs:getPlayerStatus(pname); --Status of player

    if pstatus == nil or pstatus.showing ~= formname then
        -- Se non ho lo stato del giocatore allora sicuramente non gli stavo mostrando il formspec
        -- Oppure se quello che sto mostrando è diverso da quello che ho salvato nello stato
        core.chat_send_player(pname, "Method not available in current context");
        return;
    end
    --Se è il formspec dell'editor ST allora lo gestisco
    if formname == "Industria:PLC:Editor" then
        Industria.formspecs.callbacks:STEditorCallback(pname, fields);
    elseif formname == "Industria:PLC:SetIDInput" then
        Industria.formspecs.callbacks:PLCIDInputCallback(pname, fields);
    end
end)
