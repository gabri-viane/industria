local fnresult = Industria.commons.fnresult;

--- Serialize the content of Industria.controllers (only ids and units) to the file "controllers.dt" in the world's folder.
---@return Result<nil> #It's completed if the the serialization succedees
function Industria.controllers:serialize()
    local data = {
        ids = self.player_controllers,
        units = self.registered_controllers
    };
    local text = core.serialize(data);
    -- Scrivi il file con i dati dei controllori
    local f, err = io.open(Industria.datapath .. "/controllers.dt", "w+");
    if err or f == nil then
        return fnresult(false, err, nil);
    end
    f:write(text);
    f:flush();
    f:close();
    return fnresult(true, "World's Controllers saved.", nil);
end

---Deserialize the file "controllers.dt" in the mod's folder of the world and loads the ids and units saved.
---@return Result<table|nil> #It's completed if the the deserialization succedees and the field "data" is set to point to Industria.controllers
function Industria.controllers:deserialize()
    -- Carica il file con i dati dei controllori
    local f, err = io.open(Industria.datapath .. "/controllers.dt", "r");
    if err or f == nil then
        return fnresult(false, err, nil);
    end

    local text = f:read("a");
    f:close();
    local data = core.deserialize(text, true);
    if data == nil then
        return fnresult(false, "Controllers' data file not loaded.", nil);
    end
    if data.ids == nil or data.units == nil then
        return fnresult(false, "Controllers' data file doesn't contain the required fields.", nil);
    end
    self.player_controllers = data.ids;
    self.registered_controllers = data.units;

    --Carica le unità in runtime
    for unit_code, unit in pairs(self.registered_controllers) do
        local th = coroutine.create(function()
            local res = Industria.runtime:registerControllerToRuntime(unit, false);
            if not res.completed then
                core.log("warning", "Registration to runtime of: '" .. unit_code .. "' was not completed:\n" .. res.msg);
            end
        end)
        coroutine.resume(th);
    end

    return fnresult(true, nil, self);
end

-------------------------------------------------------------------------
---                     FUNZIONI DI UTILITY                           ---
-------------------------------------------------------------------------

---Given the UnitID and Owner name (the player name that is the owner of the unit)
---@param unit_id ControllerID The UnitID, must be unique
---@param player_name owner The player name
---@return string|nil #returns nil if one of the two params is null, otherwise the unit_code
function Industria.controllers.toControllerCode(unit_id, player_name)
    if unit_id == nil or player_name == nil then
        return nil;
    else
        return unit_id .. "_" .. player_name;
    end
end

---Given the Unit gets the UnitID and Owner name (the player name that is the owner of the unit)
---@param controller Controller The Unit to get the unit_code from
---@return string|nil #returns nil if one of the two params is null, otherwise the unit_code
function Industria.controllers.getControllerCode(controller)
    if controller == nil then
        return nil;
    else
        return Industria.controllers.toControllerCode(controller.controller_id, controller.owner);
    end
end

---Checks if a Node in a specified position is a valid node to be considered as a Controller.
---The parameters to check are the meta-info "controller_owner" and "controller_id" or, if those ar not
---present, it checks if the node is in group "industria_controller".
---If the parameters "controller_owner" and "controller_id" are present than the unit should be already
---registered.
---@param pos any Position
---@param node any|nil Node If nil then the node is searched by the position
---@return Result<nil|Controller> #Returns "completed" = true if the node can be a Controller or is a Controller. If the node is already a registered Controller then the field "data" is the Controller itself.
function Industria.controllers.isValidController(pos, node)
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
    _node = core.registered_nodes[_node.name]
    if not _node then
        return fnresult(false, "Invalid Node", nil);
    end

    --Controllo se il nodo ha il gruppo
    if not _node.groups or not _node.groups.industria_controller then
        -- non può essere un controllore valido: non ha il gruppo
        return fnresult(false, "The node is not a valid controller", nil);
    end

    local meta = core.get_meta(pos);
    --Devo controllare se ho già l'id e l'owner della controller
    if not meta:contains("controller_id") or not meta:contains("controller_owner") then
        -- Non è un'unità registrata ma potrà essere registrata
        return fnresult(true, "The node is valid to be a controller", nil);
    end
    local controllerid = meta:get("controller_id");
    local ownerid = meta:get("controller_owner");
    --Provo a cercare il controllore
    local res = Industria.controllers:getController(Industria.controllers.toControllerCode(controllerid, ownerid));
    if res.completed then
        -- è un controllore registrata
        return fnresult(true, "The node is already a registered controller", res.data);
    else
        -- Non è un controllore registrato ma potrà essere registrato
        return fnresult(true, "The node is valid to be registered as controller", nil);
    end
end

---Set's the meta info into the Node to reference the Controller.
---@param controller Controller Contrller to link to the Node
function Industria.controllers.setMeta(controller)
    --Devo salvare il la unit_id nel plc_id
    --La unit_id viene scritta dal giocatore nel form
    local meta = core.get_meta(controller.pos);
    if meta == nil then
        return;
    end
    meta:set_string("controller_id", controller.controller_id);
    meta:set_string("controller_owner", controller.owner);
end

---Set's the meta info into the Node to reference the Controller.
---@param controller Controller Contrller to link to the Node
---@return Result<nil> #Return false if meta doesn't exist or the provided controller is not at the given position
function Industria.controllers.deleteMeta(controller)
    --Devo salvare il la unit_id nel plc_id
    --La unit_id viene scritta dal giocatore nel form
    local meta = core.get_meta(controller.pos);
    if meta == nil or not meta:contains("controller_id") or not meta:contains("controller_owner") then
        return fnresult(false);
    end
    local controllerid = meta:get("controller_id");
    local ownerid = meta:get("controller_owner");
    if controllerid ~= controller.controller_id or ownerid ~= controller.owner then
        return fnresult(false);
    end
    meta:set_string("controller_id", "");
    meta:set_string("controller_owner", "");
    return fnresult(true);
end

-------------------------------------------------------------------------
---                     REGISTRAZIONE DEI CONTROLLORI                 ---
-------------------------------------------------------------------------

--- Creates and binds a new Controller to a player if the player doesn't already have a Controller with the same id associated
---@param controller_id ControllerID The unit id, must be unique
---@param owner owner The player name
---@param node_pos any Poistion of the node
---@return Result<Controller|nil> #In the filed "data" the value is the newly created Unit
function Industria.controllers:registerController(controller_id, owner, node_pos)
    -- Crea il codice del plc: idcontrollore_nomeproprietario
    local ctrl_code = Industria.controllers.toControllerCode(controller_id, owner);
    -- Controllo se non ho generato il codice
    if ctrl_code == nil then
        return fnresult(false, Industria.translate("unitcode_is_invalid"));
    end
    -- Se esiste già un controllore allora ritorna un'errore
    if self.registered_controllers[ctrl_code] ~= nil then
        return fnresult(false, Industria.translate("unit_exists"));
    end
    --Se non esiste la tabella di id associata al giocatore allora generale
    if self.player_controllers[owner] == nil then
        self.player_controllers[owner] = {};
    end

    --Inserisci nella tabella il nuovo ID: in questo modo è incrementale
    table.insert(self.player_controllers[owner], ctrl_code);

    --Creazione del controllere: contiene questi dati oltre che l'ultimo environment generato dall'esecuzione dell'interprete
    ---@type Controller
    local controller = {
        controller_id = controller_id,
        pos = node_pos,
        owner = owner,                          -- owner of the unit
        reference_program = ctrl_code .. ".st", -- refrenced code file
        last_env = {},                          -- last env used
        enabled = false,
        protected = false,                      -- solo l'owner del PLC può aprirlo
        linked_iounits = {}                     -- array di id delle unità di IO
    };
    --Aggiungi il controllere
    self.registered_controllers[ctrl_code] = controller;
    --Registra il controllere per accettare IOUnits
    Industria.runtime.iounits:registerUnitToIORuntime(ctrl_code)

    return fnresult(true, Industria.translate("unit_created_with_code @1", ctrl_code), controller);
end

--- Returns a Unit, if present, binded to a player, knowing the unit's Code (ID+Owner name).
---@param ctrl_code ControllerCODE|nil The unit id, must be unique
---@return Result<Controller|nil> #If the function is completed then the field "data" contains the Unit
function Industria.controllers:getController(ctrl_code)
    --Se sono nulli allora non provare nemmeno a cercarla
    if not ctrl_code then
        return fnresult(false, Industria.translate("owner_unitid_not_defined"));
    end
    --Se non esiste allora esci
    if self.registered_controllers[ctrl_code] == nil then
        return fnresult(false, Industria.translate("unit_not_exists @1", ctrl_code));
    end

    return fnresult(true, nil, self.registered_controllers[ctrl_code]);
end

---Removes completly a unit: removse also files and saves.
---@param controller_id ControllerID unit id to be removed
---@param owner owner owner of the unit
---@return Result<nil>
function Industria.controllers:removeController(controller_id, owner)
    --Costruisce la stringa di come è salvata l'unità
    local ctrl_code = Industria.controllers.toControllerCode(controller_id, owner);
    --Se è nullo allora non provare nemmeno a cercarla
    if not ctrl_code then
        return fnresult(false, Industria.translate("owner_unitid_not_defined"));
    end
    --Se non esiste allora esci
    if self.registered_controllers[ctrl_code] == nil then
        return fnresult(false, Industria.translate("unit_not_exists", ctrl_code));
    end

    local controller = self.registered_controllers[ctrl_code];

    --Rimuovi dagli id delle unità del giocatore quella corrente
    local idx = table.indexof(self.player_controllers[owner], ctrl_code);
    if idx == -1 then
        return fnresult(false, Industria.translate("player_no_permission_unit"));
    end

    --Rimuove l'unità dall'ioruntime e unlinka tutti gli IOUnits
    Industria.runtime.iounits:unregisterControllerFromIORuntime(ctrl_code)

    table.remove(self.player_controllers[owner], idx);
    --Elimina il file del codice
    Industria.files.deleteControllerCode(controller);
    --Elimina il file dell'environment
    Industria.files.deleteControllerEnvironment(controller);
    --Rimuove la unit
    self.registered_controllers[ctrl_code] = nil;
    --Rimuovi la Unit dal runtime
    Industria.runtime:unregisterControllerFromRuntime(controller)

    return fnresult(true, Industria.translate("unit_removed"));
end

---Removes a previously associated IOUnit to an Unit. This function should be called when an IOUnit is removed or
---rebound to a different Unit.
---@param unit_code ControllerCODE The Unit code of the Unit from which the IOUnit has to be removed
---@param io_unit_code IOUnitCODE The IOUnit code to remove from the Unit
---@param deleteUnit boolean This parameters is used to call the function Industria.iounits.removeIOUnit to prevent cicrular calls.
---@return Result<nil|Controller>
function Industria.controllers:removeIOUnitFromController(unit_code, io_unit_code, deleteUnit)
    --Se il codice è nullo allora faccio finta di averla rimossa
    if io_unit_code == nil then
        return fnresult(true, Industria.translate("no_iounit_removed_from_unit"));
    end

    local res_unit = self:getController(unit_code);
    if not res_unit.completed then
        return res_unit;
    end
    --Unità da cui rimuovere il codice
    local unit = res_unit.data;
    if unit == nil or unit.linked_iounits == nil then
        return fnresult(false, Industria.translate("unit_not_contains_iounit"));
    end

    local idx = table.indexof(unit.linked_iounits, io_unit_code);
    if idx == -1 then
        return fnresult(false, Industria.translate("unit_not_contains_iounit"));
    end

    --Se devo eliminare anche l'unità IO allora chiamo la funzione che lo gestisce
    if deleteUnit then
        Industria.iounits:removeIOUnit(io_unit_code, unit.owner);
    end

    table.remove(unit.linked_iounits, idx);

    return fnresult(true, nil, unit);
end
