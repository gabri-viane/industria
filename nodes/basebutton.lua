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
                { name = "industria:basebutton", param1 = current_node.param1, param2 = current_node.param2 });
        end)
    end
    return itemstack;
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
        paramtype = "light",
        paramtype2 = "wallmounted",
        is_ground_content = false,
        industria_props = { is_button = true, is_pressed = true },
        groups = { dig_immediate = 2, industria_signal_digital = 1, industria_iounit = 1 },
        on_rightclick = on_rightclick_callback
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
        paramtype = "light",
        paramtype2 = "wallmounted",
        is_ground_content = false,
        industria_props = { is_button = true, is_pressed = false },
        groups = { dig_immediate = 2, industria_signal_digital = 1, industria_iounit = 1 },
        on_rightclick = on_rightclick_callback
    });
end

Industria.register_digital_button({
    material = "default"
});
