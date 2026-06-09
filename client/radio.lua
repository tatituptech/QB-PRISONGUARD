--[[ ============================================================
     QB-PRISONGUARD — CLIENT / RADIO
     Handles: B key backup request, F7 control-room shortcut,
              guard-to-guard radio communications & sounds.
     ============================================================ ]]

local QBCore   = exports['qb-core']:GetCoreObject()
local InRadio  = false     -- true while PTT (push-to-talk) is held

-- ─────────────────────────────────────────────
--  KEY BINDS (B = Backup, F7 = Control Room)
-- ─────────────────────────────────────────────
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        -- Only process keys if player is a guard on duty
        local pd = QBCore.Functions.GetPlayerData()
        if pd.job and pd.job.name == Config.JobName and pd.job.onduty then

            -- ── B KEY — Backup Request ────────────────────────
            if IsControlJustReleased(0, 29) then   -- B key
                TriggerEvent('qb-prison_guard:client:requestBackup')
            end

            -- ── F7 KEY — Control Room Menu ───────────────────
            if IsControlJustReleased(0, 166) then  -- F7 key
                TriggerEvent('qb-prison_guard:client:openControlRoom')
            end
        end
    end
end)

-- ─────────────────────────────────────────────
--  BACKUP REQUEST
-- ─────────────────────────────────────────────
local BackupCooldown = false

AddEventHandler('qb-prison_guard:client:requestBackup', function()
    if BackupCooldown then
        QBCore.Functions.Notify('Backup already requested. Please wait.', 'error', 3000)
        return
    end

    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local street1, street2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local location = GetStreetNameFromHashKey(street1)

    TriggerServerEvent('qb-prison_guard:server:requestBackup', {
        location = location,
        coords   = { x = coords.x, y = coords.y, z = coords.z },
    })

    -- Play local dispatch beep sound
    PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)

    QBCore.Functions.Notify(Config.Notify.BackupSent, 'success', 4000)

    -- 30 second cooldown
    BackupCooldown = true
    Citizen.SetTimeout(30000, function()
        BackupCooldown = false
    end)
end)

-- ─────────────────────────────────────────────
--  RECEIVE BACKUP ALERT (from server broadcast)
-- ─────────────────────────────────────────────
RegisterNetEvent('qb-prison_guard:client:receiveBackupAlert', function(data)
    -- Notification
    QBCore.Functions.Notify(
        '🚨 ~r~BACKUP REQUESTED~s~ by ' .. data.requester ..
        ' at ~y~' .. data.location,
        'error',
        8000
    )

    -- System sound alert
    PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)

    -- Add a temporary blip at the backup location
    local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    SetBlipSprite(blip, 161)
    SetBlipColour(blip, 1) -- red
    SetBlipScale(blip, 0.9)
    SetBlipAsShortRange(blip, false)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('⚠ Backup: ' .. data.requester)
    EndTextCommandSetBlipName(blip)

    -- Auto-remove blip after 2 minutes
    Citizen.SetTimeout(120000, function()
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end)
end)

-- ─────────────────────────────────────────────
--  GUARD RADIO CHAT  (on-duty only channel)
-- ─────────────────────────────────────────────
RegisterNetEvent('qb-prison_guard:client:radioMessage', function(sender, message)
    -- Display as a styled notification
    QBCore.Functions.Notify(
        '📡 ~b~[GUARD RADIO]~s~ ' .. sender .. ': ~w~' .. message,
        'primary',
        6000
    )
    PlaySoundFrontend(-1, 'PICK_UP_HEALTH', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end)

-- ─────────────────────────────────────────────
--  /guardradio COMMAND  (client-side trigger)
-- ─────────────────────────────────────────────
RegisterCommand('guardradio', function(source, args)
    local pd = QBCore.Functions.GetPlayerData()
    if not pd.job or pd.job.name ~= Config.JobName then
        QBCore.Functions.Notify('You are not a Prison Guard.', 'error')
        return
    end
    if not pd.job.onduty then
        QBCore.Functions.Notify(Config.Notify.NotOnDuty, 'error')
        return
    end
    if #args == 0 then
        QBCore.Functions.Notify('Usage: /guardradio [message]', 'error')
        return
    end
    local message = table.concat(args, ' ')
    TriggerServerEvent('qb-prison_guard:server:guardRadio', message)
end, false)

TriggerEvent('chat:addSuggestion', '/guardradio', 'Broadcast a message to all on-duty prison guards.', {
    { name = 'message', help = 'Your radio message' }
})
