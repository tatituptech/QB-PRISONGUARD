--[[ ============================================================
     QB-PRISONGUARD — SERVER / COMMANDS
     Admin & guard console/chat commands.
     ============================================================ ]]

local QBCore = exports['qb-core']:GetCoreObject()

local function IsGuard(src)
    local Player = QBCore.Functions.GetPlayer(src)
    return Player and Player.PlayerData.job.name == Config.JobName
end

local function GetGrade(src)
    local Player = QBCore.Functions.GetPlayer(src)
    return Player and tonumber(Player.PlayerData.job.grade.level) or 0
end

-- ─────────────────────────────────────────────
--  /lockdown  — Initiate or lift lockdown
--  Requires: Sergeant (grade 3) or above
-- ─────────────────────────────────────────────
QBCore.Commands.Add('lockdown', '(Prison Guard) Initiate or lift a prison lockdown', {}, false, function(source, args)
    local src = source
    if not IsGuard(src) then
        TriggerClientEvent('QBCore:Notify', src, 'You are not a Prison Guard.', 'error')
        return
    end
    if GetGrade(src) < Config.MinGradeForLockdown then
        TriggerClientEvent('QBCore:Notify', src, Config.Notify.NoPermission, 'error')
        return
    end
    TriggerEvent('qb-prison_guard:server:initiateLockdown', src) -- re-uses server event logic
    -- Re-trigger via net event so it routes through the existing handler
    TriggerNetEvent('qb-prison_guard:server:initiateLockdown')
end, Config.JobName)

-- ─────────────────────────────────────────────
--  /liftlockdown  — Manually lift lockdown
--  Requires: Warden (grade 4)
-- ─────────────────────────────────────────────
QBCore.Commands.Add('liftlockdown', '(Prison Guard) Manually lift the active lockdown', {}, false, function(source, args)
    local src = source
    if not IsGuard(src) then
        TriggerClientEvent('QBCore:Notify', src, 'You are not a Prison Guard.', 'error')
        return
    end
    if GetGrade(src) < 4 then
        TriggerClientEvent('QBCore:Notify', src, Config.Notify.NoPermission, 'error')
        return
    end
    TriggerNetEvent('qb-prison_guard:server:liftLockdown')
end, Config.JobName)

-- ─────────────────────────────────────────────
--  /prisonercheck [id]  — Look up a player's sentence
--  Requires: Any on-duty guard
-- ─────────────────────────────────────────────
QBCore.Commands.Add('prisonercheck', '(Prison Guard) Check a prisoner\'s sentence info', {
    { name = 'id', help = 'Server ID of the prisoner' },
}, true, function(source, args)
    local src      = source
    local targetId = tonumber(args[1])

    if not IsGuard(src) then
        TriggerClientEvent('QBCore:Notify', src, 'You are not a Prison Guard.', 'error')
        return
    end
    if not targetId then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid player ID.', 'error')
        return
    end

    local Target = QBCore.Functions.GetPlayer(targetId)
    if not Target then
        TriggerClientEvent('QBCore:Notify', src, 'Player not found.', 'error')
        return
    end

    local info = {
        name     = Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname,
        sentence = Target.PlayerData.metadata['inlaststandard'] or 0,
        reason   = Target.PlayerData.metadata['criminalreason'] or 'No record',
    }
    TriggerClientEvent('qb-prison_guard:client:showPrisonerInfo', src, info)
end, Config.JobName)

-- ─────────────────────────────────────────────
--  /guardduty  — List all on-duty guards (admin)
-- ─────────────────────────────────────────────
QBCore.Commands.Add('guardduty', 'List all on-duty prison guards', {}, false, function(source, args)
    local src     = source
    local count, guards = exports['qb-prison_guard']:getOnDutyGuards()

    if count == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'No guards currently on duty.', 'primary')
        return
    end

    local list = '~b~On-Duty Guards (' .. count .. ')~s~\n'
    for id, data in pairs(guards) do
        list = list .. '• ' .. data.name .. ' (ID: ' .. id .. ') — Grade ' .. data.grade .. '\n'
    end
    TriggerClientEvent('QBCore:Notify', src, list, 'primary', 8000)
end, 'admin')

-- ─────────────────────────────────────────────
--  /setprisoner [id] [minutes] [reason]
--  Admin command — manually sentence a player
-- ─────────────────────────────────────────────
QBCore.Commands.Add('setprisoner', '(Admin) Manually sentence a player to prison', {
    { name = 'id',      help = 'Server ID of the target player' },
    { name = 'minutes', help = 'Sentence length in minutes' },
    { name = 'reason',  help = 'Reason for imprisonment' },
}, true, function(source, args)
    local src      = source
    local targetId = tonumber(args[1])
    local minutes  = tonumber(args[2]) or 10
    local reason   = args[3] or 'Sentenced by staff'

    local Target = QBCore.Functions.GetPlayer(targetId)
    if not Target then
        TriggerClientEvent('QBCore:Notify', src, 'Player not found.', 'error')
        return
    end

    Target.Functions.SetMetaData('inlaststandard', minutes)
    Target.Functions.SetMetaData('criminalreason', reason)
    Target.Functions.SetJob('prisoner', 0)

    TriggerClientEvent('QBCore:Notify', targetId,
        '~r~You have been sentenced to ' .. minutes .. ' minutes in prison.\nReason: ' .. reason,
        'error', 8000)
    TriggerClientEvent('QBCore:Notify', src,
        'Player ~y~' .. Target.PlayerData.charinfo.firstname .. '~s~ sentenced for ~r~' .. minutes .. ' min~s~.',
        'success')

    print('[qb-prison_guard] Admin ID:' .. src .. ' sentenced player ID:' .. targetId ..
          ' for ' .. minutes .. ' min. Reason: ' .. reason)
end, 'admin')
