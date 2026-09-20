local function on_rightclick_callback(pos, node, clicker, itemstack, pointed_thing)
    if clicker:is_player() and clicker:get_player_control().sneak then
        return;
    end
    local current_node = core.get_node_or_nil(pos);
    if current_node == nil then
        return;
    end

    local node_def = core.registered_nodes[current_node.name];
    local ind_props = node_def.industria_props;
    if ind_props == nil then
        return itemstack;
    end

    if ind_props.is_button and not ind_props.is_pressed then
        local metainf = core.get_meta(pos);

        --TODO: gestire il segnale se è stato linkato
        local link = metainf:get_string("industria:io:input:linked");

        core.swap_node(pos,
            { name = node_def.name .. "_pressed", param1 = current_node.param1, param2 = current_node.param2 });
        core.after(1, function()
            local node_back = core.get_node_or_nil(pos);
            if node_back == nil or node_back.name ~= node_def.name .. "_pressed" then
                return;
            end
            core.swap_node(pos,
                { name = node_def.name, param1 = current_node.param1, param2 = current_node.param2 });
        end)
    end
    return itemstack;
end

local function after_dig_callback(pos, oldnode, oldmetadata, digger)
    local iounit_code = Industria.iounits.getIOUnitCode(pos)
    if not iounit_code then
        return;
    end
    local res = Industria.iounits:getIOUnit(iounit_code)
    --Devo controllare se esiste l'IOUnit
    if not res.completed then
        --Se non la ho non devo rimuovere nulla
        return;
    end
    local iounit = res.data
    if not iounit then
        --Se non lo ho non devo rimuovere nulla
        return;
    end
    local playername = ""
    if digger:is_player() then
        playername = digger:get_player_name()
    end
    local res2 = Industria.iounits:unregisterIOUnit(iounit_code, playername)
    if res2.completed then
        core.chat_send_player(iounit.owner,
            "The IOUnit at position (" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ") has been removed.");
    elseif digger:is_player() then
        core.chat_send_player(playername, res.msg);
    end
end

local function after_place_callback(pos, placer, itemstack, pointed_thing)
    if placer and placer:is_player() then
        --Registro l'IOUnit
        Industria.iounits:registerIOUnit(placer:get_player_name(), pos)
        local node = core.get_node_or_nil(pos)
        --[[  if node then
            local res = Industria.iounits.getAvailableStates(node.name)
            if res.completed then
                core.chat_send_player(placer:get_player_name(), table.concat(res.data,", "))
            else
                core.chat_send_player(placer:get_player_name(), res.msg)
            end
        end ]]
    end
    return false --Consuma l'oggetto
end


function Industria.register_digital_button(def)
    if def.material == nil then
        def.material = "unknwon"
    end

    if def.texture == nil then
        def.texture = { default = "BaseButton.png", pressed = "BaseButton.png" };
    else
        if def.texture.default == nil then
            def.texture.default = "BaseButton.png";
        end
        if def.texture.pressed == nil then
            def.texture.pressed = "BaseButton.png";
        end
    end

    core.register_node("industria:digibutton_" .. def.material .. "_pressed", {
        description = "Digital Button [" .. def.material .. "]",
        drawtype = "mesh",
        mesh = "BaseButtonModel_pressed.glb",
        tiles = { def.texture.pressed },
        drop = "industria:digibutton_" .. def.material,
        node_box = {
            type = "fixed",
            fixed = {
                { 2 / 16, -8 / 16, -1.5 / 16,
                    -2 / 16, -6 / 16, 1.5 / 16 },
            }
        },
        selection_box = {
            type = "fixed",
            fixed = {
                { 2 / 16, -8 / 16, -1.5 / 16,
                    -2 / 16, -6 / 16, 1.5 / 16 },
            }
        },
        paramtype = "light",
        paramtype2 = "wallmounted",
        is_ground_content = false,
        industria_props = { is_button = true, states = { pressed = { value = 1, iotype = 0, dtype = "BOOL" } }, material = def.material },
        groups = { dig_immediate = 2, industria_signal_digital = 1, industria_iounit = 1, not_in_creative_inventory = 1 },
        on_rightclick = on_rightclick_callback,
        after_dig_node = after_dig_callback
    });

    core.register_node("industria:digibutton_" .. def.material, {
        description = "Digital Button [" .. def.material .. "]",
        drawtype = "mesh",
        mesh = "BaseButtonModel.glb",
        tiles = { def.texture.default },
        node_box = {
            type = "fixed",
            fixed = {
                { 2 / 16, -8 / 16, -1.5 / 16,
                    -2 / 16, -6 / 16, 1.5 / 16 },
            }
        },
        selection_box = {
            type = "fixed",
            fixed = {
                { 2 / 16, -8 / 16, -1.5 / 16,
                    -2 / 16, -6 / 16, 1.5 / 16 },
            }
        },
        paramtype = "light",
        paramtype2 = "wallmounted",
        is_ground_content = false,
        industria_props = { is_button = true, states = { pressed = { value = 0, iotype = 0, dtype = "BOOL" } }, material = def.material },
        groups = { dig_immediate = 2, industria_signal_digital = 1, industria_iounit = 1 },
        on_rightclick = on_rightclick_callback,
        after_dig_node = after_dig_callback,
        after_place_node = after_place_callback
    });
end

Industria.register_digital_button({
    material = "default"
});
