Industria = {};

Industria.path = core.get_modpath("industria");
local worldmotd_path = core.get_worldpath();

dofile(Industria.path .. "/commons.lua");
dofile(Industria.path .. "/core/init.lua");
dofile(Industria.path .. "/core/STCore.lua");
dofile(Industria.path .. "/core/STFiles.lua");
dofile(Industria.path .. "/core/controllers.lua");
dofile(Industria.path .. "/core/runtime.lua");
dofile(Industria.path .. "/gui/formspecs.lua");

Industria.datapath = worldmotd_path .. "/industriadt";
if not (core.path_exists(Industria.datapath)) then
    core.mkdir(Industria.datapath);
end


core.register_chatcommand("tmp", {
    func = function(name, param)
        core.chat_send_all(core.serialize(Industria.controllers.units));
    end
});

---On exit save controllers data
core.register_on_shutdown(function()
    Industria.runtime:saveCurrentEnv();
    Industria.controllers:serialize();
end)

core.register_node("industria:baseunit", {
    description = "Base PLC",
    --[[tiles = {
        "PLCTop.png",    -- y+
        "PLCTop.png",    -- y-
        "PLCBorder.png", -- x+
        "PLCBorder.png", -- x-
        "PLCBorder.png", -- z+
        "PLCFace.png",   -- z-
    },]]
    drawtype = "mesh",
    mesh = "BaseModelController.glb",
    tiles = { "BaseControllerTexture.png" },
    node_box = {
        type = "fixed",
        fixed = {
            { -1 / 16, -4.5 / 16, 8 / 16,
                1 / 16, 0.5 / 16, 2 / 16 },
        }
    },
    paramtype2 = "facedir",
    is_ground_content = false,
    groups = { dig_immediate = 2, industria_controller = 1 },
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        if clicker:is_player() then
            local meta = core.get_meta(pos);
            --Devo controllare se ho già l'id del unit
            if not meta:contains("unit_id") then
                --Se non lo ho lo faccio mettere
                core.chat_send_player(clicker:get_player_name(), "Newly created Unit: set the new ID");
                Industria.formspecs:showPLCInputID(clicker:get_player_name(), pos);
                return;
            end
            local plcid = meta:get("unit_id");
            local res = Industria.controllers:getUnit(plcid, clicker:get_player_name());
            if res.completed then
                Industria.files.saveUnitEnvironment(res.data);
            else
                core.chat_send_player(clicker:get_player_name(), res.msg);
                return;
            end
            Industria.formspecs:showUnitMainForm(clicker:get_player_name(), plcid);
        end
    end,
    after_dig_node = function(pos, oldnode, oldmetadata, digger)
        --Devo controllare se ho già l'id del unit
        if not oldmetadata.fields["unit_id"] or not oldmetadata.fields["unit_owner"] then
            --Se non lo ho non devo rimuovere nulla
            return;
        end
        local plcid = oldmetadata.fields["unit_id"];       --prendo l'id
        local plcowner = oldmetadata.fields["unit_owner"]; --prendo l'owner

        local res = Industria.controllers:removeController(plcid, plcowner);
        if digger:is_player() then
            if res.completed then
                core.chat_send_player(digger:get_player_name(), "Unit removed");
            else
                core.chat_send_player(digger:get_player_name(), res.msg);
            end
        end
    end
});

local loadres = Industria.controllers:deserialize();

if not loadres.completed then
    core.chat_send_all(loadres.msg);
else
    core.chat_send_all("Controllers loaded");
end
