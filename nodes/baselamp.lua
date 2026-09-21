function Industria.register_base_lamp(def)
    local def_texture_off = "industria_baselamp_off.png"
    local def_texture_on = "industria_baselamp_on.png"
    if def.material == nil then
        def.material = "unknwon"
    end

    if def.texture == nil then
        def.texture = { on = def_texture_on, off = def_texture_off };
    else
        if def.texture.off == nil then
            def.texture.off = def_texture_off;
        end
        if def.texture.on == nil then
            def.texture.on = def_texture_on;
        end
    end
    local nodename_on = "industria:baselamp_" .. def.material
    local nodename_off = nodename_on .. "_off"
    nodename_on = nodename_on .. "_on"

    --local box = { type = "fixed", fixed = { { 2 / 16, -8 / 16, -1.5 / 16, -2 / 16, -6 / 16, 1.5 / 16 } } }

    local nodedef_on = {
        description = "Lamp [" .. def.material .. "]",
        drawtype = "mesh",
        mesh = "industria_baselamp.glb",
        tiles = { def.texture.on },
        drop = nodename_off,
        --node_box = box,
        --selection_box = box,
        paramtype = "light",
        light_source = 13,
        paramtype2 = "wallmounted",
        is_ground_content = false,
        industria_props = { is_lamp = true, lighted = true, material = def.material },
        groups = { dig_immediate = 2, not_in_creative_inventory = 1 }
    };

    local nodedef_off = {
        description = "Lamp [" .. def.material .. "]",
        drawtype = "mesh",
        mesh = "industria_baselamp.glb",
        tiles = { def.texture.off },
        drop = nodename_off,
        --node_box = box,
        --selection_box = box,
        paramtype = "light",
        light_source = 0,
        paramtype2 = "wallmounted",
        is_ground_content = false,
        industria_props = { is_lamp = true, lighted = true, material = def.material },
        groups = { dig_immediate = 2 }
    };

    Industria.IOStatesBuilder("industria:baselamp")
        :addState("lighted")
        :generateOutputFunction(function(iounit, value)
            local node = core.get_node_or_nil(iounit.pos_block)
            if not node or node.name == "ignore" then
                return
            end
            if value and node.name ~= nodename_on then
                node.name = nodename_on
                core.swap_node(iounit.pos_block, node)
            elseif not value and node.name ~= nodename_off then
                node.name = nodename_off
                core.swap_node(iounit.pos_block, node)
            end
        end, "BOOL")
        :build()
        :register()


    Industria.registerIOUnitNode("industria:baselamp", nodename_on, nodedef_on)
    Industria.registerIOUnitNode("industria:baselamp", nodename_off, nodedef_off)
end

Industria.register_base_lamp({
    material = "default"
});
