local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('brp-pawn:sellitem', function(item, price, itemAmount, payMethod)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    -- Convert input to number
    local amount = tonumber(itemAmount)
    if not item or not amount or amount <= 0 then 
        TriggerClientEvent('QBCore:Notify', src, 'Invalid amount entered.', 'error', 4500)
        return 
    end

    -- Get total count of item across all stacks
    local totalItemCount = 0
    for _, v in pairs(Player.PlayerData.items) do
        if v.name == item then
            totalItemCount = totalItemCount + v.amount
        end
    end

    -- Debugging: Show actual inventory count
    --print(("[brp-pawn] Player %s tried to sell %s x%s"):format(src, item, amount))
    --print(("[brp-pawn] Player has %s x%s in inventory (total count)"):format(item, totalItemCount))

    -- Check if player has enough
    if totalItemCount < amount then
        TriggerClientEvent('QBCore:Notify', src, 'You don\'t have enough '..QBCore.Shared.Items[item].label..'.', 'error', 4500)
        return
    end

    -- Remove items across all stacks
    local remainingToRemove = amount
    for slot, v in pairs(Player.PlayerData.items) do
        if v.name == item and remainingToRemove > 0 then
            local toRemove = math.min(v.amount, remainingToRemove)
            Player.Functions.RemoveItem(item, toRemove, slot)
            remainingToRemove = remainingToRemove - toRemove
        end
    end

    -- Process payment
    local pay = amount * price
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], "remove", amount)
    Player.Functions.AddMoney(payMethod, pay, 'Items Sold')
    TriggerClientEvent('QBCore:Notify', src, 'You sold '..amount..'x '..QBCore.Shared.Items[item].label..' for $'..pay..'.', 'success', 4500)
end)
