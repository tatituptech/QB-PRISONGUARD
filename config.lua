--[[ ============================================================
     QB-PRISONGUARD — CONFIG
     Adjust all values below to match your server setup.
     ============================================================ ]]

Config = {}

-- ─────────────────────────────────────────────
--  JOB DEFINITION
-- ─────────────────────────────────────────────
Config.JobName = 'prison_guard'   -- Must match your qb-core/shared/jobs.lua entry

-- ─────────────────────────────────────────────
--  GRADES / RANKS
--  Add this table to qb-core/shared/jobs.lua
-- ─────────────────────────────────────────────
--[[
    ['prison_guard'] = {
        label = 'Prison Guard',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'trainee',      label = 'Trainee',       payment = 150 },
            ['1'] = { name = 'guard',        label = 'Guard',         payment = 200 },
            ['2'] = { name = 'seniorguard',  label = 'Senior Guard',  payment = 275 },
            ['3'] = { name = 'sergeant',     label = 'Sergeant',      payment = 350, isboss = false },
            ['4'] = { name = 'warden',       label = 'Warden',        payment = 500, isboss = true },
        },
    },
]]--

Config.MinGradeForLockdown  = 3   -- Sergeant+ can call lockdown
Config.MinGradeForArmory    = 1   -- Guard+ can use armory

-- ─────────────────────────────────────────────
--  SALARY (server-side)
-- ─────────────────────────────────────────────
Config.SalaryInterval       = 30   -- minutes between paychecks
Config.SalaryBase           = 250  -- fallback if grade pay not found in jobs.lua

-- ─────────────────────────────────────────────
--  LOCATIONS  (all coords are vec3 or vec4)
-- ─────────────────────────────────────────────
-- Duty toggle marker (inside Bolingbroke guard office)
Config.DutyLocation = vector4(1842.38, 2586.73, 45.67, 92.66)

-- Armory locker interaction point
Config.ArmoryLocation = vector3(1839.71, 2600.23, 45.67)

-- Control room desk (F7 menu anchor / qb-target object)
Config.ControlRoomLocation = vector3(1834.52, 2603.14, 45.67)

-- Guard Posts (blip markers placed around the prison)
Config.GuardPosts = {
    { label = 'Main Gate',        coords = vector3(1699.56, 2567.44, 45.56),  blipSprite = 280, blipColor = 3 },
    { label = 'East Tower',       coords = vector3(1852.27, 2442.24, 45.67),  blipSprite = 280, blipColor = 3 },
    { label = 'West Tower',       coords = vector3(1693.67, 2441.03, 45.67),  blipSprite = 280, blipColor = 3 },
    { label = 'North Yard',       coords = vector3(1766.22, 2602.18, 45.67),  blipSprite = 280, blipColor = 3 },
    { label = 'Cell Block A',     coords = vector3(1757.21, 2499.74, 45.67),  blipSprite = 280, blipColor = 3 },
    { label = 'Visitation',       coords = vector3(1797.67, 2508.41, 45.67),  blipSprite = 280, blipColor = 3 },
    { label = 'Control Room',     coords = vector3(1834.52, 2603.14, 45.67),  blipSprite = 422, blipColor = 5 },
    { label = 'Guard Armory',     coords = vector3(1839.71, 2600.23, 45.67),  blipSprite = 110, blipColor = 5 },
}

-- ─────────────────────────────────────────────
--  PRISON BLIP (shows for everyone)
-- ─────────────────────────────────────────────
Config.PrisonBlip = {
    sprite = 422,
    color  = 3,
    scale  = 0.9,
    label  = 'Bolingbroke Penitentiary',
    coords = vector3(1756.75, 2512.23, 45.67),
}

-- ─────────────────────────────────────────────
--  DUTY MARKER
-- ─────────────────────────────────────────────
Config.DutyMarker = {
    type   = 1,      -- cylinder
    size   = vector3(1.5, 1.5, 0.5),
    color  = { r = 41, g = 128, b = 185, a = 180 },
}

-- ─────────────────────────────────────────────
--  UNIFORMS (component ID + drawable + texture)
--  Adjust to match your clothing pack.
--  Format: { component, drawable, texture, palette }
-- ─────────────────────────────────────────────
Config.Uniform = {
    male = {
        { component = 1,  drawable = 0,   texture = 0,  palette = 0 }, -- mask
        { component = 3,  drawable = 28,  texture = 0,  palette = 0 }, -- arms/torso
        { component = 4,  drawable = 35,  texture = 1,  palette = 0 }, -- pants
        { component = 5,  drawable = 45,  texture = 0,  palette = 0 }, -- parachute (bag slot)
        { component = 6,  drawable = 34,  texture = 1,  palette = 0 }, -- shoes (boots)
        { component = 7,  drawable = 0,   texture = 0,  palette = 0 }, -- accessories
        { component = 8,  drawable = 15,  texture = 0,  palette = 0 }, -- undershirt
        { component = 9,  drawable = 0,   texture = 0,  palette = 0 }, -- body armor slot
        { component = 10, drawable = 0,   texture = 0,  palette = 0 }, -- decals
        { component = 11, drawable = 15,  texture = 0,  palette = 0 }, -- top/jacket
    },
    female = {
        { component = 1,  drawable = 0,   texture = 0,  palette = 0 },
        { component = 3,  drawable = 28,  texture = 0,  palette = 0 },
        { component = 4,  drawable = 35,  texture = 1,  palette = 0 },
        { component = 5,  drawable = 45,  texture = 0,  palette = 0 },
        { component = 6,  drawable = 34,  texture = 1,  palette = 0 },
        { component = 7,  drawable = 0,   texture = 0,  palette = 0 },
        { component = 8,  drawable = 15,  texture = 0,  palette = 0 },
        { component = 9,  drawable = 0,   texture = 0,  palette = 0 },
        { component = 10, drawable = 0,   texture = 0,  palette = 0 },
        { component = 11, drawable = 15,  texture = 0,  palette = 0 },
    },
}

-- Props (hat, badge) — format: { prop, drawable, texture }
Config.UniformProps = {
    male = {
        { prop = 0, drawable = 61,  texture = 1 },  -- hat/cap
    },
    female = {
        { prop = 0, drawable = 61,  texture = 1 },
    },
}

-- ─────────────────────────────────────────────
--  ARMORY WEAPONS
-- ─────────────────────────────────────────────
Config.ArmoryWeapons = {
    { label = 'Nightstick',       weapon = 'WEAPON_NIGHTSTICK',       price = 0   },
    { label = 'Flashlight',       weapon = 'WEAPON_FLASHLIGHT',       price = 0   },
    { label = 'Pistol',           weapon = 'WEAPON_PISTOL',           price = 0   },
    { label = 'Shotgun',          weapon = 'WEAPON_PUMPSHOTGUN',      price = 250 },
    { label = 'SMG',              weapon = 'WEAPON_SMG',              price = 500 },
    { label = 'Stun Gun',         weapon = 'WEAPON_STUNGUN',          price = 0   },
    { label = 'Tear Gas',         weapon = 'WEAPON_SMOKEGRENADE',     price = 100 },
}

-- Ammo given per weapon pickup (0 = default)
Config.ArmoryAmmo = {
    ['WEAPON_PISTOL']       = 60,
    ['WEAPON_PUMPSHOTGUN']  = 20,
    ['WEAPON_SMG']          = 120,
    ['WEAPON_STUNGUN']      = 10,
    ['WEAPON_SMOKEGRENADE'] = 3,
}

-- ─────────────────────────────────────────────
--  RADIO / BACKUP KEYS
-- ─────────────────────────────────────────────
Config.BackupKey       = 0x6B          -- B key (same as original mod)
Config.ControlRoomKey  = 0x76          -- F7 key (same as original mod)

-- Radio channel for guard communications
Config.RadioChannel = 'PRISON_GUARD_RADIO'

-- ─────────────────────────────────────────────
--  LOCKDOWN
-- ─────────────────────────────────────────────
Config.LockdownDuration = 300    -- seconds (5 min) before auto-lift
Config.LockdownAlert    = '🚨 PRISON LOCKDOWN INITIATED — All guards to posts!'

-- ─────────────────────────────────────────────
--  NOTIFICATIONS
-- ─────────────────────────────────────────────
Config.Notify = {
    OnDuty         = 'You are now ~g~ON DUTY~s~ as a Prison Guard.',
    OffDuty        = 'You are now ~r~OFF DUTY~s~.',
    NotOnDuty      = 'You must be ~r~on duty~s~ to use this.',
    NoPermission   = 'You do not have the rank required for this action.',
    BackupSent     = 'Backup request ~y~broadcasted~s~ to all guards.',
    BackupReceived = '🚨 GUARD BACKUP REQUESTED at your location!',
    Salary         = 'Prison Guard paycheck: ~g~$%s~s~',
    LockdownStart  = '🔒 Prison lockdown ~r~ACTIVATED~s~.',
    LockdownEnd    = '🔓 Prison lockdown ~g~LIFTED~s~.',
}
