function dump(o)
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

Xoshiro128plus = {}

function Xoshiro128plus:new()
    local o = {math.random(), math.random(), math.random(), math.random()}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Xoshiro128plus:next_u32()
    local result = bit32.bor(0, self[1] + self[4])

    local t = bit32.lshift(self[2], 9)
    self[3] = bit32.bxor(self[3], self[1])
    self[4] = bit32.bxor(self[4], self[2])
    self[2] = bit32.bxor(self[2], self[3])
    self[1] = bit32.bxor(self[1], self[4])
    self[3] = bit32.bxor(self[3], t)
    self[4] = bit32.lrotate(self[4], 11)

    return result
end

-- X ~ U([0, 1])
function Xoshiro128plus:next_uniform_f()
    return 1.1641532182693481e-10 * (2 * self:next_u32() + 1)
end

-- X ~ N(0, 1)
-- Y ~ N(0, 1)
function Xoshiro128plus:next_normal_f()
    local x = self:next_uniform_f()
    local y = self:next_uniform_f()
    return math.sqrt(-2 * math.log(x)) * math.cos(2 * math.pi * y), math.sqrt(-2 * math.log(x)) * math.sin(2 * math.pi * y)
end

--------------------------------------

local objective = {
    [1] =   3,
    [2] = -11,
    [3] =  -2,
}

local constraints = {
    {{[1] =  1, [2] = -3,           [4] = 1},  5},
    {{[1] = -3, [2] = -3,           [5] = 1},  4},
    {{          [2] = -3, [3] = -2, [6] = 1},  6},
    {{[1] =  3,           [3] =  5, [7] = 1}, -4},
}

-- This implements the _parametric self-dual simplex method_ for solving a
-- linear program; see Robert J. Vanderbei's book "Linear Programming:
-- Foundations and Extensions" for details.

local INF = 1/0

local _a = {}
local _b = {}

Simplex = {}

function Simplex:new()
    o = {
        N = {
            [1] = {[_b] =   3},
            [2] = {[_b] = -11},
            [3] = {[_b] =  -2},
        },
        B = {
            [4] = {[_b] =   5, [1] =  1, [2] = -3,         },
            [5] = {[_b] =   4, [1] = -3, [2] = -3,         },
            [6] = {[_b] =   6,           [2] = -3, [3] = -2},
            [7] = {[_b] =  -4, [1] =  3,           [3] =  5},
        },
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

function Simplex:solve()
    local rng = Xoshiro128plus:new()

    -- FIXME: move this to :new() or something
    for i, _ in pairs(self.B) do
        self.B[i][_a] = math.exp(rng:next_normal_f())
    end
    for i, _ in pairs(self.N) do
        self.N[i][_a] = math.exp(rng:next_normal_f())
    end

    local obj = 0
    while true do
        local lb = 0
        local li = nil
        for i, _ in pairs(self.B) do
            if self.B[i][_a] > 0 then
                local x = -self.B[i][_b] / self.B[i][_a]
                if x > lb then
                    lb = x
                    li = i
                end
            end
        end
        for i, _ in pairs(self.N) do
            if self.N[i][_a] > 0 then
                local x = -self.N[i][_b] / self.N[i][_a]
                if x > lb then
                    lb = x
                    li = i
                end
            end
        end

        if li == nil then
            ans = {}
            for i, _ in pairs(self.B) do
                ans[i] = self.B[i][_b]
            end
            for i, _ in pairs(self.N) do
                ans[i] = 0
            end
            return obj, ans
        end

        local i_b, i_n
        if self.N[li] then
            local ub = INF
            local ui = nil
            for i, _ in pairs(self.B) do
                if (self.B[i][li] or 0) < 0 then
                    local x = -(self.B[i][_b] + lb * self.B[i][_a]) / self.B[i][li]
                    if x < ub then
                        ub = x
                        ui = i
                    end
                end
            end
            if ui == nil then
                -- TODO: problem ill-defined: is it unfeasible or unbounded?
                return nil, {}
            end

            i_b = ui
            i_n = li
        else
            local ub = INF
            local ui = nil
            for i, _ in pairs(self.N) do
                if (self.B[li][i] or 0) > 0 then
                    local x = (self.N[i][_b] + lb * self.N[i][_a]) / self.B[li][i]
                    if x < ub then
                        ub = x
                        ui = i
                    end
                end
            end
            if ui == nil then
                -- TODO: problem ill-defined: is it unfeasible or unbounded?
                return nil, {}
            end

            i_b = li
            i_n = ui   
        end

        do
            local eql = self.B[i_b]
            local equ = self.N[i_n]
            self.B[i_b] = nil
            self.N[i_n] = nil

            local k = -1 / eql[i_n]
            for j, _ in pairs(eql) do
                eql[j] = eql[j] * k
            end
            eql[i_n] = nil
            eql[i_b] = -k

            obj = obj + equ[_b] * eql[_b]
            for i, _ in pairs(self.N) do
                self.N[i][_a] = self.N[i][_a] + equ[_a] * (eql[i] or 0)
                self.N[i][_b] = self.N[i][_b] + equ[_b] * (eql[i] or 0)
            end

            equ[_b] = -equ[_b] * k
            equ[_a] = -equ[_a] * k

            for i, _ in pairs(self.B) do
                if self.B[i][i_n] then
                    local k = self.B[i][i_n]
                    for j, _ in pairs(eql) do
                        self.B[i][j] = (self.B[i][j] or 0) + k * eql[j]
                    end
                    self.B[i][i_n] = nil
                end
            end

            self.B[i_n] = eql
            self.N[i_b] = equ
        end
    end
end

solver = Simplex:new()
obj, ans = solver:solve()
print(obj)
print(dump(ans))