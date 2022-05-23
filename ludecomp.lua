#!/usr/bin/env lua5.2

local function dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k, v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..tostring(k)..'"' end
          s = s .. '['..k..'] = ' .. dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
end

----------------------------------------------------

AffineExpression = {}

function AffineExpression:new(o)
    o = o or {{}, 0}
    setmetatable(o, self)
    self.__index = self
    return o
end

function AffineExpression:replace(variable, replacement)
    local old_A, old_b = table.unpack(self)
    local replacement_A, replacement_b = table.unpack(replacement)

    local p = old_A[variable]
    if not p then
        return self
    end

    local new_A = {}
    for x, _ in pairs(old_A) do
        new_A[x] = old_A[x]
    end

    new_A[variable] = nil
    for x, _ in pairs(replacement_A) do
        new_A[x] = (new_A[x] or 0) + replacement_A[x] * p
        if new_A[x] == 0 then
            new_A[x] = nil
        end
    end
    local new_b = old_b + replacement_b * p

    return AffineExpression:new{new_A, new_b}
end

function AffineExpression:__tostring()
    local A, b = table.unpack(self)

    local s = {}
    for x, _ in pairs(A) do
        if A[x] > 0 then
            table.insert(s, " + ")
            if A[x] ~= 1 then
                table.insert(s, tostring(A[x]))
                table.insert(s, " ")
            end
            table.insert(s, "`")
            table.insert(s, tostring(x))
            table.insert(s, "`")
        elseif A[x] < 0 then
            table.insert(s, " - ")
            if -A[x] ~= 1 then
                table.insert(s, tostring(-A[x]))
                table.insert(s, " ")
            end
            table.insert(s, "`")
            table.insert(s, tostring(x))
            table.insert(s, "`")
        end
    end
    if b > 0 then
        table.insert(s, " + ")
        table.insert(s, tostring(b))
    elseif b < 0 then
        table.insert(s, " - ")
        table.insert(s, tostring(-b))
    end
    return table.concat(s)
end

-----------------------------------------------------

-- Vanderbei Exercise 2.10

--[[
local objective = AffineExpression:new{{
    [1] =  -6,
    [2] =  -8,
    [3] =  -5,
    [4] =  -9,
}, 0}

-- Variable constraints: all expressions must evaluate to zero.
local constraints = {
    AffineExpression:new{{[1] = 1, [2] = 1, [3] = 1, [4] = 1},  1},
}
]]

-- Vanderbei Exercise 2.11

--[[
--local objective = AffineExpression:new{{
    [12] = 1,
    [13] = 8,
    [14] = 9,
    [23] = 2,
    [24] = 7,
    [34] = 3,
}, 0}

-- Variable constraints: all expressions must evaluate to zero.
local constraints = {
    AffineExpression:new{{[12] =  1, [13] =  1, [14] =  1,                                  [1] = -1}, 1},
    AffineExpression:new{{[12] = -1,                       [23] =  1, [24] =  1,                    }, 0},
    AffineExpression:new{{           [13] = -1,            [23] = -1,            [34] =  1,         }, 0},
    AffineExpression:new{{                      [14] =  1,            [24] =  1, [34] =  1, [2] =  1}, 1},
}
]]

-- Hilbert matrix

--[
local objective = AffineExpression:new{{}, 0}

local constraints = {
}

do
    local N = 9
    for i = 1, N do
        local A = {}
        local b = 0
        for j = N, 1, -1 do
            A[j] = 1/(i+j-1)
            b = b - 1/(i+j-1)
        end
        table.insert(constraints, AffineExpression:new{A, b})
    end
end

--]]

-- TODO: document
local foo_k = {}
local foo_x = {}
local bar = {}

local function quux()
    while true do
        -- Count how often each variable appears in a constraint.
        local constraint_count = {}
        for k, _ in pairs(constraints) do
            local A, _ = table.unpack(constraints[k])
            for x, _ in pairs(A) do
                constraint_count[x] = (constraint_count[x] or 0) + 1
            end
        end

        -- Select the variables that appear in the smallest number of constraints.
        local good_variables = {}
        do
            local lowest_constraint_count = 1/0
            for x, _ in pairs(constraint_count) do
                if constraint_count[x] < lowest_constraint_count then
                    lowest_constraint_count = constraint_count[x]
                    good_variables = {}
                end
                if constraint_count[x] <= lowest_constraint_count then
                    good_variables[x] = true
                end
            end
        end

        -- TODO: what if out of variables?

        local good_constraints = {}
        do
            local lowest_variable_count = 1/0
            for k, _ in pairs(constraints) do
                local A, b = table.unpack(constraints[k])

                local variable_count = 0
                local contains_good_variable = false
                for x, _ in pairs(A) do
                    variable_count = variable_count + 1
                    if good_variables[x] then
                        contains_good_variable = true
                    end
                end
                if contains_good_variable then
                    if variable_count < lowest_variable_count then
                        lowest_variable_count = variable_count
                        good_constraints = {}
                    end
                    if variable_count <= lowest_variable_count then
                        good_constraints[k] = true
                    end
                end
            end
        end

        local pivot_k, pivot_x
        do
            for k, _ in pairs(good_constraints) do
                pivot_k = k
                break
            end
            if pivot_k == nil then
                -- out of constraints
                break
            end
            local A, _ = table.unpack(constraints[pivot_k])
            do
                local pivot_abs_a = 0
                for x, _ in pairs(A) do
                    if good_variables[x] then
                        if math.abs(A[x]) > pivot_abs_a then
                            pivot_abs_a = math.abs(A[x])
                            pivot_x = x
                        end
                    end
                end
            end
            if pivot_x == nil then
                -- unreachable
                print("fuck!")
            end
        end

        table.insert(foo_k, pivot_k)
        table.insert(foo_x, pivot_x)

        local pivot_eq = constraints[pivot_k]
        constraints[pivot_k] = nil

        local pivot_A, pivot_b = table.unpack(pivot_eq)
        local scale = -1 / pivot_A[pivot_x]
        for x, a in pairs(pivot_A) do
            pivot_A[x] = a * scale
        end
        pivot_A[pivot_x] = nil
        pivot_b = pivot_b * scale
        local pivot_expression = AffineExpression:new{pivot_A, pivot_b}
        bar[pivot_x] = pivot_expression

        for k, _ in pairs(constraints) do
            constraints[k] = constraints[k]:replace(pivot_x, pivot_expression)
        end
        objective = objective:replace(pivot_x, pivot_expression)
    end

    -- backwards substitution
    for i = #foo_x, 1, -1 do
        local x = foo_x[i]
        for j = i-1, 1, -1 do
            local y = foo_x[j]
            bar[y] = bar[y]:replace(x, bar[x])
        end
    end
end

quux()

for x, y in pairs(bar) do
    print("#", x, y)
end
print("!", objective)