
fx_version 'cerulean'

author 'Bluster_Madness'
description 'Bluster Pawn - Free & Open Source'
version '1.1.1'

game 'gta5'

client_scripts {
	'client/*.lua',
}

server_scripts {
	'server/*.lua',
}

shared_scripts {
	'@ox_lib/init.lua',
	'config.lua',
}

lua54 'yes'
