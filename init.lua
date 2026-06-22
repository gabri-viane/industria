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
dofile(Industria.path .. "/nodes/init.lua");

Industria.datapath = worldmotd_path .. "/industriadt";
if not (core.path_exists(Industria.datapath)) then
    core.mkdir(Industria.datapath);
end


core.register_chatcommand("tmp", {
    func = function(name, param)
        core.chat_send_all(core.serialize(Industria.controllers.units));
    end
});

---Saves all the mods data
local saveFun = function()
    Industria.runtime:saveCurrentEnv();
    Industria.controllers:serialize();
end

---On exit save controllers data
core.register_on_shutdown(function()
    saveFun();
end)

local programm_save;
programm_save = function()
    core.after(120, function()
        saveFun();
        programm_save();
    end);
end

programm_save();




local loadres = Industria.controllers:deserialize();

if not loadres.completed then
    core.chat_send_all(loadres.msg);
else
    core.chat_send_all("Controllers loaded");
end
