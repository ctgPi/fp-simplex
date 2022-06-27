local AffineExpression = require "affine_expression"
local Xoshiro128plus = require "xoshiro128plus"

--------------------------------------

-- This implements the _parametric self-dual simplex method_ for solving a
-- linear program; see Robert J. Vanderbei's book "Linear Programming:
-- Foundations and Extensions" for details.

local INF = 1/0

local _1 = AffineExpression._1
local _m = AffineExpression._m

local Simplex = {}

function Simplex:new(o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Simplex:copy()
    local copy = Simplex:new()
    for x, _ in pairs(self) do
        copy[x] = self[x]:copy()
    end
    return copy
end

function Simplex:add_constraint(constraint)
    for x, _ in pairs(self) do
        if x ~= _1 and x ~= _m then
            constraint = constraint:replace(x, self[x])
        end
    end

    local best_equation_count = INF
    local best_variable = nil
    for y, _ in pairs(constraint) do
        if y ~= _1 and y ~= _m then
            local equation_count = 0
            for x, _ in pairs(self) do
                if x ~= _1 and x ~= _m then
                    if self[x][y] ~= nil then
                        equation_count = equation_count + 1
                    end
                end
            end

            if equation_count < best_equation_count then
                best_equation_count = equation_count
                best_variable = y
            end
        end
    end

    if best_variable == nil then
        if constraint[_1] == 0 then
            return true
        else
            return false
        end
    else
        self[best_variable] = constraint:isolate(best_variable)
        return true
    end
end

-- TODO: these functions look like they share some commonality. How to
--       refactor/rename/document them?

function Simplex:search_rows_max(mu, y)
    local lower_bound = -INF
    local lower_bound_culprit = nil

    for x, _ in pairs(self) do
        if x ~= _1 and x ~= _m then
            if (self[x][y] or 0) > 0 then
                local critical_mu = -((self[x][_1] or 0) + mu * (self[x][_m] or 0)) / self[x][y]
                if critical_mu > lower_bound then
                    lower_bound = critical_mu
                    lower_bound_culprit = x
                end
            end
        end
    end

    return lower_bound_culprit, lower_bound
end

function Simplex:search_cols_max(mu, x)
    local lower_bound = -INF
    local lower_bound_culprit = nil

    for y, _ in pairs(self[_1]) do
        if y ~= _1 and y ~= _m then
            if (self[x][y] or 0) > 0 then
                local critical_mu = -(self[_1][y] or 0) / self[x][y]
                if critical_mu > lower_bound then
                    lower_bound = critical_mu
                    lower_bound_culprit = y
                end
            end
        end
    end

    return lower_bound_culprit, lower_bound
end

function Simplex:search_rows_min(mu, y)
    local ub = INF
    local ui = nil
    for x, _ in pairs(self) do
        if x ~= _1 and x ~= _m then
            if (self[x][y] or 0) < 0 then
                local xx = -((self[x][_1] or 0) + mu * (self[x][_m] or 0)) / self[x][y]
                if xx < ub then
                    ub = xx
                    ui = x
                end
            end
        end
    end

    return ui, ub
end

function Simplex:search_cols_min(mu, x)
    local ub = INF
    local ui = nil
    for y, _ in pairs(self[_1]) do
        if y ~= _1 and y ~= _m then
            if (self[x][y] or 0) > 0 then
                local xx = ((self[_1][y] or 0) + mu * (self[_m][y] or 0)) / self[x][y]
                if xx < ub then
                    ub = xx
                    ui = y
                end
            end
        end
    end

    return ui, ub
end

function Simplex:set_objective(objective)
    if objective ~= nil then
        for x, _ in pairs(self) do
            if x ~= _1 and x ~= _m then
                objective = objective:replace(x, self[x])
            end
        end
        self[_1] = objective
    end
end

-- TODO: give this a better name?
function Simplex:start()
    local rng = Xoshiro128plus:new()

    -- Tweak the coefficients for basic/non-basic variables with a positive,
    -- log-normal coefficient times `µ`; the problem will always be primal-
    -- and dual-feasible for sufficiently large `µ`.
    self[_m] = AffineExpression:new{}

    for x, _ in pairs(self[_1]) do
        if x ~= _1 and x ~= _m then
            self[_m][x] = math.exp(rng:next_normal_f())
        end
    end
    for x, _ in pairs(self) do
        if x ~= _1 and x ~= _m then
            self[x][_m] = math.exp(rng:next_normal_f())
        end
    end
end

function Simplex:step()
    -- Find the `x` and `y` variables that prevent `µ` from being lowered; we
    -- store their indexes as well as the corresponding `µ ≥ bound_*`. 
    local pivot_x, bound_x = self:search_rows_max(0, _m)
    local pivot_y, bound_y = self:search_cols_max(0, _m)

    if bound_x <= 0 and bound_y <= 0 then
        -- All variables meet primal and dual constraints with `µ = 0`: we're done!
        local answer = {}
        for x, _ in pairs(self) do
            if x ~= _1 and x ~= _m then
                answer[x] = self[x][_1]
            end
        end
        return self[_1][_1] or 0, answer
    end

    -- `µ = 0` would make the problem unfeasible; find the variable with the
    -- tighest bound and search for the replacement pivot that still keeps
    -- the problem feasible for the corresponding `bound_*` value.
    if bound_x > bound_y then
        pivot_y, _ = self:search_cols_min(bound_x, pivot_x)
        if pivot_y == nil then
            -- TODO: problem ill-defined: is it unfeasible or unbounded?
            return INF, nil
        end
    else
        pivot_x, _ = self:search_rows_min(bound_y, pivot_y)
        if pivot_x == nil then
            -- TODO: problem ill-defined: is it unfeasible or unbounded?
            return INF, nil
        end
    end

    -- Remove `pivot_x` from the objective function expression.
    local pivot_equation = self[pivot_x]
    self[pivot_x] = nil

    -- Isolate `pivot_y` in the (former) expression for `pivot_x`.
    -- (`pivot_x = pivot_equation` is equivalent to `pivot_equation - pivot_x = 0`.)
    pivot_equation[pivot_x] = -1
    pivot_equation = pivot_equation:isolate(pivot_y)

    for x, _ in pairs(self) do
        self[x] = self[x]:replace(pivot_y, pivot_equation)
    end

    self[pivot_y] = pivot_equation

    return nil, nil
end

function Simplex:solve()
    self:start()
    while true do
        local obj, ans = self:step()
        if ans ~= nil then
            return obj, ans
        end
    end
end

return Simplex
