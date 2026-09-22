# Industria — API Documentation (Lua)

A **Luanti** mod that adds programmable Control Units, a Structured Text
language (ST, IEC 61131-3-like), and connectable digital I/O modules
(buttons, lamps) that can be linked to Control Units to build automations.

> This documentation describes **only** what is actually present and exposed
> in the mod's source code (global namespace `Industria`). It does not
> include internal/local functions of the ST parser/lexer, which are not
> part of the public API.

- Global namespace: `Industria`
- Main nodes: `industria:baseunit`, `industria:digibutton_default[_pressed]`,
  `industria:baselamp_default_off/_on`
- Tool: `industria:iolinker`
- World data path: `<world>/industriadt/`

---

## Table of contents

1. [Industria — API Documentation (Lua)](#industria--api-documentation-lua)
   1. [Table of contents](#table-of-contents)
   2. [1. Project structure](#1-project-structure)
   3. [2. Load order (`init.lua`)](#2-load-order-initlua)
   4. [3. Types and aliases (`docs.lua`)](#3-types-and-aliases-docslua)
   5. [4. `Industria.commons` — generic utilities](#4-industriacommons--generic-utilities)
   6. [5. `Industria.units` — Control Unit helpers](#5-industriaunits--control-unit-helpers)
   7. [6. `Industria.controllers` — Control Unit management](#6-industriacontrollers--control-unit-management)
   8. [7. `Industria.iounits` — I/O module management](#7-industriaiounits--io-module-management)
   9. [8. `Industria.runtime` — unit execution runtime](#8-industriaruntime--unit-execution-runtime)
      1. [Global execution loop](#global-execution-loop)
   10. [9. `Industria.runtime.iounits` — I/O linking runtime](#9-industriaruntimeiounits--io-linking-runtime)
   11. [10. `Industria.ST` — program compilation and execution](#10-industriast--program-compilation-and-execution)
   12. [11. `Interpreter` object](#11-interpreter-object)
   13. [12. `Industria.files` — `.st`/`.st.env` file persistence](#12-industriafiles--ststenv-file-persistence)
   14. [13. I/O node registration API (`Industria.IOStatesBuilder`)](#13-io-node-registration-api-industriaiostatesbuilder)
   15. [14. Registration of predefined nodes](#14-registration-of-predefined-nodes)
       1. [Lamp — `Industria.register_base_lamp(def)`](#lamp--industriaregister_base_lampdef)
       2. [Digital button — `Industria.register_digital_button(def)`](#digital-button--industriaregister_digital_buttondef)
       3. [Control Unit — `industria:baseunit`](#control-unit--industriabaseunit)
   16. [15. `Industria.formspecs` — GUI management](#15-industriaformspecs--gui-management)
       1. [Specific formspecs](#specific-formspecs)
   17. [16. Tool `industria:iolinker`](#16-tool-industriaiolinker)
   18. [17. Supported Structured Text language](#17-supported-structured-text-language)
       1. [Data types](#data-types)
       2. [Control structures](#control-structures)
       3. [Operators](#operators)
       4. [Other](#other)
   19. [18. Built-in ST functions](#18-built-in-st-functions)
       1. [Output](#output)
       2. [Math](#math)
       3. [Type conversion](#type-conversion)
       4. [Strings](#strings)
       5. [Selection and time](#selection-and-time)
   20. [19. Disk persistence](#19-disk-persistence)
   21. [20. Chat commands](#20-chat-commands)

---

## 1. Project structure

```
industria/
├── core/         Controllers, ST interpreter, files, runtime, IO runtime
│   ├── STCore.lua       Lexer, parser, interpreter of the ST language
│   ├── STFiles.lua      Saving/loading code and environment (.st/.st.env)
│   ├── controllers.lua  Control Unit management (creation, removal, persistence)
│   ├── iounits.lua      IO module management (creation, removal, persistence)
│   ├── runtime.lua      Unit execution runtime (enable/disable, cycles)
│   ├── ioruntime.lua    Linking (link/unlink) of ST variables <-> IO states
│   ├── Prova.st         Example file in the ST language (not part of the API)
│   └── init.lua         Initializes the tables and loads the core module's files
├── gui/          Formspecs: code editor, ID setup, IO linking
├── nodes/        Control Unit, buttons, lamps, IOUnit registration API
├── tools/        IO Linker
├── items/        Entry point for item registration (currently empty)
├── models/       .glb models
├── textures/     Mod textures
├── commons.lua   Shared utility functions
├── docs.lua      Type definitions (LuaLS/EmmyLua annotations, `@meta`)
├── init.lua      Mod entry point
├── mod.conf      Mod metadata
└── LICENSE       MIT License
```

> `items/init.lua` is present but **empty**: no additional items are
> currently registered through this file.

## 2. Load order (`init.lua`)

```lua
Industria = {};
Industria.path = core.get_modpath("industria");

dofile(Industria.path .. "/commons.lua");
dofile(Industria.path .. "/core/init.lua");
dofile(Industria.path .. "/gui/formspecs.lua");
dofile(Industria.path .. "/nodes/init.lua");
dofile(Industria.path .. "/tools/init.lua");
```

At the end of loading:

- the world data folder `industriadt/` is created (if it doesn't already exist);
- the `/tmp` chat command is registered;
- a periodic save every **120 seconds** and one **on server shutdown** are registered;
- `controllers.dt` and `iounits.dt` are deserialized, with a status message sent to all players.

## 3. Types and aliases (`docs.lua`)

An annotations-only file (`---@meta`), useful as a reference for the types
used throughout the API. Contains no executable code.

| Alias | Definition | Meaning |
|---|---|---|
| `Result<T>` | `{completed:boolean, msg:string, data:T}` | Standard return value of almost all API functions |
| `unit_id` | `string` | Identifier chosen for a Control Unit |
| `owner` | `string` | Name of the owning player |
| `unit_code` | `string` | `unit_id .. "_" .. owner` |
| `io_unit_code` | `string` | Unique code of an IO module (derived from its position in the world) |
| `iounitname` | `string` | Name of the IOUnit "type" (e.g. button, lamp) |
| `reference_program` | `string` | Name of the `.st` file associated with a Unit |
| `varname` | `string` | Name of a variable declared in the ST environment |
| `IOname` | `string` | Name of an IO state exposed by a module |
| `IOType` | `0 \| 1 \| 2` | `0`=Input, `1`=Output, `2`=Input/Output |
| `DType` | `"INT" \| "REAL" \| "BOOL" \| "STRING"` | Data types supported by ST programs |
| `VarEnv` | `{value: any, dtype: any}` | Value + type of an environment variable |
| `Environment` | `table<varname, VarEnv>` | Variable → value table of the interpreter |
| `IOLinks` | `table<varname, io_unit_code \| nil>` | Variable ↔ linked IO module |
| `IOPort` | `{linked_var: varname \| nil, type: IOType}` | Port exposed by an IO module |
| `IOState` | `{value: any, iotype: IOType, dtype: DType}` | State definition of an IO module |
| `IOUnitStats` | `table<IOname, IOState>` | All states defined for an IOUnit type |
| `Unit` | `{unit_id, owner, reference_program, last_env, enabled, protected, io_units}` | Representation of a Control Unit |
| `IOUnit` | `{iounitname, iounit_code, owner, reference_unit, pos_block, io_ports, linked_states}` | Representation of a registered IO module |
| `RTInfo` | `{enabled:boolean, interp: Interpreter\|nil, errors:string[]}` | Runtime state of a Unit |

All API functions that return a `Result` follow this convention:
`completed` indicates success/failure, `msg` a message (error or informational),
`data` the useful value on success.

## 4. `Industria.commons` — generic utilities

Defined in `commons.lua`.

```lua
Industria.commons.fnresult(completed, message, data)
```
Builds and returns a `Result` object: `{ completed, msg, data }`. This is the
function used by (almost) every other API function to return the outcome of
operations.

```lua
Industria.commons.isBlank(str)
```
Returns `true` if `str` is `nil` or contains only whitespace. Raises a Lua
error (`error(...)`) if `str` is neither `nil` nor a string.

```lua
Industria.commons.strtrim(str)
```
Removes trailing whitespace from a string. Raises an error if the argument is
not a string.

```lua
Industria.commons.rndstr(size)
```
Generates a random string of `size` printable ASCII characters (codes 32–126).

## 5. `Industria.units` — Control Unit helpers

Table initialized in `nodes/init.lua` (`Industria.units = {}`) and populated
in `nodes/commons.lua`.

```lua
Industria.units.toUnitCode(unit_id, player_name)
```
Returns `unit_id .. "_" .. player_name`, or `nil` if either argument is `nil`.

```lua
Industria.units.getUnitCode(unit)
```
Equivalent to `toUnitCode(unit.unit_id, unit.owner)`; returns `nil` if `unit`
is `nil`.

```lua
Industria.units.isValidUnit(pos, node)
```
Checks whether the node at position `pos` can be/is a Control Unit:

- if `node` is not provided, it is read with `core.get_node_or_nil(pos)`;
- checks that the node belongs to the `industria_controller` group;
- if the node does not yet have the `unit_id`/`unit_owner` metadata, returns
  `completed = true, data = nil` ("valid to be registered");
- if it does, looks up the already-registered unit in `Industria.controllers`
  and returns it in `data` if found.

Always returns a `Result<Unit|nil>`.

## 6. `Industria.controllers` — Control Unit management

Initialized in `core/init.lua`:

```lua
Industria.controllers = {
    ids = {},   -- table<owner, unit_code[]>
    units = {}  -- table<unit_code, Unit>
};
```

Functions defined in `core/controllers.lua`:

```lua
Industria.controllers:serialize()
```
Serializes `{ ids, units }` with `core.serialize` and writes it to
`<world>/industriadt/controllers.dt`. Returns `Result<nil>`.

```lua
Industria.controllers:deserialize()
```
Reads and deserializes `controllers.dt`, populates `self.ids`/`self.units`,
and for each loaded unit registers it at runtime (in a coroutine) by calling
`Industria.runtime:registerToRuntime(unit, false)`. Returns
`Result<table|nil>` with `data = self` on success.

```lua
Industria.controllers:addUnit(unit_id, owner)
```
Creates a new `Unit` for the player `owner`, provided a unit with the same
`unit_code` doesn't already exist. The new unit has:

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

It also registers the unit in the IO runtime via
`Industria.runtime.iounits:registerUnitToIORuntime(unit_code)`. Returns
`Result<Unit|nil>`.

```lua
Industria.controllers:getUnit(unit_code)
```
Returns the `Unit` associated with `unit_code`, if it exists.
`Result<Unit|nil>`.

```lua
Industria.controllers:removeController(unit_id, owner)
```
Completely removes a unit:

1. verifies it exists and belongs to the given owner;
2. unlinks it from the IO runtime (`Industria.runtime.iounits:unregisterUnitToIORuntime`);
3. deletes the associated `.st` and `.st.env` files (`Industria.files.deleteUnitCode/deleteUnitEnvironment`);
4. removes it from the `units` table and from the runtime (`Industria.runtime:removeUnit`).

Returns `Result<nil>`.

```lua
Industria.controllers:removeIOUnitFromController(unit_code, io_unit_code, deleteUnit)
```
Removes the reference to an IO module (`io_unit_code`) from a Unit's
`io_units` list. If `deleteUnit` is `true`, it also calls
`Industria.iounits:removeIOUnit(io_unit_code, unit.owner)` to completely
delete the IO module (use with care to avoid circular calls). Returns
`Result<nil|Unit>`.

## 7. `Industria.iounits` — I/O module management

Initialized in `core/init.lua`:

```lua
Industria.iounits = {
    ids = {},         -- table<owner, io_unit_code[]>
    registered = {}    -- table<io_unit_code, IOUnit>
};
```

The code of an IO module (`io_unit_code`) is computed in `nodes/commons.lua`
from its position in the world:

```lua
Industria.iounits.getIOUnitCode(pos)
-- returns "x"..pos.x.."y"..pos.y.."z"..pos.z, or nil if pos is nil
```

Functions defined in `core/iounits.lua`:

```lua
Industria.iounits:serialize()
```
Serializes `{ ids, registered, ioruntime = { inputs, outputs } }` (where
`ioruntime` comes from `Industria.runtime.iounits`) and writes it to
`<world>/industriadt/iounits.dt`. Returns `Result<nil>`.

```lua
Industria.iounits:deserialize()
```
Reads and deserializes `iounits.dt`; also restores
`Industria.runtime.iounits.inputs` and `.outputs` if present in the file.
Returns `Result<table|nil>`.

```lua
Industria.iounits:registerIOUnit(owner, pos)
```
Registers the node at `pos` as an `IOUnit`, provided that:

- the node exists and is actually registered in Luanti (`core.registered_nodes`);
- it has `industria_props` and belongs to the `industria_iounit` group;
- `industria_props.iounit_name` is defined.

Creates an `IOUnit`:

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

The `io_ports` are generated automatically from all the states registered for
that `iounit_name` via `Industria.IOStatesBuilder` (see §13). Returns
`Result<IOUnit|nil>`.

```lua
Industria.iounits:unregisterIOUnit(iounit_code, owner)
```
Completely removes an IO module: if it was linked to a Unit
(`reference_unit`), it is unlinked first with
`Industria.runtime.iounits:unlink(iounit)`. Returns `Result<nil>`.

```lua
Industria.iounits:getIOUnit(iounit_code)
```
Returns the `IOUnit` corresponding to `iounit_code`, if registered.
`Result<IOUnit|nil>`.

```lua
Industria.iounits.getAvailableStates(node_name)
```
Returns the list (array of strings) of state names available for the IOUnit
type associated with the node `node_name` (must be a registered node with
`industria_props` and the `industria_iounit` group). `Result<string[]|nil>`.

```lua
Industria.iounits.getIOUnitNodeName(iounit)
```
Returns the name of the current Luanti node at position `iounit.pos_block`,
or `nil` if it cannot be determined.

```lua
Industria.iounits.getLinkedState(iounit, envVarName)
```
Searches the `IOUnit`'s `io_ports` to find which state (`IOname`) is linked to
the variable `envVarName` in the ST environment. Returns the state name or
`nil`.

```lua
Industria.iounits.getStateData(node_name, state_name)
```
Returns the definition (`IOState`: `value`, `iotype`, `dtype`) of the state
`state_name` for the IOUnit type of the node `node_name`.
`Result<IOState|nil>`.

```lua
Industria.iounits.getIOUnitStates(iounit)
```
Returns the entire `IOUnitStats` table (all defined states) for the IOUnit
type that `iounit` belongs to, or `nil` if it cannot be determined.

## 8. `Industria.runtime` — unit execution runtime

Initialized in `core/init.lua`:

```lua
Industria.runtime = {
    current_unit = nil,
    units = {},   -- table<unit_code, RTInfo>
    iounits = {}  -- (later extended in core/ioruntime.lua, see §9)
};
```

Functions defined in `core/runtime.lua`:

```lua
Industria.runtime.print(text, unit)
```
Function invoked by the ST built-in `PRINT(...)`. Sends `text` in chat to the
unit's owner (`unit.owner`), prefixed with `[unit_id]:`. If `unit` is `nil`,
nothing is sent.

```lua
Industria.runtime:registerError(unit_code, message)
```
Appends `message` to the unit's error list (`errors`) in the runtime, if the
unit is already registered at runtime. Returns `Result<nil>`.

```lua
Industria.runtime:getErrors(unit_code)
```
Returns the list of errors registered for the unit. `Result<string[]>`.

```lua
Industria.runtime:removeUnit(unit)
```
Removes the unit from the `Industria.runtime.units` table. `Result<nil>`.

```lua
Industria.runtime:enableUnit(unit)
```
Enables execution of the unit:

- requires the unit to already be registered at runtime;
- if a valid interpreter doesn't exist yet, creates a new one with
  `self:createInterpreter(unit, false)` (without loading the saved environment);
- sets `enabled = true` both in the runtime and on the `Unit` object.

`Result<nil>`.

```lua
Industria.runtime:disableUnit(unit)
```
Disables the unit (`enabled = false`) both on the `Unit` object and in the
runtime, and if the interpreter exposes `init`, calls it to **reset the
environment**. `Result<nil>`.

```lua
Industria.runtime:setUnitInterpreter(unit, interpreter)
```
Binds an `Interpreter` (see §11) to a `Unit`, registering it at runtime if not
already registered. `Result<nil>`.

```lua
Industria.runtime:createInterpreter(unit, load_init)
```
Loads the Unit's ST code from the `reference_program` file, compiles it with
`Industria.ST.interpCode`, creates/assigns the interpreter, initializes it
(`interp:init()`), and if `load_init = true` tries to load the saved
environment from `<reference_program>.env`. Finally, via
`Industria.runtime.iounits:checkEnvs`, checks whether variables previously
linked to IO modules have been removed by the new code, unlinking them
accordingly. `Result<Interpreter|nil>`.

```lua
Industria.runtime:registerToRuntime(unit, justCreated)
```
Registers the unit in the `Industria.runtime.units` table (if not present)
with initial state `{ enabled, errors = {}, interp = nil }`, then calls
`self:createInterpreter(unit, justCreated == nil or not justCreated)`.
`Result<nil>`.

```lua
Industria.runtime:saveCurrentEnv()
```
For every unit present in the runtime, if enabled and with a valid
interpreter, updates `unit.last_env` with the interpreter's current
environment, then saves it to disk with
`Industria.files.saveUnitEnvironment(unit)`. Called by the periodic save
cycle and on shutdown.

### Global execution loop

`core/runtime.lua` registers a `core.register_globalstep`: on every engine
step, for each enabled unit with a valid interpreter:

1. copies **input** values from linked IO modules into the ST environment
   (`Industria.runtime.iounits:executeCopy(interp, unit, 0)`);
2. executes one cycle of the program (`interp:cycle()`), in a coroutine;
3. if the cycle fails, disables the unit;
4. otherwise copies **output** values from the ST environment to the linked
   IO modules (`executeCopy(interp, unit, 1)`).

## 9. `Industria.runtime.iounits` — I/O linking runtime

Initialized in `core/ioruntime.lua`:

```lua
Industria.runtime.iounits = {
    inputs = {},   -- table<unit_code, io_unit_code[]>
    outputs = {},  -- table<unit_code, io_unit_code[]>
    states = {}    -- table<iounitname, IOUnitStats>
};
```

`states` is populated via `Industria.IOStatesBuilder(...):register()` (see
§13) for every IOUnit type registered in the mod.

```lua
Industria.runtime.iounits:registerUnitToIORuntime(unit_code)
```
Initializes the `inputs[unit_code]` and `outputs[unit_code]` lists to `{}` if
not already present. Called automatically by
`Industria.controllers:addUnit`.

```lua
Industria.runtime.iounits:unregisterUnitToIORuntime(unit_code)
```
Unlinks all IO modules currently registered as inputs or outputs of the Unit,
then removes the `inputs[unit_code]` and `outputs[unit_code]` entries.

```lua
Industria.runtime.iounits:tryRegisterIOUnitToRuntime(unit_code, iounit, type)
```
Adds (if not already present) `iounit.iounit_code` to the Unit's `inputs`
and/or `outputs` list, depending on `type` (`0`=input, `1`=output,
`2`=both). Requires the Unit to already be registered in the IO runtime.
`Result<nil>`.

```lua
Industria.runtime.iounits:tryUnregisterIOUnitToRuntime(unit, iounit)
```
Counts how many linked states of the `iounit` are still of input/output type;
if there are none left, removes `iounit.iounit_code` from the Unit's
`inputs`/`outputs` lists. If **no** link remains at all, clears
`iounit.reference_unit`.

```lua
Industria.runtime.iounits:link(unit, iounit, iounitStateName, envVarName, type)
```
Links a state (`iounitStateName`) of an IO module to a variable
(`envVarName`) in a Unit's environment. Checks, in order:

1. `envVarName` is not empty;
2. the Unit has a valid `unit_code`;
3. the `IOUnit` is not already linked to a different unit;
4. the Unit has an associated interpreter with a valid environment;
5. the variable `envVarName` actually exists in the environment;
6. the state `iounitStateName` exists among the IO module's ports.

If all conditions are met, it registers the link in the IO runtime, updates
`iounit.io_ports[...]`, `iounit.linked_states[...]`, `unit.io_units[...]` and
`iounit.reference_unit`. `Result<IOUnit|nil>`.

```lua
Industria.runtime.iounits:unlink(iounit, iounitStateName)
```
Unlinks a specific state (if `iounitStateName` is provided) or **all** linked
states of the IO module (if omitted), clearing
`unit.io_units`/`iounit.linked_states`/`iounit.io_ports[...].linked_var`.
Then calls `tryUnregisterIOUnitToRuntime`. `Result<nil>`.

```lua
Industria.runtime.iounits:checkEnvs(unit, newEnv, prevEnv)
```
Compares the new environment generated after recompiling the ST code with the
previous one: for every variable present in `prevEnv` but no longer in
`newEnv`, if it was linked to an IO module, it is automatically unlinked.

```lua
Industria.runtime.iounits:executeCopy(interp, unit, direction)
```
Copies values between the ST environment and the states of the IO modules
linked to the Unit:

- `direction = 0` (input): for every variable linked to an input-type state
  (`iotype == 0`) with the same `dtype`, updates the environment value by
  reading the state (calling the function, if `value` is a function, or
  copying the constant value otherwise);
- `direction = 1` (output): for every variable linked to an output-type state
  (`iotype == 1`), invokes the output function passing the variable's current
  value.

Called automatically by the global loop (§8), before and after
`interp:cycle()`.

## 10. `Industria.ST` — program compilation and execution

Initialized in `core/init.lua` (`Industria.ST = {}`), populated in
`core/STCore.lua`.

```lua
Industria.ST.interpCode(code_source, unit_code, unit)
```
Compiles the ST source text (`code_source`) in three phases (lexer → parser →
interpreter):

1. **Lexical**: tokenization. On error, registers an error
   `(LESSICAL) ...` via `Industria.runtime:registerError(unit_code, ...)` and
   returns `Result(false, msg, nil)`.
2. **Syntactic**: parsing into an AST. On error, registers
   `(SYNTACTIC) ...` and returns `Result(false, msg, nil)`.
3. **Interpreter creation**: builds the `Interpreter` object (§11) associated
   with the AST and the `unit`.

Returns `Result<Interpreter|nil>`. It does **not** automatically run `init()`
nor `cycle()`: that is the caller's responsibility (see
`Industria.runtime:createInterpreter`).

```lua
Industria.ST.loadCode(filename)
```
Reads and returns the textual content of the file `filename`.
`Result<string|nil>`.

## 11. `Interpreter` object

Returned by `Industria.ST.interpCode(...).data`. Exposes these methods:

```lua
interp:init(ast_in)
```
"Power-on" phase: walks through all `VAR` declarations of the AST and
populates the environment (`env`) with initial values (evaluating the `:=
...` expression if present, otherwise using the type's default value: `0` for
`INT`, `0.0` for `REAL`, `false` for `BOOL`, `""` for `STRING`). Must be
called **exactly once** before the scan cycle. Returns the resulting
`Environment`.

```lua
interp:cycle()
```
Executes **one scan cycle**: walks through all statements in the `PROGRAM`
body, from start to end, without reinitializing the variables (the typical
stateful behavior of a PLC). Execution happens via `pcall`, so runtime errors
do not interrupt the Lua process.

Returns **four values**:
```lua
local ok, err, env, stats = interp:cycle()
-- ok    : boolean — cycle outcome
-- err   : string|nil — error message if ok == false
-- env   : Environment — current environment after the cycle
-- stats : { cycle:number, steps_this:number, steps_total:number }
```

```lua
interp:setEnv(newEnv)
```
Sets the environment variables: if the internal environment is empty/nil, it
is fully replaced with `newEnv`; otherwise only the values of keys already
present in the current environment are copied (no new variables are
introduced).

```lua
interp:getEnv()
```
Returns the interpreter's current `Environment`.

```lua
interp:getUnit()
```
Returns the `Unit` associated with this interpreter.

## 12. `Industria.files` — `.st`/`.st.env` file persistence

Initialized in `core/init.lua` (`Industria.files = {}`), populated in
`core/STFiles.lua`.

```lua
Industria.files.STtemplate
```
Constant string: content of a sample/template ST program, presumably used as
the initial content in the editor for new units.

```lua
Industria.files.saveUnitEnvironment(unit)
```
Serializes `unit.last_env` and writes it to
`<world>/industriadt/<reference_program>.env`. Returns **a plain boolean**
(`true`/`false`), not a `Result` (the only exception in the `files` module).

```lua
Industria.files.saveUnitCode(unit, text)
```
Writes `text` to the file `<world>/industriadt/<reference_program>` (the
source `.st` file). `Result<nil>`.

```lua
Industria.files.deleteUnitEnvironment(unit)
```
Deletes the `.st.env` file associated with the unit. `Result<number>` (the
`data` field contains `os.remove`'s error code, if any).

```lua
Industria.files.deleteUnitCode(unit)
```
Deletes the `.st` file associated with the unit. `Result<number>`.

## 13. I/O node registration API (`Industria.IOStatesBuilder`)

Defined in `nodes/api_iounits.lua`. Allows declaring, for an IOUnit "type",
which states it exposes and how they are read/written by the runtime.

```lua
Industria.IOStatesBuilder(iounit_name)
```
Creates a builder (`IOBuilder`) for the IOUnit type `iounit_name`.

```lua
IOBuilder:addState(state_name)
```
Starts the definition of a state named `state_name`, returning an
`IOStateBuilder`.

On the `IOStateBuilder` the following are available (only one should be used
per state):

```lua
IOStateBuilder:generateInputFunction(callbackFunction, dtype)
```
The state is of type **Input**: `callbackFunction` receives the `IOUnit` and
must return the current value to provide to the ST program.
`callbackFunction: fun(iounit: IOUnit): any`.

```lua
IOStateBuilder:generateOutputFunction(callbackFunction, dtype)
```
The state is of type **Output**: `callbackFunction` receives the `IOUnit` and
the value written by the ST program, and performs the side effect (e.g.
changing the node in the world). `callbackFunction: fun(iounit: IOUnit, value: any): nil`.

```lua
IOStateBuilder:generateInputOutputFunction(callbackFunction, dtype)
```
The state is **Input/Output**: the same function is called both on read and
on write. `callbackFunction: fun(iounit: IOUnit, value: any): any`.

```lua
IOStateBuilder:setConstantInputValue(value, dtype)
```
Sets an **Input** state with a constant value (not a function), useful for
static properties (e.g. a "pressed" node with a constant state different from
the "not pressed" node). Checks the consistency between `type(value)` and
`dtype` (`number`↔`INT`/`REAL`, `string`↔`STRING`, `boolean`↔`BOOL`); raises a
Lua error if they don't match. For `INT`, converts the value with
`math.tointeger` if possible.

```lua
IOStateBuilder:build()
```
Finalizes the current state and adds it to `IOBuilder.states_props`.
Requires `value`, `dtype`, `iotype` and `state` to all be defined, otherwise
raises a Lua error. Returns the `IOBuilder` (to chain further
`:addState(...)` calls).

```lua
IOBuilder:register()
```
Permanently registers the defined states in
`Industria.runtime.iounits.states[iounit_name]`.

**Full example** (adapted from `nodes/baselamp.lua`):

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
Registers a **Luanti node** as an instance of an IOUnit type already defined
with `IOStatesBuilder`. Raises a Lua error if `iounit_name` was not
previously registered with `:register()`.

The function:

- sets `node_definition.industria_props = { iounit = 1, iounit_name = iounit_name }`
  (preserving any fields already present in `industria_props`);
- adds the group `groups.industria_iounit = 1`;
- sets `node_definition.after_place_node`: on placement it automatically
  registers the node as an `IOUnit` via
  `Industria.iounits:registerIOUnit(placer:get_player_name(), pos)`, then
  calls (if provided) `after_place_callback(pos, placer, itemstack, pointed_thing)`;
- sets `node_definition.after_dig_node`: on removal, retrieves the `IOUnit`
  at that position and deregisters it with
  `Industria.iounits:unregisterIOUnit`, sending a chat message to the owner;
  then calls (if provided) `after_dig_callback(pos, oldnode, oldmetadata, digger)`;
- finally registers the node with `core.register_node(node_name, node_definition)`.

> **Warning**: if the passed `node_definition` already defines
> `after_place_node` or `after_dig_node`, these are **entirely overwritten**
> by the function (the `after_place_callback` / `after_dig_callback`
> parameters are the only way to add additional logic).

## 14. Registration of predefined nodes

### Lamp — `Industria.register_base_lamp(def)`

Defined in `nodes/baselamp.lua`. Registers a pair of nodes
`industria:baselamp_<material>_on` / `_off`, with:

- mesh `industria_baselamp.glb`;
- default textures `industria_baselamp_on.png` / `industria_baselamp_off.png`
  (overridable via `def.texture = { on = ..., off = ... }`);
- `def.material` (string, defaults to `"unknwon"` if omitted — a typo present
  in the source code) used to compose the node name;
- IO state `lighted` (`BOOL`, Output): writing `TRUE`/`FALSE` switches the
  node between the "on" and "off" variant in the world.

The mod already registers by default:
```lua
Industria.register_base_lamp({ material = "default" });
```
which produces the nodes `industria:baselamp_default_on` /
`industria:baselamp_default_off`.

### Digital button — `Industria.register_digital_button(def)`

Defined in `nodes/basebutton.lua`. Registers `industria:digibutton_<material>`
and its `_pressed` variant, with:

- mesh `industria_digibutton.glb` / `industria_digibutton_pressed.glb`;
- right-clicking the unpressed button switches it to "pressed" and
  automatically restores it after **1 second** (`core.after(1, ...)`), unless
  the player is sneaking;
- IO state `pressed` (`BOOL`, Input): reflects whether the current node is in
  the "pressed" state.

Registered by default with:
```lua
Industria.register_digital_button({ material = "default" });
```

### Control Unit — `industria:baseunit`

Defined directly (not via a factory function) in `nodes/baseunit.lua`:

- mesh `industria_basecontroller.glb`;
- group `industria_controller`;
- `on_rightclick`: if the node is not yet a registered unit, opens the ID
  setup formspec (`Industria.formspecs:showPLCInputID`); if it is already
  registered and protected by an owner different from the clicking player,
  does nothing; in all other cases opens the main formspec
  (`Industria.formspecs:showUnitMainForm`);
- `after_dig_node`: if the node had `unit_id`/`unit_owner` metadata, removes
  the corresponding controller with `Industria.controllers:removeController`.

## 15. `Industria.formspecs` — GUI management

Defined in `gui/formspecs.lua` and completed by the individual GUI files.

```lua
Industria.formspecs.errorFormspec(msg)
```
Returns (as a string) a minimal formspec that shows an error message.

```lua
Industria.formspecs:setPlayerStatus(playername, formspecid, data)
Industria.formspecs:setPlayerStatusFallback(playername, fallbackto)
Industria.formspecs:getPlayerStatus(playername)
```
Manage the "which formspec is being shown to which player" state, with
optional associated data and a fallback function to call on close.

```lua
Industria.formspecs:setCurrentCallback(playername, callback)
```
Sets the function (`callback(playername, fields)`) that will be invoked when
the fields of the formspec currently shown to that player are received.

The mod registers a single global handler:
```lua
core.register_on_player_receive_fields(function(player, formname, fields) ... end)
```
which checks that `formname` matches the formspec currently tracked for that
player, and if so invokes the callback registered with `setCurrentCallback`.

### Specific formspecs

| Function | File | Purpose |
|---|---|---|
| `Industria.formspecs:showPLCInputID(player_name, node_position)` | `UnitIDInputFS.lua` | Prompts for entering the ID of a new Control Unit |
| `Industria.formspecs:showUnitMainForm(playername, unit_code)` | `UnitMainFormFS.lua` | Main menu of the Control Unit (enable/disable, protection, editor, errors, deletion) |
| `Industria.formspecs:showEditor(player_name, unit_code)` | `STCodeEditorFS.lua` | Editor for the Control Unit's ST code |
| `Industria.formspecs:showIOLinkForm(playername, pos_unit, pos_iounit)` | `IOLinkForm.lua` | Confirms the link between a Control Unit and an IO module |
| `Industria.formspecs:showIOLinkVariableForm(playername, unit, iounit, error)` | `IOLinkVariableForm.lua` | Selection of the IO state and the ST variable to link |

The respective callbacks (`Industria.formspecs.callbacks:PLCIDInputCallback`,
`:UnitMainFormCallback`, `:STEditorCallback`, `:IOLinkFormCallback`,
`:IOLinkVariableFormCallback`) handle processing of the fields submitted by
each formspec and are not meant to be called directly from external code.

## 16. Tool `industria:iolinker`

Defined in `tools/IOLinker.lua`. It is a reusable tool (not consumed on use)
that allows linking a Control Unit to an IO module:

1. Clicking a node of the `industria_controller` group: stores its position
   in the itemstack's metadata (`industria:io:link:first`).
2. Clicking a node of the `industria_iounit` group: stores its position
   (`industria:io:link:second`).
3. When both positions are present, opens
   `Industria.formspecs:showIOLinkForm(playername, unit_pos, iounit_pos)` and
   clears the metadata for a new use.
4. Clicking a node that belongs to neither group: clears both selections
   ("Linker cleared").

## 17. Supported Structured Text language

Implemented in `core/STCore.lua` (lexer, parser, interpreter). Syntax of a
program:

```st
PROGRAM ProgramName

VAR
    variable : TYPE := initial_value;
END_VAR

(* statements *)

END_PROGRAM
```

### Data types

- `INT`
- `REAL`
- `BOOL`
- `STRING`

### Control structures

- `IF ... THEN ... ELSIF ... THEN ... ELSE ... END_IF`
- `FOR ... TO ... [BY ...] DO ... END_FOR`
- `WHILE ... DO ... END_WHILE`

### Operators

- Arithmetic: `+`, `-`, `*`, `/` (integer division if both operands are
  `INT`, floating-point otherwise; `+` between strings performs
  concatenation if at least one operand is `STRING`)
- Comparison: `<`, `>`, `<=`, `>=`, `=`, `<>`
- Logical: `AND`, `OR`, `NOT` (with **short-circuit evaluation** for `AND`/`OR`)
- Unary: `-` (arithmetic negation), `NOT` (logical negation)

### Other

- Variable assignments (`variable := expression;`)
- Function calls (see §18)
- Comments: `(* ... *)` and `// ...` (seen in the example file `Prova.st`)
- Division by zero: raises a runtime error (`"Division by zero"`)
- Every enabled Control Unit executes **one full cycle** of its own program
  on every global engine step (`core.register_globalstep`)

## 18. Built-in ST functions

Available as function calls within an ST program (case-insensitive:
internally converted to uppercase).

### Output

| Function | Description |
|---|---|
| `PRINT(v1, v2, ...)` | Sends the values, tab-concatenated, in chat to the unit's owner, prefixed with `[unit_id]:` |

### Math

| Function | Description |
|---|---|
| `ABS(x)` | Absolute value |
| `SQRT(x)` | Square root |
| `SQR(x)` | Square (`x*x`) |
| `MAX(a,b)` | Maximum of two values |
| `MIN(a,b)` | Minimum of two values |
| `MOD(a,b)` | Remainder of division (`a % b`) |
| `EXPT(a,b)` | Power (`a^b`) |
| `LN(x)` | Natural logarithm |
| `LOG(x)` | Base-10 logarithm |
| `SIN(x)` / `COS(x)` / `TAN(x)` | Trigonometric functions (radians) |
| `ASIN(x)` / `ACOS(x)` / `ATAN(x)` | Inverse trigonometric functions |
| `CEIL(x)` | Round toward +∞ |
| `FLOOR(x)` | Round toward -∞ |
| `TRUNC(x)` | Truncate toward zero |
| `ROUND(x)` | Round to nearest |

### Type conversion

| Function | Description |
|---|---|
| `INT_TO_REAL(x)` | From integer to real |
| `REAL_TO_INT(x)` | From real to integer (truncation downward) |
| `INT_TO_BOOL(x)` | `0` → `FALSE`, otherwise `TRUE` |
| `BOOL_TO_INT(x)` | `TRUE` → `1`, `FALSE` → `0` |
| `TO_STRING(x)` | Converts any value to a string (ST format) |
| `INT_TO_STRING(x)` | Converts an integer (truncated) to a string |

### Strings

| Function | Description |
|---|---|
| `CONCAT(v1, v2, ...)` | Concatenates all arguments |
| `LEN(s)` | Length of the string |
| `LEFT(s, n)` | First `n` characters from the left |
| `RIGHT(s, n)` | Last `n` characters from the right |
| `MID(s, pos, len)` | Substring starting at `pos`, of length `len` |
| `UPPER(s)` | Converts to uppercase |
| `LOWER(s)` | Converts to lowercase |
| `FIND(s, sub)` | Position (1-based) of the first occurrence of `sub` in `s`, `0` if not found |

### Selection and time

| Function | Description |
|---|---|
| `SEL(g, in0, in1)` | If `g` is `FALSE` returns `in0`, otherwise `in1` |
| `MUX(k, in0, in1, ...)` | Returns the argument at position `k` (0-based index); runtime error if out of range |
| `TIME()` | Returns the in-game time |

## 19. Disk persistence

Data folder created at `<world>/industriadt/` (created by `init.lua` if
missing).

| File | Content |
|---|---|
| `controllers.dt` | `{ ids, units }` from `Industria.controllers`, serialized with `core.serialize` |
| `iounits.dt` | `{ ids, registered, ioruntime = {inputs, outputs} }` from `Industria.iounits`/`Industria.runtime.iounits` |
| `<unit_code>.st` | ST source code of the Control Unit |
| `<unit_code>.st.env` | Latest execution environment (variables/values) of the Control Unit |

Saving (`controllers`, `iounits`, current environments) happens:

- every **120 seconds** (recursive `core.after(120, ...)`, started when the mod loads);
- on server **shutdown** (`core.register_on_shutdown`);
- at specific points, during operations such as `serialize()`/interpreter
  creation, as described in the respective sections.

## 20. Chat commands

| Command | Description |
|---|---|
| `/tmp` | Prints the serialized `Industria.controllers.units` table to all players in chat (debug/inspection command) |