---comment
---@param player_name any
---@param fields any
---@param playerdata IDEData
function Industria.formspecs.IDE.callbacks:OptionsFormCallback(player_name, fields, playerdata)
    if fields.save then
        local unit = Industria.controllers:getController(playerdata.ctrl_code);
        if not unit.completed then
            table.insert(playerdata.output, "[WARN] The controller was not found");
        else
            table.insert(playerdata.output, "[INFO] The controller data has been saved");
            Industria.files.saveControllerCode(unit.data, playerdata);
        end
        Industria.formspecs.IDE:updateIDEData(player_name, playerdata);
    end

    if fields.build then
        local unit = Industria.controllers:getController(playerdata.ctrl_code);
        if not unit.completed then
            table.insert(playerdata.output, "[WARN] The controller was not found");
        else
            Industria.files.saveControllerCode(unit.data, playerdata);
            local res = Industria.ST.interpCode(playerdata, playerdata.ctrl_code, unit.data, true);
            if not res.completed then
                table.insert(playerdata.output, "[ERR] Error generating code: "..res.msg);
            else
                table.insert(playerdata.output, "[INFO] The code has been succesfully built");
            end
        end
        Industria.formspecs.IDE:updateIDEData(player_name, playerdata);
    end

    if fields.buildanddownload then
        local unit = Industria.controllers:getController(playerdata.ctrl_code);
        if not unit.completed then
            table.insert(playerdata.output, "[WARN] The controller was not found");
        else
            Industria.files.saveControllerCode(unit.data, playerdata);
            local res = Industria.runtime:createInterpreter(unit.data, false);
            if not res.completed then
                table.insert(playerdata.output, "[ERR] Error generating code: "..res.msg);
            else
                table.insert(playerdata.output, "[INFO] The code has been succesfully built and downloaded");
            end
        end
        Industria.formspecs.IDE:updateIDEData(player_name, playerdata);
    end
end
