--[[
Handles the base unit: node interaction and removal
]] --

local function on_rightclick_callback(pos, node, clicker, itemstack, pointed_thing)
    --Solo i giocatori possono accedere al formspec per impostare l'ID o
    --accedere alla gestione
    if clicker:is_player() then
        local result = Industria.units.isValidUnit(pos, node);

        if not result.completed then
            return; -- Unità non valida
        end

        if result.data == nil then
            --Nodo valido ma non ancora unità: chiedo di impostare l'id, il giocatore che lo imposta
            --core.chat_send_player(clicker:get_player_name(), "Newly created Unit: set the new ID");
            Industria.formspecs:showPLCInputID(clicker:get_player_name(), pos);
            return;
        end

        local unit = result.data;
        --Se l'unità non è valida o non ha l'id allora esci
        if unit == nil or unit.unit_id == nil then
            return;
        end
        --se l'unità è protetta solo il giocatore che l'ha creata può accedervi
        if unit.protected and unit.owner ~= clicker:get_player_name() then
            return;
        else
            --Ho l'unità: mostro il formspec per gestirla, non è protetta e quindi chiunque può accederci
            Industria.formspecs:showUnitMainForm(clicker:get_player_name(),
                Industria.units.toUnitCode(unit.unit_id, unit.owner) or "");
        end
    end
end

local function after_dig_callback(pos, oldnode, oldmetadata, digger)
    --Devo controllare se ho già l'id del unit
    if not oldmetadata.fields["unit_id"] or not oldmetadata.fields["unit_owner"] then
        --Se non lo ho non devo rimuovere nulla
        return;
    end
    local plcid = oldmetadata.fields["unit_id"];       --prendo l'id
    local plcowner = oldmetadata.fields["unit_owner"]; --prendo l'owner

    local res = Industria.controllers:removeController(plcid, plcowner);
    if digger:is_player() then
        if res.completed then
            core.chat_send_player(digger:get_player_name(), "Unit removed");
        else
            core.chat_send_player(digger:get_player_name(), res.msg);
        end
    end
end

core.register_node("industria:baseunit", {
    description = "Base Unit",
    drawtype = "mesh",
    mesh = "BaseModelController.glb",
    tiles = { "BaseController.png" },
    node_box = {
        type = "fixed",
        fixed = {
            { -1 / 16, -4.5 / 16, 8 / 16,
                1 / 16, 0.5 / 16, 2 / 16 },
        }
    },
    paramtype = "none",
    paramtype2 = "facedir",
    is_ground_content = false,
    groups = { dig_immediate = 2, industria_controller = 1 },
    on_rightclick = on_rightclick_callback,
    after_dig_node = after_dig_callback
});
