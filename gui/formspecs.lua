---@alias FSPlayerStatus {showing:string,data:any,fallbackto:function|nil}


---Contains functions and data to handle Formspecs
Industria.formspecs = {
    ---@type FSPlayerStatus
    players_status = {}, -- Contiene quale form viene mostrato a quale giocatore

    ---@type table<string, function<string,any>>
    player_callbacks = {} -- Contiene il callback corrente
};

---Changes the current player status (relative to formspecs displayed)
---@param playername string The playe to set the status to
---@param formspecid string|nil ID of the formspec
---@param data any Data associated (if any)
function Industria.formspecs:setPlayerStatus(playername, formspecid, data)
    if self.players_status[playername] == nil then
        self.players_status[playername] = {};
    end
    self.players_status[playername].showing = formspecid;
    self.players_status[playername].data = data;
end

---Changes the current player status fallback function: this function will be called back when current formspec is closed
---@param playername string The playe to set the status to
---@param fallbackto function|nil function to call when closing form
function Industria.formspecs:setPlayerStatusFallback(playername, fallbackto)
    if self.players_status[playername] == nil then
        self.players_status[playername] = {};
    end
    self.players_status[playername].fallbackto = fallbackto;
end

---Get current player status (Formspec displaying)
---@param playername string
---@return FSPlayerStatus #The current status of Formspec that is being displayed to the player
function Industria.formspecs:getPlayerStatus(playername)
    if self.players_status[playername] == nil then
        self.players_status[playername] = {};
        return {};
    end
    return self.players_status[playername];
end

---Set's the current callback handler for the "on_receive_fields" event.
---@param playername string The player name
---@param callback function<string,any> The function callback when on_receive_fields corrisponding to the formname is received
function Industria.formspecs:setCurrentCallback(playername, callback)
    if self.player_callbacks[playername] == nil then
        self.player_callbacks[playername] = nil;
    end
    self.player_callbacks[playername] = callback;
end

----------------------------------------------CALLBACKS---------------------------------------------

-- Contiene i callbacks per le risposte dei Formspec
-- Le funzioni dovrebbero contenere due parametri: player, fields
Industria.formspecs.callbacks = {};

core.register_on_player_receive_fields(function(player, formname, fields)
    local pname = player:get_player_name();
    local pstatus = Industria.formspecs:getPlayerStatus(pname); --Status of player

    if pstatus == nil or pstatus.showing ~= formname then
        -- Se non ho lo stato del giocatore allora sicuramente non gli stavo mostrando il formspec
        -- Oppure se quello che sto mostrando è diverso da quello che ho salvato nello stato
        --core.chat_send_player(pname, "Method not available in current context");
        return;
    end
    -- Chiama la funzione di callback
    local fncallback = Industria.formspecs.player_callbacks[pname];
    if fncallback ~= nil and type(fncallback) == "function" then
        fncallback(pname, fields);
    end
    --[[
    -- Se è il formspec dell'editor ST allora lo gestisco
    if formname == "Industria:Unit:UnitMainForm" then
        Industria.formspecs.callbacks:UnitMainFormCallback(pname, fields);
    elseif formname == "Industria:Unit:Editor" then
        Industria.formspecs.callbacks:STEditorCallback(pname, fields);
    elseif formname == "Industria:Unit:SetIDInput" then
        Industria.formspecs.callbacks:PLCIDInputCallback(pname, fields);
    end
    ]] --
end)


dofile(Industria.path.."/gui/STCodeEditorFS.lua");
dofile(Industria.path.."/gui/UnitIDInputFS.lua");
dofile(Industria.path.."/gui/UnitMainFormFS.lua");