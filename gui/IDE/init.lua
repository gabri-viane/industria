local fnresult = Industria.commons.fnresult;
local sendPlayerMsg = core.chat_send_player;

Industria.formspecs.IDE = {
    callbacks = {},
    forms = {},
    FSKeyCode = "Industria:Controller:IDE",
}



---Restituisce i dati dell'IDE
---@param playername string Nome del giocatore
---@return Result<IDEData|nil> #Dati dell'IDE oppure nil se non è possibile recuperarli
function Industria.formspecs.IDE:getIDEData(playername)
    local res = Industria.formspecs:getPlayerStatus(playername);
    if res.showing ~= self.FSKeyCode then
        return fnresult(false, "Player is not currently in IDE Formspec")
    end

    local data = res.data
    --Se non ho inizializzato le variabili o gli errori li inizializzo
    if not data.variables then
        data.variables = {}
    end
    if not data.output then
        data.output = {}
    end
    return fnresult(true, nil, data)
end

---Aggiorna la playerdata (FSPlayerStatus) e imposta il formspec visualizato a FSKyeCode
---@param playername string
---@param data IDEData
function Industria.formspecs.IDE:updateIDEData(playername, data)
    if not data.variables then
        data.variables = {}
    end
    if not data.output then
        data.output = {}
    end
    Industria.formspecs:setPlayerStatus(playername, self.FSKeyCode, data)
end

---Aggiorna il Formspec ricaricando i nuovi dati
---@param playername string
function Industria.formspecs.IDE:refresh(playername)
    -- Prendo i dati del giocatore e controllo che siano presenti
    local data_res = self:getIDEData(playername)
    if data_res.completed then
        -- Se tutto è corretto mostro il formspec e imposto il callback per "onReceivedFields"
        Industria.formspecs:setCurrentCallback(playername,
            function(pname, fields)
                self.callbacks:STMainIDECallback(pname, fields);
            end);
        self:coreShowFormSpec(playername, self.forms.MainIDE(data_res.data));
    else
        sendPlayerMsg(playername, "No IDE data")
    end
end

dofile(Industria.path .. "/gui/IDE/forms.lua");
dofile(Industria.path .. "/gui/IDE/IDEMain.lua");
dofile(Industria.path .. "/gui/IDE/IDEVariableForm.lua");
dofile(Industria.path .. "/gui/IDE/IDEOutputForm.lua");
dofile(Industria.path .. "/gui/IDE/IDECodeForm.lua");

---Chiude il form al giocatore.
---@param playername string Giocatore a cui chiudere il formspec
---@param message string|nil Messaggio facoltativo da mostrare al giocatore alla chiusura
---@param preserveData boolean|nil Se chiamando questa funzione non elimina i dati (di default li elimina)
function Industria.formspecs.IDE:coreCloseFormSpec(playername, message, preserveData)
    if message ~= nil then
        sendPlayerMsg(playername, message);
    end
    if preserveData then
        local res = self:getIDEData(playername); -- Non mi interessa se mi restituisce nil oppure IDEData, in qualsisasi caso mantengo
        Industria.formspecs:setPlayerStatus(playername, nil, res.data);
    else
        Industria.formspecs:setPlayerStatus(playername, nil, nil);
    end
    -- Chiudo il formspec
    core.close_formspec(playername, self.FSKeyCode)
    -- Se ho una funzione di callback da chiamare la chiamo e la consumo
    if Industria.formspecs:getPlayerStatus(playername).fallbackto ~= nil then
        Industria.formspecs:getPlayerStatus(playername).fallbackto(); --Esegui il callback se presente
        Industria.formspecs:setPlayerStatusFallback(playername, nil); --Consuma il callback
    end
end

function Industria.formspecs.IDE:coreShowFormSpec(playername, formspec)
    core.show_formspec(playername, self.FSKeyCode, formspec)
end

---Shows the IDE to a Player to programm a Controller
---@param playername string
---@param ctrl_code ControllerCODE
function Industria.formspecs.IDE:IDE(playername, ctrl_code)
    self:showIDE(playername, ctrl_code)
end
