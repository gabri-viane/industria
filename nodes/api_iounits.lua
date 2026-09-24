local fnresult = Industria.commons.fnresult

---@alias InputFunction fun(iounit: IOUnit): any
---@alias OutputFunction fun(iounit: IOUnit, value: any): nil
---@alias InputOutputFunction fun(iounit: IOUnit, value: any): any

---Create the states for an IOUnit like a builder class. The states represents what kind of properties the IOUnit has and can share with the Control Units.
---@param iounit_name IOUnitName The name of type of IOUnit to register
---@return IOBuilder #The builder itself
function Industria.IOStatesBuilder(iounit_name)
    ---@class IOBuilder
    local IOBuilder = {
        iounit_name = iounit_name,
        states_props = {}
    }

    ---Create a state for the IOUnit
    ---@param state_name string Name of the state to be added
    ---@return IOStateBuilder
    function IOBuilder:addState(state_name)
        ---@class IOStateBuilder
        local IOStateBuilder = {
            state = state_name
        }
        ---Generates the InputFunction for the field "Value" of a state
        ---@param callbackFunction InputFunction
        ---@param dtype DType INT, REAL, STRING, BOOL
        ---@return IOStateBuilder
        function IOStateBuilder:generateInputFunction(callbackFunction, dtype)
            if type(callbackFunction) ~= "function" then
                error("Incorrect Argument: required Input function but found '" .. type(callbackFunction) .. "'")
            end
            self.value = callbackFunction --funzione di callback
            self.dtype = dtype;           -- Tipo restituito dalla funzione
            self.iotype = 0;              -- Input
            return self
        end

        ---Sets the value field as an OutputFunction that will be called on state change event
        ---@param callbackFunction OutputFunction The output function that the Unit will call when the outputs are written
        ---@param dtype DType INT, REAL, STRING, BOOL
        ---@return IOStateBuilder
        function IOStateBuilder:generateOutputFunction(callbackFunction, dtype)
            if type(callbackFunction) ~= "function" then
                error("Incorrect Argument: required Output function but found '" .. type(callbackFunction) .. "'")
            end
            self.value = callbackFunction --funzione di callback
            self.dtype = dtype;           -- Tipo restituito dalla funzione
            self.iotype = 1;              -- Input
            return self
        end

        ---Sets the value field as an InputOutputFunction that will be called both when Unit reads the input and writes the outputs
        ---@param callbackFunction InputOutputFunction
        ---@param dtype DType INT, REAL, STRING, BOOL
        ---@return IOStateBuilder
        function IOStateBuilder:generateInputOutputFunction(callbackFunction, dtype)
            if type(callbackFunction) ~= "function" then
                error("Incorrect Argument: required InputOutput function but found '" .. type(callbackFunction) .. "'")
            end
            self.value = callbackFunction --funzione di callback
            self.dtype = dtype;           -- Tipo restituito dalla funzione
            self.iotype = 2;              -- Input/Output
            return self
        end

        ---Sets the value field to a constant value. Useful whene the node has a constant properties like buttons
        ---(pressed node has a different state value from the not-pressed node)
        ---@param value number | string | boolean The value binded to the state. Can be also a function:
        ---                 -INPUT:  accepts the IOUnit as argument and returns the value to send to the unit
        ---                 -OUTPUT: accepts the IOUnit and the value given by the unit as argument
        ---                 -INPUT/OUTPUT: both of the previous
        ---@param dtype DType
        function IOStateBuilder:setConstantInputValue(value, dtype)
            local vtype = type(value)
            if (vtype == "number" and (dtype == "INT" or dtype == "REAL")) or
                (type(value) == "string" and dtype == "STRING") or
                (type(value) == "boolean" and dtype == "BOOL")
            then
                if dtype == "INT" then
                    local val = math.tointeger(value);
                    if val then
                        value = val;
                    end
                end
                self.value = value;
                self.dtype = dtype;
                self.iotype = 0;
                return self
            end
            error("Mismatch Argument: given value doesn't match DType (" .. type(value) .. " ~= " .. dtype .. ")")
        end

        ---Build the state
        function IOStateBuilder:build()
            if self.value and self.dtype and self.iotype and self.state then
                IOBuilder.states_props[self.state] = { value = self.value, iotype = self.iotype, dtype = self.dtype }
                return IOBuilder
            end
            error("Invalid State: value or dtype or iotype or state name is invalid")
        end

        return IOStateBuilder
    end

    ---Register the states for the IOUnit
    function IOBuilder:register()
        Industria.runtime.iounits.definitions[iounit_name] = self.states_props;
    end

    return IOBuilder
end

---Register a Node as an IOUnit. An IOUnit must be previosuly defined by it's states with Industria.IOStatesBuilder
---@param iounit_name IOUnitName The unit name (such as button, lamp, lever, ...) which defines the states available for the IOUnit
---@param node_name string The name of the node that will be passed to core.register_node
---@param node_definition table The definition of the node that will be passed to core.register_node . The definition will be altered by adding industria_props and the group definitio industria_iounit
---@param after_place_callback function|nil Function to pass to the callback of the node
---@param after_dig_callback function|nil Function to pass to the callback of the node
function Industria.registerIOUnitNode(iounit_name, node_name, node_definition,
                                  after_place_callback, after_dig_callback)
    if not Industria.runtime.iounits.definitions[iounit_name] then
        error("Unregisterd IOUnit: requested to register the node '" ..
            node_name .. "' as an undefined IOUnit '" .. iounit_name .. "'")
    end
    --Aggiungo le informazioni per la IOUnit
    if not node_definition.industria_props then
        node_definition.industria_props = { iounit = 1, iounit_name = iounit_name }
    else
        node_definition.industria_props.iounit = 1
        node_definition.industria_props.iounit_name = iounit_name
    end
    --Aggiungo il gruppo per segnare che è una IOUnit
    if not node_definition.groups then
        node_definition.groups = { industria_iounit = 1 }
    else
        node_definition.groups.industria_iounit = 1
    end

    --Registro la funzione di callback del nodo
    node_definition.after_place_node = function(pos, placer, itemstack, pointed_thing)
        if placer and placer:is_player() then
            --Registro l'IOUnit
            Industria.iounits:registerIOUnit(placer:get_player_name(), pos)
        end
        if after_place_callback then
            return after_place_callback(pos, placer, itemstack, pointed_thing)
        end
        return false --Consuma l'oggetto
    end

    node_definition.after_dig_node = function(pos, oldnode, oldmetadata, digger)
        local iounit_code = Industria.iounits.getIOUnitCode(pos)
        if not iounit_code then
            return;
        end
        local res = Industria.iounits:getIOUnit(iounit_code)
        --Devo controllare se esiste l'IOUnit
        if not res.completed then
            --Se non la ho non devo rimuovere nulla
            return;
        end
        local iounit = res.data
        if not iounit then
            --Se non lo ho non devo rimuovere nulla
            return;
        end
        local playername = ""
        if digger:is_player() then
            playername = digger:get_player_name()
        end
        local res2 = Industria.iounits:unregisterIOUnit(iounit_code, playername)
        if res2.completed then
            core.chat_send_player(iounit.owner,
                "The IOUnit at position (" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ") has been removed.");
        elseif digger:is_player() then
            core.chat_send_player(playername, res.msg);
        end

        if after_dig_callback then
            after_dig_callback(pos, oldnode, oldmetadata, digger)
        end
    end

    core.register_node(node_name, node_definition)
end
