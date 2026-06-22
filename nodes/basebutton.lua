local function on_rightclick_callback(pos, node, clicker, itemstack, pointed_thing)
    if clicker:is_player() and clicker:get_player_control().sneak then
        return;
    end
    local current_node = core.get_node_or_nil(pos);
    if current_node == nil then
        return;
    end

    if current_node.name == "industria:basebutton" then

        local metainf = core.get_meta(pos);

        local link = metainf:get_string("industria:io:input:linked");

        core.swap_node(pos,
            { name = "industria:basebutton_pressed", param1 = current_node.param1, param2 = current_node.param2 });
        core.after(1, function()
            local node_back = core.get_node_or_nil(pos);
            if node_back == nil or node_back.name ~= "industria:basebutton_pressed" then
                return;
            end
            core.swap_node(pos,
                { name = "industria:basebutton", param1 = current_node.param1, param2 = current_node.param2 });
        end)
    end
    return itemstack;
end

core.register_node("industria:basebutton_pressed", {
    description = "Base Button",
    drawtype = "mesh",
    mesh = "BaseButtonModel_pressed.glb",
    tiles = { "ButtonTexture_pressed.png" },
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
    groups = { dig_immediate = 2, industria_signal = 1 },
    on_rightclick = on_rightclick_callback
});

core.register_node("industria:basebutton", {
    description = "Base Button",
    drawtype = "mesh",
    mesh = "BaseButtonModel.glb",
    tiles = { "ButtonTexture.png" },
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
    groups = { dig_immediate = 2, industria_signal = 1 },
    on_rightclick = on_rightclick_callback
});
