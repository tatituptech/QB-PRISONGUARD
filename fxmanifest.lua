fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'ALPHA DARXK | Converted to QB-Core'
description 'QB-Core Prison Guard Job Resource'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua',
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/CircleZone.lua',
    'client/main.lua',
    'client/radio.lua',
    'client/escort.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/commands.lua',
}

dependencies {
    'qb-core',
    'qb-menu',
    'qb-target',
    'PolyZone',
}
