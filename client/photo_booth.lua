-- Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

-- Sichere Foto-Kabine: kein MLO-Crash, kurze Script-Kamera, sofortige Rückkehr.
-- Ablauf: Server -> :client:photoPrepare -> wir teleportieren in SafeSpot, bauen Kamera, melden :server:photoPrepared
-- Nach Server-Screenshot -> :client:photoCleanup -> Kamera weg, zurück, Fade-In.

local RESOURCE = (GetCurrentResourceName and GetCurrentResourceName()) or 'mtj_fahrschule'
local DEBUG = false

local saved = { pos = nil, heading = nil, inVeh = false, veh = 0 }
local cam = nil
local preparing = false

local function dbg(...) if not DEBUG then return end
    local t = {}; for i=1,select('#', ...) do t[#t+1]=tostring(select(i,...)) end
    print(('[%s][client/photo_booth] %s'):format(RESOURCE, table.concat(t, ' ')))
end

local function fadeOut(ms)
    DoScreenFadeOut(ms or 400)
    local t = GetGameTimer() + (ms or 400) + 200
    while not IsScreenFadedOut() and GetGameTimer() < t do Wait(10) end
end

local function fadeIn(ms)
    DoScreenFadeIn(ms or 400)
    local t = GetGameTimer() + (ms or 400) + 200
    while not IsScreenFadedIn() and GetGameTimer() < t do Wait(10) end
end

-- entfernter, leerer SafeSpot (unter der Map) – keine MLO/Kollisionen
local SAFE_SPOT = vector3(4020.0, 4020.0, -30.0)

local function buildCamAtPedHead(ped)
    if cam and DoesCamExist(cam) then DestroyCam(cam, false) cam = nil end
    local p = GetEntityCoords(ped)
    local f = GetEntityForwardVector(ped)
    local up = vector3(0.0, 0.0, 0.65)
    -- Kamera 1.0m vor dem Ped, leicht angehoben
    local camPos = vector3(p.x + f.x*1.0, p.y + f.y*1.0, p.z) + up
    cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    PointCamAtPedBone(cam, ped, 31086, 0.0, 0.0, 0.0) -- HEAD bone
    SetCamFov(cam, 40.0)
    RenderScriptCams(true, false, 0, true, true)
end

local function clearCam()
    if cam and DoesCamExist(cam) then
        RenderScriptCams(false, true, 200, true, true)
        DestroyCam(cam, false)
    end
    cam = nil
end

RegisterNetEvent(RESOURCE..':client:photoPrepare', function()
    if preparing then return end
    preparing = true
    local ped = PlayerPedId()

    -- sichern
    saved.inVeh = IsPedInAnyVehicle(ped, false)
    if saved.inVeh then saved.veh = GetVehiclePedIsIn(ped, false) end
    saved.pos = GetEntityCoords(ped)
    saved.heading = GetEntityHeading(ped)

    -- raus aus Fahrzeug
    if saved.inVeh then
        TaskLeaveVehicle(ped, saved.veh, 16)
        local t = GetGameTimer() + 3500
        while IsPedInAnyVehicle(ped, false) and GetGameTimer() < t do Wait(50) end
    end

    -- Fade und Freeze
    fadeOut(300)
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, true)

    -- teleport in SafeSpot, neutral hinstellen
    SetEntityCoordsNoOffset(ped, SAFE_SPOT.x, SAFE_SPOT.y, SAFE_SPOT.z, false, false, false)
    SetEntityHeading(ped, 0.0)
    SetEntityCollision(ped, true, true)
    SetEntityVisible(ped, true, false)

    -- min. Delay zum Laden, dann Kamera setzen
    Wait(200)
    buildCamAtPedHead(ped)

    -- noch ganz kurz warten, dann Server melden
    Wait(150)
    TriggerServerEvent(RESOURCE..':server:photoPrepared')
    dbg('photoPrepared sent')
end)

RegisterNetEvent(RESOURCE..':client:photoCleanup', function()
    local ped = PlayerPedId()
    -- Kamera zurück
    clearCam()

    -- zurück teleportieren
    if saved and saved.pos then
        SetEntityCoordsNoOffset(ped, saved.pos.x, saved.pos.y, saved.pos.z, false, false, false)
        if saved.heading then SetEntityHeading(ped, saved.heading) end
    end

    -- Vehicle ggf. ignorieren – der Spieler kann wieder einsteigen
    FreezeEntityPosition(ped, false)

    -- Fade in
    fadeIn(300)
    preparing = false
    dbg('cleanup done')
end)