---comment
---@param player_name any
---@param fields any
---@param playerdata IDEData
function Industria.formspecs.IDE.callbacks:CodeFormCallback(player_name, fields, playerdata)
    local edited = false;

    if fields.key_enter_field == "pname" or fields.pname then --Premuto Enter nel campo di testo: imposto il nome
        --Validazione del nome della variabile
        if fields.pname and not Industria.commons.isBlank(fields.pname) then
            playerdata.programname = fields.pname
        else
            table.insert(playerdata.output, "[ERR] Invalid Program Name")
        end
        edited = true;
    end

    if fields.code then
        playerdata.code = fields.code;
        edited = true;
    end
    if edited then
        Industria.formspecs.IDE:updateIDEData(player_name, playerdata);
    end
end
