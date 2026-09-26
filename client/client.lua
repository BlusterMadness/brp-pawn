local QBCore = exports['qb-core']:GetCoreObject()

-- Keep this limit the same as MAX_SELL_AMOUNT in server.lua.
local MAX_SELL_AMOUNT = 10000
local buyerPed

local function ShowMenu()
    -- Config prices may use math.random(), so request the actual server prices.
    local ok, prices = pcall(lib.callback.await, 'bluster-pawn:getPrices', false)
    if not ok or type(prices) ~= 'table' then
        QBCore.Functions.Notify('Pawn shop prices are unavailable. Try again shortly.', 'error', 4500)
        return
    end

    local options = {}

    for itemName, price in pairs(prices) do
        local itemInfo = QBCore.Shared.Items[itemName]

        -- A missing shared item should not crash the whole pawn-shop menu.
        if itemInfo and QBCore.Functions.HasItem(itemName) then
            options[#options + 1] = {
                title = itemInfo.label,
                description = ('Price: $%s each'):format(price),
                event = 'bluster-pawn:giveinput',
                args = { item = itemName }
            }
        end
    end

    if #options == 0 then
        QBCore.Functions.Notify('You have no items to sell here.', 'error', 4500)
        return
    end

    lib.registerContext({
        id = 'bluster-pawn:item-menu',
        title = 'Sellable Items',
        options = options
    })
    lib.showContext('bluster-pawn:item-menu')
end

CreateThread(function()
    local model = Config.PedProps.hash
    local coords = Config.PedProps.location

    QBCore.Functions.LoadModel(model)
    buyerPed = CreatePed(0, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, false)
    if not buyerPed or buyerPed == 0 then
        print('[bluster-pawn] Could not create the pawn-shop ped.')
        return
    end

    TaskStartScenarioInPlace(buyerPed, 'WORLD_HUMAN_AA_SMOKE', 0, true)
    FreezeEntityPosition(buyerPed, true)
    SetEntityInvincible(buyerPed, true)
    SetBlockingOfNonTemporaryEvents(buyerPed, true)

    exports['qb-target']:AddTargetEntity(buyerPed, {
        options = {{
            icon = 'fas fa-circle',
            label = 'Sell Items',
            action = function()
                local playerCoords = GetEntityCoords(PlayerPedId())
                local shopCoords = vector3(coords.x, coords.y, coords.z)
                if #(playerCoords - shopCoords) <= 5.0 then
                    ShowMenu()
                end
            end
        }},
        distance = 2.0
    })
end)

RegisterNetEvent('bluster-pawn:giveinput', function(data)
    if type(data) ~= 'table' or type(data.item) ~= 'string' then return end

    local itemName = data.item
    local itemInfo = QBCore.Shared.Items[itemName]
    if not Config.Items[itemName] or not itemInfo then return end

    local input = lib.inputDialog('Sell: ' .. itemInfo.label, {
        {
            type = 'number',
            label = 'Sell Amount',
            description = ('1–%d items per sale'):format(MAX_SELL_AMOUNT),
            default = 1,
            min = 1,
            max = MAX_SELL_AMOUNT,
            precision = 0,
            required = true
        },
        {
            type = 'select',
            label = 'Payment Method',
            options = {
                { value = 'cash', label = 'Cash', icon = 'fas fa-wallet' },
                { value = 'bank', label = 'Bank', icon = 'fas fa-landmark' }
            },
            required = true
        }
    })

    if not input then return end

    local amount = tonumber(input[1])
    local paymentMethod = input[2]
    if not amount or amount < 1 or amount > MAX_SELL_AMOUNT or amount % 1 ~= 0 then
        QBCore.Functions.Notify('Enter a valid whole-number amount.', 'error', 4500)
        return
    end
    if paymentMethod ~= 'cash' and paymentMethod ~= 'bank' then
        QBCore.Functions.Notify('Choose cash or bank.', 'error', 4500)
        return
    end

    -- The server looks up the price independently; the client never sends it.
    TriggerServerEvent('bluster-pawn:sellitem', itemName, amount, paymentMethod)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and buyerPed and DoesEntityExist(buyerPed) then
        DeleteEntity(buyerPed)
    end
end)
