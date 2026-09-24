local fnresult = Industria.commons.fnresult;

Industria.files.STtemplate =
"(* ============================================================\n   Usage Example: Variable declaration + instructions\n   ============================================================ *)\n\nPROGRAM TemplateProgram\n\nVAR\n    (* Variables here *)\n    counter      : INT   := 0;\n    realNumber      : REAL   := 0;\n    SensorInput :  BOOL := 0;\nEND_VAR\nrealNumber := realNumber+0.1;\nIF SensorInput THEN\n	counter := counter +1;\n    PRINT('VALUE:');\n    PRINT(counter);\nEND_IF\n\nEND_PROGRAM";


---Writes out the Unit Code (ST File) to the file referenced by: unit.reference_program
---@param unit Controller
---@param text string
---@return Result<nil>
Industria.files.saveControllerCode = function(unit, text)
    --Controlla che abbia i campi utilizzati
    if unit == nil or unit.reference_program == nil then
        return fnresult(false, "Invalid controller"); -- Se non ha i campi necessari
    end

    --Apre il file di scrittura: cartella_mondo/industriadt/idunità_proprietario.st
    local f, err = io.open(Industria.datapath .. "/" .. unit.reference_program, "w");
    if err or f == nil then
        return fnresult(false, "File not written: " .. err);
    end
    --Scrivi il codice
    f:write(text);
    f:flush();
    f:close();
    return fnresult(true, nil);
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
