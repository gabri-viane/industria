---@alias UnitSize {max_vars:number,max_io:number}
---@alias UnitType {type:UnitSize,id:string}

Industria.units = {
    definitions = {
        ---@type UnitSize
        small = {
            max_vars = 10,
            max_io = 4,
        },
        ---@type UnitSize
        medium = {
            max_vars = 20,
            max_io = 8,
        },
        ---@type UnitSize
        large = {
            max_vars = 40,
            max_io = 16,
        },
        ---@type UnitSize
        unlimited = {
            max_vars = 400,
            max_io = 72,
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
