fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'corlinks_vipgarage'
description 'Premium VIP / admin vehicle editor: showroom camera, liveries, paint, wheels, body, lights, extras, plate, performance.'
version '2.0.0'
shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client.lua'
server_scripts { '@oxmysql/lib/MySQL.lua', 'server.lua' }
ui_page 'html/index.html'
files { 'html/index.html' }
dependencies { 'qb-core', 'ox_lib', 'oxmysql' }
