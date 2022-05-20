local list = {}
for _, recipe in pairs(game.player.force.recipes) do
    if recipe.enabled then
        table.insert(list, "[recipe=")
        table.insert(list, recipe.name)
        table.insert(list, "] := ")
        do
            local first_ingredient = true
            for _, def in ipairs(recipe.ingredients) do
                if not first_ingredient then
                    table.insert(list, " + ")
                end
                table.insert(list, tostring(def.amount * (def.probability or 1.0)))
                table.insert(list, " [")
                table.insert(list, def.type)
                table.insert(list, "=")
                table.insert(list, def.name)
                table.insert(list, "]")
                first_ingredient = false
            end
        end
        table.insert(list, " + ")
        table.insert(list, tostring(recipe.energy))
        table.insert(list, " s -> ")
        do
            local first_product = true
            for _, def in ipairs(recipe.products) do
                if not first_product then
                    table.insert(list, " + ")
                end
                table.insert(list, tostring(def.amount * (def.probability or 1.0)))
                table.insert(list, " [")
                table.insert(list, def.type)
                table.insert(list, "=")
                table.insert(list, def.name)
                table.insert(list, "]")
                first_product = false
            end
        end
        table.insert(list, ";\n")
    end
end
game.write_file("recipes.json", table.concat(list, ""), false)