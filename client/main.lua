local spawnedProps = {}
local spawnedBlips = {}
local duiObj = nil
local txdName = "StwPaystationDUI"
local txnName = "ScreenTexture"
local currentVehicleList = nil 
local isInteracting = false
local cam = nil
local selectedIndex = 0
local currentListLength = 0
local currentSpawnLoc = nil
local spawnVehicleAt
local isSpawnAreaClear
local getDepositForModel



local function showConfirmAlert(displayName, price, model)
    if not lib or not lib.alertDialog then
        return
    end
    local alert = lib.alertDialog({
        header = 'WARNING!!',
        content = ('Are you sure you want to pay $%s to rent a %s?'):format(tostring(price), tostring(displayName)),
        centered = true,
        cancel = true,
        size = 'sm',
        labels = { confirm = 'Confirm', cancel = 'Cancel' }
    })
    if alert == 'confirm' then
        if not currentSpawnLoc then
            lib.alertDialog({ header = 'Warning', content = 'No spawn location available.', centered = true, size = 'xs' })
            return
        end
        if not isSpawnAreaClear(currentSpawnLoc) then
            lib.alertDialog({ header = 'Warning', content = 'Spawn location is blocked.', centered = true, size = 'xs' })
            return
        end
        local dep = getDepositForModel(model or displayName)
        local res = lib.callback.await('stw-paystation:purchase', false, price, dep)
        if res and res.success then
            local m = model or string.lower(displayName)
            if currentSpawnLoc then
                spawnVehicleAt(m, currentSpawnLoc)
            end
            if res.deposit and res.deposit > 0 then
                lib.alertDialog({ header = 'Info', content = ('Deposit held: $%d'):format(res.deposit), centered = true, size = 'xs' })
            end
        else
            local msg = 'Insufficient funds.'
            if res and res.reason == 'active_rental' then
                msg = 'You already have an active rental. Return it first.'
            end
            lib.alertDialog({ header = 'Warning', content = msg, centered = true, size = 'xs' })
        end
    end
end

local function loadModel(model)
    local hash = type(model) == "number" and model or GetHashKey(model)
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    if not HasModelLoaded(hash) then
        return nil
    end
    return hash
end

local function createInteractionCamera(prop)
    local propCoords = GetEntityCoords(prop)
    local heading = GetEntityHeading(prop)
    local rad = math.rad(heading)
    
    local forwardX = -math.sin(rad)
    local forwardY = math.cos(rad)
    local sideX = math.cos(rad)
    local sideY = math.sin(rad)
    
    local dist = (Config.Cam and Config.Cam.distance) or 1.2
    local camX = propCoords.x + (forwardX * -dist)
    local camY = propCoords.y + (forwardY * -dist)
    local camZ = propCoords.z + 1.4
    
    cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(cam, camX, camY, camZ)
    PointCamAtCoord(cam, propCoords.x + (forwardX * -0.3), propCoords.y + (forwardY * -0.3), propCoords.z + 1.28)
    SetCamFov(cam, 35.0)
    RenderScriptCams(true, true, 1000, true, true)
end

local function hasInteract()
    return exports and exports.interact and (type(exports.interact.AddLocalEntityInteraction) == 'function')
end

getDepositForModel = function(model)
    local default = (Config.DepositDefault or 75)
    local list = currentVehicleList and Config.VehicleLists[currentVehicleList] or nil
    if list then
        for i=1,#list do
            local v = list[i]
            if v and (v.model == model or v.name == model) then
                if v.deposit ~= nil then return v.deposit end
                break
            end
        end
    end
    return default
end

local function calcInteractionOffset(entity)
    local model = GetEntityModel(entity)
    if not model then return vec3(0.0, 0.0, 0.0) end
    local minDim, maxDim = GetModelDimensions(model)
    local cx = (minDim.x + maxDim.x) * 0.5
    local cy = (minDim.y + maxDim.y) * 0.5
    local cz = (minDim.z + maxDim.z) * 0.5
    return vec3(cx, cy, cz)
end

local function registerPropInteraction(propData)
    if not hasInteract() then return end
    local id = 'stw-paystation-' .. tostring(propData.entity)
    propData.interactionId = id
    exports.interact:AddLocalEntityInteraction({
        entity = propData.entity,
        name = 'Paystation',
        id = id,
        distance = Config.Interactsettings.interactionDistance or 3.0,
        interactDst = 1.0,
        ignoreLos = false,
        offset = calcInteractionOffset(propData.entity),
        options = {
            {
                label = 'Use machine',
                action = function(entity, coords, args)
                    if isInteracting then return end
                    isInteracting = true
                    createInteractionCamera(propData.entity)
                    updateDUIData(propData.vehicleList, true)
                    currentSpawnLoc = propData.spawnLoc
                    SetNuiFocus(true, false)
                    SetNuiFocusKeepInput(false)
                end,
            },
            {
                label = 'Return vehicle',
                action = function(entity, coords, args)
                    local data = lib.callback.await('stw-paystation:getActiveRental', false)
                    if not data or not data.plate then return end
                    local res = lib.callback.await('stw-paystation:returnActiveRental', false)
                    if not res or not res.success then
                        local msg = 'Missing rental papers.'
                        if res and res.reason == 'no_active' then msg = 'No active rental.' end
                        if res and res.reason == 'deposit_insufficient' and res.deposit then
                            msg = ('Need $%d deposit to return without papers.'):format(res.deposit)
                        end
                        lib.alertDialog({ header = 'Warning', content = msg, centered = true, size = 'xs' })
                        return
                    end
                    if res and res.method == 'papers' and res.refund then
                        lib.alertDialog({ header = 'Info', content = ('Deposit refunded: $%d'):format(res.refund), centered = true, size = 'xs' })
                    elseif res and res.method == 'forfeit' then
                        lib.alertDialog({ header = 'Info', content = 'Deposit forfeited.', centered = true, size = 'xs' })
                    end
                    local vehicles = GetGamePool('CVehicle')
                    local playerCoords = GetEntityCoords(PlayerPedId())
                    local target = nil
                    for i=1,#vehicles do
                        local v = vehicles[i]
                        if DoesEntityExist(v) then
                            local p = GetVehicleNumberPlateText(v)
                            if p == data.plate then
                                local vc = GetEntityCoords(v)
                                local d = #(playerCoords - vc)
                                if d < 30.0 then
                                    target = v
                                    break
                                end
                            end
                        end
                    end
                    if target then
                        DeleteEntity(target)
                    end
                end,
            },
        }
    })
end

local function endInteraction()
    isInteracting = false
    RenderScriptCams(false, true, 1000, true, true)
    if cam then
        DestroyCam(cam, false)
        cam = nil
    end
    if duiObj then
        SendDuiMessage(duiObj, json.encode({ type = "hideUI" }))
    end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end

local function cleanup()
    endInteraction()
    if duiObj then
        DestroyDui(duiObj)
        duiObj = nil
    end
    currentVehicleList = nil
    for i = #spawnedProps, 1, -1 do
        local propData = spawnedProps[i]
        if propData.interactionId and exports and exports.interact then
            if type(exports.interact.RemoveInteraction) == 'function' then
                exports.interact.RemoveInteraction(propData.interactionId)
            elseif type(exports.interact.RemoveLocalEntityInteraction) == 'function' then
                exports.interact.RemoveLocalEntityInteraction(propData.interactionId)
            end
        end
        if DoesEntityExist(propData.entity) then DeleteObject(propData.entity) end
        table.remove(spawnedProps, i)
    end
    for i = #spawnedBlips, 1, -1 do
        local blip = spawnedBlips[i]
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        table.remove(spawnedBlips, i)
    end
end

RegisterNUICallback('duiReady', function(data, cb)
    if currentVehicleList then
        local vehicles = Config.VehicleLists[currentVehicleList] or {}
        SendDuiMessage(duiObj, json.encode({
            type = "setupUI",
            vehicles = vehicles
        }))
        currentListLength = #vehicles
        selectedIndex = 0
        SendDuiMessage(duiObj, json.encode({ type = "highlight", index = selectedIndex }))
    end
    cb('ok')
end)

local function giveVehicleKey(veh)
    if not Config or not Config.givekeyevennt then return end
    local mode = Config.givekeyevennt.mode or 'client'
    local event = Config.givekeyevennt.event
    if not event or event == '' then return end
    local arg = GetVehicleNumberPlateText(veh)
    if mode == 'server' then
        TriggerServerEvent(event, arg)
    else
        TriggerEvent(event, arg)
    end
end

isSpawnAreaClear = function(loc)
    local x, y, z = loc.x, loc.y, loc.z
    if IsAnyVehicleNearPoint(x, y, z, 3.0) then
        return false
    end
    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    local dist = #(pcoords - vector3(x, y, z))
    if dist < 2.5 then
        return false
    end
    return true
end

spawnVehicleAt = function(model, loc)
    local hash = loadModel(model)
    if not hash then return end
    local veh = CreateVehicle(hash, loc.x, loc.y, loc.z, loc.w or 0.0, true, false)
    SetVehicleOnGroundProperly(veh)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleColours(veh, 0, 0)
    giveVehicleKey(veh)
    local display = GetDisplayNameFromVehicleModel(hash)
    local label = GetLabelText(display)
    if not label or label == 'NULL' then label = type(model) == 'string' and model or tostring(model) end
    local plate = GetVehicleNumberPlateText(veh)
    local class = GetVehicleClass(veh)
    local isBike = (class == 13)
    local deposit = getDepositForModel(model)
    TriggerServerEvent('stw-paystation:giveRentalPapers', { name = label, plate = plate, isBike = isBike, deposit = deposit })
end

RegisterNUICallback('selectVehicle', function(data, cb)
    local idx = data and data.index or -1
    local name = data and data.name or "unknown"
    local price = data and data.price or 0
    local model = data and data.model or nil
    endInteraction()
    showConfirmAlert(name, price, model)
    cb('ok')
end)

updateDUIData = function(vehicleListName, force)
    if duiObj then
        if force or currentVehicleList ~= vehicleListName then
            currentVehicleList = vehicleListName
            local vehicles = Config.VehicleLists[vehicleListName] or {}
            SendDuiMessage(duiObj, json.encode({ type = "setupUI", vehicles = vehicles }))
            currentListLength = #vehicles
            selectedIndex = 0
            SendDuiMessage(duiObj, json.encode({ type = "highlight", index = selectedIndex }))
        end
    end
end

local function createScreenDUI()
    if not duiObj then
        local url = "nui://Stw-paystation/ui/index.html"
        duiObj = CreateDui(url, 512, 512)
        local handle = GetDuiHandle(duiObj)
        local txd = CreateRuntimeTxd(txdName)
        CreateRuntimeTextureFromDuiHandle(txd, txnName, handle)
        
    end
end

CreateThread(function()
    while true do
        local sleep = 1000
        if #spawnedProps > 0 then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local nearestProp = nil
            local nearestDist = 999.0
            local nearestList = nil
            local isNearAny = false

            for _, propData in ipairs(spawnedProps) do
                local prop = propData.entity
                local propCoords = GetEntityCoords(prop)
                local dist = #(playerCoords - propCoords)
                
                if dist < Config.Interactsettings.interactionDistance and not isInteracting then
                    isNearAny = true
                    nearestProp = prop
                    nearestList = propData.vehicleList
                    sleep = 0
                    if not duiObj then
                        createScreenDUI()
                    end
                    if not hasInteract() then
                        SetTextComponentFormat("STRING")
                        AddTextComponentString("Press ~INPUT_CONTEXT~ to use machine")
                        DisplayHelpTextFromStringLabel(0, 0, 1, -1)
                        if IsControlJustReleased(0, 38) then
                            isInteracting = true
                            createInteractionCamera(prop)
                            updateDUIData(propData.vehicleList, true)
                            currentSpawnLoc = propData.spawnLoc
                            SetNuiFocus(true, false)
                            SetNuiFocusKeepInput(false)
                        end
                    end
                end
                if dist < Config.Interactsettings.drawDistance and duiObj then
                    sleep = 0
                    local heading = GetEntityHeading(prop)
                    local rad = math.rad(heading)
                    local forwardX = -math.sin(rad)
                    local forwardY = math.cos(rad)
                    local sideX = math.cos(rad)
                    local sideY = math.sin(rad)
                    local leftOffset = 0.034 
                    local centerX = propCoords.x + (forwardX * -0.30) - (sideX * leftOffset)
                    local centerY = propCoords.y + (forwardY * -0.318) - (sideY * leftOffset)
                    local centerZ = propCoords.z + 1.28 
                    local w = 0.135 
                    local h = 0.11  
                    local p1 = vector3(centerX - (sideX * w), centerY - (sideY * w), centerZ + h)
                    local p2 = vector3(centerX + (sideX * w), centerY + (sideY * w), centerZ + h)
                    local p3 = vector3(centerX + (sideX * w), centerY + (sideY * w), centerZ - h)
                    local p4 = vector3(centerX - (sideX * w), centerY - (sideY * w), centerZ - h)
                    DrawSpritePoly(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, p3.x, p3.y, p3.z, 255, 255, 255, 255, txdName, txnName, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0)
                    DrawSpritePoly(p3.x, p3.y, p3.z, p4.x, p4.y, p4.z, p1.x, p1.y, p1.z, 255, 255, 255, 255, txdName, txnName, 1.0, 1.0, 1.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0)
                    DrawSpritePoly(p3.x, p3.y, p3.z, p2.x, p2.y, p2.z, p1.x, p1.y, p1.z, 255, 255, 255, 255, txdName, txnName, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0)
                    DrawSpritePoly(p1.x, p1.y, p1.z, p4.x, p4.y, p4.z, p3.x, p3.y, p3.z, 255, 255, 255, 255, txdName, txnName, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0)
                    if isInteracting and (IsControlJustReleased(0, 177) or IsControlJustReleased(0, 202)) then
                        endInteraction()
                    end
                    if isInteracting and currentListLength > 0 then
                        DisableControlAction(0, 30, true)
                        DisableControlAction(0, 31, true)
                        DisableControlAction(0, 32, true)
                        DisableControlAction(0, 33, true)
                        DisableControlAction(0, 34, true)
                        DisableControlAction(0, 35, true)
                        DisableControlAction(0, 21, true)
                        DisableControlAction(0, 22, true)
                        DisableControlAction(0, 25, true)
                        DisableControlAction(0, 37, true)
                        DisableControlAction(0, 172, true)
                        DisableControlAction(0, 173, true)
                        DisableControlAction(0, 24, true)
                        DisableControlAction(0, 140, true)
                        DisableControlAction(0, 141, true)
                        DisableControlAction(0, 142, true)
                        DisableControlAction(0, 143, true)
                        DisableControlAction(0, 157, true)
                        DisableControlAction(0, 158, true)
                        DisableControlAction(0, 159, true)
                        DisableControlAction(0, 160, true)
                        DisableControlAction(0, 161, true)
                        DisableControlAction(0, 162, true)
                        DisableControlAction(0, 163, true)
                        DisableControlAction(0, 164, true)

                        local upPressed = IsDisabledControlJustReleased(0, 172) or IsDisabledControlJustReleased(0, 32)
                        local downPressed = IsDisabledControlJustReleased(0, 173) or IsDisabledControlJustReleased(0, 33)
                        local enterPressed = IsControlJustReleased(0, 201) or IsControlJustReleased(0, 18)
                        local clickPressed = IsDisabledControlJustReleased(0, 24)
                        local digitIndex = nil
                        if IsDisabledControlJustReleased(0, 157) then
                            digitIndex = 0
                        elseif IsDisabledControlJustReleased(0, 158) then
                            digitIndex = 1
                        elseif IsDisabledControlJustReleased(0, 159) then
                            digitIndex = 2
                        elseif IsDisabledControlJustReleased(0, 160) then
                            digitIndex = 3
                        elseif IsDisabledControlJustReleased(0, 161) then
                            digitIndex = 4
                        elseif IsDisabledControlJustReleased(0, 162) then
                            digitIndex = 5
                        elseif IsDisabledControlJustReleased(0, 163) then
                            digitIndex = 6
                        elseif IsDisabledControlJustReleased(0, 164) then
                            digitIndex = 7
                        end

                        if upPressed then
                            selectedIndex = (selectedIndex - 1 + currentListLength) % currentListLength
                            SendDuiMessage(duiObj, json.encode({ type = "highlight", index = selectedIndex }))
                        elseif downPressed then
                            selectedIndex = (selectedIndex + 1) % currentListLength
                            SendDuiMessage(duiObj, json.encode({ type = "highlight", index = selectedIndex }))
                        elseif digitIndex ~= nil then
                            local list = Config.VehicleLists[currentVehicleList] or {}
                            local chosen = list[(digitIndex % currentListLength) + 1]
                            if chosen then
                                endInteraction()
                                showConfirmAlert(chosen.name, chosen.price or 0, chosen.model)
                            end
                        elseif enterPressed or clickPressed then
                            local list = Config.VehicleLists[currentVehicleList] or {}
                            local chosen = list[selectedIndex + 1]
                            if chosen then
                                endInteraction()
                                showConfirmAlert(chosen.name, chosen.price or 0, chosen.model)
                            end
                        end
                    end
                end
                if dist < Config.Interactsettings.removeDistance then
                    isNearAny = true
                end
            end
            if not isNearAny and not isInteracting and duiObj then
                DestroyDui(duiObj)
                duiObj = nil
                currentVehicleList = nil
            end
        end
        Wait(sleep)
    end
end)

local function spawnPaystations()
    cleanup()
    Wait(200)
    for _, data in ipairs(Config.Paystations) do
        local modelHash = loadModel(data.model)
        if modelHash then
            local prop = CreateObject(modelHash, data.coords.x, data.coords.y, data.coords.z, false, false, false)
            if DoesEntityExist(prop) then
                SetEntityHeading(prop, data.heading)
                SetEntityRotation(prop, data.rotation.x, data.rotation.y, data.rotation.z, 2, true)
                FreezeEntityPosition(prop, true)
                SetEntityInvincible(prop, true)
                local pd = { entity = prop, vehicleList = data.vehicleList, spawnLoc = data.spawnLoc }
                registerPropInteraction(pd)
                table.insert(spawnedProps, pd)
            end
            if data.blip and data.blip.enabled then
                local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
                SetBlipSprite(blip, data.blip.sprite)
                SetBlipDisplay(blip, 4)
                SetBlipScale(blip, data.blip.scale)
                SetBlipColour(blip, data.blip.color)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(data.blip.name)
                EndTextCommandSetBlipName(blip)
                table.insert(spawnedBlips, blip)
            end
        end
    end
end

CreateThread(function()
    Wait(1000)
    spawnPaystations()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then cleanup() end
end)
