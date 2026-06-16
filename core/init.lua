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
    units = {},
    --- Contiene gli interpreti (instanze) he gestiscono le unitid
    ---@type table<unit_code,Interpreter|{}>
    interpreters = {} -- {codice1={...}}
};
