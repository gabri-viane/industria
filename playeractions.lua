Industria.playerActions = {
    players = {}
};
---Adds to the player an action (overrides the previous one)
---@param playername string
---@param action_name string
---@param action_data any
function Industria.playerActions:addAction(playername, action_name, action_data)
    if self.players[playername] == nil then
        self.players[playername] = {};
    end

    self.players[playername][action_name] = action_data;
end

---Removes from a player an aciton given its name
---@param playername string
---@param action_name string
function Industria.playerActions:removeAction(playername, action_name)
    if self.players[playername] == nil then
        return;
    end

    self.players[playername][action_name] = nil;
end

---Gets an action, if exists, of a player
---@param playername string
---@param action_name string
---@return any|nil #Returns the action if present or nil
function Industria.playerActions:getAction(playername, action_name)
    if self.players[playername] == nil then
        return nil;
    end

    return self.players[playername][action_name];
end