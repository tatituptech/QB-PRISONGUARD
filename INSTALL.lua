--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║          QB-PRISONGUARD — JOB INSTALLATION GUIDE            ║
    ║  Add the block below to: qb-core/shared/jobs.lua            ║
    ╚══════════════════════════════════════════════════════════════╝

    Find the ['Jobs'] table and paste this entry inside it:
--]]

--[[  ← COPY FROM HERE ──────────────────────────────────────────

    ['prison_guard'] = {
        label       = 'Prison Guard',
        defaultDuty = false,
        offDutyPay  = false,
        grades = {
            ['0'] = {
                name    = 'trainee',
                label   = 'Trainee',
                payment = 150,
            },
            ['1'] = {
                name    = 'guard',
                label   = 'Guard',
                payment = 200,
            },
            ['2'] = {
                name    = 'seniorguard',
                label   = 'Senior Guard',
                payment = 275,
            },
            ['3'] = {
                name    = 'sergeant',
                label   = 'Sergeant',
                payment = 350,
                isboss  = false,
            },
            ['4'] = {
                name    = 'warden',
                label   = 'Warden',
                payment = 500,
                isboss  = true,
            },
        },
    },

──────────────────────────────────────────── TO HERE ]]--

--[[
    ══════════════════════════════════════════════════════════════
    SERVER.CFG — Add this line to ensure the resource loads:
    ══════════════════════════════════════════════════════════════

    ensure qb-prison_guard

    ══════════════════════════════════════════════════════════════
    RESOURCE FOLDER — Place in your resources folder like so:
    ══════════════════════════════════════════════════════════════

    resources/
    └── [qb]/
        └── qb-prison_guard/      ← this folder

    ══════════════════════════════════════════════════════════════
    TEST IN-GAME:
    ══════════════════════════════════════════════════════════════

    1. Set your job:
       /setjob [yourID] prison_guard 4

    2. Walk to the duty marker at Bolingbroke (~1842, ~2586, ~45)
       Press [E] to go on duty → uniform auto-applies

    3. Press [F7] to open the Control Room menu
       Press [B] to broadcast a backup request

    4. Walk to the armory marker (~1839, ~2600, ~45)
       Look at it for qb-target → "Access Armory"

    5. Look at another player:
       qb-target options: Handcuff / Escort / Check Info / Put In Vehicle

    ══════════════════════════════════════════════════════════════
    DEPENDENCIES (must be installed and ensured before this):
    ══════════════════════════════════════════════════════════════

    - qb-core
    - qb-menu
    - qb-target
    - PolyZone

    ══════════════════════════════════════════════════════════════
    COMMANDS REFERENCE:
    ══════════════════════════════════════════════════════════════

    /guardradio [msg]           — Broadcast to all on-duty guards
    /prisonercheck [id]         — Check a prisoner's sentence info
    /lockdown                   — Initiate lockdown (Sergeant+)
    /liftlockdown               — Lift lockdown manually (Warden)
    /guardduty                  — List on-duty guards (admin)
    /setprisoner [id] [min] [reason]  — Sentence a player (admin)

    ══════════════════════════════════════════════════════════════
    CLOTHING NOTE:
    ══════════════════════════════════════════════════════════════

    The uniform component IDs in config.lua are placeholder values.
    Adjust them in config.lua → Config.Uniform to match your
    clothing pack (EUP, Frp-Clothing, etc.).

--]]
