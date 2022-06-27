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

------------------------------

local AffineExpression = require "affine_expression"
local Simplex = require "simplex"

local INF = 1/0

local _1 = AffineExpression._1

local MILP = {}

function MILP:new(o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function MILP:start()
    self._best_integer_objective = INF
    self._best_integer_variables = nil
end

function MILP:step()
    local top = self.stack[#self.stack]
    if top == nil then
        return self._best_integer_objective, self._best_integer_variables
    end
    local obj, ans = top:step()
    if obj == nil then
        return nil, nil
    end

    table.remove(self.stack)
    if obj >= self._best_integer_objective then
        return nil, nil
    end
    local branch_variable = nil
    local max_separation = 0
    for x, _ in pairs(self.integers) do
        local v = ans[x] or 0
        local lower_bound = math.floor(v)
        local upper_bound = math.ceil(v)
        local separation = math.min(v - lower_bound, upper_bound - v)
        if separation > max_separation then
            max_separation = separation
            branch_variable = x
        end
    end

    if branch_variable == nil then
        self._best_integer_objective = obj
        self._best_integer_variables = ans
        return nil, nil
    else
        local x = branch_variable
        local v = ans[x] or 0
        local lower_bound = math.floor(v)
        local upper_bound = math.ceil(v)

        local lower_branch = top:copy()
        lower_branch:add_constraint(AffineExpression:new{[_1] = -lower_bound, [x] = 1, [{}] = 1})
        lower_branch:start()

        local upper_branch = top:copy()
        upper_branch:add_constraint(AffineExpression:new{[_1] = -upper_bound, [x] = 1, [{}] = -1})
        upper_branch:start()

        table.insert(self.stack, lower_branch)
        table.insert(self.stack, upper_branch)
        return nil, nil
    end
end

local milp = MILP:new()
milp.stack = {}
milp.integers = {[1] = true, [2] = true, [3] = true}
local branch = Simplex:new()
branch:add_constraint(AffineExpression:new{[_1] =   5, [1] =  1, [2] =  -3,           [{}] = -1})
branch:add_constraint(AffineExpression:new{[_1] =   4, [1] = -3, [2] =  -3,           [{}] = -1})
branch:add_constraint(AffineExpression:new{[_1] =   6,           [2] =  -3, [3] = -2, [{}] = -1})
branch:add_constraint(AffineExpression:new{[_1] =  -4, [1] =  3,            [3] =  5, [{}] = -1})
branch:set_objective(AffineExpression:new{[1] =  3, [2] = -11, [3] = -2})
branch:start()
table.insert(milp.stack, branch)

milp:start()
while true do
    local obj, ans = milp:step()
    if obj ~= nil then
        print(obj, dump(ans))
        break
    end
end
