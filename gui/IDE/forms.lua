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
        , "box[0,0;20,4.2;#1F2428FF]"
        , "textlist[0.25,0.75;20,3.45;outputlist;", table.concat(logs, ","), ";0;true]"
        , "label[0.25,0.35;Output (↓ Time):]"
        , "button[16.75,0.15;3,0.6;clearOutput;Clear Output]"
        , "image[0,0.75;19.5,0.05;industria_fs_hline.png]"
        , });
    else
        return table.concat({ "box[0,0;20,4.2;#1F2428FF]"
        , "textlist[0.25,0.75;20,3.45;outputlist;", table.concat(logs, ","), ";0;true]"
        , "label[0.25,0.35;Output (↓ Time):]"
        , "button[16.75,0.15;3,0.6;clearOutput;Clear Output]"
        , "image[0,0.75;19.5,0.05;industria_fs_hline.png]"
        , });
    end
end

local OptionsForm = function(playerdata, as_form)
    if as_form then
        return table.concat({ "formspec_version[11]"
        , "size[3.5,1.25]"
        , "box[0,0;3.5,1.25;#1F2428FF]"
        , "image_button[0.25,0.25;0.75,0.75;industria_fs_save.png^[resize:16x16;save;;false;false;]"
        , "image_button[1.25,0.25;0.75,0.75;industria_fs_build.png;build;;false;false;]"
        , "image_button[2.25,0.25;0.75,0.75;industria_fs_build_download.png;buildanddownload;;false;false;]"
        , });
    else
        return table.concat({ "box[0,0;3.5,1.25;#1F2428FF]"
        , "image_button[0.25,0.25;0.75,0.75;industria_fs_save.png^[resize:16x16;save;;false;false;]"
        , "image_button[1.25,0.25;0.75,0.75;industria_fs_build.png;build;;false;false;]"
        , "image_button[2.25,0.25;0.75,0.75;industria_fs_build_download.png;buildanddownload;;false;false;]"
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
        , "textarea[0,0.75;20,12;code;;", core.formspec_escape(playerdata.code), "]"
        , "field[2.25,0;3.75,0.5;pname;;", core.formspec_escape(playerdata.programname), "]"
        --, "hypertext[0,0.5;5.5,0.75;;", core.formspec_escape("[Variable Definition]"), "]"
        , "label[0,0.25;PROGRAM]"
        , "label[0,13;END_PROGRAM]"
        , "field_close_on_enter[pname;false]"
        , });
    else
        return table.concat({ "style[code;font=mono;bgcolor=black]"
        , "textarea[0,0.75;20,12;code;;", core.formspec_escape(playerdata.code), "]"
        , "field[2.25,0;3.75,0.5;pname;;", core.formspec_escape(playerdata.programname), "]"
        --, "hypertext[0,0.5;5.5,0.75;;", core.formspec_escape("[Variable Definition]"), "]"
        , "label[0,0.25;PROGRAM]"
        , "label[0,13;END_PROGRAM]"
        , "field_close_on_enter[pname;false]"
        , });
    end
end

---comment
---@param playerdata IDEData
---@param as_form boolean
---@return string
local IOLinkedForm = function(playerdata, as_form)
    local linked_ios = {}

    if playerdata.ctrl_code then
        local res = Industria.controllers:getController(playerdata.ctrl_code)
        local cntrl = res.data
        local idx = 0.05
        if res.completed and cntrl then
            for varname, iounit_code in pairs(cntrl.linked_iounits) do
                local rs = Industria.iounits:getIOUnit(iounit_code)
                local iounit = rs.data
                if rs.completed and iounit then
                    local pos = iounit.pos_block
                    table.insert(linked_ios, table.concat({ "container[0,", tostring(idx), "]"
                    , "image[0,0;4,0.05;industria_fs_hline.png]"
                    , "item_image[0,0.05;1.25,1.25;", core.formspec_escape(iounit.node_name), "]"
                    ,
                        "hypertext[1.25,0.15;3.5,0.5;ht1;<normal>Var: <mono><style font=mono color=#6DB8DC>",
                        core.formspec_escape(varname), "</style></mono></normal>]"
                    , "hypertext[1.25,0.5;3.5,0.5;ht1;<normal>Pos: <mono><style font=mono color=#00ecff>"
                    , "X:", tostring(pos.x), " Y:", tostring(pos.y), " Z:", tostring(pos.z)
                    , "</style></mono></normal>]"
                    , "container_end[]"
                    }))
                    idx = idx + 1.1
                end
            end
        end
    end

    if as_form then
        return table.concat({ "formspec_version[11]"
        , "size[4.5,11]"
        , "hypertext[0,0;3.5,0.7;ht1;<big>Linked IOs:</big>]"
        , "scroll_container[0,0.7;4.5,11;linkedsscrlbar;vertical;0.1]"
        , table.concat(linked_ios)
        , "scroll_container_end[]"
        , });
    else
        return table.concat({ 
         "hypertext[0,0;3.5,0.7;ht1;<big>Linked IOs:</big>]"
        ,"scroll_container[0,0.7;4.5,11;linkedsscrlbar;vertical;0.1]"
        , table.concat(linked_ios)
        , "scroll_container_end[]"
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
        , "box[0,0;5,10;#1F2428FF]"
        , "container[0.25,0.25]"
        --, "style_type[label;font_size=21]"
        , "hypertext[0,0;4.5,0.7;;<style color=#D1D5DA><b><big>Variables Panel</big></b></style>]"
        , "image[0,0.7;4.5,0.05;industria_fs_hline.png]"
        , "container[0,1.2]"
        , "dropdown[0,0;2,0.8;vartype;INT,REAL,BOOL,STRING;1;false]"
        , "field[2,0;2.25,0.8;vardefault;Default Value:;]"
        , "field[0,1.25;3.5,0.8;varname;Name:;]"
        , "image_button[3.5,1.25;0.75,0.8;industria_fs_add.png;addbtn;;false;false;]"
        , "textarea[0,2.7;4.85,4;;Declaration:;", core.formspec_escape(text), "]"
        , "field[0,7.4;3.5,0.8;remvarname;Remove Variable:;]"
        , "image_button[3.5,7.4;0.75,0.8;industria_fs_rem.png;rembtn;;false;false;]"
        , "container_end[]"
        , "container_end[]"
        , "container_end[]"
        , "field_close_on_enter[varname;false]"
        , "field_close_on_enter[vardefault;false]"
        , });
    else
        return table.concat({ "box[0,0;5,10;#1F2428FF]"
        , "container[0.25,0.25]"
        --, "style_type[label;font_size=21]"
        , "hypertext[0,0;4.5,0.7;;<style color=#D1D5DA><b><big>Variables Panel</big></b></style>]"
        , "image[0,0.7;4.5,0.05;industria_fs_hline.png]"
        , "container[0,1.2]"
        , "dropdown[0,0;2,0.8;vartype;INT,REAL,BOOL,STRING;1;false]"
        , "field[2,0;2.25,0.8;vardefault;Default Value:;]"
        , "field[0,1.25;3.5,0.8;varname;Name:;]"
        , "image_button[3.5,1.25;0.75,0.8;industria_fs_add.png;addbtn;;false;false;]"
        , "textarea[0,2.7;4.85,4;;Declaration:;", core.formspec_escape(text), "]"
        , "field[0,7.4;3.5,0.8;remvarname;Remove Variable:;]"
        , "image_button[3.5,7.4;0.75,0.8;industria_fs_rem.png;rembtn;;false;false;]"
        , "container_end[]"
        , "container_end[]"
        , "field_close_on_enter[varname;false]"
        , "field_close_on_enter[vardefault;false]"
        , });
    end
end


Industria.formspecs.IDE.forms.MainIDE = function(playerdata)
    return table.concat({ "formspec_version[11]"
    , "size[32,18]"
    , "no_prepend[]"
    , "bgcolor[#242424FF]"

    , "container[0.25,0.25]" --Pannello di sinistra (alto)
    , VariableForm(playerdata, false)
    , "container_end[]"

    , "container[0.25,12.25]" --Pannello di sinistra (basso)
    , OptionsForm(playerdata, false)
    , "container_end[]"

    , "container[5.4,0.25]" --Pannello centrale
    , CodingForm(playerdata, false)
    , "container_end[]"

    , "container[26,0.25]" --Pannello di destra
    , IOLinkedForm(playerdata, false)
    , "container_end[]"

    , "container[5.4,13.80]" --Pannello inferiore (logs)
    , OutputForm(playerdata, false)
    , "container_end[]"
    , });
end
