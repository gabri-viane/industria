local function on_rightclick_callback(pos, node, clicker, itemstack, pointed_thing)
    if clicker:is_player() and clicker:get_player_control().sneak then
        return;
    end
    local current_node = core.get_node_or_nil(pos);
    if current_node == nil or current_node.name == "ignore" then
        return;
    end

    local node_def = core.registered_nodes[current_node.name];
    local ind_props = node_def.industria_props;
    if ind_props == nil then
        return itemstack;
    end

    if not ind_props.pressed then
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

function Industria.register_digital_button(def)
    local def_texture = "industria_base_button.png"
    if def.material == nil then
        def.material = "unknwon"
    end

    if def.texture == nil then
        def.texture = { default = def_texture, pressed = def_texture };
    else
        if def.texture.default == nil then
            def.texture.default = def_texture;
        end
        if def.texture.pressed == nil then
            def.texture.pressed = def_texture;
        end
    end
    local nodename = "industria:digibutton_" .. def.material
    local nodename_pressed = nodename .. "_pressed"

    local box = { type = "fixed", fixed = { { 2 / 16, -8 / 16, -1.5 / 16, -2 / 16, -6 / 16, 1.5 / 16 } } }

    local nodedef_pressed = {
        description = "Digital Button [" .. def.material .. "]",
        drawtype = "mesh",
        mesh = "industria_digibutton_pressed.glb",
        tiles = { def.texture.pressed },
        drop = nodename,
        node_box = box,
        selection_box = box,
        paramtype = "light",
        paramtype2 = "wallmounted",
        is_ground_content = false,
        industria_props = { is_button = true, pressed = true, material = def.material },
        groups = { dig_immediate = 2, not_in_creative_inventory = 1 },
        on_rightclick = on_rightclick_callback
    };

    local nodedef = {
        description = "Digital Button [" .. def.material .. "]",
        drawtype = "mesh",
        mesh = "industria_digibutton.glb",
        drop = nodename,
        tiles = { def.texture.default },
        node_box = box,
        selection_box = box,
        paramtype = "light",
        paramtype2 = "wallmounted",
        is_ground_content = false,
        industria_props = { is_button = true, pressed = false, material = def.material },
        groups = { dig_immediate = 2, },
        on_rightclick = on_rightclick_callback
    };

    Industria.IOStatesBuilder("industria:basebutton")
        :addState("pressed")
        :generateInputFunction(function(iounit)
            local node = core.get_node_or_nil(iounit.pos_block)
            if not node or node.name == "ignore" then
                return false
            end
            local _def = core.registered_nodes[node.name]
            return _def and _def.industria_props and _def.industria_props.pressed
        end, "BOOL")
        :build()
        :register()


    Industria.registerIOUnitNode("industria:basebutton", nodename, nodedef)
    Industria.registerIOUnitNode("industria:basebutton", nodename_pressed, nodedef_pressed)
end

Industria.register_digital_button({
    material = "default"
});
