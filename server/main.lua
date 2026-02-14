local QBCore = exports['qb-core']:GetCoreObject()

local function chargePlayer(source, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then
        return { success = true, account = 'free' }
    end

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return { success = false, reason = 'player_not_found' } end
    if Player.Functions.RemoveMoney('cash', amount, 'stw-paystation') then
        return { success = true, account = 'cash' }
    elseif Player.Functions.RemoveMoney('bank', amount, 'stw-paystation') then
        return { success = true, account = 'bank' }
    else
        return { success = false, reason = 'insufficient_funds' }
    end
end

if lib and lib.callback then
    lib.callback.register('stw-paystation:purchase', function(source, price)
        return chargePlayer(source, price)
    end)
else
    RegisterNetEvent('stw-paystation:purchase', function(price)
        local src = source
        local result = chargePlayer(src, price)
        TriggerClientEvent('stw-paystation:purchase:result', src, result)
    end)
end
