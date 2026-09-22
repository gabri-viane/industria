# Industria — Documentazione API (Lua)

Mod per **Luanti** che aggiunge Control Unit programmabili, un linguaggio Structured
Text (ST, IEC 61131-3-like) e moduli di I/O digitali (pulsanti, lampade) collegabili
alle Control Unit per costruire automazioni.

> Questa documentazione descrive **solo** ciò che è effettivamente presente ed
> esposto nel codice sorgente del mod (namespace globale `Industria`). Non sono
> incluse funzioni interne/locali del parser/lexer ST, che non fanno parte
> dell'API pubblica.

- Namespace globale: `Industria`
- Nodi principali: `industria:baseunit`, `industria:digibutton_default[_pressed]`,
  `industria:baselamp_default_off/_on`
- Tool: `industria:iolinker`
- Percorso dati mondo: `<world>/industriadt/`

---

## Indice

1. [Industria — Documentazione API (Lua)](#industria--documentazione-api-lua)
   1. [Indice](#indice)
   2. [1. Struttura del progetto](#1-struttura-del-progetto)
   3. [2. Ordine di caricamento (`init.lua`)](#2-ordine-di-caricamento-initlua)
   4. [3. Tipi e alias (`docs.lua`)](#3-tipi-e-alias-docslua)
   5. [4. `Industria.commons` — utilità generiche](#4-industriacommons--utilità-generiche)
   6. [5. `Industria.units` — helper sulle Control Unit](#5-industriaunits--helper-sulle-control-unit)
   7. [6. `Industria.controllers` — gestione delle Control Unit](#6-industriacontrollers--gestione-delle-control-unit)
   8. [7. `Industria.iounits` — gestione dei moduli di I/O](#7-industriaiounits--gestione-dei-moduli-di-io)
   9. [8. `Industria.runtime` — runtime di esecuzione delle unità](#8-industriaruntime--runtime-di-esecuzione-delle-unità)
      1. [Ciclo di esecuzione globale](#ciclo-di-esecuzione-globale)
   10. [9. `Industria.runtime.iounits` — runtime di collegamento I/O](#9-industriaruntimeiounits--runtime-di-collegamento-io)
   11. [10. `Industria.ST` — compilazione ed esecuzione dei programmi](#10-industriast--compilazione-ed-esecuzione-dei-programmi)
   12. [11. Oggetto `Interpreter`](#11-oggetto-interpreter)
   13. [12. `Industria.files` — persistenza dei file `.st`/`.st.env`](#12-industriafiles--persistenza-dei-file-ststenv)
   14. [13. API di registrazione nodi I/O (`Industria.IOStatesBuilder`)](#13-api-di-registrazione-nodi-io-industriaiostatesbuilder)
   15. [14. Registrazione di nodi predefiniti](#14-registrazione-di-nodi-predefiniti)
       1. [Lampada — `Industria.register_base_lamp(def)`](#lampada--industriaregister_base_lampdef)
       2. [Pulsante digitale — `Industria.register_digital_button(def)`](#pulsante-digitale--industriaregister_digital_buttondef)
       3. [Control Unit — `industria:baseunit`](#control-unit--industriabaseunit)
   16. [15. `Industria.formspecs` — gestione delle GUI](#15-industriaformspecs--gestione-delle-gui)
       1. [Formspec specifici](#formspec-specifici)
   17. [16. Tool `industria:iolinker`](#16-tool-industriaiolinker)
   18. [17. Linguaggio Structured Text supportato](#17-linguaggio-structured-text-supportato)
       1. [Tipi di dato](#tipi-di-dato)
       2. [Strutture di controllo](#strutture-di-controllo)
       3. [Operatori](#operatori)
       4. [Altro](#altro)
   19. [18. Funzioni built-in ST](#18-funzioni-built-in-st)
       1. [Output](#output)
       2. [Matematiche](#matematiche)
       3. [Conversione di tipo](#conversione-di-tipo)
       4. [Stringhe](#stringhe)
       5. [Selezione e tempo](#selezione-e-tempo)
   20. [19. Persistenza su disco](#19-persistenza-su-disco)
   21. [20. Comandi chat](#20-comandi-chat)

---

## 1. Struttura del progetto

```
industria/
├── core/         Controllori, interprete ST, file, runtime, IO runtime
│   ├── STCore.lua       Lexer, parser, interprete del linguaggio ST
│   ├── STFiles.lua      Salvataggio/caricamento codice e ambiente (.st/.st.env)
│   ├── controllers.lua  Gestione delle Control Unit (creazione, rimozione, persistenza)
│   ├── iounits.lua      Gestione dei moduli di IO (creazione, rimozione, persistenza)
│   ├── runtime.lua      Runtime di esecuzione delle unità (enable/disable, cicli)
│   ├── ioruntime.lua    Collegamento (link/unlink) variabili ST <-> stati IO
│   ├── Prova.st         File di esempio in linguaggio ST (non fa parte dell'API)
│   └── init.lua         Inizializza le tabelle e carica i file del modulo core
├── gui/          Formspec: editor codice, impostazione ID, linking IO
├── nodes/        Control Unit, pulsanti, lampade, API di registrazione IOUnit
├── tools/        IO Linker
├── items/        Punto di ingresso per la registrazione di item (attualmente vuoto)
├── models/       Modelli .glb
├── textures/     Texture del mod
├── commons.lua   Funzioni di utilità condivise
├── docs.lua      Definizioni di tipo (annotazioni LuaLS/EmmyLua, `@meta`)
├── init.lua      Entry point del mod
├── mod.conf      Metadati del mod
└── LICENSE       Licenza MIT
```

> `items/init.lua` è presente ma **vuoto**: al momento non vengono registrati
> item aggiuntivi tramite questo file.

## 2. Ordine di caricamento (`init.lua`)

```lua
Industria = {};
Industria.path = core.get_modpath("industria");

dofile(Industria.path .. "/commons.lua");
dofile(Industria.path .. "/core/init.lua");
dofile(Industria.path .. "/gui/formspecs.lua");
dofile(Industria.path .. "/nodes/init.lua");
dofile(Industria.path .. "/tools/init.lua");
```

Al termine del caricamento:

- viene creata (se non esiste) la cartella dati del mondo `industriadt/`;
- viene registrato il comando chat `/tmp`;
- viene registrato un salvataggio periodico ogni **120 secondi** e uno **allo shutdown** del server;
- vengono deserializzati `controllers.dt` e `iounits.dt`, con messaggio di stato inviato a tutti i giocatori.

## 3. Tipi e alias (`docs.lua`)

File di sole annotazioni (`---@meta`), utile come riferimento dei tipi usati in
tutta l'API. Non contiene codice eseguibile.

| Alias | Definizione | Significato |
|---|---|---|
| `Result<T>` | `{completed:boolean, msg:string, data:T}` | Valore di ritorno standard di quasi tutte le funzioni dell'API |
| `unit_id` | `string` | Identificativo scelto per una Control Unit |
| `owner` | `string` | Nome del giocatore proprietario |
| `unit_code` | `string` | `unit_id .. "_" .. owner` |
| `io_unit_code` | `string` | Codice univoco di un modulo IO (derivato dalla posizione nel mondo) |
| `iounitname` | `string` | Nome del "tipo" di IOUnit (es. pulsante, lampada) |
| `reference_program` | `string` | Nome del file `.st` associato a una Unit |
| `varname` | `string` | Nome di una variabile dichiarata nell'ambiente ST |
| `IOname` | `string` | Nome di uno stato di IO esposto da un modulo |
| `IOType` | `0 \| 1 \| 2` | `0`=Input, `1`=Output, `2`=Input/Output |
| `DType` | `"INT" \| "REAL" \| "BOOL" \| "STRING"` | Tipi di dato supportati dai programmi ST |
| `VarEnv` | `{value: any, dtype: any}` | Valore + tipo di una variabile d'ambiente |
| `Environment` | `table<varname, VarEnv>` | Tabella variabili → valori dell'interprete |
| `IOLinks` | `table<varname, io_unit_code \| nil>` | Variabile ↔ modulo IO collegato |
| `IOPort` | `{linked_var: varname \| nil, type: IOType}` | Porta esposta da un modulo IO |
| `IOState` | `{value: any, iotype: IOType, dtype: DType}` | Definizione di stato di un modulo IO |
| `IOUnitStats` | `table<IOname, IOState>` | Tutti gli stati definiti per un tipo di IOUnit |
| `Unit` | `{unit_id, owner, reference_program, last_env, enabled, protected, io_units}` | Rappresentazione di una Control Unit |
| `IOUnit` | `{iounitname, iounit_code, owner, reference_unit, pos_block, io_ports, linked_states}` | Rappresentazione di un modulo IO registrato |
| `RTInfo` | `{enabled:boolean, interp: Interpreter\|nil, errors:string[]}` | Stato a runtime di una Unit |

Tutte le funzioni dell'API che restituiscono un `Result` seguono questa convenzione:
`completed` indica successo/fallimento, `msg` un messaggio (errore o informativo),
`data` il valore utile in caso di successo.

## 4. `Industria.commons` — utilità generiche

Definito in `commons.lua`.

```lua
Industria.commons.fnresult(completed, message, data)
```
Costruisce e restituisce un oggetto `Result`: `{ completed, msg, data }`. È la
funzione usata da (quasi) tutte le altre funzioni dell'API per restituire
l'esito delle operazioni.

```lua
Industria.commons.isBlank(str)
```
Restituisce `true` se `str` è `nil` o contiene solo spazi bianchi. Genera un
errore Lua (`error(...)`) se `str` non è `nil` né una stringa.

```lua
Industria.commons.strtrim(str)
```
Rimuove gli spazi bianchi finali da una stringa. Genera un errore se
l'argomento non è una stringa.

```lua
Industria.commons.rndstr(size)
```
Genera una stringa casuale di `size` caratteri stampabili ASCII (codici 32–126).

## 5. `Industria.units` — helper sulle Control Unit

Tabella inizializzata in `nodes/init.lua` (`Industria.units = {}`) e popolata in
`nodes/commons.lua`.

```lua
Industria.units.toUnitCode(unit_id, player_name)
```
Restituisce `unit_id .. "_" .. player_name`, oppure `nil` se uno dei due
argomenti è `nil`.

```lua
Industria.units.getUnitCode(unit)
```
Equivalente a `toUnitCode(unit.unit_id, unit.owner)`; restituisce `nil` se
`unit` è `nil`.

```lua
Industria.units.isValidUnit(pos, node)
```
Verifica se il nodo in posizione `pos` può essere/è una Control Unit:

- se `node` non è passato, viene letto con `core.get_node_or_nil(pos)`;
- controlla che il nodo appartenga al gruppo `industria_controller`;
- se il nodo non ha ancora i metadati `unit_id`/`unit_owner`, restituisce
  `completed = true, data = nil` ("valido per essere registrato");
- se li ha, cerca l'unità già registrata in `Industria.controllers` e la
  restituisce in `data` se trovata.

Ritorna sempre un `Result<Unit|nil>`.

## 6. `Industria.controllers` — gestione delle Control Unit

Inizializzato in `core/init.lua`:

```lua
Industria.controllers = {
    ids = {},   -- table<owner, unit_code[]>
    units = {}  -- table<unit_code, Unit>
};
```

Funzioni definite in `core/controllers.lua`:

```lua
Industria.controllers:serialize()
```
Serializza `{ ids, units }` con `core.serialize` e lo scrive in
`<world>/industriadt/controllers.dt`. Ritorna `Result<nil>`.

```lua
Industria.controllers:deserialize()
```
Legge e deserializza `controllers.dt`, popola `self.ids`/`self.units`, e per
ogni unità caricata la registra a runtime (in una coroutine) chiamando
`Industria.runtime:registerToRuntime(unit, false)`. Ritorna `Result<table|nil>`
con `data = self` in caso di successo.

```lua
Industria.controllers:addUnit(unit_id, owner)
```
Crea una nuova `Unit` per il giocatore `owner`, se non esiste già un'unità con
lo stesso `unit_code`. La nuova unità ha:

```lua
{
    unit_id = unit_id,
    owner = owner,
    reference_program = unit_code .. ".st",
    last_env = {},
    enabled = false,
    protected = false,
    io_units = {}
}
```

Registra inoltre l'unità nel runtime di IO tramite
`Industria.runtime.iounits:registerUnitToIORuntime(unit_code)`. Ritorna
`Result<Unit|nil>`.

```lua
Industria.controllers:getUnit(unit_code)
```
Restituisce la `Unit` associata a `unit_code`, se esiste. `Result<Unit|nil>`.

```lua
Industria.controllers:removeController(unit_id, owner)
```
Rimuove completamente un'unità:

1. verifica che esista e che appartenga al proprietario indicato;
2. la scollega dal runtime di IO (`Industria.runtime.iounits:unregisterUnitToIORuntime`);
3. elimina i file `.st` e `.st.env` associati (`Industria.files.deleteUnitCode/deleteUnitEnvironment`);
4. la rimuove dalla tabella `units` e dal runtime (`Industria.runtime:removeUnit`).

Ritorna `Result<nil>`.

```lua
Industria.controllers:removeIOUnitFromController(unit_code, io_unit_code, deleteUnit)
```
Rimuove il riferimento a un modulo IO (`io_unit_code`) dalla lista `io_units`
di una Unit. Se `deleteUnit` è `true`, chiama anche
`Industria.iounits:removeIOUnit(io_unit_code, unit.owner)` per eliminare
completamente il modulo IO (da usare con attenzione per evitare chiamate
circolari). Ritorna `Result<nil|Unit>`.

## 7. `Industria.iounits` — gestione dei moduli di I/O

Inizializzato in `core/init.lua`:

```lua
Industria.iounits = {
    ids = {},         -- table<owner, io_unit_code[]>
    registered = {}    -- table<io_unit_code, IOUnit>
};
```

Il codice di un modulo IO (`io_unit_code`) è calcolato in `nodes/commons.lua` a
partire dalla posizione nel mondo:

```lua
Industria.iounits.getIOUnitCode(pos)
-- restituisce "x"..pos.x.."y"..pos.y.."z"..pos.z, o nil se pos è nil
```

Funzioni definite in `core/iounits.lua`:

```lua
Industria.iounits:serialize()
```
Serializza `{ ids, registered, ioruntime = { inputs, outputs } }` (dove
`ioruntime` proviene da `Industria.runtime.iounits`) e lo scrive in
`<world>/industriadt/iounits.dt`. Ritorna `Result<nil>`.

```lua
Industria.iounits:deserialize()
```
Legge e deserializza `iounits.dt`; ripristina anche `Industria.runtime.iounits.inputs`
e `.outputs` se presenti nel file. Ritorna `Result<table|nil>`.

```lua
Industria.iounits:registerIOUnit(owner, pos)
```
Registra come `IOUnit` il nodo presente in `pos`, se:

- il nodo esiste ed è effettivamente registrato in Luanti (`core.registered_nodes`);
- possiede `industria_props` e appartiene al gruppo `industria_iounit`;
- `industria_props.iounit_name` è definito.

Crea un `IOUnit`:

```lua
{
    iounitname = data.iounit_name,
    iounit_code = iounit_code,
    owner = owner,
    reference_unit = nil,
    io_ports = { [state_name] = { linked_var = nil, type = <iotype> }, ... },
    pos_block = pos,
    linked_states = {}
}
```

I `io_ports` vengono generati automaticamente da tutti gli stati registrati
per quel `iounit_name` tramite `Industria.IOStatesBuilder` (vedi §13). Ritorna
`Result<IOUnit|nil>`.

```lua
Industria.iounits:unregisterIOUnit(iounit_code, owner)
```
Rimuove completamente un modulo IO: se era collegato a una Unit
(`reference_unit`), lo scollega prima con
`Industria.runtime.iounits:unlink(iounit)`. Ritorna `Result<nil>`.

```lua
Industria.iounits:getIOUnit(iounit_code)
```
Restituisce l'`IOUnit` corrispondente a `iounit_code`, se registrato.
`Result<IOUnit|nil>`.

```lua
Industria.iounits.getAvailableStates(node_name)
```
Restituisce l'elenco (array di stringhe) dei nomi degli stati disponibili per
il tipo di IOUnit associato al nodo `node_name` (dev'essere un nodo registrato
con `industria_props` e gruppo `industria_iounit`). `Result<string[]|nil>`.

```lua
Industria.iounits.getIOUnitNodeName(iounit)
```
Restituisce il nome del nodo Luanti corrente nella posizione `iounit.pos_block`,
oppure `nil` se non determinabile.

```lua
Industria.iounits.getLinkedState(iounit, envVarName)
```
Cerca, tra le `io_ports` dell'`IOUnit`, quale stato (`IOname`) risulta collegato
alla variabile `envVarName` dell'ambiente ST. Restituisce il nome dello stato
o `nil`.

```lua
Industria.iounits.getStateData(node_name, state_name)
```
Restituisce la definizione (`IOState`: `value`, `iotype`, `dtype`) dello stato
`state_name` per il tipo di IOUnit del nodo `node_name`. `Result<IOState|nil>`.

```lua
Industria.iounits.getIOUnitStates(iounit)
```
Restituisce l'intera tabella `IOUnitStats` (tutti gli stati definiti) per il
tipo di IOUnit a cui appartiene `iounit`, oppure `nil` se non determinabile.

## 8. `Industria.runtime` — runtime di esecuzione delle unità

Inizializzato in `core/init.lua`:

```lua
Industria.runtime = {
    current_unit = nil,
    units = {},   -- table<unit_code, RTInfo>
    iounits = {}  -- (esteso poi in core/ioruntime.lua, vedi §9)
};
```

Funzioni definite in `core/runtime.lua`:

```lua
Industria.runtime.print(text, unit)
```
Funzione richiamata dal built-in ST `PRINT(...)`. Invia `text` in chat al
proprietario dell'unità (`unit.owner`), con prefisso `[unit_id]:`. Se `unit`
è `nil`, non invia nulla.

```lua
Industria.runtime:registerError(unit_code, message)
```
Aggiunge `message` alla lista errori (`errors`) dell'unità nel runtime, se
l'unità è già registrata a runtime. Ritorna `Result<nil>`.

```lua
Industria.runtime:getErrors(unit_code)
```
Restituisce la lista di errori registrati per l'unità. `Result<string[]>`.

```lua
Industria.runtime:removeUnit(unit)
```
Rimuove l'unità dalla tabella `Industria.runtime.units`. `Result<nil>`.

```lua
Industria.runtime:enableUnit(unit)
```
Abilita l'esecuzione dell'unità:

- richiede che l'unità sia già registrata a runtime;
- se non esiste ancora un interprete valido, ne crea uno nuovo con
  `self:createInterpreter(unit, false)` (senza caricare l'ambiente salvato);
- imposta `enabled = true` sia nel runtime che sull'oggetto `Unit`.

`Result<nil>`.

```lua
Industria.runtime:disableUnit(unit)
```
Disabilita l'unità (`enabled = false`) sia sull'oggetto `Unit` sia nel
runtime, e se l'interprete espone `init`, lo richiama per **resettare
l'ambiente**. `Result<nil>`.

```lua
Industria.runtime:setUnitInterpreter(unit, interpreter)
```
Associa un `Interpreter` (vedi §11) a una `Unit`, registrandola a runtime se
non lo è già. `Result<nil>`.

```lua
Industria.runtime:createInterpreter(unit, load_init)
```
Carica il codice ST della Unit dal file `reference_program`, lo compila con
`Industria.ST.interpCode`, crea/assegna l'interprete, lo inizializza
(`interp:init()`), e se `load_init = true` prova a caricare l'ambiente salvato
da `<reference_program>.env`. Verifica infine, tramite
`Industria.runtime.iounits:checkEnvs`, se variabili precedentemente collegate
a moduli IO sono state rimosse dal nuovo codice, scollegandole di conseguenza.
`Result<Interpreter|nil>`.

```lua
Industria.runtime:registerToRuntime(unit, justCreated)
```
Registra l'unità nella tabella `Industria.runtime.units` (se non presente) con
stato iniziale `{ enabled, errors = {}, interp = nil }`, quindi chiama
`self:createInterpreter(unit, justCreated == nil or not justCreated)`.
`Result<nil>`.

```lua
Industria.runtime:saveCurrentEnv()
```
Per ogni unità presente nel runtime, se abilitata e con interprete valido,
aggiorna `unit.last_env` con l'ambiente corrente dell'interprete, quindi salva
su disco con `Industria.files.saveUnitEnvironment(unit)`. Chiamata dal ciclo
di salvataggio periodico e allo shutdown.

### Ciclo di esecuzione globale

`core/runtime.lua` registra un `core.register_globalstep`: ad ogni step del
motore, per ogni unità abilitata con interprete valido:

1. copia i valori di **input** dai moduli IO collegati verso l'ambiente ST
   (`Industria.runtime.iounits:executeCopy(interp, unit, 0)`);
2. esegue un ciclo del programma (`interp:cycle()`), in una coroutine;
3. se il ciclo fallisce, disabilita l'unità;
4. altrimenti copia i valori di **output** dall'ambiente ST verso i moduli IO
   collegati (`executeCopy(interp, unit, 1)`).

## 9. `Industria.runtime.iounits` — runtime di collegamento I/O

Inizializzato in `core/ioruntime.lua`:

```lua
Industria.runtime.iounits = {
    inputs = {},   -- table<unit_code, io_unit_code[]>
    outputs = {},  -- table<unit_code, io_unit_code[]>
    states = {}    -- table<iounitname, IOUnitStats>
};
```

`states` viene popolato tramite `Industria.IOStatesBuilder(...):register()`
(vedi §13) per ogni tipo di IOUnit registrato nel mod.

```lua
Industria.runtime.iounits:registerUnitToIORuntime(unit_code)
```
Inizializza le liste `inputs[unit_code]` e `outputs[unit_code]` a `{}` se non
già presenti. Chiamata automaticamente da `Industria.controllers:addUnit`.

```lua
Industria.runtime.iounits:unregisterUnitToIORuntime(unit_code)
```
Scollega (`unlink`) tutti i moduli IO attualmente registrati come input o
output della Unit, quindi rimuove le voci `inputs[unit_code]` e
`outputs[unit_code]`.

```lua
Industria.runtime.iounits:tryRegisterIOUnitToRuntime(unit_code, iounit, type)
```
Aggiunge (se non già presente) `iounit.iounit_code` alla lista `inputs`
e/o `outputs` della Unit, in base a `type` (`0`=input, `1`=output, `2`=entrambi).
Richiede che la Unit sia già registrata nel runtime di IO. `Result<nil>`.

```lua
Industria.runtime.iounits:tryUnregisterIOUnitToRuntime(unit, iounit)
```
Conta quanti stati collegati dell'`iounit` sono ancora di tipo input/output; se
non ce ne sono più, rimuove `iounit.iounit_code` dalle liste `inputs`/`outputs`
della Unit. Se non rimane **nessun** collegamento, azzera
`iounit.reference_unit`.

```lua
Industria.runtime.iounits:link(unit, iounit, iounitStateName, envVarName, type)
```
Collega uno stato (`iounitStateName`) di un modulo IO a una variabile
(`envVarName`) dell'ambiente di una Unit. Verifica, in ordine:

1. `envVarName` non vuoto;
2. la Unit ha un `unit_code` valido;
3. l'`IOUnit` non è già collegato a un'unità diversa;
4. la Unit ha un interprete associato con ambiente valido;
5. la variabile `envVarName` esiste effettivamente nell'ambiente;
6. lo stato `iounitStateName` esiste tra le porte del modulo IO.

Se tutte le condizioni sono soddisfatte, registra il collegamento nel runtime
IO, aggiorna `iounit.io_ports[...]`, `iounit.linked_states[...]`,
`unit.io_units[...]` e `iounit.reference_unit`. `Result<IOUnit|nil>`.

```lua
Industria.runtime.iounits:unlink(iounit, iounitStateName)
```
Scollega uno stato specifico (se `iounitStateName` è fornito) oppure **tutti**
gli stati collegati del modulo IO (se omesso), ripulendo
`unit.io_units`/`iounit.linked_states`/`iounit.io_ports[...].linked_var`.
Richiama poi `tryUnregisterIOUnitToRuntime`. `Result<nil>`.

```lua
Industria.runtime.iounits:checkEnvs(unit, newEnv, prevEnv)
```
Confronta il nuovo ambiente generato dopo una ricompilazione del codice ST con
quello precedente: per ogni variabile presente in `prevEnv` ma non più in
`newEnv`, se era collegata a un modulo IO, lo scollega automaticamente.

```lua
Industria.runtime.iounits:executeCopy(interp, unit, direction)
```
Copia i valori tra ambiente ST e stati dei moduli IO collegati alla Unit:

- `direction = 0` (input): per ogni variabile collegata a uno stato di tipo
  input (`iotype == 0`) con lo stesso `dtype`, aggiorna il valore
  dell'ambiente leggendo lo stato (chiamando la funzione, se `value` è una
  funzione, oppure copiando il valore costante);
- `direction = 1` (output): per ogni variabile collegata a uno stato di tipo
  output (`iotype == 1`), invoca la funzione di output passando il valore
  corrente della variabile.

Richiamata automaticamente dal ciclo globale (§8), prima e dopo `interp:cycle()`.

## 10. `Industria.ST` — compilazione ed esecuzione dei programmi

Inizializzato in `core/init.lua` (`Industria.ST = {}`), popolato in
`core/STCore.lua`.

```lua
Industria.ST.interpCode(code_source, unit_code, unit)
```
Compila il testo sorgente ST (`code_source`) in tre fasi (lexer → parser →
interprete):

1. **Lessicale**: tokenizzazione. In caso di errore, registra un errore
   `(LESSICAL) ...` tramite `Industria.runtime:registerError(unit_code, ...)`
   e restituisce `Result(false, msg, nil)`.
2. **Sintattica**: parsing in AST. In caso di errore, registra
   `(SYNTACTIC) ...` e restituisce `Result(false, msg, nil)`.
3. **Creazione dell'interprete**: costruisce l'oggetto `Interpreter` (§11)
   associato all'AST e alla `unit`.

Ritorna `Result<Interpreter|nil>`. **Non** esegue automaticamente `init()` né
`cycle()`: questo è responsabilità del chiamante (vedi
`Industria.runtime:createInterpreter`).

```lua
Industria.ST.loadCode(filename)
```
Legge e restituisce il contenuto testuale del file `filename`.
`Result<string|nil>`.

## 11. Oggetto `Interpreter`

Restituito da `Industria.ST.interpCode(...).data`. Espone questi metodi:

```lua
interp:init(ast_in)
```
Fase di "power-on": percorre tutte le dichiarazioni `VAR` dell'AST e popola
l'ambiente (`env`) con i valori iniziali (valutando l'espressione `:= ...` se
presente, altrimenti usando il valore di default del tipo: `0` per `INT`,
`0.0` per `REAL`, `false` per `BOOL`, `""` per `STRING`). Va chiamata **una
sola volta** prima del ciclo di scan. Restituisce l'`Environment` risultante.

```lua
interp:cycle()
```
Esegue **un ciclo di scansione**: percorre tutti gli statement del corpo del
`PROGRAM`, dall'inizio alla fine, senza reinizializzare le variabili
(comportamento stateful tipico di un PLC). L'esecuzione avviene tramite
`pcall`, quindi gli errori runtime non interrompono il processo Lua.

Restituisce **quattro valori**:
```lua
local ok, err, env, stats = interp:cycle()
-- ok    : boolean — esito del ciclo
-- err   : string|nil — messaggio d'errore se ok == false
-- env   : Environment — ambiente corrente dopo il ciclo
-- stats : { cycle:number, steps_this:number, steps_total:number }
```

```lua
interp:setEnv(newEnv)
```
Imposta le variabili d'ambiente: se l'ambiente interno è vuoto/nullo, lo
sostituisce interamente con `newEnv`; altrimenti copia solo i valori delle
chiavi già presenti nell'ambiente corrente (non introduce nuove variabili).

```lua
interp:getEnv()
```
Restituisce l'`Environment` corrente dell'interprete.

```lua
interp:getUnit()
```
Restituisce la `Unit` associata a questo interprete.

## 12. `Industria.files` — persistenza dei file `.st`/`.st.env`

Inizializzato in `core/init.lua` (`Industria.files = {}`), popolato in
`core/STFiles.lua`.

```lua
Industria.files.STtemplate
```
Stringa costante: contenuto di un programma ST di esempio/template, utilizzato
presumibilmente come contenuto iniziale nell'editor per nuove unità.

```lua
Industria.files.saveUnitEnvironment(unit)
```
Serializza `unit.last_env` e lo scrive in
`<world>/industriadt/<reference_program>.env`. Restituisce **un booleano**
(`true`/`false`), non un `Result` (unica eccezione nel modulo `files`).

```lua
Industria.files.saveUnitCode(unit, text)
```
Scrive `text` nel file `<world>/industriadt/<reference_program>` (il file
`.st` del codice sorgente). `Result<nil>`.

```lua
Industria.files.deleteUnitEnvironment(unit)
```
Elimina il file `.st.env` associato all'unità. `Result<number>` (il campo
`data` contiene il codice d'errore di `os.remove`, se presente).

```lua
Industria.files.deleteUnitCode(unit)
```
Elimina il file `.st` associato all'unità. `Result<number>`.

## 13. API di registrazione nodi I/O (`Industria.IOStatesBuilder`)

Definita in `nodes/api_iounits.lua`. Permette di dichiarare, per un "tipo" di
IOUnit, quali stati espone e come vengono letti/scritti dal runtime.

```lua
Industria.IOStatesBuilder(iounit_name)
```
Crea un builder (`IOBuilder`) per il tipo di IOUnit `iounit_name`.

```lua
IOBuilder:addState(state_name)
```
Inizia la definizione di uno stato chiamato `state_name`, restituendo un
`IOStateBuilder`.

Sul `IOStateBuilder` sono disponibili (una sola di queste va usata per stato):

```lua
IOStateBuilder:generateInputFunction(callbackFunction, dtype)
```
Lo stato è di tipo **Input**: `callbackFunction` riceve l'`IOUnit` e deve
restituire il valore corrente da fornire al programma ST.
`callbackFunction: fun(iounit: IOUnit): any`.

```lua
IOStateBuilder:generateOutputFunction(callbackFunction, dtype)
```
Lo stato è di tipo **Output**: `callbackFunction` riceve l'`IOUnit` e il
valore scritto dal programma ST, ed esegue l'effetto collaterale (es.
cambiare il nodo nel mondo). `callbackFunction: fun(iounit: IOUnit, value: any): nil`.

```lua
IOStateBuilder:generateInputOutputFunction(callbackFunction, dtype)
```
Lo stato è **Input/Output**: la stessa funzione viene chiamata sia in lettura
sia in scrittura. `callbackFunction: fun(iounit: IOUnit, value: any): any`.

```lua
IOStateBuilder:setConstantInputValue(value, dtype)
```
Imposta uno stato **Input** con valore costante (non funzione), utile per
proprietà statiche (es. un nodo "premuto" con stato costante diverso dal nodo
"non premuto"). Verifica la coerenza tra `type(value)` e `dtype` (`number`↔
`INT`/`REAL`, `string`↔`STRING`, `boolean`↔`BOOL`); genera un errore Lua se non
coincide. Per `INT`, converte il valore con `math.tointeger` se possibile.

```lua
IOStateBuilder:build()
```
Finalizza lo stato corrente e lo aggiunge a `IOBuilder.states_props`. Richiede
che `value`, `dtype`, `iotype` e `state` siano tutti definiti, altrimenti
genera un errore Lua. Restituisce l'`IOBuilder` (per concatenare altri
`:addState(...)`).

```lua
IOBuilder:register()
```
Registra definitivamente gli stati definiti in
`Industria.runtime.iounits.states[iounit_name]`.

**Esempio completo** (adattato da `nodes/baselamp.lua`):

```lua
Industria.IOStatesBuilder("industria:baselamp_default")
    :addState("lighted")
    :generateOutputFunction(function(iounit, value)
        local node = core.get_node_or_nil(iounit.pos_block)
        if not node or node.name == "ignore" then return end
        local target = value and "industria:baselamp_default_on"
                              or "industria:baselamp_default_off"
        if node.name ~= target then
            node.name = target
            core.swap_node(iounit.pos_block, node)
        end
    end, "BOOL")
    :build()
    :register()
```

```lua
Industria.registerIOUnitNode(iounit_name, node_name, node_definition, after_place_callback, after_dig_callback)
```
Registra un **nodo Luanti** come istanza di un tipo di IOUnit già definito con
`IOStatesBuilder`. Genera un errore Lua se `iounit_name` non è stato
precedentemente registrato con `:register()`.

La funzione:

- imposta `node_definition.industria_props = { iounit = 1, iounit_name = iounit_name }`
  (preservando eventuali campi già presenti in `industria_props`);
- aggiunge il gruppo `groups.industria_iounit = 1`;
- imposta `node_definition.after_place_node`: alla posa registra
  automaticamente il nodo come `IOUnit` tramite
  `Industria.iounits:registerIOUnit(placer:get_player_name(), pos)`, quindi
  richiama (se fornito) `after_place_callback(pos, placer, itemstack, pointed_thing)`;
- imposta `node_definition.after_dig_node`: alla rimozione, recupera l'`IOUnit`
  dalla posizione e la deregistra con `Industria.iounits:unregisterIOUnit`,
  inviando un messaggio in chat al proprietario; poi richiama (se fornito)
  `after_dig_callback(pos, oldnode, oldmetadata, digger)`;
- registra infine il nodo con `core.register_node(node_name, node_definition)`.

> **Attenzione**: se il `node_definition` passato definisce già
> `after_place_node` o `after_dig_node`, questi vengono **sovrascritti**
> integralmente dalla funzione (i parametri `after_place_callback` /
> `after_dig_callback` sono l'unico modo per aggiungere logica aggiuntiva).

## 14. Registrazione di nodi predefiniti

### Lampada — `Industria.register_base_lamp(def)`

Definita in `nodes/baselamp.lua`. Registra una coppia di nodi
`industria:baselamp_<material>_on` / `_off`, con:

- mesh `industria_baselamp.glb`;
- texture di default `industria_baselamp_on.png` / `industria_baselamp_off.png`
  (sovrascrivibili con `def.texture = { on = ..., off = ... }`);
- `def.material` (stringa, default `"unknwon"` se omesso — refuso presente nel
  codice sorgente) usato per comporre il nome del nodo;
- stato IO `lighted` (`BOOL`, Output): scrivere `TRUE`/`FALSE` cambia il nodo
  tra la variante "on" e "off" nel mondo.

Il mod registra già di default:
```lua
Industria.register_base_lamp({ material = "default" });
```
che produce i nodi `industria:baselamp_default_on` / `industria:baselamp_default_off`.

### Pulsante digitale — `Industria.register_digital_button(def)`

Definita in `nodes/basebutton.lua`. Registra `industria:digibutton_<material>`
e la sua variante `_pressed`, con:

- mesh `industria_digibutton.glb` / `industria_digibutton_pressed.glb`;
- click destro sul pulsante non premuto: lo commuta a "premuto" e lo
  ripristina automaticamente dopo **1 secondo** (`core.after(1, ...)`), salvo
  che il giocatore sia in modalità sneak;
- stato IO `pressed` (`BOOL`, Input): riflette se il nodo attuale è nello
  stato "premuto".

Registrato di default con:
```lua
Industria.register_digital_button({ material = "default" });
```

### Control Unit — `industria:baseunit`

Definita direttamente (non tramite funzione factory) in `nodes/baseunit.lua`:

- mesh `industria_basecontroller.glb`;
- gruppo `industria_controller`;
- `on_rightclick`: se il nodo non è ancora una unità registrata, apre il
  formspec di impostazione ID (`Industria.formspecs:showPLCInputID`); se lo è
  già ed è protetta da un proprietario diverso dal giocatore, non fa nulla; in
  tutti gli altri casi apre il formspec principale
  (`Industria.formspecs:showUnitMainForm`);
- `after_dig_node`: se il nodo aveva metadati `unit_id`/`unit_owner`, rimuove
  il controllore corrispondente con `Industria.controllers:removeController`.

## 15. `Industria.formspecs` — gestione delle GUI

Definita in `gui/formspecs.lua` e completata dai singoli file GUI.

```lua
Industria.formspecs.errorFormspec(msg)
```
Restituisce (come stringa) un formspec minimale che mostra un messaggio
d'errore.

```lua
Industria.formspecs:setPlayerStatus(playername, formspecid, data)
Industria.formspecs:setPlayerStatusFallback(playername, fallbackto)
Industria.formspecs:getPlayerStatus(playername)
```
Gestiscono lo stato "quale formspec sto mostrando a quale giocatore", con dati
associati opzionali e una funzione di fallback da richiamare alla chiusura.

```lua
Industria.formspecs:setCurrentCallback(playername, callback)
```
Imposta la funzione (`callback(playername, fields)`) che verrà invocata alla
ricezione dei campi del formspec attualmente mostrato al giocatore.

Il mod registra un unico gestore globale:
```lua
core.register_on_player_receive_fields(function(player, formname, fields) ... end)
```
che verifica che `formname` corrisponda al formspec attualmente tracciato per
quel giocatore, e in tal caso invoca il callback registrato con
`setCurrentCallback`.

### Formspec specifici

| Funzione | File | Scopo |
|---|---|---|
| `Industria.formspecs:showPLCInputID(player_name, node_position)` | `UnitIDInputFS.lua` | Richiede l'inserimento dell'ID per una nuova Control Unit |
| `Industria.formspecs:showUnitMainForm(playername, unit_code)` | `UnitMainFormFS.lua` | Menu principale della Control Unit (abilita/disabilita, protezione, editor, errori, eliminazione) |
| `Industria.formspecs:showEditor(player_name, unit_code)` | `STCodeEditorFS.lua` | Editor del codice ST della Control Unit |
| `Industria.formspecs:showIOLinkForm(playername, pos_unit, pos_iounit)` | `IOLinkForm.lua` | Conferma collegamento tra una Control Unit e un modulo IO |
| `Industria.formspecs:showIOLinkVariableForm(playername, unit, iounit, error)` | `IOLinkVariableForm.lua` | Selezione dello stato IO e della variabile ST da collegare |

I rispettivi callback (`Industria.formspecs.callbacks:PLCIDInputCallback`,
`:UnitMainFormCallback`, `:STEditorCallback`, `:IOLinkFormCallback`,
`:IOLinkVariableFormCallback`) gestiscono l'elaborazione dei campi inviati da
ciascun formspec e non sono pensati per essere chiamati direttamente da codice
esterno.

## 16. Tool `industria:iolinker`

Definito in `tools/IOLinker.lua`. È un tool riutilizzabile (non consumato
all'uso) che permette di collegare una Control Unit a un modulo IO:

1. Click su un nodo del gruppo `industria_controller`: memorizza la sua
   posizione nei metadati dell'itemstack (`industria:io:link:first`).
2. Click su un nodo del gruppo `industria_iounit`: memorizza la sua posizione
   (`industria:io:link:second`).
3. Quando entrambe le posizioni sono presenti, apre
   `Industria.formspecs:showIOLinkForm(playername, unit_pos, iounit_pos)` e
   azzera i metadati per un nuovo utilizzo.
4. Click su un nodo che non appartiene a nessuno dei due gruppi: azzera
   entrambe le selezioni ("Linker cleared").

## 17. Linguaggio Structured Text supportato

Implementato in `core/STCore.lua` (lexer, parser, interprete). Sintassi di un
programma:

```st
PROGRAM NomeProgramma

VAR
    variabile : TIPO := valore_iniziale;
END_VAR

(* istruzioni *)

END_PROGRAM
```

### Tipi di dato

- `INT`
- `REAL`
- `BOOL`
- `STRING`

### Strutture di controllo

- `IF ... THEN ... ELSIF ... THEN ... ELSE ... END_IF`
- `FOR ... TO ... [BY ...] DO ... END_FOR`
- `WHILE ... DO ... END_WHILE`

### Operatori

- Aritmetici: `+`, `-`, `*`, `/` (divisione intera se entrambi gli operandi
  sono `INT`, altrimenti float; `+` tra stringhe esegue concatenazione se
  almeno un operando è `STRING`)
- Confronto: `<`, `>`, `<=`, `>=`, `=`, `<>`
- Logici: `AND`, `OR`, `NOT` (con **short-circuit evaluation** per `AND`/`OR`)
- Unario: `-` (negazione aritmetica), `NOT` (negazione logica)

### Altro

- Assegnazioni di variabili (`variabile := espressione;`)
- Chiamate a funzione (vedi §18)
- Commenti: `(* ... *)` e `// ...` (visto nel file di esempio `Prova.st`)
- Divisione per zero: genera un errore runtime (`"Division by zero"`)
- Ogni Control Unit abilitata esegue **un ciclo completo** del proprio
  programma ad ogni step globale del motore (`core.register_globalstep`)

## 18. Funzioni built-in ST

Disponibili come chiamate di funzione all'interno di un programma ST
(case-insensitive: vengono convertite internamente in maiuscolo).

### Output

| Funzione | Descrizione |
|---|---|
| `PRINT(v1, v2, ...)` | Invia in chat al proprietario dell'unità i valori concatenati da tabulazione, con prefisso `[unit_id]:` |

### Matematiche

| Funzione | Descrizione |
|---|---|
| `ABS(x)` | Valore assoluto |
| `SQRT(x)` | Radice quadrata |
| `SQR(x)` | Quadrato (`x*x`) |
| `MAX(a,b)` | Massimo tra due valori |
| `MIN(a,b)` | Minimo tra due valori |
| `MOD(a,b)` | Resto della divisione (`a % b`) |
| `EXPT(a,b)` | Potenza (`a^b`) |
| `LN(x)` | Logaritmo naturale |
| `LOG(x)` | Logaritmo in base 10 |
| `SIN(x)` / `COS(x)` / `TAN(x)` | Funzioni trigonometriche (radianti) |
| `ASIN(x)` / `ACOS(x)` / `ATAN(x)` | Funzioni trigonometriche inverse |
| `CEIL(x)` | Arrotondamento verso +∞ |
| `FLOOR(x)` | Arrotondamento verso -∞ |
| `TRUNC(x)` | Troncamento verso zero |
| `ROUND(x)` | Arrotondamento al più vicino |

### Conversione di tipo

| Funzione | Descrizione |
|---|---|
| `INT_TO_REAL(x)` | Da intero a reale |
| `REAL_TO_INT(x)` | Da reale a intero (troncamento verso il basso) |
| `INT_TO_BOOL(x)` | `0` → `FALSE`, altrimenti `TRUE` |
| `BOOL_TO_INT(x)` | `TRUE` → `1`, `FALSE` → `0` |
| `TO_STRING(x)` | Converte un valore qualsiasi in stringa (formato ST) |
| `INT_TO_STRING(x)` | Converte un intero (troncato) in stringa |

### Stringhe

| Funzione | Descrizione |
|---|---|
| `CONCAT(v1, v2, ...)` | Concatena tutti gli argomenti |
| `LEN(s)` | Lunghezza della stringa |
| `LEFT(s, n)` | Primi `n` caratteri da sinistra |
| `RIGHT(s, n)` | Ultimi `n` caratteri da destra |
| `MID(s, pos, len)` | Sottostringa a partire da `pos`, lunga `len` |
| `UPPER(s)` | Converte in maiuscolo |
| `LOWER(s)` | Converte in minuscolo |
| `FIND(s, sub)` | Posizione (1-based) della prima occorrenza di `sub` in `s`, `0` se non trovata |

### Selezione e tempo

| Funzione | Descrizione |
|---|---|
| `SEL(g, in0, in1)` | Se `g` è `FALSE` restituisce `in0`, altrimenti `in1` |
| `MUX(k, in0, in1, ...)` | Restituisce l'argomento in posizione `k` (indice 0-based); errore runtime se fuori range |
| `TIME()` | Restituisce il tempo l'orario del gioco |

## 19. Persistenza su disco

Cartella dati creata in `<world>/industriadt/` (creata da `init.lua` se
assente).

| File | Contenuto |
|---|---|
| `controllers.dt` | `{ ids, units }` di `Industria.controllers`, serializzato con `core.serialize` |
| `iounits.dt` | `{ ids, registered, ioruntime = {inputs, outputs} }` di `Industria.iounits`/`Industria.runtime.iounits` |
| `<unit_code>.st` | Codice sorgente ST della Control Unit |
| `<unit_code>.st.env` | Ultimo ambiente di esecuzione (variabili/valori) della Control Unit |

Il salvataggio (`controllers`, `iounits`, ambienti correnti) avviene:

- ogni **120 secondi** (`core.after(120, ...)` ricorsivo, avviato all'avvio del mod);
- allo **shutdown** del server (`core.register_on_shutdown`);
- puntualmente, durante operazioni come `serialize()`/creazione di
  interpreti, come descritto nelle rispettive sezioni.

## 20. Comandi chat

| Comando | Descrizione |
|---|---|
| `/industria_units` | Stampa a tutti i giocatori in chat la tabella serializzata di `Industria.controllers.units` (comando di debug/ispezione) |