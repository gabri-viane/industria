local fnresult = Industria.commons.fnresult;

Industria.files.STtemplate =
"(* ============================================================\n   Usage Example: Variable declaration + instructions\n   ============================================================ *)\n\nPROGRAM TemplateProgram\n\nVAR\n    (* Variables here *)\n    counter      : INT   := 0;\n    realNumber      : REAL   := 0;\n    SensorInput :  BOOL := 0;\nEND_VAR\nrealNumber := realNumber+0.1;\nIF SensorInput THEN\n	counter := counter +1;\n    PRINT('VALUE:');\n    PRINT(counter);\nEND_IF\n\nEND_PROGRAM";


Industria.files.saved = {}

---Get's filename from controller
---@param controller Controller
---@return string
Industria.files.getFilename = function(controller)
    return Industria.datapath .. "/" .. controller.reference_program
end

---Writes out the Unit Code (ST File) to the file referenced by: unit.reference_program
---@param unit Controller
---@param editorCode IDEData ? If nil then the variable is set to default values
---@return Result<nil>
Industria.files.saveControllerCode = function(unit, editorCode)
    local ucode = Industria.controllers.getControllerCode(unit)
    if not ucode then
        return fnresult(false, Industria.translate("unitcode_is_invalid"))
    end
    if not editorCode then
        editorCode = { code = "", ctrl_code = ucode, output = {}, variables = {}, programname = "BaseProgram" }
    end
    --Controlla che abbia i campi utilizzati
    if unit == nil or unit.reference_program == nil then
        return fnresult(false, "Invalid controller"); -- Se non ha i campi necessari
    end

    --Apre il file di scrittura: cartella_mondo/industriadt/idunità_proprietario.st
    local f, err = io.open(Industria.files.getFilename(unit), "w");
    if err or f == nil then
        return fnresult(false, "File not written: " .. err);
    end
    --Scrivi il codice
    Industria.files.saved[ucode] = editorCode;
    f:write(core.serialize(editorCode));
    f:flush();
    f:close();
    return fnresult(true, nil);
end

---Loads the Unit Code (ST File) from the file referenced by: controller.reference_program
---@param controlelr Controller
---@return Result<IDEData|nil>
Industria.files.loadControllerCode = function(controlelr)
    local f, err = io.open(Industria.files.getFilename(controlelr), "r")
    if not f or err then
        if f then
            f:close();
        end
        return fnresult(false, "File not opened: " .. tostring(err), nil);
    end
    local source = f:read("*a"); f:close();
    if not source or Industria.commons.isBlank(source) then
        return fnresult(false, "File content is invalid");
    end
    ---@type IDEData
    local data = core.deserialize(source);
    Industria.files.saved[data.ctrl_code] = data;
    return fnresult(true, nil, data);
end

---Get's, load if not present, the data of the controller (code and variables)
---@param controller Controller
---@return Result<IDEData|nil>
Industria.files.getControllerCode = function(controller)
    if not controller then
        return fnresult(false, "Controller is invalid");
    end
    local ucode = Industria.controllers.getControllerCode(controller);
    if not ucode then
        return fnresult(false, Industria.translate("unitcode_is_invalid"))
    end

    if Industria.files.saved[ucode] == nil then
        local res = Industria.files.loadControllerCode(controller)
        if not res.completed then
            return fnresult(false, "Controller Data is invalid");
        end
        return res;
    end

    return fnresult(true, nil, Industria.files.saved[ucode]);
end


---Deletes the .st file associated with a Unit. This method should be called when the unit is removed from the world
---@param unit Controller
---@return Result<number>
Industria.files.deleteControllerCode = function(unit)
    --Controlla che abbia i campi utilizzati
    if unit == nil or unit.reference_program == nil then
        return fnresult(false, "Invalid controller"); -- Se non ha i campi necessari
    end
    --Elimina il file: cartella_mondo/industriadt/idunità_proprietario.st
    local ok, msg, code =
        os.remove(Industria.datapath .. "/" .. unit.reference_program);
    return fnresult(not not ok, msg, code);
end

--- Saves a Control Unit environment file containing all variables and values
--- to be able to resume operetion on the next load of the game.
---@param controller Controller
---@return boolean #true/false based on success or error
Industria.files.saveControllerEnvironment = function(controller)
    --Controlla che abbia i campi utilizzati
    if controller == nil or controller.reference_program == nil or controller.last_env == nil then
        return fnresult(false, "Invalid controller or last environment is not present"); -- Se non ha i campi necessari
    end
    --Apre il file di scrittura: cartella_mondo/industriadt/idunità_proprietario.st.env
    local f, err = io.open(Industria.datapath .. "/" .. controller.reference_program .. ".env", "w");
    if err or f == nil then
        return fnresult(false, err); --Fallito il salvataggio
    end
    --Serializza la tabella dell'environment
    f:write(core.serialize(controller.last_env));
    f:flush();
    f:close();
    return fnresult(true, nil);
end

---Deletes the .env file associated with a Unit. This method should be called when the unit is removed from the world
---@param controller Controller
---@return Result<number>
Industria.files.deleteControllerEnvironment = function(controller)
    --Controlla che abbia i campi utilizzati
    if controller == nil or controller.reference_program == nil then
        return fnresult(false, "Invalid controller"); -- Se non ha i campi necessari
    end
    --Elimina il file: cartella_mondo/industriadt/idunità_proprietario.st.env
    local ok, msg, code =
        os.remove(Industria.datapath .. "/" .. controller.reference_program .. ".env");
    return fnresult(not not ok, msg, code);
end
