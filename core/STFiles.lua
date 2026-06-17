local fnresult = Industria.commons.fnresult;

Industria.files.STtemplate = "(* ============================================================\n   Usage Example: Variable declaration + instructions\n   ============================================================ *)\n\nPROGRAM TemplateProgram\n\nVAR\n    (* Variables here *)\n    counter      : INT   := 0;\n    realNumber      : REAL   := 0;\n    SensorInput :  BOOL := 0;\nEND_VAR\nrealNumber := realNumber+0.1;\nIF SensorInput THEN\n	counter := counter +1;\n    PRINT('VALUE:');\n    PRINT('VALUE:');\nEND_IF\n\nEND_PROGRAM";

-- Saves a Control Unit environment file containing all variables and values
-- to be able to resume operetion on the next load of the game.
--
-- Parameters:
-- unit : Unit {unitd_id, owner, reference_program, last_env}
--
-- Returns: true/false based on success or error
Industria.files.saveUnitEnvironment = function(unit)
    --Controlla che abbia i campi utilizzati
    if unit == nil or unit.reference_program == nil or unit.last_env == nil then
        return false; -- Se non ha i campi necessari
    end
    --Apre il file di scrittura: cartella_mondo/industriadt/idunità_proprietario.st.env
    local f, err = io.open(Industria.datapath .. "/" .. unit.reference_program .. ".env", "w");
    if err or f == nil then
        return false; --Fallito il salvataggio
    end
    --Serializza la tabella dell'environment
    f:write(core.serialize(unit.last_env));
    f:flush();
    f:close();
    return true;
end

---Writes out the Unit Code (ST File) to the file referenced by: unit.reference_program
---@param unit Unit
---@param text string
---@return Result<nil>
Industria.files.saveUnitCode = function(unit, text)
    --Controlla che abbia i campi utilizzati
    if unit == nil or unit.reference_program == nil or unit.last_env == nil then
        return fnresult(false, "Unit is invalid", nil); -- Se non ha i campi necessari
    end

    --Apre il file di scrittura: cartella_mondo/industriadt/idunità_proprietario.st
    local f, err = io.open(Industria.datapath .. "/" .. unit.reference_program, "w");
    if err or f == nil then
        return fnresult(false, "File not written: " .. err, nil);
    end
    --Scrivi il codice
    f:write(text);
    f:flush();
    f:close();
    return fnresult(true, nil, nil);
end

---Deletes the .env file associated with a Unit. This method should be called when the unit is removed from the world
---@param unit Unit
---@return Result<number>
Industria.files.deleteUnitEnvironment = function(unit)
    --Controlla che abbia i campi utilizzati
    if unit == nil or unit.reference_program == nil or unit.last_env == nil then
        return fnresult(false, "Unit is invalid", nil); -- Se non ha i campi necessari
    end
    --Elimina il file: cartella_mondo/industriadt/idunità_proprietario.st.env
    local ok, msg, code =
        os.remove(Industria.datapath .. "/" .. unit.reference_program .. ".env");
    return fnresult(not not ok, msg, code);
end

---Deletes the .st file associated with a Unit. This method should be called when the unit is removed from the world
---@param unit Unit
---@return Result<number>
Industria.files.deleteUnitCode = function(unit)
    --Controlla che abbia i campi utilizzati
    if unit == nil or unit.reference_program == nil or unit.last_env == nil then
        return fnresult(false, "Unit is invalid", nil); -- Se non ha i campi necessari
    end
    --Elimina il file: cartella_mondo/industriadt/idunità_proprietario.st
    local ok, msg, code =
        os.remove(Industria.datapath .. "/" .. unit.reference_program);
    return fnresult(not not ok, msg, code);
end
