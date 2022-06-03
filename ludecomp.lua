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

local AffineExpression = require "affine_expression"


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
local objective = AffineExpression:new{
    [12] = 1,
    [13] = 8,
    [14] = 9,
    [23] = 2,
    [24] = 7,
    [34] = 3,
}

local _1 = AffineExpression._1

-- Variable constraints: all expressions must evaluate to zero.
local constraints = {
    AffineExpression:new{[_1] = 1, [12] =  1, [13] =  1, [14] =  1,                                  [1] = -1},
    AffineExpression:new{          [12] = -1,                       [23] =  1, [24] =  1,                    },
    AffineExpression:new{                     [13] = -1,            [23] = -1,            [34] =  1,         },
    AffineExpression:new{[_1] = 1,                       [14] =  1,            [24] =  1, [34] =  1, [2] =  1},
}
--]]

-- Hilbert matrix

--[
local objective = AffineExpression:new{}

local constraints = {
}

do
    local _1 = AffineExpression._1

    local N = 9
    for i = 1, N do
        local A = AffineExpression:new{}
        for j = N, 1, -1 do
            A[j] = 1/(i+j-1)
            A[_1] = (A[_1] or 0) - 1/(i+j-1)
        end
        table.insert(constraints, A)
    end
end

--]]

local variable_definition = {}
local INF = 1/0

local function find_pivot()
    -- Count how often each variable appears in a constraint.
    local constraint_count = {}
    for k, _ in pairs(constraints) do
        for x, _ in pairs(constraints[k]) do
            if x ~= AffineExpression._1 then
                constraint_count[x] = (constraint_count[x] or 0) + 1
            end
        end
    end

    -- Select the variables that appear in the smallest number of constraints.
    local good_variables = {}
    do
        local lowest_constraint_count = INF
        for x, _ in pairs(constraint_count) do
            if x ~= AffineExpression._1 then
                if constraint_count[x] < lowest_constraint_count then
                    lowest_constraint_count = constraint_count[x]
                    good_variables = {}
                end
                if constraint_count[x] <= lowest_constraint_count then
                    good_variables[x] = true
                end
            end
        end
    end

    -- TODO: what if out of variables?

    local good_constraints = {}
    do
        local lowest_variable_count = INF
        for k, _ in pairs(constraints) do
            local A = constraints[k]

            local variable_count = 0
            local contains_good_variable = false
            for x, _ in pairs(A) do
                if x ~= AffineExpression._1 then
                    variable_count = variable_count + 1
                    if good_variables[x] then
                        contains_good_variable = true
                    end
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
            return nil, nil
        end
        do
            local pivot_abs_a = 0
            for x, _ in pairs(constraints[pivot_k]) do
                if good_variables[x] then
                    if math.abs(constraints[pivot_k][x]) > pivot_abs_a then
                        pivot_abs_a = math.abs(constraints[pivot_k][x])
                        pivot_x = x
                    end
                end
            end
        end
    end

    return pivot_k, pivot_x
end

local function quux()
    while true do
        local k, x = find_pivot()
        if k == nil then break end

        variable_definition[x] = constraints[k]:isolate(x)
        constraints[k] = nil

        for k, _ in pairs(constraints) do
            constraints[k] = constraints[k]:replace(x, variable_definition[x])
        end
        for y, _ in pairs(variable_definition) do
            variable_definition[y] = variable_definition[y]:replace(x, variable_definition[x])
        end
    end
end

quux()

for x, y in pairs(variable_definition) do
    print("#", x, y)
end
print("!", objective)
for x, _ in pairs(variable_definition) do
    objective = objective:replace(x, variable_definition[x])
end
print("!", objective)
