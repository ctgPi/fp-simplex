#!/usr/bin/env lua5.2

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function trim(s)
    return s:match("^%s*(.*)"):match("(.-)%s*$")
end

function split(s, d)
    local function next(state, _)
        local p = state.p
        if p == nil then
            return nil
        end
        q = s:find(d, p, true)
        if q == nil then
            local fragment = s:sub(p)
            state.p = nil
            return fragment
        else
            local fragment = s:sub(p, q - 1)
            state.p = q + d:len()
            return fragment
        end
    end
    return next, {p = 0}, nil
end

function split_exactly(s, d, n)
    local fragments = {}
    for fragment in split(s, d) do
        if #fragments == n then
            error("too many fragments: expected " .. tostring(n))
        end
        table.insert(fragments, fragment)
    end
    if #fragments ~= n then
        error("too few fragments: expected " .. tostring(n) .. ", found " .. tostring(#fragments))
    end
    return unpack(fragments)
end

function combinations(s, k)
    local function next(state, _)
        while state.p > 0 do
            if state.p > k then
                state.p = state.p-1
                state.r = true

                local c = {}
                for j = 1, k do
                    c[j] = s[state.i[j]]
                end
                return c
            elseif state.r then
                state.i[state.p] = state.i[state.p]+1
                state.r = false
            elseif state.i[state.p] > #s then
                state.p = state.p-1
                state.r = true
            else
                state.i[state.p+1] = state.i[state.p]+1
                state.p = state.p+1
                state.r = false
            end
        end
    end
    return next, {i = {1}, p = 1, r = false}, nil
end

function contains_value(t, u)
    for _, v in pairs(t) do
        if u == v then
            return true
        end
    end
end

local recipe_data = io.read("*a")
local recipes = {}
local items = {}
for declaration in split(recipe_data, ";") do
    local recipe, raw_ingredients = split_exactly(declaration, ":=", 2)
    recipe = trim(recipe)
    
    local raw_consumes, raw_produces = split_exactly(raw_ingredients, "->", 2)
    raw_consumes = trim(raw_consumes)
    raw_produces = trim(raw_produces)

    local consumes = {}
    local crafting_time = nil
    for raw_item in split(raw_consumes, "+") do
        raw_item = trim(raw_item)

        count, item = raw_item:match("^([0-9.]+)%s*(.*)$")
        count = tonumber(count)

        if item == "s" then
            crafting_time = count
        else
            consumes[item] = count
            items[item] = true
        end
    end

    if crafting_time == nil then
        error("Missing crafting time")
    end

    local produces = {}
    for raw_item in split(raw_produces, "+") do
        raw_item = trim(raw_item)

        count, item = raw_item:match("^([0-9.]+)%s*(.*)$")
        count = tonumber(count)

        produces[item] = count
        items[item] = true
    end

    -- FIXME: catalysts, etc.
    -- FIXME: adjust for speed/productivity
    -- FIXME: adjust for crafting speed
    local ingredients = {}
    for item, count in pairs(produces) do
        ingredients[item] = count / crafting_time
    end
    for item, count in pairs(consumes) do
        ingredients[item] = -count / crafting_time
    end

    recipes[recipe] = ingredients
end

local is_strictly_input = {}
local is_strictly_output = {}
for item, _ in pairs(items) do
    is_strictly_input[item] = true
    is_strictly_output[item] = true
    for recipe, ingredients in pairs(recipes) do
        if ingredients[item] ~= nil then
            if ingredients[item] > 0 then
                is_strictly_input[item] = nil
            end
            if ingredients[item] < 0 then
                is_strictly_output[item] = nil
            end
        end
    end
end

local item_rate_constraints = {}
for item, _ in pairs(items) do
    if not is_strictly_input[item] and not is_strictly_output[item] then
        item_rate_constraints[item] = 0
    end
end
-- item_rate_constraints["[item=processed-iron]"] = 2  -- FIXME
item_rate_constraints["[item=plastic-bar]"] = 2  -- FIXME

local num_recipes = 0
for _, _ in pairs(recipes) do
    num_recipes = num_recipes + 1
end

local num_item_rate_constraints = 0
local constrained_items = {}
for item, _ in pairs(item_rate_constraints) do
    num_item_rate_constraints = num_item_rate_constraints + 1
    table.insert(constrained_items, item)
end

print("# " .. tostring(num_recipes) .. " recipes")
print("# " .. tostring(num_item_rate_constraints) .. " item rate constraints")

if num_item_rate_constraints > num_recipes then
    local excess_rank = num_item_rate_constraints - num_recipes
    print("# linear system is overconstrained! (excess rank = " .. excess_rank .. ")")
    print("#")
    print("# solutions:")
    for relaxed_items in combinations(constrained_items, excess_rank) do
        do
            local model_file_name = os.tmpname()
            do
                local model_file = io.open(model_file_name, "w+")
                model_file:write("par:\n")
                model_file:write("    RECIPE := set(")
                do
                    local first_recipe = true
                    for recipe, ingredients in pairs(recipes) do
                        if not first_recipe then
                            model_file:write(", ")
                        end
                        model_file:write("\"")
                        model_file:write(recipe)  -- FIXME: escaping
                        model_file:write("\"")
                        first_recipe = false
                    end
                end
                model_file:write(");\n")
                model_file:write("    ITEM := set(")
                do
                    local first_item = true
                    for item, _ in pairs(items) do
                        if not first_item then
                            model_file:write(", ")
                        end
                        model_file:write("\"")
                        model_file:write(item)  -- FIXME: escaping
                        model_file:write("\"")
                        first_item = false
                    end
                end
                model_file:write(");\n")
                model_file:write("\n")
                model_file:write("    machine_cost[RECIPE] := (")
                do
                    local first_recipe = true
                    for recipe, ingredients in pairs(recipes) do
                        if not first_recipe then
                            model_file:write(", ")
                        end
                        model_file:write("1")
                        first_recipe = false
                    end
                end
                model_file:write(");\n")
                model_file:write("    item_production_cost[ITEM] := (")
                do
                    local first_item = true
                    for item, _ in pairs(items) do
                        if not first_item then
                            model_file:write(", ")
                        end
                        model_file:write("1")
                        first_item = false
                    end
                end
                model_file:write(");\n")
                model_file:write("    item_consumption_cost[ITEM] := (")
                do
                    local first_item = true
                    for item, _ in pairs(items) do
                        if not first_item then
                            model_file:write(", ")
                        end
                        model_file:write("1")
                        first_item = false
                    end
                end
                model_file:write(");\n")
                model_file:write("\n")
                model_file:write("    recipe_ingredients[RECIPE, ITEM] := (")
                do
                    local first_recipe = true
                    for recipe, ingredients in pairs(recipes) do
                        if not first_recipe then
                            model_file:write(",")
                        end
                        model_file:write("\n        ")
                        model_file:write("(")
                        do
                            local first_item = true
                            for item, _ in pairs(items) do
                                if not first_item then
                                    model_file:write(", ")
                                end
                                model_file:write(tostring(recipes[recipe][item] or 0))
                                first_item = false
                            end
                        end
                        model_file:write(")")
                        first_recipe = false
                    end
                end
                model_file:write(");\n")
                model_file:write("\n")
                model_file:write("var:\n")
                model_file:write("    recipe_rate[RECIPE]: real;\n")
                model_file:write("    machine_count[RECIPE]: integer[0..];\n")
                model_file:write("    item_rate[ITEM]: real[..];\n")
                model_file:write("    item_production_rate[ITEM]: real;\n")
                model_file:write("    item_consumption_rate[ITEM]: real;\n")
                model_file:write("    min_recipe_rate: real;\n") -- [1]
                model_file:write("\n")
                model_file:write("obj:\n")
                --model_file:write("    + item_production_cost^T * item_production_rate\n")
                --model_file:write("    + item_consumption_cost^T * item_consumption_rate\n")
                --model_file:write("    + machine_cost^T * machine_count -> min;\n")
                model_file:write("    min_recipe_rate -> max;\n"); -- [1]
                model_file:write("\n")
                model_file:write("con:\n")
                model_file:write("    item_rate = recipe_ingredients^T * recipe_rate;\n");
                model_file:write("    item_rate = item_production_rate - item_consumption_rate;\n");
                model_file:write("    machine_count >= recipe_rate;\n")
                model_file:write("    recipe_rate >= min_recipe_rate;\n")
                for item, rate in pairs(item_rate_constraints) do
                    if not contains_value(relaxed_items, item) then
                        model_file:write("    item_rate[\"")
                        model_file:write(item)  -- FIXME: escaping
                        model_file:write("\"] = ")
                        model_file:write(tostring(rate))
                        model_file:write(";\n")
                    end
                end
                model_file:write("\n")
                model_file:close()
            end

            local function solve_model(model_file_name)
                local solution_data
                do
                    local solution_file_name = os.tmpname()
                    os.execute("./cmpl " .. model_file_name .. " -solutionCsv " .. solution_file_name .. " >/dev/null")  -- FIXME: escaping
                    do
                        local solution_file = io.open(solution_file_name, "r")
                        solution_data = solution_file:read("*a")
                        solution_file:close()
                    end
                    os.remove(solution_file_name)
                end
                
                local variable_index = nil
                local goal = nil
                local variables = {}
                for line in split(solution_data, "\n") do
                    if variable_index ~= nil then
                        variable_index = variable_index + 1
                    end
                    if line == "No solution has been found" then
                        goal = nil
                    end
                    if line:find("Objective value ;", 0, true) == 1 then
                        local _, value, _ = split_exactly(line, ";", 3)
                        goal = tonumber(value)
                    end
                    if line == "Variables;" then
                        variable_index = -1
                    end
                    if line == "Constraints " then
                        variable_index = nil
                    end
                    if variable_index ~= nil and variable_index >= 1 then
                        local variable, _, value, _, _, _ = split_exactly(line, ";", 6)
                        variables[variable] = value
                    end
                end
                return goal, variables
            end

            goal, variables = solve_model(model_file_name)
            os.remove(model_file_name)

            for k, v in pairs(variables) do
                io.write(k)
                io.write(" = ")
                io.write(tostring(v))
                io.write("\n")
            end
--            io.write("\n")
--            io.write("#     goal = ")
--            io.write(tostring(goal))
--            io.write("\n")

            if goal ~= nil and goal > 0 then
                for _, item in pairs(relaxed_items) do
                    print("#     " .. item)
                end
                print("#")
            end
        end
    end
end
