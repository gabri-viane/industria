# Industria

Industria is a Luanti mod that adds programmable Control Units, Structured Text (ST) programs, and connectable digital input/output units for automation systems.

## Features

- Programmable Control Units with per-player identifiers.
- Structured Text editor, compiler, parser, and runtime interpreter.
- Digital buttons and lamps usable as I/O modules.
- Variable-to-I/O linking.
- Unit protection and ownership management.
- Persistent controllers, I/O modules, environments, and runtime links.
- Built-in ST mathematical, conversion, string, selection, timing, and output functions.

## Requirements

No mandatory dependencies are required.

## Installation

1. Copy the `industria` directory into the Luanti `mods` directory.
2. Enable **Industria** for the desired world.
3. Start the world.
4. Obtain the Control Unit, I/O modules, and IO Linker from the creative inventory or another compatible source.

No crafting recipes are registered by this mod by now.

## Example Nodes

### Control Unit

Node name:

```text
industria:baseunit
```

The Control Unit is the programmable controller. Right-click it to:

- Assign a unique Unit ID.
- Enable or disable execution.
- Protect or unprotect the unit.
- Open the ST code editor.
- View runtime errors.
- Delete the unit.

A unit code is generated from its ID and owner:

```text
<unit_id>_<owner>
```

### Digital Button

Node names:

```text
industria:digibutton_default
industria:digibutton_default_pressed
```

The button produces the Boolean state:

```text
pressed : BOOL
```

Right-clicking the unpressed button temporarily changes it to the pressed state.

### Lamp

Node names:

```text
industria:baselamp_default_off
industria:baselamp_default_on
```

The lamp exposes the output state:

```text
lighted : BOOL
```

Writing `TRUE` switches the lamp on; writing `FALSE` switches it off.

## Items and Tools

### IO Linker

Item name:

```text
industria:iolinker
```

The IO Linker connects a Control Unit to an I/O module:

1. Use it on a Control Unit.
2. Use it on a button or lamp.
3. Confirm the connection in the linking form.
4. Select an I/O state and an ST variable.
5. Create the link.

The tool is reusable and is not consumed when used. To clear the selection use it on a not-industria node.

## Structured Text

Programs use the following structure:

````st
PROGRAM Example

VAR
    counter : INT := 0;
    button_state : BOOL := FALSE;
END_VAR

counter := counter + 1;

IF button_state THEN
    PRINT('Button pressed');
END_IF

END_PROGRAM
````

Supported declarations and control structures include:

- `INT`
- `REAL`
- `BOOL`
- `STRING`
- `IF`, `ELSIF`, `ELSE`, `END_IF`
- `FOR`, `TO`, `BY`, `DO`, `END_FOR`
- `WHILE`, `DO`, `END_WHILE`
- Arithmetic, comparison, logical, and unary operators
- Variable assignments
- Function calls

Each enabled controller executes its program during the Luanti global step.

## Built-in ST Functions

### Output

- `PRINT(value, ...)`

Sends output to the owner’s chat with the unit ID prefix.

### Mathematics

- `ABS`
- `SQRT`
- `SQR`
- `MAX`
- `MIN`
- `MOD`
- `EXPT`
- `LN`
- `LOG`
- `SIN`
- `COS`
- `TAN`
- `ASIN`
- `ACOS`
- `ATAN`
- `CEIL`
- `FLOOR`
- `TRUNC`
- `ROUND`

### Type Conversion

- `INT_TO_REAL`
- `REAL_TO_INT`
- `INT_TO_BOOL`
- `BOOL_TO_INT`
- `TO_STRING`
- `INT_TO_STRING`

### Strings

- `CONCAT`
- `LEN`
- `LEFT`
- `RIGHT`
- `MID`
- `UPPER`
- `LOWER`
- `FIND`

### Selection and Time

- `SEL`
- `MUX`
- `TIME`

## Linking Variables to I/O

I/O states have one of three directions:

- Input
- Output
- Input/Output

The data types currently used by the I/O API are:

- `INT`
- `REAL`
- `BOOL`
- `STRING`

A Control Unit and an I/O module must belong to the same player before they can be linked. An I/O module can reference one Control Unit at a time.

## Persistence

Industria creates the following directory inside the active world directory:

```text
industriadt/
```

Stored files include:

```text
controllers.dt
iounits.dt
<unit_code>.st
<unit_code>.st.env
```

- `controllers.dt` stores controller identifiers and controller data.
- `iounits.dt` stores registered I/O modules and I/O runtime links.
- `.st` files store the program of each Control Unit.
- `.st.env` files store the latest execution environment.

Data is saved:

- Every 120 seconds.
- When the server shuts down.
- During controller and I/O serialization.

## Chat Commands

### `/tmp`

Prints the serialized controller table to chat. This command is intended for inspecting stored controller data.

## Lua API

### Common utilities

```lua
Industria.commons.fnresult(completed, message, data)
Industria.commons.isBlank(value)
Industria.commons.strtrim(value)
Industria.commons.rndstr(size)
```

### Unit helpers

```lua
Industria.units.toUnitCode(unit_id, player_name)
Industria.units.getUnitCode(unit)
Industria.units.isValidUnit(pos, node)
```

### Controller management

```lua
Industria.controllers:addUnit(unit_id, owner)
Industria.controllers:getUnit(unit_code)
Industria.controllers:removeController(unit_id, owner)
Industria.controllers:serialize()
Industria.controllers:deserialize()
```

### I/O unit management

```lua
Industria.iounits:registerIOUnit(owner, pos)
Industria.iounits:getIOUnit(iounit_code)
Industria.iounits:unregisterIOUnit(iounit_code, owner)
Industria.iounits.getIOUnitCode(pos)
Industria.iounits.getAvailableStates(node_name)
Industria.iounits.getStateData(node_name, state_name)
```

### Runtime linking

```lua
Industria.runtime.iounits:link(unit, iounit, state_name, variable_name, io_type)
Industria.runtime.iounits:unlink(iounit, state_name)
Industria.runtime:enableUnit(unit)
Industria.runtime:disableUnit(unit)
Industria.runtime:createInterpreter(unit, load_init)
```

### Registering custom I/O modules

```lua
Industria.IOStatesBuilder("my_iounit")
    :addState("value")
    :generateInputFunction(function(iounit)
        return false
    end, "BOOL")
    :build()
    :register()
```

Nodes can then be registered with:

```lua
Industria.registerIOUnitNode(
    "my_iounit",
    "industria:my_iounit",
    node_definition
)
```

## Project Structure

```text
industria/
├── core/       Controllers, ST interpreter, files, runtime, and I/O runtime
├── gui/        Control Unit, editor, and linking forms
├── nodes/      Control Unit, buttons, lamps, and I/O registration API
├── tools/      IO Linker
├── items/      Item registration entry point
├── models/     glTF models
├── textures/   Mod textures
├── commons.lua Shared utility functions
├── docs.lua    Lua type definitions
├── init.lua    Mod entry point
├── mod.conf    Mod metadata
└── LICENSE     MIT License
```

## License

Copyright (c) 2026 `@gabri-viane`.

Industria is distributed under the MIT License. See `LICENSE` for the complete license text.

### Important Note

Industria focuses on bringing automation programming to Luanti rather than reimplementing existing language-processing technology. The Structured Text lexer, parser, and interpreter were generated with AI assistance, while the rest of the mod was developed manually.