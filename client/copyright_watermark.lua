-- Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

--[[
  client/copyright_watermark.lua – Clientseitiger Plagiatschutz
  Zeigt ein dezentes Copyright-Wasserzeichen im NUI und prueft die Ressourcen-Integritaet.
]]

local _MTJ_SIG = 'MTJ2024-FAHRSCHULE'
local RESOURCE = (GetCurrentResourceName and GetCurrentResourceName()) or 'mtj_fahrschule'

-- ============================================================================
-- 1) Copyright-Metadaten an NUI senden
-- ============================================================================
local function pushCopyrightToNUI()
    pcall(function()
        SendNUIMessage({
            action    = 'mtj_copyright',
            author    = 'MTJ2024',
            year      = '2024-2026',
            signature = _MTJ_SIG,
        })
    end)
end

-- ============================================================================
-- 2) Integritaetspruefung: fxmanifest-Autor validieren
-- ============================================================================
local function checkIntegrity()
    local author = GetResourceMetadata(RESOURCE, 'author', 0)
    if author and not string.find(author, 'MTJ2024', 1, true) then
        print(('[%s][COPYRIGHT] WARNUNG: Autor-Feld wurde manipuliert!'):format(RESOURCE))
    end
end

-- ============================================================================
-- 3) Beim Ressourcenstart
-- ============================================================================
CreateThread(function()
    Wait(800)
    checkIntegrity()
    pushCopyrightToNUI()
end)

-- Bei NUI-Oeffnung Copyright mitsenden
RegisterNetEvent('mtj_fahrschule:client:copyrightInfo', function(data)
    if type(data) == 'table' then
        pcall(function()
            SendNUIMessage({
                action    = 'mtj_copyright',
                author    = data.author or 'MTJ2024',
                year      = data.year or '2024-2026',
                signature = _MTJ_SIG,
            })
        end)
    end
end)
