local OutputForm = function(playerdata, as_form)
    local logs = {}

    if playerdata.output then
        for _, value in ipairs(playerdata.output) do
            table.insert(logs, core.formspec_escape(value))
        end
    end


    if as_form then
        return table.concat({ "formspec_version[11]"
        , "size[20,4]"
        , "box[0,0;15,4;#000000]"
        , "textlist[0.25,0.5;15,3.75;outputlist;", table.concat(logs, ","), ";0;true]"
        , "label[0.25,0.25;Output (↓ Time):]"
        , "button[16.75,0.25;3,0.5;clearOutput;Clear Output]"
        , });
    else
        return table.concat({ "box[0,0;20,4.2;#000000]"
        , "textlist[0.25,0.75;20,3.45;outputlist;", table.concat(logs, ","), ";0;true]"
        , "label[0.25,0.25;Output (↓ Time):]"
        , "button[16.75,0.25;3,0.5;clearOutput;Clear Output]"
        , });
    end
end

local CodingForm = function(playerdata, as_form)
    if not playerdata.code then
        playerdata.code = ""
    end
    if not playerdata.programname or Industria.commons.isBlank(playerdata.programname) then
        playerdata.programname = "BaseProgram"
    end

    if as_form then
        return table.concat({ "formspec_version[11]"
        , "size[20,13.5]"
        , "textarea[0,1.25;20,11.5;code;;", core.formspec_escape(playerdata.code), "]"
        , "field[2.25,0;3.75,0.5;pname;;", core.formspec_escape(playerdata.programname), "]"
        , "hypertext[0,0.5;5.5,0.75;;", core.formspec_escape("[Variable Definition]"), "]"
        , "label[0,0.25;PROGRAM]"
        , "label[0,13;END_PROGRAM]"
        , "field_close_on_enter[pname;false]"
        , });
    else
        return table.concat({
            "textarea[0,1.25;20,11.5;code;;", core.formspec_escape(playerdata.code), "]"
        , "field[2.25,0;3.75,0.5;pname;;", core.formspec_escape(playerdata.programname), "]"
        , "hypertext[0,0.5;5.5,0.75;;", core.formspec_escape("[Variable Definition]"), "]"
        , "label[0,0.25;PROGRAM]"
        , "label[0,13;END_PROGRAM]"
        , "field_close_on_enter[pname;false]"
        , });
    end
end

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
        , "size[4,7.7]"
        , "container[0,0]"
        , "box[0,0;5,8;#555555F5]"
        , "container[0.25,0.25]"
        , "style_type[label;font_size=21]"
        , "label[0,0.25;Variables Panel]"
        , "image[0,0.5;4.5,0.05;industria_fs_hline.png]"
        , "dropdown[0,1;2,0.8;vartype;INT,REAL,BOOL,STRING;1;false]"
        , "field[2,1;2.25,0.8;vardefault;Default Value:;]"
        , "field[0,2.25;3.5,0.8;varname;Name:;]"
        , "textarea[0,3.7;4.85,4;;Declaration:;", core.formspec_escape(text), "]"
        , "image_button[3.5,2.25;0.75,0.8;industria_fs_add.png;addbtn;;false;false;]"
        , "container_end[]"
        , "container_end[]"
        , "field_close_on_enter[varname;false]"
        , "field_close_on_enter[vardefault;false]"
        , });
    else
        return table.concat({ "box[0,0;5,8;#555555F5]"
        , "container[0.25,0.25]"
        , "style_type[label;font_size=21]"
        , "label[0,0.25;Variables Panel]"
        , "image[0,0.5;4.5,0.05;industria_fs_hline.png]"
        , "dropdown[0,1;2,0.8;vartype;INT,REAL,BOOL,STRING;1;false]"
        , "field[2,1;2.25,0.8;vardefault;Default Value:;]"
        , "field[0,2.25;3.5,0.8;varname;Name:;]"
        , "textarea[0,3.7;4.85,4;;Declaration:;", core.formspec_escape(text), "]"
        , "image_button[3.5,2.25;0.75,0.8;industria_fs_add.png;addbtn;;false;false;]"
        , "container_end[]"
        , "field_close_on_enter[varname;false]"
        , "field_close_on_enter[vardefault;false]"
        , });
    end
end


Industria.formspecs.IDE.forms.MainIDE = function(playerdata)
    return table.concat({ "formspec_version[11]"
    , "size[32,18]"
    , "container[0.25,0.25]" --Pannello di sinistra
    , VariableForm(playerdata, false)
    , "container_end[]"
    , "container[5.4,0.25]" --Pannello centrale
    , CodingForm(playerdata, false)
    , "container_end[]"
    , "container[5.4,13.80]" --Pannello inferiore (logs)
    , OutputForm(playerdata, false)
    , "container_end[]"
    , });
end
