local QBCore = exports['qb-core']:GetCoreObject()

local ActiveRentals = {}

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
    lib.callback.register('stw-paystation:purchase', function(source, price, deposit)
        if ActiveRentals[source] then
            return { success = false, reason = 'active_rental' }
        end
        local total = (tonumber(price) or 0) + (tonumber(deposit) or ((Config and Config.DepositDefault) or 0))
        local res = chargePlayer(source, total)
        if res and res.success then
            res.deposit = tonumber(deposit) or ((Config and Config.DepositDefault) or 0)
            res.total = total
        end
        return res
    end)
else
    RegisterNetEvent('stw-paystation:purchase', function(price, deposit)
        local src = source
        local result
        if ActiveRentals[src] then
            result = { success = false, reason = 'active_rental' }
        else
            local total = (tonumber(price) or 0) + (tonumber(deposit) or ((Config and Config.DepositDefault) or 0))
            result = chargePlayer(src, total)
            if result and result.success then
                result.deposit = tonumber(deposit) or ((Config and Config.DepositDefault) or 0)
                result.total = total
            end
        end
        TriggerClientEvent('stw-paystation:purchase:result', src, result)
    end)
end

RegisterNetEvent('stw-paystation:giveRentalPapers', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local charinfo = Player.PlayerData and Player.PlayerData.charinfo or {}
    local renter = (charinfo.firstname and charinfo.lastname) and (charinfo.firstname .. ' ' .. charinfo.lastname) or (Player.PlayerData and Player.PlayerData.name) or 'Unknown'
    local info = { vehicle = data and data.name or 'Unknown', renter = renter }
    if data and data.plate and not data.isBike then info.plate = data.plate end
    local rid = ('RP-%s-%d-%d'):format(tostring(src), math.random(10000,99999), os.time())
    info.rentalId = rid
    Player.Functions.AddItem('rentalpapers', 1, false, info)
    local deposit = (data and data.deposit) or (Config and Config.DepositDefault) or 75
    ActiveRentals[src] = { plate = data and data.plate or nil, vehicle = data and data.name or nil, rentalId = rid, deposit = deposit }
end)

RegisterNetEvent('stw-paystation:setActiveRental', function(data)
    local src = source
    ActiveRentals[src] = { plate = data and data.plate or nil, vehicle = data and data.name or nil }
end)

RegisterNetEvent('stw-paystation:clearActiveRental', function()
    local src = source
    ActiveRentals[src] = nil
end)

if lib and lib.callback then
    lib.callback.register('stw-paystation:getActiveRental', function(source)
        return ActiveRentals[source]
    end)
    lib.callback.register('stw-paystation:returnActiveRental', function(source)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return { success = false, reason = 'player_not_found' } end
        local active = ActiveRentals[source]
        if not active or not active.rentalId then
            return { success = false, reason = 'no_active' }
        end
        local items = (Player.PlayerData and Player.PlayerData.items) or {}
        local slot = nil
        for k, v in pairs(items) do
            if v and v.name == 'rentalpapers' and v.info and v.info.rentalId == active.rentalId then
                slot = v.slot or k
                break
            end
        end
        if slot then
            Player.Functions.RemoveItem('rentalpapers', 1, slot)
            local deposit = (active and active.deposit) or ((Config and Config.DepositDefault) or 0)
            if deposit > 0 then
                Player.Functions.AddMoney('cash', deposit, 'stw-paystation-deposit-refund')
            end
            ActiveRentals[source] = nil
            return { success = true, method = 'papers', refund = deposit }
        end
        ActiveRentals[source] = nil
        return { success = true, method = 'forfeit' }
    end)
end
