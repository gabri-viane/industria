local fnresult = Industria.commons.fnresult;

---Given the UnitID and Owner name (the player name that is the owner of the unit)
---@param unit_id unit_id The UnitID, must be unique
---@param player_name owner The player name
---@return string|nil #returns nil if one f the two params is null, otherwise the unit_code
function Industria.units.toUnitCode(unit_id, player_name)
    if unit_id == nil or player_name == nil then
        return nil;
    else
        return unit_id .. "_" .. player_name;
    end
end

---Checks if a Node in a specified position is a valid node to be considered as an Unit.
---The parameters to check are the meta-info "unit_owner" and "unit_id" or, if those ar not
---present, it checks if the node is in group "industria_controller".
---If the parameters "unit_owner" and "unit_id" are present than the unit should be already
---registered.
---@param pos any Position
---@param node any|nil Node If nil then the node is searched by the position
---@return Result<nil|Unit> #Returns "completed" = true if the node can be a unit or is an unit. If the node is already a registered unit then the field "data" is the unit itself.
function Industria.units.isValidUnit(pos, node)
    --Controllo se i parametri sono validi
    if pos == nil then
        return fnresult(false, "Invalid position", nil);
    end
    local _node = node;
    --Controllo se node è nil allora provo a prenderlo tramite funzioni di sistema
    if _node == nil then
        _node = core.get_node_or_nil(pos);
        -- Se non è un nodo caricato allora non permetterlo
        if _node == nil then
            return fnresult(false, "Invalid Node", nil);
        end
    end
    --Controllo se il nodo ha il gruppo
    local hasGroup = core.get_item_group(_node.name, "industria_controller");
    if hasGroup == nil or hasGroup == 0 then
        -- non può essere una valida unità: non ha il gruppo
        return fnresult(false, "The node is not a valid unit", nil);
    end

    local meta = core.get_meta(pos);
    --Devo controllare se ho già l'id e l'owner della unit
    if not meta:contains("unit_id") or not meta:contains("unit_owner") then
        -- Non è un'unità registrata ma potrà essere registrata
        return fnresult(true, "The node is valid to be a unit", nil);
    end
    local unitid = meta:get("unit_id");
    local ownerid = meta:get("unit_owner");
    --Provo a cercare l'unità
    local res = Industria.controllers:getUnit(Industria.units.toUnitCode(unitid, ownerid));
    if res.completed then
        -- è un'unità registrata
        return fnresult(true, "The node is already a registered unit", res.data);
    else
        -- Non è un'unità registrata ma potrà essere registrata
        return fnresult(true, "The node is valid to be registered as unit", nil);
    end
end
