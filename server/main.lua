--[[ ============================================================
     QB-PRISONGUARD — SERVER / MAIN
     Handles: duty state, salary, backup broadcast, lockdown,
              cuffing, escort, weapon gives, prisoner list.
     ============================================================ ]]

local QBCore = exports['qb-core']:GetCoreObject()

-- ─────────────────────────────────────────────
--  STATE TRACKING
-- ─────────────────────────────────────────────
local OnDutyGuards = {}  -- [serverId] = { name, grade, coords }
local CuffedPlayers = {} -- [serverId] = true
local LockdownActive = false
local LockdownTimer  = nil

-- ─────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────
local function IsGuard(src)
    local Player = QBCore.Functions.GetPlayer(src)
    return Player and Player.PlayerData.job.name == Config.JobName
end

local function GetGrade(src)
    local Player = QBCore.Functions.GetPlayer(src)
    return Player and tonumber(Player.PlayerData.job.grade.level) or 0
end

local function GetName(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return 'Unknown' end
    return Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
end

local function NotifyGuard(src, msg, nType)
    TriggerClientEvent('QBCore:Notify', src, msg, nType or 'primary', 5000)
end

local function BroadcastToGuards(event, data)
    for serverId, _ in pairs(OnDutyGuards) do
        TriggerClientEvent(event, serverId, data)
    end
end

-- ─────────────────────────────────────────────
--  DUTY TOGGLE
-- ─────────────────────────────────────────────
RegisterNetEvent('qb-prison_guard:server:setDuty', function(onDuty)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not IsGuard(src) then return end

    Player.Functions.SetJobDuty(onDuty)

    if onDuty then
        OnDutyGuards[src] = {
            name  = GetName(src),
            grade = GetGrade(src),
        }
        print('[qb-prison_guard] ' .. GetName(src) .. ' (ID:' .. src .. ') went ON DUTY')
    else
        OnDutyGuards[src] = nil
        print('[qb-prison_guard] ' .. GetName(src) .. ' (ID:' .. src .. ') went OFF DUTY')
    end
end)

-- Clean up if player drops
AddEventHandler('playerDropped', function()
    local src = source
    OnDutyGuards[src]  = nil
    CuffedPlayers[src] = nil
end)

-- ─────────────────────────────────────────────
--  SALARY
-- ─────────────────────────────────────────────
RegisterNetEvent('qb-prison_guard:server:paySalary', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not IsGuard(src) then return end
    if not OnDutyGuards[src] then return end

    local payment = Player.PlayerData.job.payment or Config.SalaryBase
    Player.Functions.AddMoney('bank', payment, 'prison-guard-salary')
    NotifyGuard(src, string.format(Config.Notify.Salary, payment), 'success')
    print('[qb-prison_guard] Paid $' .. payment .. ' to ' .. GetName(src))
end)

-- ─────────────────────────────────────────────
--  BACKUP REQUEST
-- ─────────────────────────────────────────────
RegisterNetEvent('qb-prison_guard:server:requestBackup', function(data)
    local src  = source
    if not IsGuard(src) then return end

    local name = GetName(src)
    local payload = {
        requester = name,
        location  = data.location,
        coords    = data.coords,
    }

    -- Broadcast to all other on-duty guards
    for guardId, _ in pairs(OnDutyGuards) do
        if guardId ~= src then
            TriggerClientEvent('qb-prison_guard:client:receiveBackupAlert', guardId, payload)
        end
    end

    -- Also notify in guard chat
    for guardId, _ in pairs(OnDutyGuards) do
        TriggerClientEvent('qb-prison_guard:client:radioMessage', guardId,
            name .. ' is requesting BACKUP at ' .. data.location)
    end

    print('[qb-prison_guard] Backup requested by ' .. name .. ' at ' .. (data.location or 'unknown'))
end)

-- ─────────────────────────────────────────────
--  GUARD RADIO BROADCAST
-- ─────────────────────────────────────────────
RegisterNetEvent('qb-prison_guard:server:guardRadio', function(message)
    local src  = source
    if not IsGuard(src) then return end
    if not OnDutyGuards[src] then
        NotifyGuard(src, Config.Notify.NotOnDuty, 'error')
        return
    end

    local name = GetName(src)
    for guardId, _ in pairs(OnDutyGuards) do
        TriggerClientEvent('qb-prison_guard:client:radioMessage', guardId, name, message)
    end
end)

-- ─────────────────────────────────────────────
--  LOCKDOWN
-- ─────────────────────────────────────────────
RegisterNetEvent('qb-prison_guard:server:initiateLockdown', function()
    local src = source
    if not IsGuard(src) then return end
    if GetGrade(src) < Config.MinGradeForLockdown then
        NotifyGuard(src, Config.Notify.NoPermission, 'error')
        return
    end
    if LockdownActive then
        NotifyGuard(src, 'Lockdown is already active.', 'error')
        return
    end

    LockdownActive = true
    print('[qb-prison_guard] LOCKDOWN initiated by ' .. GetName(src))

    -- Broadcast to all on-duty guards
    BroadcastToGuards('qb-prison_guard:client:lockdownAlert', true)

    -- Auto-lift after Config.LockdownDuration seconds
    if LockdownTimer then return end
    LockdownTimer = Citizen.SetTimeout(Config.LockdownDuration * 1000, function()
        LockdownActive = false
        LockdownTimer  = nil
        BroadcastToGuards('qb-prison_guard:client:lockdownAlert', false)
        print('[qb-prison_guard] Lockdown automatically lifted.')
    end)
end)

-- Manual lift (Warden only)
RegisterNetEvent('qb-prison_guard:server:liftLockdown', function()
    local src = source
    if not IsGuard(src) then return end
    if GetGrade(src) < 4 then  -- Warden only
        NotifyGuard(src, Config.Notify.NoPermission, 'error')
        return
    end

    LockdownActive = false
    if LockdownTimer then
        -- Can't cancel Citizen.SetTimeout directly; just flag it
        LockdownTimer = nil
    end
    BroadcastToGuards('qb-prison_guard:client:lockdownAlert', false)
    print('[qb-prison_guard] Lockdown manually lifted by ' .. GetName(src))
end)

-- ─────────────────────────────────────────────
--  PRISONER LIST
-- ─────────────────────────────────────────────
RegisterNetEvent('qb-prison_guard:server:requestPrisonerList', function()
    local src = source
    if not IsGuard(src) then return end

    local prisoners = {}
    local Players   = QBCore.Functions.GetQBPlayers()

    for _, Player in pairs(Players) do
        if Player.PlayerData.job.name == 'prisoner' then
            table.insert(prisoners, {
                id       = Player.PlayerData.source,
                name     = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
                sentence = Player.PlayerData.metadata['inlaststandard'] or 0,
                reason   = Player.PlayerData.metadata['criminalreason'] or 'Unknown',
            })
        end
    end

    TriggerClientEvent('qb-prison_guard:client:receivePrisonerList', src, prisoners)
end)

-- ─────────────────────────────────────────────
--  PRISONER INFO CHECK
-- ─────────────────────────────────────────────
RegisterNetEvent('qb-prison_guard:server:getPrisonerInfo', function(targetId)
    local src    = source
    if not IsGuard(src) then return end

    local Target = QBCore.Functions.GetPlayer(tonumber(targetId))
    if not Target then
        NotifyGuard(src, 'Player not found.', 'error')
        return
    end

    local info = {
        name     = Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname,
        sentence = Target.PlayerData.metadata['inlaststandard'] or 0,
        reason   = Target.PlayerData.metadata['criminalreason'] or 'No record',
    }
    TriggerClientEvent('qb-prison_guard:client:showPrisonerInfo', src, info)
end)

-- ─────────────────────────────────────────────
--  CUFF / UNCUFF
-- ─────────────────────────────────────────────
RegisterNetEvent('qb-prison_guard:server:cuffPlayer', function(targetId, soft)
    local src = source
    if not IsGuard(src) then return end

    local Target = QBCore.Functions.GetPlayer(tonumber(targetId))
    if not Target then return end

    CuffedPlayers[tonumber(targetId)] = true
    TriggerClientEvent('qb-prison_guard:client:cuffed', tonumber(targetId), true, soft)
    NotifyGuard(src, 'Player has been ~r~handcuffed~s~.', 'success')
end)

RegisterNetEvent('qb-prison_guard:server:uncuffPlayer', function(targetId)
    local src = source
    if not IsGuard(src) then return end

    CuffedPlayers[tonumber(targetId)] = nil
    TriggerClientEvent('qb-prison_guard:client:cuffed', tonumber(targetId), false, false)
    NotifyGuard(src, 'Player has been ~g~uncuffed~s~.', 'success')
end)

-- ─────────────────────────────────────────────
--  ESCORT
-- ─────────────────────────────────────────────
RegisterNetEvent('qb-prison_guard:server:startEscort', function(targetId)
    local src = source
    if not IsGuard(src) then return end
    TriggerClientEvent('qb-prison_guard:client:beingEscorted', tonumber(targetId), true)
end)

RegisterNetEvent('qb-prison_guard:server:stopEscort', function(targetId)
    local src = source
    TriggerClientEvent('qb-prison_guard:client:beingEscorted', tonumber(targetId), false)
end)

-- ─────────────────────────────────────────────
--  PUT IN VEHICLE
-- ─────────────────────────────────────────────
RegisterNetEvent('qb-prison_guard:server:putInVehicle', function(targetId, netVeh)
    local src = source
    if not IsGuard(src) then return end
    TriggerClientEvent('qb-prison_guard:client:putInVehicle', tonumber(targetId), netVeh, -2)
end)

-- ─────────────────────────────────────────────
--  WEAPON GIVE (from armory)
-- ─────────────────────────────────────────────
RegisterNetEvent('qb-prison_guard:server:giveWeapon', function(weapon, price)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not IsGuard(src) then return end
    if not OnDutyGuards[src] then
        NotifyGuard(src, Config.Notify.NotOnDuty, 'error')
        return
    end

    -- Validate weapon is in allowed list
    local allowed = false
    for _, w in ipairs(Config.ArmoryWeapons) do
        if w.weapon == weapon then allowed = true break end
    end
    if not allowed then
        NotifyGuard(src, 'Invalid weapon.', 'error')
        return
    end

    -- Charge if price > 0
    if price > 0 then
        local cash = Player.Functions.GetMoney('cash')
        local bank = Player.Functions.GetMoney('bank')
        if cash + bank < price then
            NotifyGuard(src, 'You cannot afford this weapon.', 'error')
            return
        end
        if cash >= price then
            Player.Functions.RemoveMoney('cash', price, 'armory-weapon-purchase')
        else
            Player.Functions.RemoveMoney('bank', price, 'armory-weapon-purchase')
        end
    end

    local ammo = Config.ArmoryAmmo[weapon] or 0
    Player.Functions.AddItem(weapon, 1)
    TriggerClientEvent('QBCore:Client:AddItem', src, weapon, 1)
    if ammo > 0 then
        -- Give ammo via client event (requires qb-weapons or similar)
        TriggerClientEvent('qb-prison_guard:client:giveAmmo', src, weapon, ammo)
    end

    NotifyGuard(src, 'You picked up a ~g~' .. weapon .. '~s~.', 'success')
end)

-- ─────────────────────────────────────────────
--  AMMO GIVE (client side)
-- ─────────────────────────────────────────────
RegisterNetEvent('qb-prison_guard:client:giveAmmo', function(weapon, ammo)
    AddAmmoToPed(PlayerPedId(), GetHashKey(weapon), ammo)
end)

-- ─────────────────────────────────────────────
--  EXPORT: ON-DUTY COUNT (for external resources)
-- ─────────────────────────────────────────────
exports('getOnDutyGuards', function()
    local count = 0
    for _ in pairs(OnDutyGuards) do count = count + 1 end
    return count, OnDutyGuards
end)

exports('isLockdownActive', function()
    return LockdownActive
end)
