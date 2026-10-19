fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'corlinks_foodvan'
author 'Corlinks RP'
description "Murko's Cyber Taco - order at the tacotuck hatch, pay the invoice, get the food"
version '1.0.0'

shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'
files { 'html/index.html', 'images/*.png' }

dependencies { 'qb-core', 'ox_lib', 'ox_inventory', 'ox_target' }
