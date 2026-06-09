--[[ ============================================================
     QB-PRISONGUARD — CLIENT / MAIN
     Handles: duty toggle, blips, markers, uniform, qb-target,
              armory menu, control room menu (F7), salary timer.
     ============================================================ ]]

local QBCore       = exports['qb-core']:GetCoreObject()
local PlayerData   = {}
local OnDuty       = false
local SavedClothes = {}
local Blips        = {}
local DutyZone     = nil

-- ─────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────
local function Notify(msg, nType)
    nType = nType or 'primary'
    QBCore.Functions.Notify(msg, nType, 4500)
end

local function IsGuard()
    PlayerData = QBCore.Functions.GetPlayerData()
    return PlayerData.job and PlayerData.job.name == Config.JobName
end

local function GetGrade()
    PlayerData = QBCore.Functions.GetPlayerData()
    return tonumber(PlayerData.job and PlayerData.job.grade.level) or 0
end

-- ─────────────────────────────────────────────
--  BLIPS
-- ─────────────────────────────────────────────
local function CreateBlips()
    -- Prison main blip
    local mainBlip = AddBlipForCoord(Config.PrisonBlip.coords.x, Config.PrisonBlip.coords.y, Config.PrisonBlip.coords.z)
    SetBlipSprite(mainBlip, Config.PrisonBlip.sprite)
    SetBlipColour(mainBlip, Config.PrisonBlip.color)
    SetBlipScale(mainBlip, Config.PrisonBlip.scale)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.PrisonBlip.label)
    EndTextCommandSetBlipName(mainBlip)
    table.insert(Blips, mainBlip)
end

local function CreateGuardBlips()
    for _, post in ipairs(Config.GuardPosts) do
        local blip = AddBlipForCoord(post.coords.x, post.coords.y, post.coords.z)
        SetBlipSprite(blip, post.blipSprite)
        SetBlipColour(blip, post.blipColor)
        SetBlipScale(blip, 0.6)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Guard Post: ' .. post.label)
        EndTextCommandSetBlipName(blip)
        table.insert(Blips, blip)
    end
end

local function RemoveGuardBlips()
    for _, blip in ipairs(Blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    Blips = {}
end

-- ─────────────────────────────────────────────
--  UNIFORM
-- ─────────────────────────────────────────────
local function SaveCurrentClothes()
    local ped = PlayerPedId()
    SavedClothes = {}
    for _, comp in ipairs({ 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }) do
        SavedClothes[comp] = {
            drawable = GetPedDrawableVariation(ped, comp),
            texture  = GetPedTextureVariation(ped, comp),
        }
    end
end

local function ApplyUniform()
    local ped   = PlayerPedId()
    local model = GetEntityModel(ped)
    local isFemale = (model == GetHashKey('mp_f_freemode_01'))
    local clothes = isFemale and Config.Uniform.female or Config.Uniform.male
    local props   = isFemale and Config.UniformProps.female or Config.UniformProps.male

    for _, comp in ipairs(clothes) do
        SetPedComponentVariation(ped, comp.component, comp.drawable, comp.texture, comp.palette)
    end
    for _, prop in ipairs(props) do
        SetPedPropIndex(ped, prop.prop, prop.drawable, prop.texture, true)
    end
end

local function RevertClothes()
    local ped = PlayerPedId()
    for comp, data in pairs(SavedClothes) do
        SetPedComponentVariation(ped, comp, data.drawable, data.texture, 0)
    end
    -- Remove hat
    ClearPedProp(ped, 0)
end

-- ─────────────────────────────────────────────
--  DUTY TOGGLE
-- ─────────────────────────────────────────────
local function GoOnDuty()
    if OnDuty then return end
    SaveCurrentClothes()
    ApplyUniform()
    OnDuty = true
    TriggerServerEvent('qb-prison_guard:server:setDuty', true)
    CreateGuardBlips()
    Notify(Config.Notify.OnDuty, 'success')
    TriggerEvent('qb-prison_guard:client:startSalaryTimer')
end

local function GoOffDuty()
    if not OnDuty then return end
    RevertClothes()
    OnDuty = false
    TriggerServerEvent('qb-prison_guard:server:setDuty', false)
    RemoveGuardBlips()
    CreateBlips() -- keep the main prison blip
    Notify(Config.Notify.OffDuty, 'error')
    TriggerEvent('qb-prison_guard:client:stopSalaryTimer')
end

local function ToggleDuty()
    if not IsGuard() then
        Notify('You are not a Prison Guard.', 'error')
        return
    end
    if OnDuty then
        GoOffDuty()
    else
        GoOnDuty()
    end
end

-- ─────────────────────────────────────────────
--  DUTY MARKER LOOP
-- ─────────────────────────────────────────────
Citizen.CreateThread(function()
    local loc = Config.DutyLocation
    local m   = Config.DutyMarker

    while true do
        local sleep   = 1000
        local ped     = PlayerPedId()
        local pos     = GetEntityCoords(ped)
        local dist    = #(pos - vector3(loc.x, loc.y, loc.z))

        if dist < 5.0 then
            sleep = 0
            DrawMarker(
                m.type,
                loc.x, loc.y, loc.z - 0.95,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                m.size.x, m.size.y, m.size.z,
                m.color.r, m.color.g, m.color.b, m.color.a,
                false, true, 2, false, nil, nil, false
            )
            if dist < 1.5 then
                QBCore.Functions.DrawText3D(loc.x, loc.y, loc.z + 0.3,
                    '[E] ' .. (OnDuty and '~r~Go Off Duty' or '~g~Go On Duty'))
                if IsControlJustReleased(0, 38) then -- E
                    ToggleDuty()
                end
            end
        end
        Citizen.Wait(sleep)
    end
end)

-- ─────────────────────────────────────────────
--  ARMORY MENU (qb-target interaction)
-- ─────────────────────────────────────────────
local function OpenArmoryMenu()
    if not OnDuty then
        Notify(Config.Notify.NotOnDuty, 'error')
        return
    end
    if GetGrade() < Config.MinGradeForArmory then
        Notify(Config.Notify.NoPermission, 'error')
        return
    end

    local menuItems = {
        {
            header  = '🔒 Guard Armory',
            isMenuHeader = true,
        },
    }

    for _, weapon in ipairs(Config.ArmoryWeapons) do
        local cost  = weapon.price > 0 and (' — $' .. weapon.price) or ' — FREE'
        table.insert(menuItems, {
            header  = weapon.label .. cost,
            txt     = 'Take ' .. weapon.label,
            params  = {
                event   = 'qb-prison_guard:client:giveWeapon',
                args    = { weapon = weapon.weapon, price = weapon.price },
            },
        })
    end

    table.insert(menuItems, {
        header  = '❌ Close',
        txt     = '',
        params  = { event = 'qb-menu:client:closeMenu', args = {} },
    })

    exports['qb-menu']:openMenu(menuItems)
end

AddEventHandler('qb-prison_guard:client:giveWeapon', function(data)
    TriggerServerEvent('qb-prison_guard:server:giveWeapon', data.weapon, data.price)
end)

-- ─────────────────────────────────────────────
--  CONTROL ROOM MENU (opened via F7 or qb-target)
-- ─────────────────────────────────────────────
local function OpenControlRoomMenu()
    if not OnDuty then
        Notify(Config.Notify.NotOnDuty, 'error')
        return
    end

    local gradeLevel = GetGrade()

    local menuItems = {
        {
            header       = '🖥️  Prison Control Room',
            isMenuHeader = true,
        },
        {
            header = '📡  Request Backup',
            txt    = 'Broadcast a backup alert to all on-duty guards',
            params = { event = 'qb-prison_guard:client:requestBackup', args = {} },
        },
        {
            header = '📋  Prisoner Roster',
            txt    = 'View all active prisoners on the server',
            params = { event = 'qb-prison_guard:client:viewPrisoners', args = {} },
        },
        {
            header = '📷  CCTV Monitor',
            txt    = 'Access the prison CCTV camera system',
            params = { event = 'qb-prison_guard:client:openCCTV', args = {} },
        },
    }

    -- Sergeant+ only actions
    if gradeLevel >= Config.MinGradeForLockdown then
        table.insert(menuItems, {
            header = '🔒  Initiate Lockdown',
            txt    = 'Lock down all cell blocks and trigger alert',
            params = { event = 'qb-prison_guard:client:triggerLockdown', args = {} },
        })
    end

    table.insert(menuItems, {
        header = '❌  Close',
        txt    = '',
        params = { event = 'qb-menu:client:closeMenu', args = {} },
    })

    exports['qb-menu']:openMenu(menuItems)
end

-- ─────────────────────────────────────────────
--  CCTV STUB (extend as needed)
-- ─────────────────────────────────────────────
AddEventHandler('qb-prison_guard:client:openCCTV', function()
    Notify('~y~CCTV system is currently offline for maintenance.', 'primary')
end)

-- ─────────────────────────────────────────────
--  PRISONER ROSTER
-- ─────────────────────────────────────────────
AddEventHandler('qb-prison_guard:client:viewPrisoners', function()
    TriggerServerEvent('qb-prison_guard:server:requestPrisonerList')
end)

RegisterNetEvent('qb-prison_guard:client:receivePrisonerList', function(prisoners)
    if #prisoners == 0 then
        Notify('No active prisoners on the server.', 'primary')
        return
    end

    local menuItems = {
        { header = '📋 Active Prisoner Roster', isMenuHeader = true },
    }

    for _, p in ipairs(prisoners) do
        table.insert(menuItems, {
            header = '🔴 ' .. p.name .. ' (ID: ' .. p.id .. ')',
            txt    = 'Time remaining: ' .. p.sentence .. ' min | Reason: ' .. p.reason,
            params = { event = 'qb-menu:client:closeMenu', args = {} },
        })
    end

    table.insert(menuItems, {
        header = '← Back',
        txt    = '',
        params = { event = 'qb-menu:client:closeMenu', args = {} },
    })

    exports['qb-menu']:openMenu(menuItems)
end)

-- ─────────────────────────────────────────────
--  LOCKDOWN
-- ─────────────────────────────────────────────
AddEventHandler('qb-prison_guard:client:triggerLockdown', function()
    exports['qb-menu']:closeMenu()
    TriggerServerEvent('qb-prison_guard:server:initiateLockdown')
end)

RegisterNetEvent('qb-prison_guard:client:lockdownAlert', function(active)
    if active then
        Notify(Config.Notify.LockdownStart, 'error')
        -- Screen flash effect
        Citizen.CreateThread(function()
            for i = 1, 6 do
                SetFlash(0, 0, 100, 500, 100)
                Citizen.Wait(1000)
            end
        end)
    else
        Notify(Config.Notify.LockdownEnd, 'success')
    end
end)

-- ─────────────────────────────────────────────
--  QB-TARGET ZONES
-- ─────────────────────────────────────────────
Citizen.CreateThread(function()
    -- Armory locker target
    exports['qb-target']:AddCircleZone(
        'prison_guard_armory',
        Config.ArmoryLocation,
        1.5,
        { name = 'prison_guard_armory', debugPoly = false },
        {
            options = {
                {
                    type    = 'client',
                    event   = 'qb-prison_guard:client:openArmory',
                    icon    = 'fas fa-gun',
                    label   = 'Access Armory',
                    canInteract = function()
                        return IsGuard() and OnDuty
                    end,
                },
            },
            distance = 2.0,
        }
    )

    -- Control room desk target
    exports['qb-target']:AddCircleZone(
        'prison_guard_controlroom',
        Config.ControlRoomLocation,
        1.5,
        { name = 'prison_guard_controlroom', debugPoly = false },
        {
            options = {
                {
                    type    = 'client',
                    event   = 'qb-prison_guard:client:openControlRoom',
                    icon    = 'fas fa-desktop',
                    label   = 'Control Room Terminal',
                    canInteract = function()
                        return IsGuard() and OnDuty
                    end,
                },
            },
            distance = 2.0,
        }
    )
end)

AddEventHandler('qb-prison_guard:client:openArmory',      OpenArmoryMenu)
AddEventHandler('qb-prison_guard:client:openControlRoom', OpenControlRoomMenu)

-- ─────────────────────────────────────────────
--  SALARY TIMER
-- ─────────────────────────────────────────────
local SalaryTimer = nil

AddEventHandler('qb-prison_guard:client:startSalaryTimer', function()
    if SalaryTimer then return end
    SalaryTimer = Citizen.CreateThread(function()
        while OnDuty do
            Citizen.Wait(Config.SalaryInterval * 60 * 1000)
            if OnDuty then
                TriggerServerEvent('qb-prison_guard:server:paySalary')
            end
        end
        SalaryTimer = nil
    end)
end)

AddEventHandler('qb-prison_guard:client:stopSalaryTimer', function()
    SalaryTimer = nil
end)

-- ─────────────────────────────────────────────
--  PLAYER DATA SYNC
-- ─────────────────────────────────────────────
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    CreateBlips()
end)

AddEventHandler('QBCore:Client:OnJobUpdate', function(job)
    PlayerData.job = job
    if job.name ~= Config.JobName and OnDuty then
        GoOffDuty()
    end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        PlayerData = QBCore.Functions.GetPlayerData()
        CreateBlips()
    end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if OnDuty then GoOffDuty() end
        for _, blip in ipairs(Blips) do
            if DoesBlipExist(blip) then RemoveBlip(blip) end
        end
    end
end)
