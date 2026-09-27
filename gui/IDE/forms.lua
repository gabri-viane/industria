local OutputForm = function(playerdata, as_form)
    local errs = {}

    if playerdata.errors then
        for _, value in ipairs(playerdata.errors) do
            table.insert(errs, core.formspec_escape(value))
        end
    end


    if as_form then
        return table.concat({ "formspec_version[11]"
        , "size[15,3.5]"
        , "box[0,0;15,3;#000000]"
        , "textlist[0,0.5;15,3;outputlist;", table.concat(errs, ","), ";0;true]"
        , "label[0,0.25;Output:]"
        , "button[12,0;3,0.5;clearErrors;Clear Output]"
        , });
    else
        return table.concat({ "box[0,0;15,3;#000000]"
        , "textlist[0,0.5;15,3;outputlist;", table.concat(errs, ","), ";0;true]"
        , "label[0,0.25;Output:]"
        , "button[12,0;3,0.5;clearErrors;Clear Output]"
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
        return table.concat({ "box[0,0;5,7.5;#555555F5]"
        , "style_type[label;font_size=21]"
        , "label[0,0.25;Variables Panel]"
        , "image[0,0.5;4,0.05;industria_fs_hline.png]"
        , "dropdown[0,1;2,0.8;vartype;INT,REAL,BOOL,STRING;1;false]"
        , "field[2,1;2.25,0.8;vardefault;Default Value:;]"
        , "field[0,2.25;3.5,0.8;varname;Name:;]"
        , "textarea[0,3.5;5,4;;Declaration:;", core.formspec_escape(text), "]"
        , "image_button[3.5,2.25;0.75,0.8;industria_fs_add.png;addbtn;;false;false;]"
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
    , "container[5.2,0.25]" --Pannello inferiore (errori)
    , "container_end[]"
    , "container[5.2,11.5]" --Pannello centrale
    , OutputForm(playerdata, false)
    , "container_end[]"
    , });
end
