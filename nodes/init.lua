---@alias UnitSize {max_vars:number,max_io:number}
---@alias UnitType {type:UnitSize,id:string}

Industria.units = {
    definitions = {
        ---@type UnitSize
        small = {
            max_vars = 10,
            max_io = 8, --4 inputs, 4 outputs
        },
        ---@type UnitSize
        medium = {
            max_vars = 20,
            max_io = 16, --8 inputs, 8 outputs
        },
        ---@type UnitSize
        large = {
            max_vars = 40,
            max_io = 32, --16 inputs, 16 outputs
        },
        ---@type UnitSize
        unlimited = {
            max_vars = 400,
            max_io = 64,--32 inputs, 32 outputs
        },
    },

};
Industria.units. ---@type UnitType
baseunit = {
    type = Industria.units.definitions.small,
    id = "industria:baseunit"
}

dofile(Industria.path .. "/nodes/commons.lua");
dofile(Industria.path .. "/nodes/baseunit.lua");
dofile(Industria.path .. "/nodes/basebutton.lua");
