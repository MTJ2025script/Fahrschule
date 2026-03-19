-- Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mtj_fahrschule'
author 'MTJ2024'
description 'ESX Legacy Fahrschule mit Theorie & Praxis und Pflicht-Foto (serverseitig) | (c) MTJ2024'
version '1.2.6'

shared_scripts {
    'config/config.lua',
    'debug.lua',
    '@es_extended/imports.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/debug_ui.lua',
    'server/main.lua',
    'server/enrollment_persist.lua',
    'server/theorie_result.lua',
    'server/screenshot_bridge.lua',
    'server/copyright_guard.lua'
}

client_scripts {
    'client/debug_ui.lua',
    'client/blip.lua',
    'client/practice.lua',
    'client/enrollment.lua',
    'client/ui.lua',
    'client/theorie.lua',
    'client/enroll_capture.lua',

    -- Neu: Absicherung für Marker-Zeichnung
    'client/markers_hardening.lua',

    -- Copyright / Plagiatschutz
    'client/copyright_watermark.lua',

    -- Wichtig: Foto-Kabine NICHT doppelt laden (in main enthalten)
    -- 'client/photo_booth.lua',

    -- main zuletzt
    'client/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/sfx.js',
    'html/img/**/*',
    'html/data/*.js'
}

dependency 'oxmysql'
dependency 'es_extended'
dependency 'screenshot-basic'