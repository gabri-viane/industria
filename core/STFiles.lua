Industria.ST.saveUnit = function(unit)
    if unit == nil or unit.reference_program == nil or unit.last_env == nil then
        return false;
    end
    local f, err = io.open(Industria.datapath .. "/" .. unit.reference_program .. ".env", "w");
    if err or f == nil then
        return false;
    end

    f:write(core.serialize(unit.last_env));
    f:flush();
    f:close();
end

Industria.ST.initUnit = function(unit, fresh_init)
    if unit == nil or unit.reference_program == nil or unit.last_env == nil then
        return false;
    end

    local code = Industria.ST.loadCode(Industria.datapath .. "/" .. unit.reference_program);
    local interpreter = Industria.ST.interpret(code);
    if interpreter == nil then
        return false;
    end
    
    Industria.controllers:setUnitInterpreter(unit, interpreter);
    interpreter:init();

    if fresh_init then
        local f, err = io.open(Industria.datapath .. "/" .. unit.reference_program .. ".env", "r");
        if err or f == nil then
            return false;
        end
        unit.last_env = core.deserialize(f:read("a"), true);
        unit.interpreter:setEnv(unit.last_env);
        f:close();
    end
    return true;
end
