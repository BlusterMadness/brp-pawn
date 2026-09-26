local QBCore = exports['qb-core']:GetCoreObject()

-- This config.lua must load on BOTH the client and the server (shared_scripts).
local MAX_SELL_AMOUNT = 10000 -- Match the limit in client.lua.
local MAX_PAYOUT = 2147483647
local SHOP_DISTANCE = 5.0
local selling = {}

local function notify(src, message, kind)
    TriggerClientEvent('QBCore:Notify', src, message, kind or 'error', 4500)
end

local function isAtPawnShop(src)
    if not Config or not Config.PedProps or not Config.PedProps.location then
        print('[bluster-pawn] ERROR: config.lua must be loaded as a shared script.')
        return false
    end

    local location = Config.PedProps.location
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    local playerCoords = GetEntityCoords(ped)
    local shopCoords = vector3(location.x, location.y, location.z)
    return #(playerCoords - shopCoords) <= SHOP_DISTANCE
end

-- The server is the sole price authority. This keeps randomized config prices
-- in the menu consistent with what players are actually paid.
lib.callback.register('bluster-pawn:getPrices', function(src)
    if not isAtPawnShop(src) then return nil end

    local prices = {}
    for itemName, listing in pairs(Config.Items or {}) do
        local sharedItem = QBCore.Shared.Items[itemName]
        local price = type(listing) == 'table' and tonumber(listing.price) or nil
        if sharedItem and price and price > 0 and price == math.floor(price) and price <= MAX_PAYOUT then
            prices[itemName] = price
        end
    end
    return prices
end)

local function collectItemStacks(items, itemName)
    local stacks = {}
    local total = 0

    for key, entry in pairs(items or {}) do
        if entry and entry.name == itemName then
            local slot = tonumber(entry.slot) or tonumber(key)
            local count = tonumber(entry.amount)
            if slot and count and count > 0 then
                total = total + count
                stacks[#stacks + 1] = {
                    slot = slot,
                    amount = count,
                    info = entry.info
                }
            end
        end
    end

    table.sort(stacks, function(a, b) return a.slot < b.slot end)
    return stacks, total
end

RegisterNetEvent('bluster-pawn:sellitem', function(itemName, itemAmount, paymentMethod)
    local src = source
    if selling[src] then return end
    selling[src] = true

    -- Always clear the lock, even if an external inventory or banking script errors.
    local ok, err = pcall(function()
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end

        if type(itemName) ~= 'string' or
            not Config or type(Config.Items) ~= 'table' or
            type(Config.Items[itemName]) ~= 'table' then
            notify(src, 'That item cannot be sold here.')
            return
        end

        local sharedItem = QBCore.Shared.Items[itemName]
        local price = tonumber(Config.Items[itemName].price)
        if not sharedItem or not price or price <= 0 or price ~= math.floor(price) then
            notify(src, 'This item is not configured correctly.')
            return
        end

        local amount = tonumber(itemAmount)
        if not amount or amount < 1 or amount > MAX_SELL_AMOUNT or amount ~= math.floor(amount) then
            notify(src, 'Enter a valid whole-number amount.')
            return
        end

        if paymentMethod ~= 'cash' and paymentMethod ~= 'bank' then
            notify(src, 'Invalid payment method.')
            return
        end

        if amount * price > MAX_PAYOUT then
            notify(src, 'That sale exceeds the maximum payout.')
            return
        end

        -- Checking on the server prevents selling remotely by triggering the event.
        if not isAtPawnShop(src) then
            notify(src, 'You must be at the pawn shop to sell items.')
            return
        end

        local stacks, total = collectItemStacks(Player.PlayerData.items, itemName)
        if total < amount then
            notify(src, ('You do not have enough %s.'):format(sharedItem.label))
            return
        end

        -- Snapshot slots before removing them, because RemoveItem mutates inventory.
        local removed = {}
        local removedTotal = 0
        for _, stack in ipairs(stacks) do
            if removedTotal >= amount then break end
            local take = math.min(stack.amount, amount - removedTotal)
            local removalOk, didRemove = pcall(Player.Functions.RemoveItem, itemName, take, stack.slot, 'bluster-pawn sale')
            if not removalOk then
                print(('[bluster-pawn] Inventory error for player %s: %s'):format(src, tostring(didRemove)))
            end
            if not removalOk or didRemove ~= true then break end

            removedTotal = removedTotal + take
            removed[#removed + 1] = {
                amount = take,
                slot = stack.slot,
                info = stack.info
            }
        end

        if removedTotal == 0 then
            notify(src, 'Unable to remove those items. Please try again.')
            return
        end

        -- If the inventory changed mid-sale, pay ONLY for the quantity removed.
        local payout = removedTotal * price
        local paymentOk, paid = pcall(Player.Functions.AddMoney, paymentMethod, payout, 'bluster-pawn sale')
        if not paymentOk then
            print(('[bluster-pawn] Payment error for player %s: %s'):format(src, tostring(paid)))
        end
        if not paymentOk or paid ~= true then
            -- Restore removed items if the banking system rejects payment.
            local restored = 0
            for _, stack in ipairs(removed) do
                local refundOk, refundResult = pcall(Player.Functions.AddItem, itemName, stack.amount, stack.slot, stack.info, 'bluster-pawn refund')
                if refundOk and refundResult == true then
                    restored = restored + stack.amount
                else
                    print(('[bluster-pawn] Refund error for player %s, item %s, slot %s: %s'):format(src, itemName, stack.slot, tostring(refundResult)))
                end
            end
            if restored < removedTotal then
                print(('[bluster-pawn] WARNING: Could not refund %s x%s to player %s after payment failure.'):format(itemName, removedTotal - restored, src))
                notify(src, 'Payment failed. Contact staff: some items could not be restored.')
            else
                notify(src, 'Payment failed; your items were returned.')
            end
            return
        end

        TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItem, 'remove', removedTotal)
        if removedTotal < amount then
            notify(src, ('Only %sx %s could be sold for $%s.'):format(removedTotal, sharedItem.label, payout), 'primary')
        else
            notify(src, ('You sold %sx %s for $%s.'):format(removedTotal, sharedItem.label, payout), 'success')
        end
    end)

    selling[src] = nil
    if not ok then
        print(('[bluster-pawn] ERROR processing sale for player %s: %s'):format(src, tostring(err)))
        notify(src, 'The sale could not be completed. Contact staff if items are missing.')
    end
end)

AddEventHandler('playerDropped', function()
    selling[source] = nil
end)
