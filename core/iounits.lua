local fnresult = Industria.commons.fnresult;

--- Serialize the content of Industria.iounits (only ids and iounits) to the file "iounits.dt" in the world's folder.
---@return Result<nil> #It's completed if the the serialization succedees
function Industria.iounits:serialize()
    local data = {
        ids = self.ids,
        registered = self.registered,
        ioruntime = { inputs = Industria.runtime.iounits.inputs, outputs = Industria.runtime.iounits.outputs }
    };
    local text = core.serialize(data);
    -- Scrivi il file con i dati dei controllori
    local f, err = io.open(Industria.datapath .. "/iounits.dt", "w+");
    if err or f == nil then
        return fnresult(false, err, nil);
    end
    f:write(text);
    f:flush();
    f:close();
    return fnresult(true, "World IOUnits saved", nil);
end

---Deserialize the file "iounits.dt" in the mod's folder of the world and loads the ids and iounits saved.
---@return Result<table|nil> #It's completed if the the deserialization succedees and the field "data" is set to point to Industria.iounits
function Industria.iounits:deserialize()
    -- Carica il file con i dati dei controllori
    local f, err = io.open(Industria.datapath .. "/iounits.dt", "r");
    if err or f == nil then
        return fnresult(false, err, nil);
    end

    local text = f:read("a");
    f:close();
    local data = core.deserialize(text, true);
    if data == nil then
        return fnresult(false, "Data not loaded", nil);
    end
    if data.ids == nil or data.registered == nil then
        return fnresult(false, "Data doesn't contain the required fields", nil);
    end
    self.ids = data.ids;
    self.registered = data.registered;
    if data.ioruntime then
        Industria.runtime.iounits.inputs = data.ioruntime.inputs
        Industria.runtime.iounits.outputs = data.ioruntime.outputs
    end

    return fnresult(true, nil, self);
end

-------------------------------------------------------------------------
---                     FUNZIONI DI UTILITY                           ---
-------------------------------------------------------------------------

---Given the position of the Node that represents the IOUnit returns the IOUnit Code
---@param pos any The Unit Node position
---@return string|nil #returns nil if the parameter is nil, otherwise the iounit_code
function Industria.iounits.getIOUnitCode(pos)
    if not pos then
        return nil
    end
    return "x" .. pos.x .. "y" .. pos.y .. "z" .. pos.z
end

-------------------------------------------------------------------------
---                     GESTIONE IOUNITS REGISTRATE                   ---
-------------------------------------------------------------------------

---Prende, se esiste, il valore salvato nel nodo "iounit_name" contenuto in "industria_props". Controlla
---che esista il nodo, che il nodo abbia la proprietà "industria_props" e che faccia parte del gruppo "industria_iounit".
---Se queste valutazioni danno esito positivo allora viene controllato che esista "iounit_name" all'interno di "industria_props".
---@param node_name string Il nome con cui il nodo è stato registrato.
---@return Result<IOUnitName|nil> #Restituisce, se trovato, il nome dell'unità IO che questo blocco rappresenta
---                               (registrato in Industria.runtime.iounits.states)
local function getIOUnitName(node_name)
    local node = core.registered_nodes[node_name];
    if not node then
        return fnresult(false, Industria.translate("unregistred_node @1", node_name), nil);
    end

    if not node.industria_props or not node.groups.industria_iounit then
        return fnresult(false, Industria.translate("node_not_iounit"), nil);
    end

    local data = node.industria_props
    if not data.iounit_name then
        return fnresult(false, Industria.translate("invalid_io_ref_name"), nil);
    end
    return fnresult(true, nil, data.iounit_name);
end

---Find the state of the IOUnit linked to a certain variable of the environment of the Unit
---@param iounit IOUnit
---@param envVarName string
---@return varname|nil
function Industria.iounits.getLinkedState(iounit, envVarName)
    if not envVarName then
        return nil
    end
    --Cerco se la variabile è linkata a qualche stato della IOUnit
    for key, value in pairs(iounit.io_ports) do
        if value.linked_var and value.linked_var == envVarName then
            return key
        end
    end
    return nil
end

---Get the state of a Node if it was registered as an IOUnit.
---@param node_name string Name of the node: must be an IOUnit
---@param state_name string Name of the state to get
---@return Result<IOProperty | nil> #The state requested
function Industria.iounits.getNodeState(node_name, state_name)
    local result = getIOUnitName(node_name)
    if not result.completed then
        return fnresult(false, result.msg, nil)
    end

    local state = Industria.runtime.iounits.definitions[result.data][state_name]
    if not state or not state.value or not state.iotype or not state.dtype then
        return fnresult(false, Industria.translate("iounit_state_not_exists_or_different"), nil);
    end

    return fnresult(true, nil, state);
end

---Find all the states of a Node if the node was registered as an IOUnit.
---@param node_name string Name of the node: must be registered as an IOUnit to get the requested State.
---@return Result<IOPropertyList|nil> #The list of the states of the IOUnit
function Industria.iounits.getNodeStates(node_name)
    local result = getIOUnitName(node_name)
    if not result.completed then
        return fnresult(false, result.msg, nil)
    end

    return fnresult(true, nil, Industria.runtime.iounits.definitions[result.data]);
end

---Get the state of the IOUnit given the IOUnit refrence.
---@param iounit IOUnit The IOUnit reference
---@return Result<IOProperty|nil> #The state requested
function Industria.iounits.getIOUnitState(iounit, state_name)
    if not iounit.iounit_name then
        return fnresult(false, Industria.translate("iounit_state_not_exists_or_different"), nil)
    end
    local state = Industria.runtime.iounits.definitions[iounit.iounit_name][state_name]
    if not state or not state.value or not state.iotype or not state.dtype then
        return fnresult(false, Industria.translate("iounit_state_not_exists_or_different"), nil);
    end
    return fnresult(true, nil, Industria.runtime.iounits.definitions[iounit.iounit_name]);
end

---Find all the states of the IOUnit given the IOUnit reference
---@param iounit IOUnit The IOUnit reference
---@return Result<IOPropertyList|nil> #The list of the states of the IOUnit
function Industria.iounits.getIOUnitStates(iounit)
    if not iounit.iounit_name then
        return fnresult(false, Industria.translate("iounit_state_not_exists_or_different"), nil)
    end
    return fnresult(true, nil, Industria.runtime.iounits.definitions[iounit.iounit_name]);
end

---Get the states defined for an IOUnit as a list of strings (returns just the states names).
---@param node string|IOUnit Name of the node or an IOUnit reference
---@return Result<string[] | nil> #List of states' names
function Industria.iounits.getAvailableStates(node)
    local result;
    if type(node) == "string" then
        result = Industria.iounits.getNodeStates(node)
    elseif type(node) == "table" and node.iounit_name then
        result = Industria.iounits.getIOUnitStates(node)
    else
        return fnresult(false, Industria.translate("invalid_nodename_or_iounit"), nil)
    end

    if not result.completed then
        return fnresult(false, result.msg, nil)
    end

    -- Prendo tutti gli stati possibili per questo blocco
    local states = {}
    for key, _ in pairs(Industria.runtime.iounits.definitions[result.data]) do
        table.insert(states, key)
    end
    return fnresult(true, nil, states);
end

-------------------------------------------------------------------------
---                     GESTIONE REGISTRAZIONE IOUNITS                ---
-------------------------------------------------------------------------


---Register an IO Unit: registered units can be checked during runtime to get or set their values/properites
---@param owner owner Owner of the IO Unit
---@param pos any|nil Position of the node that is going to be registered as an IO Unit
---@return Result<IOUnit|nil> #Returns the newly created IOUnit
function Industria.iounits:registerIOUnit(owner, pos)
    if owner == nil then
        return fnresult(false, Industria.translate("iounit_owner_not_valid"), nil);
    end

    local iounit_code = Industria.iounits.getIOUnitCode(pos)
    if not iounit_code then
        return fnresult(false, Industria.translate("iounit_code_invalid"), nil);
    end

    local node = core.get_node_or_nil(pos)
    if not node then
        return fnresult(false, Industria.translate("node_invalid"), nil);
    end

    local result = getIOUnitName(node.name)
    if not result.completed then
        return fnresult(false, result.msg, nil)
    end

    --Se non esiste la tabella di id associata al giocatore allora generale
    if self.ids[owner] == nil then
        self.ids[owner] = {};
    end
    --Inserisci nella tabella il nuovo ID: in questo modo è incrementale
    table.insert(self.ids[owner], iounit_code);

    local io_ports = {}
    for key, value in pairs(Industria.runtime.iounits.definitions[result.data]) do
        io_ports[key] = { linked_var = nil, type = value.iotype }
    end

    ---@type IOUnit
    local iounit = {
        iounit_name = result.data,
        iounit_code = iounit_code,
        owner = owner,
        reference_controller = nil,
        io_ports = io_ports,
        pos_block = pos,
        linked_properties = {}
    };
    self.registered[iounit_code] = iounit;

    return fnresult(true, nil, iounit);
end

---Removes completly an IO Unit. This will invalid remove the references to the previously binded variables.
---@param iounit_code IOUnitCODE IO Unit to be removed
---@param owner owner owner of the IO Unit
---@return Result<nil>
function Industria.iounits:unregisterIOUnit(iounit_code, owner)
    --Se sono nulli allora non provare nemmeno a cercarla
    if not iounit_code or not owner then
        return fnresult(false, Industria.translate("owner_iounitcode_not_defined"));
    end
    --Se non esiste allora esci
    local iounit = self.registered[iounit_code];
    if iounit == nil then
        return fnresult(false, Industria.translate("iounit_not_exists @1", iounit_code));
    end
    if self.ids[iounit.owner] == nil then --self.ids[owner] == nil then
        return fnresult(false, Industria.translate("iounit_owner_not_valid"));
    end
    --Cerca se il giocatore "owner" la possiede
    local idx = table.indexof(self.ids[iounit.owner], iounit_code); -- self.ids[owner], iounit_code);
    if idx == -1 then
        return fnresult(false, Industria.translate("player_no_permission_iounit"));
    end

    if iounit.reference_controller then
        --Per prevenire che la funzioni richiami a sua volta questa funzione per eliminare il
        Industria.runtime.iounits:unlink(iounit);
    end

    --Elimina l'unità IO
    self.registered[iounit_code] = nil;
    table.remove(self.ids[iounit.owner], idx); --self.ids[owner], idx)

    return fnresult(true, Industria.translate("iounit_removed"));
end

--- Returns an IOUnit, if present, binded to a player, knowing the iounit's Code.
---@param iounit_code IOUnitCODE|nil The iounit code, must be unique
---@return Result<IOUnit|nil> #If the function is completed then the field "data" contains the IOUnit
function Industria.iounits:getIOUnit(iounit_code)
    --Se sono nulli allora non provare nemmeno a cercarla
    if not iounit_code then
        return fnresult(false, Industria.translate("iounit_code_invalid"));
    end
    --Se non esiste allora esci
    if self.registered[iounit_code] == nil then
        return fnresult(false, Industria.translate("unit_not_exists @1", iounit_code));
    end

    return fnresult(true, nil, self.registered[iounit_code]);
end

---Get Node name for the IOUnit
---@param iounit IOUnit
---@return string|nil
function Industria.iounits.getIOUnitNodeName(iounit)
    if not iounit then
        return nil;
    end
    if not iounit.pos_block then
        return nil;
    end
    local node = core.get_node_or_nil(iounit.pos_block)
    if node then
        return node.name
    end
    return nil
end
