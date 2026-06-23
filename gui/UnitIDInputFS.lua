------------------------------------------ Definition of the Unit ID Input ---------------------------------------

local FSKeyCode = "Industria:Unit:SetIDInput";
local coreCloseFormSpec = core.close_formspec;
local sendPlayerMsg = core.chat_send_player;

--- Generate the formspec for inputting the Unit  ID.
---@return string #The formspec
local PLCIDInput = function()
    return table.concat({ "formspec_version[6]", "size[7.5,2.8]",
        "label[0.2,0.4;Insert Unit ID (must be unique for the player):]",
        "field[0.2,1.1;7,0.8;unitID;Unit ID;]", "button[4.2,2;3,0.7;setid;Set ID]",
        "button[2.1,2;2,0.7;exit;Cancel]" });
end

--- Callback function to handle fields of the "Set Unit ID" form
---@param player_name string Player name
---@param fields any The fields of the formspec
function Industria.formspecs.callbacks:PLCIDInputCallback(player_name, fields)
    local node_pos = Industria.formspecs:getPlayerStatus(player_name).data;

    if node_pos == nil then
        sendPlayerMsg(player_name, "No Node Position");
        Industria.formspecs:setPlayerStatus(player_name, nil, nil);
        coreCloseFormSpec(player_name, FSKeyCode);
        return;
    end
    --Richiesto di uscire dal form senza salvare oppure nodo non esiste
    local node = core.get_node_or_nil(node_pos);
    if node == nil or fields.exit then
        Industria.formspecs:setPlayerStatus(player_name, nil, nil);
        coreCloseFormSpec(player_name, FSKeyCode);
        return;
    else

    end

    if fields.setid or fields.key_enter_field == "unitID" then
        --Devo salvare il la unit_id nel plc_id
        --La unit_id viene scritta dal giocatore nel form
        local meta = core.get_meta(node_pos);
        if meta == nil then
            return;
        end
        --Controllo che il testo inserito non sia vuoto
        if Industria.commons.isBlank(fields.unitID) then
            sendPlayerMsg(player_name, "Empty ID not permitted.");
            return;
        end

        --unit_id senza spazi bianchi
        local trimmedID = Industria.commons.strtrim(fields.unitID);

        local res = Industria.controllers:addUnit(trimmedID, player_name);
        --Unità creata
        if res.completed then
            --Salvo il codice (il file con template di un programma)
            if Industria.files.saveUnitCode(res.data, Industria.files.STtemplate) then
                --Chiudo il formspec
                coreCloseFormSpec(player_name, FSKeyCode);
                Industria.formspecs:setPlayerStatus(player_name, nil, nil);
                --Registro a runtime l'unità
                Industria.runtime:registerToRuntime(res.data);
            else
                sendPlayerMsg(player_name, "ST File not generated");
            end
            meta:set_string("unit_id", trimmedID);
            meta:set_string("unit_owner", player_name);
        else
            sendPlayerMsg(player_name, "Unit already exists or is invalid.");
        end
        --Se non ho creato l'unità chiudo comunque
        coreCloseFormSpec(player_name, FSKeyCode);
        Industria.formspecs:setPlayerStatus(player_name, nil, nil);
    end
end

--- Show the formspec for inputting the ID for the Unit, it also checks if the node has group "industria_controller" as only
--- the controller units can be used.
---@param player_name string Name of the player
---@param node_position any Position of the node (should be the Unit)
function Industria.formspecs:showPLCInputID(player_name, node_position)
    if node_position == nil then
        return;
    end
    local node = core.get_node_or_nil(node_position);
    -- Se non è un nodo caricato allora non permetterlo
    if node == nil then
        return;
    end
    local hasGroup = core.get_node_group(node.name, "industria_controller");
    if hasGroup == nil or hasGroup == 0 then
        return; -- non è un plc
    end
    self:setCurrentCallback(player_name,
        function(pname, fields)
            Industria.formspecs.callbacks:PLCIDInputCallback(pname, fields);
        end);
    self:setPlayerStatus(player_name, FSKeyCode, node_position);
    coreCloseFormSpec(player_name, FSKeyCode, PLCIDInput());
end
