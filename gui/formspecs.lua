Industria.formspecs = {
    players_status = {},
};

local codeEditor = function(text)
    return table.concat({ "formspec_version[6]",
        "size[10.5,11]",
        "textarea[0.1,1;10.3,9;CodeEditor;Program Code:;", core.formspec_escape(text),
        "]",
        "button[7.4,10.1;3,0.8;saveCode;Save]",
        "button[4.2,10.1;3,0.8;cancelEdits;Undo]",
        "button_exit[8.9,0;1.6,0.8;exitForm;Exit]",
        "button[0.1,10.1;3,0.8;compileCode;Compile]" }, "");
end

function Industria.formspecs:showEditor(name, plc_id)
    if self.players_status[name] == nil then
        self.players_status[name] = {};
    end

    local res = Industria.controllers:getUnit(plc_id, name)

    if res.completed then
        local code = Industria.ST.loadCode(Industria.datapath .. "/" .. res.data.reference_program);
        self.players_status[name] = plc_id;
        core.show_formspec(name, "Industria:PLC:Editor", codeEditor(code));
    end
end

core.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "Industria:PLC:Editor" then
        return
    end

    if fields.saveCode then
        local unit = Industria.controllers:getUnit("unittest", player:get_player_name());

        local f, err = io.open(Industria.datapath .. "/" .. unit.data.reference_program, "w");
        if err or f == nil then
            return false, "Errore";
        end
        f:write(fields.CodeEditor);
        f:flush();
        f:close();
        core.close_formspec(player:get_player_name(), "Industria:PLC:Editor");
        return;
    end

    if fields.exitForm then
        core.close_formspec(player:get_player_name(), "Industria:PLC:Editor");
        return;
    end
end)
