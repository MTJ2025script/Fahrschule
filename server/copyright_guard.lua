-- Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

--[[
  server/copyright_guard.lua – Plagiatschutz & Copyright-Verifizierung
  Überprüft beim Start die Ressourcen-Integrität und gibt Copyright-Hinweise aus.
]]

local _MTJ_COPYRIGHT = {
    author   = 'MTJ2024',
    project  = 'mtj_fahrschule',
    year     = '2024-2026',
    sig      = 'MTJ2024-FAHRSCHULE-SIG-A7F3',
}

-- ============================================================================
-- 1) Konsolen-Wasserzeichen beim Start
-- ============================================================================
local function printBanner()
    local line = string.rep('=', 72)
    print('')
    print(line)
    print('  mtj_fahrschule – Fahrschul-System fuer FiveM (ESX Legacy)')
    print('  Copyright (c) ' .. _MTJ_COPYRIGHT.year .. ' ' .. _MTJ_COPYRIGHT.author)
    print('  Alle Rechte vorbehalten / All rights reserved.')
    print(line)
    print('')
end

-- ============================================================================
-- 2) Ressourcen-Identitaet pruefen (fxmanifest author)
-- ============================================================================
local function verifyResourceIdentity()
    local resName = GetCurrentResourceName()
    if not resName then return end

    local manifestAuthor = GetResourceMetadata(resName, 'author', 0)
    if manifestAuthor and manifestAuthor ~= '' then
        if not string.find(manifestAuthor, _MTJ_COPYRIGHT.author, 1, true) then
            print(('[%s][WARNUNG] Autor-Feld in fxmanifest.lua wurde veraendert! Erwartet: %s'):format(
                resName, _MTJ_COPYRIGHT.author
            ))
        end
    else
        print(('[%s][WARNUNG] Kein Autor-Feld in fxmanifest.lua gefunden.'):format(resName))
    end
end

-- ============================================================================
-- 3) Fingerprint-Pruefung – Stellt sicher, dass der Copyright-Block existiert
-- ============================================================================
local function verifyFingerprint()
    local resName = GetCurrentResourceName()
    if not resName then return end

    local desc = GetResourceMetadata(resName, 'description', 0)
    if desc and desc ~= '' then
        if not string.find(desc, 'Fahrschule', 1, true) then
            print(('[%s][HINWEIS] Beschreibung wurde veraendert.'):format(resName))
        end
    end

    -- Signatur-Check (interner Marker)
    if _MTJ_COPYRIGHT.sig ~= 'MTJ2024-FAHRSCHULE-SIG-A7F3' then
        print(('[%s][WARNUNG] Copyright-Signatur ungueltig!'):format(resName))
    end
end

-- ============================================================================
-- 4) Periodische Konsolen-Erinnerung (alle 30 Minuten)
-- ============================================================================
CreateThread(function()
    while true do
        Wait(30 * 60 * 1000) -- 30 Minuten
        print(('[%s] Copyright (c) %s %s'):format(
            GetCurrentResourceName() or 'mtj_fahrschule',
            _MTJ_COPYRIGHT.year,
            _MTJ_COPYRIGHT.author
        ))
    end
end)

-- ============================================================================
-- 5) Client-Event: Copyright-Info an NUI senden
-- ============================================================================
RegisterNetEvent('mtj_fahrschule:server:getCopyright', function()
    local src = source
    if not src or src <= 0 then return end
    TriggerClientEvent('mtj_fahrschule:client:copyrightInfo', src, {
        author  = _MTJ_COPYRIGHT.author,
        year    = _MTJ_COPYRIGHT.year,
        project = _MTJ_COPYRIGHT.project,
    })
end)

-- ============================================================================
-- Ausfuehrung beim Start
-- ============================================================================
CreateThread(function()
    Wait(500)
    printBanner()
    verifyResourceIdentity()
    verifyFingerprint()
end)
