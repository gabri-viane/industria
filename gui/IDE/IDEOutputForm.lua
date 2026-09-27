function Industria.formspecs.IDE.callbacks:OutputFormCallback(player_name, fields, playerdata)
    if fields.clearOutput then
        --Validazione del nome della variabile
        playerdata.output = {}

        Industria.formspecs.IDE:updateIDEData(player_name, playerdata);
    end
end
