local Xoshiro128plus = {}

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

return Xoshiro128plus
