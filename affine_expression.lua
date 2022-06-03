--- Represents an affine expression on arbitrary variables.
-- The table that represents the expression maps variables to their coefficients;
-- keys may be any arbitrary Lua objects.
-- By convention, `AffineExpression._1` represents the constant term, so e.g.
-- `x + 2y - 4` is represented as `{[_1] = -4, [x] = 1, [y] = 2}`

local AffineExpression = {}
AffineExpression._1 = {}
AffineExpression._m = {}

function AffineExpression:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function AffineExpression:copy()
    local copy = AffineExpression:new{}
    for x, _ in pairs(self) do
        copy[x] = self[x]
    end

    return copy
end

-- TODO: set a rounding threshold?
function AffineExpression:simplify()
    for x, _ in pairs(self) do
        if self[x] == 0 then
            self[x] = nil
        end
    end

    return self
end

-- Return a new expression such that `x = new_expression` is equivalent to
-- `self = 0`.
function AffineExpression:isolate(x)
    if self[x] == 0 then
        -- TODO: error handling
    end

    local new_expression = self:copy()
    new_expression[x] = nil
    for y, _ in pairs(new_expression) do
        new_expression[y] = -new_expression[y] / self[x]
    end

    return new_expression
end

-- Return the result of replacing `x = replacement` to this expression.
function AffineExpression:replace(x, replacement)
    local new_expression = self:copy()

    new_expression[x] = nil
    for y, _ in pairs(replacement) do
        new_expression[y] = (new_expression[y] or 0) + replacement[y] * (self[x] or 0)
    end

    return new_expression:simplify()
end

function AffineExpression:__tostring()
    local A = self

    local s = {}
    for x, _ in pairs(A) do
        if x == AffineExpression._1 then
            if A[x] > 0 then
                table.insert(s, " + ")
                table.insert(s, tostring(A[x]))
                table.insert(s, " ")
            elseif A[x] < 0 then
                table.insert(s, " - ")
                table.insert(s, tostring(-A[x]))
                table.insert(s, " ")
            end
        elseif x == AffineExpression._m then
            if A[x] > 0 then
                table.insert(s, " + ")
                if A[x] ~= 1 then
                    table.insert(s, tostring(A[x]))
                    table.insert(s, " ")
                end
                table.insert(s, "µ")
            elseif A[x] < 0 then
                table.insert(s, " - ")
                if -A[x] ~= 1 then
                    table.insert(s, tostring(-A[x]))
                    table.insert(s, " ")
                end
                table.insert(s, "µ")
            end
        else
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
    end
    return table.concat(s)
end

return AffineExpression
