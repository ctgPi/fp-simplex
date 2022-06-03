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

local _1 = AffineExpression._1

local branch_0 = Simplex:new()
branch_0:add_constraint(AffineExpression:new{[_1] =   5, [1] =  1, [2] =  -3,           [{}] = -1})
branch_0:add_constraint(AffineExpression:new{[_1] =   4, [1] = -3, [2] =  -3,           [{}] = -1})
branch_0:add_constraint(AffineExpression:new{[_1] =   6,           [2] =  -3, [3] = -2, [{}] = -1})
branch_0:add_constraint(AffineExpression:new{[_1] =  -4, [1] =  3,            [3] =  5, [{}] = -1})
local obj, ans = branch_0:solve(AffineExpression:new{[1] =  3, [2] = -11, [3] = -2})
print(obj)  -- -16.666…
print(dump(ans))  -- {[2] = 1.333…, [3] = 1, …}

local branch_1 = branch_0:copy()
branch_1:add_constraint(AffineExpression:new{[_1] = -2, [2] = 1, [{}] = -1})  -- `2` ≥ 2
local obj, ans = branch_1:solve()
print(obj)  -- nil

local branch_2 = branch_0:copy()
branch_2:add_constraint(AffineExpression:new{[_1] = -1, [2] = 1, [{}] = 1})  -- `2` ≤ 1
local obj, ans = branch_2:solve()
print(obj)  -- -14
print(dump(ans))  -- {[2] = 1, [3] = 1.5, …}

local branch_3 = branch_2:copy()
branch_3:add_constraint(AffineExpression:new{[_1] = -1, [3] = 1, [{}] = 1})  -- `3` ≤ 1
local obj, ans = branch_3:solve()
print(obj)  -- -13
print(dump(ans))  -- {[2] = 1, [3] = 1, …}

local branch_4 = branch_2:copy()
branch_4:add_constraint(AffineExpression:new{[_1] = -2, [3] = 1, [{}] = -1})  -- `3` ≥ 2
local obj, ans = branch_4:solve()
print(obj)  -- -11.333…
print(dump(ans))  -- {[2] = 0.666…, [3] = 2, …}

local branch_5 = branch_4:copy()
branch_5:add_constraint(AffineExpression:new{[_1] = -1, [2] = 1, [{}] = -1})  -- `2` ≥ 1
local obj, ans = branch_5:solve()
print(obj)  -- nil

local branch_6 = branch_4:copy()
branch_6:add_constraint(AffineExpression:new{[_1] = 0, [2] = 1, [{}] = 1})  -- `2` ≤ 0
local obj, ans = branch_6:solve()
print(obj)  -- -6
print(dump(ans))  -- {[3] = 3, …}
