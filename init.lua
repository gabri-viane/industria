Industria = {};

local path = core.get_modpath("industria");
local worldmotd_path = core.get_worldpath();

dofile(path .. "/core/init.lua");
dofile(path .. "/core/STCore.lua");
dofile(path .. "/core/STFiles.lua");
dofile(path .. "/units/controllers.lua");
dofile(path .. "/gui/formspecs.lua");

Industria.datapath = worldmotd_path .. "/industriadt";
if not (core.path_exists(Industria.datapath)) then
    core.mkdir(Industria.datapath);
end

core.register_chatcommand("create", {
    func = function(name, param)
        local res = Industria.controllers:addUnit("unittest", name);
        if res.completed then
            Industria.ST.saveUnit(res.data);
        end
        return res.completed, res.msg;
    end
});

core.register_chatcommand("edit", {
    func = function(name, param)
        local res = Industria.controllers:getUnit("unittest", name);
        if not res.completed then
            return res.completed, res.msg;
        end
        Industria.formspecs:showEditor(name, "unittest");
    end
});

core.register_on_shutdown(function()
    Industria.controllers:serialize();
end)

Industria.controllers:deserialize();