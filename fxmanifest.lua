fx_version 'cerulean'
game 'gta5'

author 'Stw'
description 'Stw Rental Script'
version '1.0.0'

client_scripts {
    'config.lua',
    'client/*.lua'
}

server_scripts {
    'server/*.lua'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

files {
    'ui/*.*',
    'ui/app/*.*',
    'ui/css/*.*',
    'ui/images/*.*',
}
