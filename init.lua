Industria = {};

local path = core.get_modpath("industria");
local worldmotd_path = core.get_worldpath();

dofile(path .. "/commons.lua");
dofile(path .. "/core/init.lua");
dofile(path .. "/core/STCore.lua");
dofile(path .. "/core/STFiles.lua");
dofile(path .. "/core/controllers.lua");
dofile(path .. "/gui/formspecs.lua");

Industria.datapath = worldmotd_path .. "/industriadt";
if not (core.path_exists(Industria.datapath)) then
    core.mkdir(Industria.datapath);
end
Industria.controllers:deserialize();

core.register_chatcommand("tmp", {
    func = function(name, param)

    end
});

---On exit save controllers data
core.register_on_shutdown(function()
    Industria.controllers:serialize();
end)


core.register_node("industria:plcbase", {
    description = "Base PLC",
    tiles = {
        "PLCTop.png",    -- y+
        "PLCTop.png",    -- y-
        "PLCBorder.png", -- x+
        "PLCBorder.png", -- x-
        "PLCBorder.png", -- z+
        "PLCFace.png",   -- z-
    },
    is_ground_content = false,
    groups = { dig_immediate = 2, industria_controller = 1 },
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        if clicker:is_player() then
            local meta = core.get_meta(pos);
            --Devo controllare se ho già l'id del plc
            if not meta:contains("plc_id") then
                --Se non lo ho lo faccio mettere
                core.chat_send_player(clicker:get_player_name(), "Newly created Unit: set the new ID");
                Industria.formspecs:showPLCInputID(clicker:get_player_name(), pos);
                return;
            end
            local plcid = meta:get("plc_id");
            local res = Industria.controllers:getUnit(plcid, clicker:get_player_name());
            if res.completed then
                Industria.files.saveUnitEnvironment(res.data);
            else
                core.chat_send_player(clicker:get_player_name(), res.msg);
                return;
            end
            Industria.formspecs:showEditor(clicker:get_player_name(), plcid);
        end
    end,
    after_dig_node = function(pos, oldnode, oldmetadata, digger)
        --Devo controllare se ho già l'id del plc
        if not oldmetadata.fields["plc_id"] or not oldmetadata.fields["plc_owner"] then
            --Se non lo ho non devo rimuovere nulla
            return;
        end
        local plcid = oldmetadata.fields["plc_id"];       --prendo l'id
        local plcowner = oldmetadata.fields["plc_owner"]; --prendo l'owner

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
