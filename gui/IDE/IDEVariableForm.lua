function Industria.formspecs.IDE.callbacks:VariableFormCallback(player_name, fields, playerdata)
    if not playerdata.variables then
        ---@type Environment
        playerdata.variables = {}
    end
    if not playerdata.output then
        playerdata.output = {}
    end

    if fields.addbtn then
        --Validazione del nome della variabile
        if fields.varname and Industria.commons.isValidVarname(fields.varname) then
            local default = nil;
            --Devo generare i default della variabile
            if fields.vartype == "INT" or fields.vartype == "REAL" then
                -- Controllo se il valore di default non è fornito e lo imposto in automatico
                if not fields.vardefault or Industria.commons.isBlank(fields.vardefault) then
                    default = 0;
                else
                    --Controllo che sia convertibile in un numero
                    default = tonumber(fields.vardefault)
                    if not default then
                        --Se non lo è aggiungo un errore
                        table.insert(playerdata.output,
                            "[ERR] Invalid Default Value for '" .. fields.varname .. "': not a number")
                    elseif fields.vartype == "INT" then
                        --Se è la definizione di un numero interno allora provo a convertirlo
                        default = math.floor(default)
                        if not default then
                            --Se non riesco do errore
                            table.insert(playerdata.output,
                                "[ERR] Invalid Default Value for '" .. fields.varname .. "': can't convert to int")
                        end
                    end
                end
            elseif fields.vartype == "BOOL" then
                --Devo generare i default della variabile
                if not fields.vardefault or Industria.commons.isBlank(fields.vardefault) then
                    default = "FALSE";
                else
                    local def_ = string.lower(fields.vardefault)
                    if def_ == "true" or def_ == "1" then default = "TRUE" else default = "FALSE" end
                end
            elseif fields.vartype == "STRING" then
                if not fields.vardefault or Industria.commons.isBlank(fields.vardefault) then
                    default = "";
                else
                    ---@type string
                    local def_ = "" .. fields.vardefault
                    default = "'" .. def_:gsub("'", "`") .. "'"
                end
            end

            if default ~= nil then
                playerdata.variables[Industria.commons.strtrim(fields.varname)] = {
                    dtype = fields.vartype,
                    value = default
                }
            end
        else
            table.insert(playerdata.output, "[ERR] Invalid Variable Name")
        end

        Industria.formspecs.IDE:updateIDEData(player_name, playerdata);
    end

    if fields.rembtn then
        --Validazione del nome della variabile
        if fields.remvarname and Industria.commons.isValidVarname(fields.remvarname) then
            playerdata.variables[Industria.commons.strtrim(fields.remvarname)] = nil
        else
            table.insert(playerdata.output, "[ERR] Can't remove variable: Invalid Name")
        end

        Industria.formspecs.IDE:updateIDEData(player_name, playerdata);
    end
end
