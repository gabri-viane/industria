Industria.ST = {};
Industria.files = {};
Industria.controllers = {
    ---Contiene gli id delle unità di un giocatore nel formato:
    ---{nome_owner={codice1, codice2, codice3}}
    ---@type table<owner, unit_id[]>
    ids = {},
    ---Contiene le unità con il codice associato nel formato:
    ---{codice1={...},codice2={...}}
    ---@type table<unit_code,Unit>
    units = {}
};
Industria.runtime = {
    ---Contiene tutte le unità caricate/create: se un unità non è
    ---presente in questa tabella allora non può essere avviata a runtime
    ---
    ---@type table<unit_code,RTInfo> Tabella che associa unit_code a {enabled,interpreter}
    units = {},
};
