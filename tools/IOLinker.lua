core.register_tool("industria:iolinker",
    {
        short_description = "IO Linker",
        description = "The IO Linker permits to link IO modules to a Control Unit",
        inventory_image = "IOLinker.png",
        tool_capabilities = {
        },
        node_placement_prediction = nil,
        on_place = function(itemstack, placer, pointed_thing)
            if itemstack == nil or itemstack:get_name() ~= "industria:iolinker" then
                return itemstack;
            end
            if pointed_thing.type ~= "node" then
                return itemstack;
            end

            -- Get the position of the clicked block
            local pos_under = pointed_thing.under

            -- Get the node definition
            local node_under = core.get_node(pos_under);

            local is_controller = core.get_item_group(node_under.name, "industria_controller");
            local is_iounit = core.get_item_group(node_under.name, "industria_iounit");

            if is_controller > 0 or is_iounit > 0 then
                if is_controller > 0 then
                    itemstack:get_meta():set_string("industria:io:link:first", core.serialize(pos_under));
                end
                if is_iounit > 0 then
                    itemstack:get_meta():set_string("industria:io:link:second", core.serialize(pos_under));
                end

                local first = itemstack:get_meta():get("industria:io:link:first");
                local second = itemstack:get_meta():get("industria:io:link:second");

                if first ~= nil and first ~= "" and second ~= nil and second ~= "" then
                    core.chat_send_player(placer:get_player_name(), "Linked");
                    itemstack:get_meta():set_string("industria:io:link:first", "");
                    itemstack:get_meta():set_string("industria:io:link:second", "");
                end
            else
                itemstack:get_meta():set_string("industria:io:link:first", "");
                itemstack:get_meta():set_string("industria:io:link:second", "");
            end
            return itemstack -- Don't consume the item
        end
    })
