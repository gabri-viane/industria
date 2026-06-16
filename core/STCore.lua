-- ============================================================
--  st_plc.lua  –  Simulatore PLC Structured Text (IEC 61131-3)
--
--  Modella il ciclo di vita reale di un PLC:
--
--    POWER-ON:
--      Lexer -> Parser -> AST
--      interp:init()   <- alloca env da VAR  (una sola volta)
--
--    SCAN LOOP (ripetuto):
--      interp:cycle()  <- esegue il corpo del PROGRAM
--      le variabili in env persistono tra un ciclo e l'altro
--      [attesa inter-ciclo opzionale]
--      loop fino a --cycles N  oppure Ctrl-C
--
--  Uso:
--    lua st_plc.lua <file.st> [opzioni]
--
--  Opzioni:
--    --cycles  N   numero di cicli da eseguire (default: 10)
--    --delay   N   pausa in millisecondi tra un ciclo e l'altro (default: 0)
--    --trace       stampa su stderr ogni istruzione eseguita
-- ============================================================


-- ────────────────────────────────────────────────────────────
--  UTILITÀ GLOBALI
-- ────────────────────────────────────────────────────────────

local fnresult = Industria.commons.fnresult;

-- Genera un errore di runtime con prefisso uniforme "[RUNTIME]".
-- Il livello 2 fa puntare il messaggio al chiamante, non qui dentro.
local function runtime_error(msg)
    error("[RUNTIME] " .. msg, 2)
end


-- ────────────────────────────────────────────────────────────
--  LEXER
--  Responsabilità: trasformare il testo sorgente in una lista
--  piatta di token { type, value, line }.
-- ────────────────────────────────────────────────────────────

-- Insieme delle parole riservate del linguaggio, in uppercase.
-- Usato per distinguere identificatori normali da keyword.
-- La chiave è la forma uppercase, il valore è la stessa stringa
-- (serve solo come presenza nel set).
local KEYWORDS = {
    PROGRAM = "PROGRAM",
    END_PROGRAM = "END_PROGRAM",
    VAR = "VAR",
    END_VAR = "END_VAR",
    IF = "IF",
    THEN = "THEN",
    ELSIF = "ELSIF",
    ELSE = "ELSE",
    END_IF = "END_IF",
    FOR = "FOR",
    TO = "TO",
    DO = "DO",
    END_FOR = "END_FOR",
    WHILE = "WHILE",
    END_WHILE = "END_WHILE",
    TRUE = "TRUE",
    FALSE = "FALSE",
    AND = "AND",
    OR = "OR",
    NOT = "NOT",
    INT = "INT",
    REAL = "REAL",
    BOOL = "BOOL",
    STRING = "STRING",
}

-- Mappa da keyword uppercase → tipo di token (TokenType).
-- Alcune keyword condividono lo stesso tipo (TRUE e FALSE → "BOOL"),
-- altre hanno un tipo distinto per evitare conflitti con i tipi dato
-- (BOOL keyword vs BOOL_T tipo, STRING keyword vs STRING_T tipo).
local KW_TO_TT = {
    PROGRAM = "PROGRAM",
    END_PROGRAM = "END_PROGRAM",
    VAR = "VAR",
    END_VAR = "END_VAR",
    IF = "IF",
    THEN = "THEN",
    ELSIF = "ELSIF",
    ELSE = "ELSE",
    END_IF = "END_IF",
    FOR = "FOR",
    TO = "TO",
    DO = "DO",
    END_FOR = "END_FOR",
    WHILE = "WHILE",
    END_WHILE = "END_WHILE",
    TRUE = "BOOL",
    FALSE = "BOOL", -- letterali booleani
    AND = "AND",
    OR = "OR",
    NOT = "NOT",
    INT = "INT",
    REAL = "REAL",
    BOOL = "BOOL_T",
    STRING = "STRING_T", -- nomi di tipo (usati in VAR)
}

-- Costruisce e restituisce un oggetto Lexer per il sorgente dato.
-- Lo stato interno (posizione, numero di riga, lista token) è
-- incapsulato nella closure; l'unico metodo pubblico è :tokenize().
local function new_lexer(source)
    local lex = { src = source, pos = 1, line = 1, tokens = {} }

    -- Legge il carattere a distanza `n` dalla posizione corrente
    -- senza avanzare. Con n=0 (default) è il look-ahead corrente.
    local function peek(n) return lex.src:sub(lex.pos + (n or 0), lex.pos + (n or 0)) end

    -- Consuma e restituisce il carattere corrente, aggiornando il
    -- contatore di riga quando incontra un newline.
    local function advance()
        local c = lex.src:sub(lex.pos, lex.pos)
        lex.pos = lex.pos + 1
        if c == "\n" then lex.line = lex.line + 1 end
        return c
    end

    -- Costruisce un token con tipo, valore e numero di riga corrente.
    local function tok(tt, val) return { type = tt, value = val, line = lex.line } end

    -- Metodo principale: scandisce l'intero sorgente e popola
    -- self.tokens. Ogni iterazione consuma almeno un carattere.
    function lex:tokenize()
        while self.pos <= #self.src do
            local c = peek()

            -- Spazio bianco: semplicemente ignorato
            if c:match("%s") then
                advance()

                -- Commento (* ... *): avanza fino alla sequenza di chiusura.
                -- Non supporta commenti annidati (come lo standard IEC).
            elseif c == "(" and peek(1) == "*" then
                self.pos = self.pos + 2 -- salta "(""*"
                while self.pos <= #self.src do
                    if peek() == "*" and peek(1) == ")" then
                        self.pos = self.pos + 2; break
                    end
                    advance()
                end

                -- Commento // riga: ignora fino al newline (non standard IEC,
                -- ma comune nelle implementazioni reali).
            elseif c == "/" and peek(1) == "/" then
                while self.pos <= #self.src and peek() ~= "\n" do advance() end

                -- Stringa letterale 'testo': raccoglie i caratteri tra apici
                -- singoli. Non gestisce escape sequences.
            elseif c == "'" then
                advance() -- consuma l'apice aperto
                local s = {}
                while self.pos <= #self.src and peek() ~= "'" do
                    table.insert(s, advance())
                end
                advance() -- consuma l'apice chiuso
                table.insert(self.tokens, tok("STRING", table.concat(s)))

                -- Numero: intero o reale (con punto decimale).
                -- tonumber() converte automaticamente "3.14" in float e "42" in int.
            elseif c:match("%d") then
                local num = {}
                while peek():match("[%d%.]") do table.insert(num, advance()) end
                local ns = table.concat(num)
                table.insert(self.tokens, tok("NUMBER", tonumber(ns)))

                -- Identificatore o keyword: inizia con lettera o underscore,
                -- continua con lettere, cifre, underscore.
                -- Il confronto con KEYWORDS è case-insensitive (uppercase).
            elseif c:match("[%a_]") then
                local id = {}
                while peek():match("[%a%d_]") do table.insert(id, advance()) end
                local word = table.concat(id)
                local upper = word:upper()
                if KEYWORDS[upper] then
                    -- È una keyword: usa il tipo specifico e il valore canonico.
                    -- TRUE/FALSE ottengono il valore Lua boolean direttamente.
                    local tt  = KW_TO_TT[upper] or upper
                    local val = (upper == "TRUE") and true or (upper == "FALSE") and false or word
                    table.insert(self.tokens, tok(tt, val))
                else
                    -- Identificatore utente: mantiene la scrittura originale
                    table.insert(self.tokens, tok("IDENT", word))
                end

                -- Operatori a DUE caratteri: devono essere controllati prima
                -- di quelli a un carattere per evitare match parziali.
            elseif c == ":" and peek(1) == "=" then
                self.pos = self.pos + 2; table.insert(self.tokens, tok("ASSIGN", ":="))
            elseif c == "<" and peek(1) == "=" then
                self.pos = self.pos + 2; table.insert(self.tokens, tok("LE", "<="))
            elseif c == ">" and peek(1) == "=" then
                self.pos = self.pos + 2; table.insert(self.tokens, tok("GE", ">="))
            elseif c == "<" and peek(1) == ">" then
                self.pos = self.pos + 2; table.insert(self.tokens, tok("NEQ", "<>"))

                -- Operatori e punteggiatura a UN carattere
            elseif c == "<" then
                advance(); table.insert(self.tokens, tok("LT", "<"))
            elseif c == ">" then
                advance(); table.insert(self.tokens, tok("GT", ">"))
            elseif c == "=" then
                advance(); table.insert(self.tokens, tok("EQ", "="))
            elseif c == "+" then
                advance(); table.insert(self.tokens, tok("PLUS", "+"))
            elseif c == "-" then
                advance(); table.insert(self.tokens, tok("MINUS", "-"))
            elseif c == "*" then
                advance(); table.insert(self.tokens, tok("STAR", "*"))
            elseif c == "/" then
                advance(); table.insert(self.tokens, tok("SLASH", "/"))
            elseif c == ":" then
                advance(); table.insert(self.tokens, tok("COLON", ":"))
            elseif c == ";" then
                advance(); table.insert(self.tokens, tok("SEMI", ";"))
            elseif c == "," then
                advance(); table.insert(self.tokens, tok("COMMA", ","))
            elseif c == "." then
                advance(); table.insert(self.tokens, tok("DOT", "."))
            elseif c == "(" then
                advance(); table.insert(self.tokens, tok("LPAREN", "("))
            elseif c == ")" then
                advance(); table.insert(self.tokens, tok("RPAREN", ")"))
            else
                -- Carattere non riconosciuto: avvisa ma continua (tolleranza errori)
                io.stderr:write(("Carattere inatteso '%s' alla riga %d\n"):format(c, self.line))
                advance()
            end
        end
        -- Sentinella EOF: il parser la usa per sapere quando fermarsi
        -- senza dover controllare i limiti dell'array ad ogni passo.
        table.insert(self.tokens, tok("EOF", nil))
        return self.tokens
    end

    return lex
end


-- ────────────────────────────────────────────────────────────
--  PARSER  (Recursive Descent)
--  Responsabilità: consumare la lista di token e costruire l'AST.
--
--  Ogni nodo AST è una table Lua con almeno il campo `kind`.
--  La grammatica implementata (semplificata):
--
--    program    ::= PROGRAM IDENT var_section* stmt* END_PROGRAM
--    var_section::= VAR (IDENT+ ':' type (':=' expr)? ';')* END_VAR
--    stmt       ::= assign | if_stmt | for_stmt | while_stmt | call_stmt
--    expr       ::= or_expr
--    or_expr    ::= and_expr  (OR  and_expr)*
--    and_expr   ::= rel_expr  (AND rel_expr)*
--    rel_expr   ::= add_expr  (('<'|'>'|'<='|'>='|'='|'<>') add_expr)*
--    add_expr   ::= mul_expr  (('+'|'-') mul_expr)*
--    mul_expr   ::= unary     (('*'|'/') unary)*
--    unary      ::= ('-'|NOT) unary | primary
--    primary    ::= NUMBER | STRING | BOOL | IDENT ['(' args ')'] | '(' expr ')'
-- ────────────────────────────────────────────────────────────

local function new_parser(tokens)
    local p = { tokens = tokens, pos = 1 }

    -- Restituisce il token corrente senza consumarlo
    local function cur() return p.tokens[p.pos] end

    -- Consuma e restituisce il token corrente
    local function advance()
        local t = cur(); p.pos = p.pos + 1; return t
    end

    -- Controlla il tipo del token corrente senza consumarlo
    local function check(tt) return cur().type == tt end

    -- Consuma il token solo se il tipo corrisponde; altrimenti nil
    local function match(tt) if check(tt) then return advance() end end

    -- Come match ma genera un errore se il tipo non corrisponde.
    -- Usato dove un certo token è obbligatorio dalla grammatica.
    local function expect(tt)
        local t = cur()
        if t.type ~= tt then
            error(("Riga %d: atteso '%s', trovato '%s' ('%s')")
                :format(t.line, tt, t.type, tostring(t.value)), 2)
        end
        return advance()
    end

    -- Helper per creare un nodo AST: aggiunge il campo `kind` alla
    -- table opzionale passata e la restituisce.
    local function node(k, tbl)
        tbl = tbl or {}; tbl.kind = k; return tbl
    end

    -- Forward declaration: parse_stmt e parse_expr si chiamano a vicenda
    -- (un IF contiene stmt, uno stmt può contenere expr con chiamate).
    local parse_stmt, parse_expr

    -- ── Parsing delle ESPRESSIONI ────────────────────────────
    -- La struttura a funzioni annidate implementa la precedenza degli
    -- operatori: ogni livello chiama quello con precedenza più alta.
    -- Ordine crescente di precedenza:
    --   OR < AND < relazionali < additivi < moltiplicativi < unario < primario

    -- Livello base: letterali, variabili, chiamate di funzione, parentesi
    local function parse_primary()
        local t = cur()
        if t.type == "NUMBER" then
            advance()
            -- Distingue INT da REAL in base alla presenza del punto decimale
            return node("Literal", { dtype = tostring(t.value):find("%.") and "REAL" or "INT", value = t.value })
        elseif t.type == "STRING" then
            advance(); return node("Literal", { dtype = "STRING", value = t.value })
        elseif t.type == "BOOL" then
            advance(); return node("Literal", { dtype = "BOOL", value = t.value })
        elseif t.type == "IDENT" then
            advance()
            -- Se l'identificatore è seguito da '(' è una chiamata di funzione
            if check("LPAREN") then
                advance()
                local args = {}
                if not check("RPAREN") then
                    table.insert(args, parse_expr())
                    while match("COMMA") do table.insert(args, parse_expr()) end
                end
                expect("RPAREN")
                return node("FuncCall", { name = t.value, args = args })
            end
            -- Altrimenti è un riferimento a variabile
            return node("Var", { name = t.value })
        elseif t.type == "LPAREN" then
            -- Sottoespressione parentesizzata
            advance(); local e = parse_expr(); expect("RPAREN")
            return node("Group", { expr = e })
        else
            error(("Riga %d: espressione attesa, trovato '%s'"):format(t.line, t.type))
        end
    end

    -- Operatori unari: negazione aritmetica (-) e logica (NOT).
    -- Sono right-associativi per ricorsione (es. NOT NOT x è valido).
    local function parse_unary()
        if check("MINUS") then
            advance(); return node("Unary", { op = "-", operand = parse_unary() })
        end
        if check("NOT") then
            advance(); return node("Unary", { op = "NOT", operand = parse_unary() })
        end
        return parse_primary()
    end

    -- Funzione generica per operatori binari left-associativi.
    -- `sub` è la funzione di livello superiore (più alta precedenza),
    -- `ops` è l'insieme dei tipi di token accettati a questo livello.
    -- Costruisce un albero sinistro-bilanciato: a+b+c → ((a+b)+c)
    local function parse_bin(sub, ops)
        local l = sub()
        while ops[cur().type] do
            local op = advance(); local r = sub()
            l = node("BinOp", { op = op.value, left = l, right = r })
        end
        return l
    end

    -- Livello moltiplicativo: * e /
    local function parse_mult() return parse_bin(parse_unary, { STAR = true, SLASH = true }) end

    -- Livello additivo: + e -
    local function parse_add() return parse_bin(parse_mult, { PLUS = true, MINUS = true }) end

    -- Livello relazionale: <, >, <=, >=, =, <>
    local function parse_rel()
        return parse_bin(parse_add,
            { LT = true, GT = true, LE = true, GE = true, EQ = true, NEQ = true })
    end

    -- Livello AND: più basso di relazionale ma più alto di OR
    local function parse_and()
        local l = parse_rel()
        while check("AND") do
            advance(); local r = parse_rel(); l = node("BinOp", { op = "AND", left = l, right = r })
        end
        return l
    end

    -- Livello OR: il più basso in assoluto (punto d'ingresso delle espressioni)
    parse_expr = function()
        local l = parse_and()
        while check("OR") do
            advance(); local r = parse_and(); l = node("BinOp", { op = "OR", left = l, right = r })
        end
        return l
    end

    -- ── Parsing delle ISTRUZIONI ─────────────────────────────

    -- IF expr THEN stmts [ELSIF expr THEN stmts]* [ELSE stmts] END_IF
    -- Il token IF è già stato consumato dal chiamante (parse_stmt).
    local function parse_if()
        local cond = parse_expr(); expect("THEN")
        -- Raccoglie le istruzioni del ramo THEN fino al primo ELSIF/ELSE/END_IF
        local then_body = {}
        while not (check("ELSIF") or check("ELSE") or check("END_IF")) do
            table.insert(then_body, parse_stmt())
        end
        -- Zero o più rami ELSIF, ognuno con la propria condizione e corpo
        local elsif_clauses = {}
        while check("ELSIF") do
            advance()
            local ec = parse_expr(); expect("THEN")
            local eb = {}
            while not (check("ELSIF") or check("ELSE") or check("END_IF")) do
                table.insert(eb, parse_stmt())
            end
            table.insert(elsif_clauses, { cond = ec, body = eb })
        end
        -- Ramo ELSE opzionale
        local else_body = nil
        if match("ELSE") then
            else_body = {}
            while not check("END_IF") do table.insert(else_body, parse_stmt()) end
        end
        expect("END_IF")
        return node("If", {
            cond = cond,
            then_body = then_body,
            elsif_clauses = elsif_clauses,
            else_body = else_body
        })
    end

    -- FOR ident := expr TO expr [BY expr] DO stmts END_FOR
    -- Il token FOR è già stato consumato dal chiamante.
    local function parse_for()
        local v = expect("IDENT"); expect("ASSIGN")
        local from = parse_expr(); expect("TO")
        local to = parse_expr()
        -- BY è opzionale: se assente, l'interprete userà 1 come default
        local by = nil
        if cur().type == "IDENT" and cur().value:upper() == "BY" then
            advance(); by = parse_expr()
        end
        expect("DO")
        local body = {}
        while not check("END_FOR") do table.insert(body, parse_stmt()) end
        expect("END_FOR")
        return node("For", { var = v.value, from = from, to = to, by = by, body = body })
    end

    -- WHILE expr DO stmts END_WHILE
    -- Il token WHILE è già stato consumato dal chiamante.
    local function parse_while()
        local cond = parse_expr(); expect("DO")
        local body = {}
        while not check("END_WHILE") do table.insert(body, parse_stmt()) end
        expect("END_WHILE")
        return node("While", { cond = cond, body = body })
    end

    -- Dispatch principale delle istruzioni.
    -- Identifica il tipo di istruzione dal token corrente e delega.
    parse_stmt = function()
        local t = cur()
        if t.type == "IF" then
            advance(); return parse_if()
        elseif t.type == "FOR" then
            advance(); return parse_for()
        elseif t.type == "WHILE" then
            advance(); return parse_while()
        elseif t.type == "IDENT" then
            advance()
            if check("ASSIGN") then
                -- Assegnazione: ident := expr ;
                expect("ASSIGN"); local val = parse_expr(); expect("SEMI")
                return node("Assign", { target = t.value, value = val })
            elseif check("LPAREN") then
                -- Chiamata di funzione come statement (valore di ritorno ignorato)
                advance()
                local args = {}
                if not check("RPAREN") then
                    table.insert(args, parse_expr())
                    while match("COMMA") do table.insert(args, parse_expr()) end
                end
                expect("RPAREN"); expect("SEMI")
                return node("FuncCallStmt", { name = t.value, args = args })
            else
                error(("Riga %d: ':=' o '(' attesi dopo '%s'"):format(t.line, t.value))
            end
        else
            error(("Riga %d: istruzione attesa, trovato '%s'"):format(t.line, t.type))
        end
    end

    -- Set dei tipi di token che rappresentano nomi di tipo ST.
    -- BOOL_T e STRING_T sono i token-tipo (usati in VAR), distinti
    -- dalle keyword BOOL e STRING usate nelle espressioni.
    local TYPES = { INT = true, REAL = true, BOOL_T = true, STRING_T = true }

    -- Consuma un nome di tipo e lo restituisce come stringa canonica.
    -- Gestisce sia i tipi built-in (INT, REAL, BOOL, STRING) sia
    -- tipi utente (identificatori generici, per strutture future).
    local function type_name()
        local t = cur()
        if TYPES[t.type] then
            advance()
            -- Normalizza i token-tipo al nome canonico senza suffisso _T
            return t.type == "BOOL_T" and "BOOL" or t.type == "STRING_T" and "STRING" or t.type
        elseif t.type == "IDENT" then
            advance(); return t.value
        else
            error(("Riga %d: tipo atteso"):format(t.line))
        end
    end

    -- Analizza il blocco VAR ... END_VAR.
    -- Supporta la dichiarazione multipla su una riga: a, b, c : INT := 0;
    -- In quel caso genera un nodo VarDecl per ogni nome con la stessa
    -- inizializzazione (il nodo init è condiviso, ma non è un problema
    -- perché è read-only durante l'esecuzione).
    local function parse_var_section()
        local decls = {}
        while not check("END_VAR") do
            -- Una o più variabili separate da virgola
            local names = { expect("IDENT").value }
            while match("COMMA") do table.insert(names, expect("IDENT").value) end
            expect("COLON"); local dtype = type_name()
            -- Valore iniziale opzionale
            local init = nil
            if match("ASSIGN") then init = parse_expr() end
            expect("SEMI")
            -- Crea un nodo per ogni nome della lista
            for _, nm in ipairs(names) do
                table.insert(decls, node("VarDecl", { name = nm, dtype = dtype, init = init }))
            end
        end
        expect("END_VAR"); return decls
    end

    -- Punto d'ingresso del parser: analizza l'intero programma ST.
    -- Restituisce un nodo "Program" che è la radice dell'AST.
    function p:parse()
        expect("PROGRAM")
        local name = expect("IDENT")
        local var_decls, stmts = {}, {}
        -- Il corpo del programma alterna blocchi VAR e istruzioni
        while not check("END_PROGRAM") and not check("EOF") do
            if check("VAR") then
                advance()
                -- Accoda tutte le dichiarazioni del blocco VAR
                for _, d in ipairs(parse_var_section()) do table.insert(var_decls, d) end
            else
                table.insert(stmts, parse_stmt())
            end
        end
        expect("END_PROGRAM")
        return node("Program", { name = name.value, var_decls = var_decls, stmts = stmts })
    end

    return p
end


-- ────────────────────────────────────────────────────────────
--  INTERPRETE  (tree-walking evaluator)
--
--  Strategia: visita ricorsiva dell'AST.
--    eval(nodo_expr)  → valore Lua (number, string, boolean)
--    exec(nodo_stmt)  → side-effect sull'ambiente (env)
--
--  L'ambiente `env` è una table { nome → { value, dtype } }.
--  Tutti i valori sono nativamente valori Lua; la coercizione di
--  tipo avviene solo al momento dell'assegnazione.
-- ────────────────────────────────────────────────────────────

-- Soglia massima di istruzioni eseguibili in un singolo programma.
-- Protegge contro loop infiniti senza dipendere da os.clock().
local MAX_STEPS = 1000000

--- Genera un nuovo interprete dato l'AST
--- @param ast any
--- @return Interpreter
local function new_interpreter(ast)
    -- Ambiente di esecuzione: mappa nome variabile → { value, dtype }.
    -- Viene popolato da interp:run() prima di eseguire il corpo.
    local env = {}

    -- Contatore globale di istruzioni eseguite (incrementato da exec()).
    local steps = 0

    -- ── Funzioni built-in ────────────────────────────────────
    -- Tutte le funzioni standard ST sono mappate su funzioni Lua.
    -- Convenzione: ricevono una table `args` (lista di valori già
    -- valutati) e restituiscono un singolo valore (o nil per I/O).
    -- I nomi sono in UPPERCASE per corrispondere alla ricerca di
    -- fname:upper() nell'interprete.

    -- Converte un valore Lua nel formato stringa ST corretto.
    -- Usato da PRINT e dai messaggi di trace per uniformità.
    local function val_to_str(v)
        if type(v) == "boolean" then return v and "TRUE" or "FALSE" end
        if type(v) == "number" then
            -- math.type distingue float da integer (Lua 5.3+)
            if math.type and math.type(v) == "float" then
                return string.format("%g", v)
            end
            return tostring(v)
        end
        return tostring(v)
    end

    local BUILTINS = {
        -- ── I/O ─────────────────────────────────────────────
        -- PRINT(v1, v2, ...): stampa tutti gli argomenti separati da tab.
        -- Non è una funzione ST standard ma è indispensabile per il debug.
        PRINT         = function(args)
            local parts = {}
            for _, a in ipairs(args) do table.insert(parts, val_to_str(a)) end
            print(table.concat(parts, "\t"))
            return nil
        end,

        -- ── Matematica (IEC 61131-3 §2.5.1) ─────────────────
        ABS           = function(a) return math.abs(a[1]) end,         -- valore assoluto
        SQRT          = function(a) return math.sqrt(a[1]) end,        -- radice quadrata
        SQR           = function(a) return a[1] * a[1] end,            -- quadrato (= EXPT(x,2))
        MAX           = function(a) return math.max(a[1], a[2]) end,   -- massimo tra due valori
        MIN           = function(a) return math.min(a[1], a[2]) end,   -- minimo tra due valori
        MOD           = function(a) return a[1] % a[2] end,            -- modulo (resto divisione)
        EXPT          = function(a) return a[1] ^ a[2] end,            -- potenza: a[1]^a[2]
        LN            = function(a) return math.log(a[1]) end,         -- logaritmo naturale
        LOG           = function(a) return math.log(a[1], 10) end,     -- logaritmo in base 10
        SIN           = function(a) return math.sin(a[1]) end,         -- seno (radianti)
        COS           = function(a) return math.cos(a[1]) end,         -- coseno (radianti)
        TAN           = function(a) return math.tan(a[1]) end,         -- tangente (radianti)
        ASIN          = function(a) return math.asin(a[1]) end,        -- arcoseno
        ACOS          = function(a) return math.acos(a[1]) end,        -- arcocoseno
        ATAN          = function(a) return math.atan(a[1]) end,        -- arcotangente
        CEIL          = function(a) return math.ceil(a[1]) end,        -- arrotonda verso +∞
        FLOOR         = function(a) return math.floor(a[1]) end,       -- arrotonda verso -∞
        TRUNC         = function(a) return math.modf(a[1]) end,        -- tronca verso zero
        ROUND         = function(a) return math.floor(a[1] + 0.5) end, -- arrotonda al più vicino

        -- ── Conversioni di tipo (IEC 61131-3 §2.5.1.5) ──────
        -- In ST le conversioni esplicite sono obbligatorie tra tipi diversi.
        INT_TO_REAL   = function(a) return a[1] + 0.0 end,       -- int → float Lua
        REAL_TO_INT   = function(a) return math.floor(a[1]) end, -- float → int (troncamento)
        INT_TO_BOOL   = function(a) return a[1] ~= 0 end,        -- 0 → FALSE, altro → TRUE
        BOOL_TO_INT   = function(a) return a[1] and 1 or 0 end,  -- TRUE → 1, FALSE → 0
        TO_STRING     = function(a) return val_to_str(a[1]) end, -- qualsiasi → stringa ST
        INT_TO_STRING = function(a) return tostring(math.floor(a[1])) end,

        -- ── Stringhe (IEC 61131-3 §2.4.3) ───────────────────
        CONCAT        = function(a) return table.concat(a, "") end,         -- concatena tutti gli argomenti
        LEN           = function(a) return #tostring(a[1]) end,             -- lunghezza stringa
        LEFT          = function(a) return tostring(a[1]):sub(1, a[2]) end, -- n caratteri da sinistra
        RIGHT         = function(a)
            local s = tostring(a[1]); return s:sub(#s - a[2] + 1)
        end,                                                                                      -- n caratteri da destra
        MID           = function(a) return tostring(a[1]):sub(a[2], a[2] + a[3] - 1) end,         -- sottostringa: pos, len
        UPPER         = function(a) return tostring(a[1]):upper() end,                            -- tutto maiuscolo
        LOWER         = function(a) return tostring(a[1]):lower() end,                            -- tutto minuscolo
        FIND          = function(a) return tostring(a[1]):find(tostring(a[2]), 1, true) or 0 end, -- posizione sottostringa (0 = non trovata)

        -- ── Selezione (IEC 61131-3 §2.5.1.4) ────────────────
        -- SEL(G, IN0, IN1): se G=FALSE restituisce IN0, se G=TRUE restituisce IN1
        SEL           = function(a) return a[1] and a[3] or a[2] end,
        -- MUX(K, IN0, IN1, ...): seleziona l'argomento all'indice K (base 0)
        MUX           = function(a)
            local idx = math.floor(a[1]) + 2 -- +1 per base-1 Lua, +1 per saltare K
            return a[idx] or runtime_error("MUX: indice fuori range")
        end,

        -- ── Tempo ────────────────────────────────────────────
        -- TIME(): restituisce il tempo CPU in secondi (simulazione, non wall clock).
        TIME          = function(_) return os.clock() end,
    }

    -- ── Gestione dei tipi in fase di esecuzione ──────────────

    -- Promuove entrambi gli operandi a REAL se almeno uno è float.
    -- Questo rispecchia la promozione implicita INT→REAL dello standard
    -- quando si mescolano i due tipi nelle operazioni aritmetiche.
    local function coerce(a, b)
        if type(a) == "number" and type(b) == "number" then
            if math.type and (math.type(a) == "float" or math.type(b) == "float") then
                return a + 0.0, b + 0.0 -- forza entrambi a float Lua
            end
        end
        return a, b
    end

    -- Converte qualsiasi valore Lua in BOOL ST.
    -- Regole: false/nil → falso; 0 → falso (come in C); "" → falso.
    local function truthy(v)
        if type(v) == "boolean" then return v end
        if type(v) == "number" then return v ~= 0 end
        if type(v) == "string" then return v ~= "" end
        return v ~= nil
    end

    -- ── Valutatore di espressioni ────────────────────────────
    -- Visita ricorsiva di un nodo espressione e restituisce il valore.
    -- Non ha side-effect sull'ambiente (le espressioni ST sono pure).
    local function eval(n)
        if n == nil then return nil end

        if n.kind == "Literal" then
            -- Valore costante: restituito direttamente
            return n.value
        elseif n.kind == "Var" then
            -- Lettura di variabile: cerca nell'ambiente, errore se assente
            local entry = env[n.name]
            if entry == nil then
                runtime_error("Variabile non inizializzata: '" .. n.name .. "'")
            end
            return entry.value
        elseif n.kind == "Group" then
            -- Sottoespressione tra parentesi: eval trasparente
            return eval(n.expr)
        elseif n.kind == "Unary" then
            local v = eval(n.operand)
            if n.op == "-" then return -v end              -- negazione aritmetica
            if n.op == "NOT" then return not truthy(v) end -- negazione logica
        elseif n.kind == "BinOp" then
            -- AND e OR usano cortocircuito (short-circuit evaluation):
            -- il secondo operando NON viene valutato se il risultato
            -- è già determinato dal primo. Conforme allo standard IEC.
            if n.op == "AND" then return truthy(eval(n.left)) and truthy(eval(n.right)) end
            if n.op == "OR" then return truthy(eval(n.left)) or truthy(eval(n.right)) end

            -- Per tutti gli altri operatori, valuta entrambi i lati
            local l, r = eval(n.left), eval(n.right)
            local op = n.op

            -- Caso speciale: + con almeno un operando stringa → concatenazione
            if op == "+" and (type(l) == "string" or type(r) == "string") then
                return tostring(l) .. tostring(r)
            end

            -- Promozione INT→REAL se necessario
            l, r = coerce(l, r)

            if op == "+" then
                return l + r
            elseif op == "-" then
                return l - r
            elseif op == "*" then
                return l * r
            elseif op == "/" then
                if r == 0 then runtime_error("Divisione per zero") end
                -- Divisione intera (floor) se entrambi gli operandi sono interi
                -- (math.type è disponibile da Lua 5.3; su versioni precedenti
                --  si fa sempre divisione floating-point).
                if type(l) == "number" and type(r) == "number" and
                    (not math.type or (math.type(l) == "integer" and math.type(r) == "integer")) then
                    return math.floor(l / r)
                end
                return l / r
            elseif op == "<" then
                return l < r
            elseif op == ">" then
                return l > r
            elseif op == "<=" then
                return l <= r
            elseif op == ">=" then
                return l >= r
            elseif op == "=" then
                return l == r -- = in ST è == in Lua
            elseif op == "<>" then
                return l ~= r -- <> in ST è ~= in Lua
            end
        elseif n.kind == "FuncCall" then
            -- Ricerca del built-in in modo case-insensitive (uppercase)
            local fname = n.name:upper()
            local builtin = BUILTINS[fname]
            if not builtin then
                runtime_error("Funzione sconosciuta: '" .. n.name .. "'")
            end
            -- Valuta ricorsivamente tutti gli argomenti prima della chiamata
            local args = {}
            for _, a in ipairs(n.args) do table.insert(args, eval(a)) end
            -- Log di trace: costruisce la stringa degli argomenti on-demand
            -- (chiusura immediata per evitare lavoro se TRACE è disattivo)
            return builtin(args)
        end

        runtime_error("Nodo espressione sconosciuto: " .. tostring(n.kind))
    end

    -- ── Esecutore di istruzioni ──────────────────────────────
    -- Visita un nodo statement e applica i suoi effetti sull'ambiente.
    -- Restituisce sempre nil; i "valori" transitano solo attraverso env.
    local function exec(n)
        -- Incrementa il contatore e controlla il limite di sicurezza
        steps = steps + 1
        if steps > MAX_STEPS then
            runtime_error(("Limite istruzioni raggiunto (%d). Loop infinito?"):format(MAX_STEPS))
        end

        if n.kind == "Assign" then
            local v = eval(n.value)
            local entry = env[n.target]
            if not entry then
                runtime_error("Assegnazione a variabile non dichiarata: '" .. n.target .. "'")
            end
            -- Coercizione al tipo dichiarato nella sezione VAR.
            -- Evita che un calcolo intermedio con REAL "contamini" una
            -- variabile INT (es: x := REAL_TO_INT(3.7) assegna 3, non 3.0).
            if entry.dtype == "INT" and type(v) == "number" then
                v = math.floor(v) -- tronca verso -∞ (floor, non truncate)
            elseif entry.dtype == "REAL" and type(v) == "number" then
                v = v + 0.0       -- forza a float Lua
            elseif entry.dtype == "BOOL" then
                v = truthy(v)     -- normalizza a boolean
            elseif entry.dtype == "STRING" then
                v = tostring(v)   -- qualsiasi valore → stringa
            end
            entry.value = v
        elseif n.kind == "FuncCallStmt" then
            -- Chiamata di funzione come istruzione standalone (es. PRINT(...);).
            -- Identica a FuncCall in eval, ma il valore di ritorno è scartato.
            local fname = n.name:upper()
            local builtin = BUILTINS[fname]
            if not builtin then
                runtime_error("Funzione sconosciuta: '" .. n.name .. "'")
            end
            local args = {}
            for _, a in ipairs(n.args) do table.insert(args, eval(a)) end
            builtin(args)
        elseif n.kind == "If" then
            -- Valuta la condizione principale e, se vera, esegue il corpo THEN.
            -- Nota: la condizione viene valutata due volte (una per il trace,
            -- una per la branch). Accettabile perché le espressioni ST sono pure.
            if truthy(eval(n.cond)) then
                for _, s in ipairs(n.then_body) do exec(s) end
            else
                -- Prova ogni clausola ELSIF nell'ordine in cui è stata scritta.
                -- Appena una è vera, esegue il suo corpo e interrompe la ricerca.
                local taken = false
                for _, ec in ipairs(n.elsif_clauses) do
                    if truthy(eval(ec.cond)) then
                        for _, s in ipairs(ec.body) do exec(s) end
                        taken = true; break
                    end
                end
                -- ELSE: eseguito solo se nessun ramo precedente era vero
                if not taken and n.else_body then
                    for _, s in ipairs(n.else_body) do exec(s) end
                end
            end
        elseif n.kind == "For" then
            local from_v = eval(n.from)
            local to_v   = eval(n.to)
            -- BY default = 1; convertito a intero (il contatore FOR è sempre INT)
            local by_v   = n.by and eval(n.by) or 1
            by_v         = math.floor(by_v)
            if by_v == 0 then runtime_error("FOR: incremento (BY) non può essere 0") end
            local entry = env[n.var]
            if not entry then runtime_error("Variabile di ciclo non dichiarata: '" .. n.var .. "'") end
            local i = math.floor(from_v)
            local limit = math.floor(to_v)
            -- La condizione di terminazione dipende dal segno di BY:
            -- BY > 0 → ciclo ascendente (i <= limit)
            -- BY < 0 → ciclo discendente (i >= limit)
            while (by_v > 0 and i <= limit) or (by_v < 0 and i >= limit) do
                entry.value = i -- aggiorna la variabile di controllo nell'env
                for _, s in ipairs(n.body) do exec(s) end
                i = i + by_v    -- incrementa/decrementa il contatore locale
            end
            -- Nota: dopo il FOR la variabile mantiene il valore post-loop
            -- (comportamento conforme IEC 61131-3).
        elseif n.kind == "While" then
            local iter = 0
            -- Rivaluta la condizione all'inizio di ogni iterazione.
            -- Il corpo del ciclo deve eventualmente rendere la condizione falsa,
            -- altrimenti MAX_STEPS interverrà come sicurezza.
            while truthy(eval(n.cond)) do
                iter = iter + 1
                for _, s in ipairs(n.body) do exec(s) end
            end
        else
            runtime_error("Nodo statement sconosciuto: " .. tostring(n.kind))
        end
    end

    -- ── Valore di default per tipo ───────────────────────────
    -- Restituisce il valore iniziale ST per le variabili non inizializzate.
    -- Conforme IEC 61131-3: INT=0, REAL=0.0, BOOL=FALSE, STRING=''.
    local function default_value(dtype)
        if dtype == "INT" then return 0 end
        if dtype == "REAL" then return 0.0 end
        if dtype == "BOOL" then return false end
        if dtype == "STRING" then return "" end
        return nil -- tipo utente o sconosciuto: nil fino a prima assegnazione
    end

    -- ── API pubblica dell'interprete ─────────────────────────
    -- Esposta come oggetto con due metodi separati che rispecchiano
    -- le due fasi di vita di un PLC reale.

    ---@class Interpreter
    local interp = {
        _ast = ast,
        cycle_count = 0,
        steps_cycle = 0,
        steps_total = 0
    }
    -- Riferimento interno all'AST, memorizzato da init() e riusato da cycle().
    -- Evita di passare l'AST ad ogni chiamata di cycle().
    --interp._ast        = ast
    -- Contatori accessibili dall'esterno dopo ogni cycle()
    --interp.cycle_count = 0 -- numero totale di cicli completati
    --interp.steps_cycle = 0 -- istruzioni eseguite nell'ultimo ciclo
    --interp.steps_total = 0 -- istruzioni totali dall'avvio

    -- ── interp:init(ast_in) ──────────────────────────────────

    -- Fase di POWER-ON / inizializzazione.
    -- Va chiamata UNA SOLA VOLTA prima del loop di scan.
    --
    -- Percorre tutte le dichiarazioni VAR dell'AST e popola `env`
    -- con il valore iniziale di ogni variabile:
    --   - se la dichiarazione ha un inizializzatore (:= expr), lo valuta
    --   - altrimenti usa il valore di default per il tipo (0, 0.0, FALSE, "")
    -- Dopo init() l'env è pronto e le variabili mantengono i loro valori
    -- tra un ciclo e l'altro (memoria persistente del PLC).
    function interp:init(ast_in)
        if ast_in ~= nil then
            self._ast = ast_in -- memorizza l'AST per i cicli futuri
        end

        for _, d in ipairs(ast_in.var_decls) do
            local init_val
            if d.init then
                -- Valuta l'espressione inizializzatrice (es. := 42 oppure := TRUE)
                init_val = eval(d.init)
                -- Coercizione al tipo dichiarato: garantisce che una costante
                -- come 3.0 finisca come INT=3 se il tipo è INT.
                if d.dtype == "INT" and type(init_val) == "number" then
                    init_val = math.floor(init_val)
                elseif d.dtype == "REAL" and type(init_val) == "number" then
                    init_val = init_val + 0.0
                elseif d.dtype == "BOOL" then
                    init_val = truthy(init_val)
                elseif d.dtype == "STRING" then
                    init_val = tostring(init_val)
                end
            else
                -- Nessun inizializzatore: usa il valore di default del tipo
                init_val = default_value(d.dtype)
            end
            env[d.name] = { value = init_val, dtype = d.dtype }
        end
        return env;
    end

    -- ── interp:cycle() ───────────────────────────────────────

    ---Esegue UN ciclo di scansione: percorre tutti gli statement
    ---del corpo del PROGRAM dall'inizio alla fine, esattamente come
    ---farebbe il task ciclico di un PLC reale.
    --
    ---Le variabili in `env` NON vengono reinizializzate: i valori
    ---scritti in un ciclo sono visibili nel ciclo successivo.
    ---Questo è il comportamento fondamentale che permette di
    ---implementare logica stateful (contatori, macchine a stati, ecc.)
    --
    ---@return boolean ok
    ---@return string|nil err
    ---@return Environment env
    ---@return {cycle:number,steps_this:number,steps_total:number} stats
    function interp:cycle()
        -- Reset del contatore di istruzioni per questo ciclo.
        -- `steps` (upvalue della closure) viene usato da exec() per
        -- la protezione MAX_STEPS; lo resettiamo per misurare la durata
        -- di ogni singolo ciclo indipendentemente dagli altri.
        steps = 0

        self.cycle_count = self.cycle_count + 1

        -- Esecuzione protetta: pcall cattura errori runtime senza
        -- terminare il processo, permettendo al chiamante di decidere
        -- se fermarsi o continuare (es. loggare l'errore e proseguire).
        local ok, err = pcall(function()
            for _, s in ipairs(self._ast.stmts) do exec(s) end
        end)

        -- Aggiorna le statistiche dopo l'esecuzione del ciclo
        self.steps_cycle = steps
        self.steps_total = self.steps_total + steps

        local stats = {
            cycle       = self.cycle_count,
            steps_this  = self.steps_cycle,
            steps_total = self.steps_total,
        }
        return ok, err, env, stats
    end

    -- ── interp:setEnv(newEnv) ───────────────────────────────────────

    --- Imposta le variabili d'ambiente: se l'ambiente corrente è nullo
    --- allora copia direttamente il nuovo ambiente, altrimenti copia solo
    --- i valori che corrispondono a variabili presenti nell'ambiente.
    ---@param newEnv Environment|nil il nuovo ambiente da impostare (se nil usa quello interno)
    function interp:setEnv(newEnv)
        if newEnv ~= nil then
            if env == nil or env == {} then
                env = newEnv;
            else
                for k, val in ipairs(env) do
                    if newEnv[k] ~= nil then
                        env[k] = newEnv[k];
                    end
                end
            end
        end
    end

    return interp
end

---Genera l'interprete dato il testo del file ST. Il file deve contenere sia le dichiarazioni di variabili sia il codice.
---@param code_source string Testo contentenuto nel file .ST associato ad una unit
---@return Interpreter|nil #Restituisce l'interprete se viene completato correttamente, altrimenti nil
Industria.ST.interpCode = function(code_source)
    -- ── Fase 1: Tokenizzazione ───────────────────────────────
    local lexer = new_lexer(code_source)
    local ok, res = pcall(function() return lexer:tokenize() end)
    if not ok then
        error("[LESSICAL] " .. tostring(res) .. "\n");
        return nil;
    end
    local tokens = res

    -- ── Fase 2: Parsing → AST ────────────────────────────────
    local parser = new_parser(tokens)
    local ok2, res2 = pcall(function() return parser:parse() end)
    if not ok2 then
        error("[SYNTACTIC] " .. tostring(res2) .. "\n");
        return nil;
    end
    local ast = res2

    -- ── Fase 3: POWER-ON – inizializzazione variabili ────────
    -- Corrisponde alla fase di "cold start" del PLC:
    -- le variabili vengono allocate e impostate ai valori iniziali
    -- dichiarati nel blocco VAR. Questa fase non esegue il programma.

    local interp = new_interpreter(ast);

    --[[
        local env_res = interp:init(ast) -- alloca env; NON esegue il corpo del PROGRAM
        local ok3, err3, cur_env, stats = interp:cycle()
    ]]
    return interp;
end

---Loads code from an ST file
---@param filename string The path to the file
---@return Result<string|nil>
Industria.ST.loadCode = function(filename)
    local f, err = io.open(filename, "r")
    if not f then
        return fnresult(false, "File not opened: " .. tostring(err) .. "\n", nil);
    end
    local source = f:read("*a"); f:close();
    return fnresult(true, nil, source);
end
