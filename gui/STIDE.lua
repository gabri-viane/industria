------------------------------------------ Definition of the code editor ---------------------------------------

local FSKeyCode = "Industria:Controller:IDE";
local coreCloseFormSpec = core.close_formspec;
local coreShowFormSpec = core.show_formspec;
local sendPlayerMsg = core.chat_send_player;

--[[
formspec_version[10]
size[4,7]
container[0,0]
box[0,0;4,7;#555555F5]
style_type[label;font_size=21]
label[0,0.25;Variables Panel]
dropdown[0,0.5;1.75,0.8;vartype;INT,REAL,BOOL,STRING;1;false]
field[1.75,0.5;2.25,0.8;vardefault;Default:;]
field[0,1.5;3.25,0.8;varname;Name:;]
textarea[0,3;4,4;;Declaration:;]
image_button[3.25,1.5;0.75,0.8;industria_fs_add.png;addbtn;;false;true;]
container_end[]
field_close_on_enter[varname;false]
field_close_on_enter[vardefault;false]
]]

local VariableForm = function(playerdata, as_form)
    local text = "VAR\n"

    if playerdata.variables then
        for key, value in pairs(playerdata.variables) do
            text = table.concat({ text, "\t", key, "\t: ", value.dtype, " := ", value.value, ";\n" })
        end
    end

    text = text .. "END_VAR"

    if as_form then
        return table.concat({ "formspec_version[10]"
        , "size[4,7.5]"
        , "container[0,0]"
        , "box[0,0;4,7.5;#555555F5]"
        , "style_type[label;font_size=21]"
        , "label[0,0.25;Variables Panel]"
        , "image[0,0.5;4,0.05;industria_fs_hline.png]"
        , "dropdown[0,1;1.75,0.8;vartype;INT,REAL,BOOL,STRING;1;false]"
        , "field[1.75,1;2.25,0.8;vardefault;Default Value:;]"
        , "field[0,2.25;3.25,0.8;varname;Name:;]"
        , "textarea[0,3.5;4,4;;Declaration:;", core.formspec_escape(text), "]"
        , "image_button[3.25,2.25;0.75,0.8;industria_fs_add.png;addbtn;;false;false;]"
        , "container_end[]"
        , "field_close_on_enter[varname;false]"
        , "field_close_on_enter[vardefault;false]"
        , });
    else
        return table.concat({ "box[0,0;4,7.5;#555555F5]"
        , "style_type[label;font_size=21]"
        , "label[0,0.25;Variables Panel]"
        , "image[0,0.5;4,0.05;industria_fs_hline.png]"
        , "dropdown[0,1;1.75,0.8;vartype;INT,REAL,BOOL,STRING;1;false]"
        , "field[1.75,1;2.25,0.8;vardefault;Default Value:;]"
        , "field[0,2.25;3.25,0.8;varname;Name:;]"
        , "textarea[0,3.5;4,4;;Declaration:;", core.formspec_escape(text), "]"
        , "image_button[3.25,2.25;0.75,0.8;industria_fs_add.png;addbtn;;false;false;]"
        , "field_close_on_enter[varname;false]"
        , "field_close_on_enter[vardefault;false]"
        , });
    end
end

local function VariableFormCallback(player_name, fields, playerdata)
    if not playerdata.variables then
        ---@type Environment
        playerdata.variables = {}
    end
    if not playerdata.errors then
        playerdata.errors = {}
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
                        table.insert(playerdata.errors,
                            "[ERR] Invalid Default Value for '" .. fields.varname .. "': not a number")
                    elseif fields.type == "INT" then
                        --Se è la definizione di un numero interno allora provo a convertirlo
                        default = math.tointeger(default)
                        if not default then
                            --Se non riesco do errore
                            table.insert(playerdata.errors,
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

            if default then
                playerdata.variables[Industria.commons.strtrim(fields.varname)] = {
                    dtype = fields.vartype,
                    value = default
                }
            end
        else
            table.insert(playerdata.errors, "[ERR] Invalid Variable Name")
        end

        Industria.formspecs:setPlayerStatus(player_name, FSKeyCode, playerdata)
        coreShowFormSpec(player_name, FSKeyCode, VariableForm(playerdata));
        return;
    end
end


--- Generate the formspec for code editor.
---@param text string #The content to display in the editor
---@return string #The formspec editor
local STCodeIDE = function(text)
    local max_lines_in_height = 24
    local textarea_height = 8.7
    local line_height = textarea_height / max_lines_in_height


    local _, linecount = text:gsub('\n', '\n')
    linecount = linecount + 2
    core.chat_send_all(core.serialize({ line_height = line_height, linecount = linecount }))

    local labels = {}
    local y_cur_pos = 1.2
    for i = 1, linecount, 1 do
        table.insert(labels, "label[0.1," .. y_cur_pos .. ";" .. i .. "]")
        y_cur_pos = y_cur_pos + line_height
    end

    return table.concat({ "formspec_version[6]",
        "size[16,14]",
        table.concat(labels),
        "scrollbar[15.1,1;0.3,9;vertical;test_scroll;]",
        "scroll_container[1,1;11,9;test_scroll_h;horizontal;0.1;0]",
        "scroll_container[0,0;11,9;test_scroll;vertical;0.1;0]",
        "style_type[textarea;font=mono]",
        "textarea[0,0;15,", line_height * linecount, ";CodeEditor;Program Code:;", core.formspec_escape(text), "]",
        "scroll_container_end[]",
        "scroll_container_end[]",
        "button[7.4,10.1;3,0.8;saveCode;Save]",
        "button[4.2,10.1;3,0.8;cancelEdits;Undo]",
        "button_exit[11.5,0;1.6,0.8;exitForm;Exit]",
        "button[0.1,10.1;3,0.8;compileCode;Compile]" }, "");
end


local MainIDE = function(playerdata)
    return table.concat({ "formspec_version[11]"
    , "size[16,11]"
    , "container[0.25,0.25]" --Pannello di sinistra
    , VariableForm(playerdata, false)
    , "container_end[]"
    , "container[4.5,7.5]"  --Pannello centrale
    , "container_end[]"
    , "container[4.5,0.25]" --Pannello inferiore (errori)
    , "container_end[]"
    , });
end

--Funzione di callback per l'editor di codice ST
function Industria.formspecs.callbacks:STCodeIDECallback(player_name, fields)
    local playerdata = Industria.formspecs:getPlayerStatus(player_name).data;
    local unitcode = playerdata.ctrl_code
    local variables = playerdata.variables or {}

    local closeFS = function()
        Industria.formspecs:setPlayerStatus(player_name, nil, nil);
        coreCloseFormSpec(player_name, FSKeyCode);
        if Industria.formspecs:getPlayerStatus(player_name).fallbackto ~= nil then
            Industria.formspecs:getPlayerStatus(player_name).fallbackto(); --Esegui il callback se presente
            Industria.formspecs:setPlayerStatusFallback(player_name, nil); --Consuma il callback
        end
    end

    ---Controlla di chi è l'unità
    ---@param unit Controller
    ---@return boolean #Se true allora il giocatore può gestire l'unità
    local checkOwnership = function(unit)
        if unit.protected and unit.owner ~= player_name then
            return false;
        end
        return true;
    end

    if unitcode == nil or not (type(unitcode) == "string") then
        core.chat_send_player(player_name, "No Unit Code");
        closeFS();
        return;
    end

    VariableFormCallback(player_name, fields, playerdata)

    if fields.saveCode then
        local unit = Industria.controllers:getController(unitcode);
        --Controllo se il giocatore può accedere all'unità
        if not checkOwnership(unit.data) then
            closeFS();
            return;
        end
        --Salvo il codice
        if Industria.files.saveControllerCode(unit.data, fields.CodeEditor) then
            --Chiudo il formspec
            closeFS();
        else
            sendPlayerMsg(player_name, "Not saved");
        end
        return;
    end

    if fields.compileCode then
        local unit = Industria.controllers:getController(unitcode);
        --Controllo se il giocatore può accedere all'unità
        if not checkOwnership(unit.data) then
            closeFS();
            return;
        end
        --Salvo il codice
        if Industria.files.saveControllerCode(unit.data, fields.CodeEditor) then
            --Compilo
            Industria.runtime:createInterpreter(unit.data, false);
            --Chiudo il formspec
            closeFS();
        else
            sendPlayerMsg(player_name, "Not saved");
        end
        return;
    end


    if fields.exitForm then
        --Chiudo il formspec
        coreCloseFormSpec(player_name, FSKeyCode);
        Industria.formspecs:setPlayerStatus(player_name, nil, nil);
        return;
    end
end

--- Displays the Code Editor Formspec to the player if the player can edit or view the Unit.
---@param player_name owner Name of the user to show the formspec to.
---@param unit_code ControllerCODE The UnitCode
function Industria.formspecs:showCodeIDE(player_name, unit_code)
    local res = Industria.controllers:getController(unit_code);

    if res.completed then
        --Controllo se il giocatore può accedere all'unità
        if res.data.protected and res.data.owner ~= player_name then
            return;
        end


        if not self:getPlayerStatus(player_name).showing or not (self:getPlayerStatus(player_name).showing == FSKeyCode) then
            local code = Industria.ST.loadCode(Industria.datapath .. "/" .. res.data.reference_program);
            if not code.completed then
                --non ho trovato il codice/file: lo devo creare
                if not Industria.files.saveControllerCode(res.data, "") then
                    return; -- Se non sono riuscito a crearlo esco
                end
                --riprovo ad aprirlo:
                code = Industria.ST.loadCode(Industria.datapath .. "/" .. res.data.reference_program);
                -- Se non sono riuscito di nuovo ad aprirlo
                if not code.completed then
                    return;
                end
            end
            self:setPlayerStatus(player_name, FSKeyCode, { ctrl_code = unit_code, code = code.data });
        end

        self:setCurrentCallback(player_name,
            function(pname, fields)
                Industria.formspecs.callbacks:STCodeIDECallback(pname, fields);
            end);
        coreShowFormSpec(player_name, FSKeyCode, MainIDE(self:getPlayerStatus(player_name).data)); --STCodeIDE(self:getPlayerStatus(player_name).data.code));
    else
        sendPlayerMsg(player_name, "No Unit found with Code: '" .. unit_code .. "'");
    end
end
