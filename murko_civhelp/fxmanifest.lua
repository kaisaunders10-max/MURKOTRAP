fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'murko_civhelp'
author 'MURKOTRAP'
description 'Standalone random "civilian in need of help" requests with a persistent karma system'
version '1.0.0'

shared_script 'config.lua'

client_scripts {
    'client/utils.lua',
    'client/context.lua',
    'client/scenarios/*.lua',
    'client/main.lua',
}

server_script 'server/main.lua'
