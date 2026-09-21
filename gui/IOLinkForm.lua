------------------------------------------ Definition of the IO Link Form ---------------------------------------

local FSKeyCode = "Industria:Unit:IOLinkForm";
local coreCloseFormSpec = core.close_formspec;
local coreShowFormSpec = core.show_formspec;
local sendPlayerMsg = core.chat_send_player;

--- Main form for a IOLinker, displays the link's confirmation panel.
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
        "image_button[2,1;1.5,0.75;industria_button_link_io.png;linkButton;Link;false;true;]",
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
    local playerdata = Industria.formspecs:getPlayerStatus(player_name).data;
    local pos_unit = playerdata.unit
    local pos_iounit = playerdata.iounit

    local closeFS = function(message)
        if message ~= nil then
            sendPlayerMsg(player_name, message);
        end
        Industria.formspecs:setPlayerStatus(player_name, nil, nil);
        coreCloseFormSpec(player_name, FSKeyCode);
    end

    if pos_unit == nil or pos_iounit == nil then
        closeFS("No Unit or IOUnit to handle");
        return;
    end

    if fields.removeIOUnit then
        return;
    end

    if fields.removeIOController then
        return;
    end

    if fields.linkButton then
        local resunit = Industria.units.isValidUnit(pos_unit, nil);
        local unit = resunit.data;
        if not resunit.completed or not unit then
            closeFS("Selected Unit is invalid");
            return;
        end
        if unit.owner ~= player_name then
            closeFS("Selected Unit is not owned by the player");
            return;
        end
        local iounit_code = Industria.iounits.getIOUnitCode(pos_iounit);
        if not iounit_code then
            closeFS("Couldn't find selected IOUnit");
            return;
        end
        local res = Industria.iounits:getIOUnit(iounit_code);
        local iounit = res.data;
        if not res.completed or not iounit then
            closeFS("Selected IOUnit is invalid");
            return;
        end
        if iounit.owner ~= player_name then
            closeFS("Selected IOUnit is not owned by the player");
            return;
        end

        closeFS();
        Industria.formspecs:showIOLinkVariableForm(player_name, unit, iounit);
        Industria.formspecs:setPlayerStatusFallback(player_name, function()
            --Una volta chiuso la gestione variabili torna alla pagina principale
            Industria.formspecs:showIOLinkForm(player_name, pos_unit, pos_iounit);
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
