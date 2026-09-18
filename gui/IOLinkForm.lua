------------------------------------------ Definition of the IO Link Form ---------------------------------------

local FSKeyCode = "Industria:Unit:IOLinkForm";
local coreCloseFormSpec = core.close_formspec;
local coreShowFormSpec = core.show_formspec;
local sendPlayerMsg = core.chat_send_player;

--- Main form for a IOLinker, displays the link's options.
---@param unit_mesh_and_texture table Name of the registered node of the Unit
---@param iounit_mesh_and_texture table Name of the registered node of the IOUnit
---@return string #The formspec
local IOLinkForm = function(unit_mesh_and_texture, iounit_mesh_and_texture)
    --local iounitnode = core.registered_nodes[iounit_name]

    local iounit_model_name = unit_mesh_and_texture[1]
    local iounit_texture_name = unit_mesh_and_texture[2]

    local unit_model_name = iounit_mesh_and_texture[1]
    local unit_texture_name = iounit_mesh_and_texture[2]

    local form = { "formspec_version[6]",
        "size[5.5,3]",
        "label[0.35,0.35;Link the two selected Units]",
        --"button[6,0;1.5,0.5;close;Close]",
        "model[0.5,0.75;1.5,1.5;iounit_model;", iounit_model_name, ";", iounit_texture_name, ";-30,30;false;true;;0]",
        "button[0.5,2.25;1.25,0.5;removeIOUnit;Remove]",
        "image_button[2,1;1.5,0.75;link_io.png;linkButton;Link;false;true;]",
        "model[3.75,0.75;1.5,1.5;unit_model;", unit_model_name, ";", unit_texture_name, ";-30,30;false;true;;0]",
        "button[3.75,2.25;1.25,0.5;removeIOController;Remove]",
        --"button[5.2,1.2;2,0.7;linkVariables;Link Variables]"
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
            sendPlayerMsg(player_name, message);
        end
        Industria.formspecs:setPlayerStatus(player_name, nil, nil);
        coreCloseFormSpec(player_name, FSKeyCode);
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
            sendPlayerMsg(player_name, core.colorize("orange", res.msg));
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
        coreCloseFormSpec(player_name, FSKeyCode);
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
---@param pos_unit any The position of the unit saved int the IOLinker
---@param pos_iounit any The position of the IO unit saved int the IOLinker
function Industria.formspecs:showIOLinkForm(playername, pos_unit, pos_iounit)
    local unit_node_simple = core.get_node_or_nil(pos_unit)
    if unit_node_simple == nil then
        sendPlayerMsg(playername, core.colorize("red", "The Unit couldn't not be found: maybe it's not loaded."));
        return;
    end

    local iounit_node_simple = core.get_node_or_nil(pos_iounit)
    if iounit_node_simple == nil then
        sendPlayerMsg(playername, core.colorize("red", "The IOUnit couldn't not be found: maybe it's not loaded."));
        return;
    end

    local res = Industria.units.isValidUnit(pos_unit, nil);

    if res.completed and res.data ~= nil then
        --Prendo il Node per prendere il mesh e la texture da usare nel formspec
        local unitnode = core.registered_nodes[unit_node_simple.name]
        local unit_model = unitnode.mesh
        local unit_texture = unitnode.tiles[1]

        --Prendo il Node per prendere il mesh e la texture da usare nel formspec
        local iounitnode = core.registered_nodes[iounit_node_simple.name]
        local iounit_model = iounitnode.mesh
        local iounit_texture = iounitnode.tiles[1]

        --Devo controllare se l'unità è protetta
        if res.data.protected and playername ~= res.data.owner then
            sendPlayerMsg(playername, core.colorize("red", "You have no access to the unit."));
            return;
        end

        self:setCurrentCallback(playername,
            function(pname, fields)
                Industria.formspecs.callbacks:IOLinkFormCallback(pname, fields);
            end);
        self:setPlayerStatus(playername, FSKeyCode, { unit = pos_unit, iounit = pos_iounit });
        coreShowFormSpec(playername, FSKeyCode,
            IOLinkForm({ unit_model, unit_texture }, { iounit_model, iounit_texture })
        );
    else
        sendPlayerMsg(playername, core.colorize("red", "The selected block is not a valid Unit"));
    end
end
