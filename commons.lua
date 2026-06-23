math.randomseed(os.clock());

---@type function<table,any>
table.indexof = table.indexof;

---Contains common functions or data that needs/should be accessed from project-wide functions
Industria.commons = {
    ---Create the result for a function to be returned to the caller
    ---@param completed boolean if the function succeded or failed
    ---@param message string|nil message of the error/success or nil if not present
    ---@param data table|nil|any that the functions returns on success
    ---@return Result #{completed,msg,data}
    fnresult = function(completed, message, data)
        return { completed = completed, msg = message, data = data };
    end,
    ---Check if string is blank (only whitespaces)
    ---@param str string|any
    ---@return boolean
    isBlank = function(str)
        -- Check for nil
        if str == nil then
            return true
        end

        -- Ensure it's a string
        if type(str) ~= "string" then
            error("Invalid input: expected a string or nil")
        end

        -- Remove leading/trailing whitespace and check length
        return str:match("^%s*$") ~= nil
    end,
    ---Trims a string
    ---@param str string
    ---@return string
    strtrim = function(str)
        -- Validate input type
        if type(str) ~= "string" then
            error("trim_trailing_spaces: expected a string, got " .. type(str))
        end
        -- Remove trailing spaces using pattern matching
        local res, count =  str:gsub("%s+$", "");
        return res;
    end,
    ---Generates a random string
    ---@param size number Size of the string to be generated
    ---@return string #The random string generated
    rndstr = function (size)
        local rnd_str = {};
        for i = 1, size, 1 do
            rnd_str[i] = string.char(math.random(32, 126))
        end
        return table.concat(rnd_str);
    end
}
