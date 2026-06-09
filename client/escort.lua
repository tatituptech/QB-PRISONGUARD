--[[ ============================================================
     QB-PRISONGUARD — CLIENT / ESCORT
     Handles: cuffing/uncuffing players, escort (force-follow),
              put in / take out vehicle, cell interaction.
     ============================================================ ]]

local QBCore      = exports['qb-core']:GetCoreObject()
local EscortTarget = nil   -- NetworkID of player being escorted
local IsCuffed    = false  -- is THIS player cuffed (set by server event)

-- ─────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────
local function Notify(msg, nType)
    QBCore.Functions.Notify(msg, nType or 'primary', 4500)
end

local function IsGuard()
    local pd = QBCore.Functions.GetPlayerData()
    return pd.job and pd.job.name == Config.JobName and pd.job.onduty
end

local function GetClosestPlayer()
    local ped     = PlayerPedId()
    local myCoord = GetEntityCoords(ped)
    local closest, closestDist = -1, 3.5

    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local targetPed  = GetPlayerPed(player)
            local targetCoord = GetEntityCoords(targetPed)
            local dist       = #(myCoord - targetCoord)
            if dist < closestDist then
                closestDist = dist
                closest     = player
            end
        end
    end
    return closest
end

-- ─────────────────────────────────────────────
--  CUFF / UNCUFF
-- ─────────────────────────────────────────────
local function CuffPlayer(targetPlayer, soft)
    if not IsGuard() then
        Notify(Config.Notify.NotOnDuty, 'error')
        return
    end

    local targetServerId = GetPlayerServerId(targetPlayer)
    TriggerServerEvent('qb-prison_guard:server:cuffPlayer', targetServerId, soft or false)
end

RegisterNetEvent('qb-prison_guard:client:cuffed', function(isHandcuffed, soft)
    IsCuffed = isHandcuffed
    local ped = PlayerPedId()

    if isHandcuffed then
        -- Apply cuff animation
        RequestAnimDict('mp_arresting')
        while not HasAnimDictLoaded('mp_arresting') do Citizen.Wait(0) end

        if soft then
            -- Zip ties (hands in front)
            TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
        else
            -- Handcuffs (hands behind back)
            TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
        end
        SetPedCanSwitchWeapon(ped, false)
        Notify('You have been ~r~handcuffed~s~.', 'error')
    else
        ClearPedTasks(ped)
        SetPedCanSwitchWeapon(ped, true)
        Notify('You have been ~g~uncuffed~s~.', 'success')
    end
end)

-- ─────────────────────────────────────────────
--  ESCORT (force follow guard)
-- ─────────────────────────────────────────────
local EscortThread = nil

local function StartEscort(targetPlayer)
    if EscortTarget then
        Notify('You are already escorting someone.', 'error')
        return
    end

    local targetPed  = GetPlayerPed(targetPlayer)
    local targetServerId = GetPlayerServerId(targetPlayer)
    EscortTarget = targetPlayer

    TriggerServerEvent('qb-prison_guard:server:startEscort', targetServerId)
    Notify('Now escorting player.', 'success')

    EscortThread = Citizen.CreateThread(function()
        while EscortTarget do
            Citizen.Wait(500)
            if not DoesEntityExist(targetPed) then
                EscortTarget = nil
                break
            end
            local myPos     = GetEntityCoords(PlayerPedId())
            local targetPos = GetEntityCoords(targetPed)
            if #(myPos - targetPos) > 10.0 then
                -- Too far, stop escort
                StopEscort(targetPlayer)
                break
            end
        end
    end)
end

local function StopEscort(targetPlayer)
    if not EscortTarget then return end
    local targetServerId = GetPlayerServerId(targetPlayer or EscortTarget)
    TriggerServerEvent('qb-prison_guard:server:stopEscort', targetServerId)
    EscortTarget = nil
    Notify('Escort ended.', 'primary')
end

RegisterNetEvent('qb-prison_guard:client:beingEscorted', function(isEscorted)
    local ped = PlayerPedId()
    if isEscorted then
        SetPedCanSwitchWeapon(ped, false)
        Notify('~y~You are being escorted by a guard.', 'primary')
    else
        SetPedCanSwitchWeapon(ped, true)
        Notify('Escort has ended.', 'primary')
    end
end)

-- ─────────────────────────────────────────────
--  QB-TARGET: PLAYER INTERACTIONS
--  (appears on other players when on duty)
-- ─────────────────────────────────────────────
exports['qb-target']:AddGlobalPlayer({
    options = {
        {
            type  = 'client',
            event = 'qb-prison_guard:client:action:cuff',
            icon  = 'fas fa-handcuffs',
            label = 'Handcuff',
            canInteract = function(entity)
                return IsGuard()
            end,
        },
        {
            type  = 'client',
            event = 'qb-prison_guard:client:action:uncuff',
            icon  = 'fas fa-unlock',
            label = 'Remove Cuffs',
            canInteract = function(entity)
                return IsGuard()
            end,
        },
        {
            type  = 'client',
            event = 'qb-prison_guard:client:action:escort',
            icon  = 'fas fa-person-walking-arrow-right',
            label = 'Escort Prisoner',
            canInteract = function(entity)
                return IsGuard()
            end,
        },
        {
            type  = 'client',
            event = 'qb-prison_guard:client:action:stopescort',
            icon  = 'fas fa-person-walking-arrow-loop-left',
            label = 'Stop Escort',
            canInteract = function(entity)
                return IsGuard() and EscortTarget ~= nil
            end,
        },
        {
            type  = 'client',
            event = 'qb-prison_guard:client:action:putinveh',
            icon  = 'fas fa-car-side',
            label = 'Put In Vehicle',
            canInteract = function(entity)
                return IsGuard() and IsPedInAnyVehicle(PlayerPedId(), false)
            end,
        },
        {
            type  = 'client',
            event = 'qb-prison_guard:client:action:check',
            icon  = 'fas fa-id-card',
            label = 'Check Prisoner Info',
            canInteract = function(entity)
                return IsGuard()
            end,
        },
    },
    distance = 3.0,
})

-- ─────────────────────────────────────────────
--  TARGET EVENT HANDLERS
-- ─────────────────────────────────────────────
AddEventHandler('qb-prison_guard:client:action:cuff', function(data)
    local target = NetworkGetEntityOwner(data.entity)
    local targPlayer = GetPlayerFromPed(data.entity)
    if targPlayer ~= -1 then
        CuffPlayer(targPlayer, false)
    end
end)

AddEventHandler('qb-prison_guard:client:action:uncuff', function(data)
    local targPlayer = GetPlayerFromPed(data.entity)
    if targPlayer ~= -1 then
        local targetServerId = GetPlayerServerId(targPlayer)
        TriggerServerEvent('qb-prison_guard:server:uncuffPlayer', targetServerId)
    end
end)

AddEventHandler('qb-prison_guard:client:action:escort', function(data)
    local targPlayer = GetPlayerFromPed(data.entity)
    if targPlayer ~= -1 then
        StartEscort(targPlayer)
    end
end)

AddEventHandler('qb-prison_guard:client:action:stopescort', function(data)
    local targPlayer = GetPlayerFromPed(data.entity)
    if targPlayer ~= -1 then
        StopEscort(targPlayer)
    end
end)

AddEventHandler('qb-prison_guard:client:action:putinveh', function(data)
    local targPlayer     = GetPlayerFromPed(data.entity)
    local targetPed      = data.entity
    local guardVeh       = GetVehiclePedIsIn(PlayerPedId(), false)

    if targPlayer == -1 or guardVeh == 0 then return end

    local targetServerId = GetPlayerServerId(targPlayer)
    local netVeh         = NetworkGetNetworkIdFromEntity(guardVeh)
    TriggerServerEvent('qb-prison_guard:server:putInVehicle', targetServerId, netVeh)
    Notify('Prisoner placed in vehicle.', 'success')
end)

AddEventHandler('qb-prison_guard:client:action:check', function(data)
    local targPlayer = GetPlayerFromPed(data.entity)
    if targPlayer == -1 then return end
    local targetServerId = GetPlayerServerId(targPlayer)
    TriggerServerEvent('qb-prison_guard:server:getPrisonerInfo', targetServerId)
end)

-- ─────────────────────────────────────────────
--  RECEIVE PRISONER INFO CARD
-- ─────────────────────────────────────────────
RegisterNetEvent('qb-prison_guard:client:showPrisonerInfo', function(info)
    local items = {
        { header = '🪪 Prisoner Information', isMenuHeader = true },
        { header = 'Name: '     .. info.name,      txt = '' },
        { header = 'Reason: '   .. info.reason,    txt = '' },
        { header = 'Sentence: ' .. info.sentence .. ' min remaining', txt = '' },
        { header = '❌ Close',   txt = '', params = { event = 'qb-menu:client:closeMenu', args = {} } },
    }
    exports['qb-menu']:openMenu(items)
end)

-- ─────────────────────────────────────────────
--  PUT IN VEHICLE (client receive)
-- ─────────────────────────────────────────────
RegisterNetEvent('qb-prison_guard:client:putInVehicle', function(netVeh, seat)
    local veh = NetToVeh(netVeh)
    if DoesEntityExist(veh) then
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, seat or -2)
    end
end)

-- ─────────────────────────────────────────────
--  PREVENT CUFFED MOVEMENT
-- ─────────────────────────────────────────────
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsCuffed then
            DisableControlAction(0, 24,  true) -- Attack
            DisableControlAction(0, 25,  true) -- Aim
            DisableControlAction(0, 47,  true) -- Weapon
            DisableControlAction(0, 58,  true) -- Weapon special
            DisableControlAction(0, 140, true) -- Melee attack
            DisableControlAction(0, 141, true) -- Melee attack alt
            DisableControlAction(0, 263, true) -- Melee
            DisableControlAction(0, 264, true) -- Melee 2
            DisableControlAction(0, 257, true) -- Attack 2
        end
    end
end)
