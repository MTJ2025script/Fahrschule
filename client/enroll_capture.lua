-- Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

-- mtj_fahrschule/client/enroll_capture.lua
-- Gesicht zentriert, Spieler fixiert (Freeze + Controls sperren) bis Cleanup
-- Foto wird mit Delay gemacht, damit das Gesicht sicher bereit ist!

local RESOURCE = GetCurrentResourceName()

local cam, camActive = nil, false
local photoBusy = false
local wasHud, wasRadar = true, true

local function hideHUD(hide)
    DisplayHud(not hide)
    DisplayRadar(not hide)
end

local function destroyCam()
    if camActive then
        RenderScriptCams(false, true, 250, true, true)
        camActive = false
    end
    if cam then
        DestroyCam(cam, false)
        cam = nil
    end
end

local function faceToEnrollmentHeading(ped)
    if not (Config and Config.License and Config.License.Enrollment and Config.License.Enrollment.Location) then return end
    local loc = Config.License.Enrollment.Location
    local heading = loc.w or loc.h or loc.heading or loc[4]
    if heading then
        SetEntityHeading(ped, tonumber(heading) or GetEntityHeading(ped))
    end
end

local function setupFaceCam()
    local ped = PlayerPedId()
    faceToEnrollmentHeading(ped)

    local headBone = 31086 -- SKEL_Head
    local headPos = GetPedBoneCoords(ped, headBone, 0.0, 0.0, 0.0)
    local fwd = GetEntityForwardVector(ped)

    -- Noch weiter weg und breiteres FOV für sauberes Porträt
    local camPos = vector3(
        headPos.x + fwd.x * 0.90,
        headPos.y + fwd.y * 0.90,
        headPos.z - 0.05
    )

    cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(cam, headPos.x, headPos.y, headPos.z - 0.08)
    SetCamFov(cam, 42.0) -- breiter
    SetCamNearDof(cam, 0.0)
    SetCamFarDof(cam, 0.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 250, true, true)
    camActive = true
end

local function startFreeze(seconds)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    ClearPedTasksImmediately(ped)
    TaskStandStill(ped, math.floor((seconds or 2) * 1000))

    photoBusy = true
    CreateThread(function()
        -- Controls komplett sperren bis Cleanup
        while photoBusy do
            Wait(0)
            DisableAllControlActions(0)
            -- ESC erlauben:
            EnableControlAction(0, 200, true)
        end
    end)
end

local function stopFreeze()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    photoBusy = false
end

RegisterNetEvent('mtj_fahrschule:client:photoPrepare', function()
    wasHud = IsHudHidden() ~= 1
    wasRadar = IsRadarHidden() ~= 1
    hideHUD(true)

    setupFaceCam()

    -- Freeze (aus Config)
    local secs = 2
    if Config and Config.License and Config.License.Enrollment and tonumber(Config.License.Enrollment.FreezeSeconds) then
        secs = tonumber(Config.License.Enrollment.FreezeSeconds)
    end
    startFreeze(secs)

    -- NEU: Foto erst nach kurzem Delay machen, damit das Gesicht sicher bereit ist!
    Citizen.SetTimeout(math.floor(secs * 1000), function()
        -- Screenshot serverseitig anfordern (wie gehabt)
        TriggerServerEvent('mtj_fahrschule:server:photoPrepared')
    end)
end)

RegisterNetEvent('mtj_fahrschule:client:photoCleanup', function()
    destroyCam()
    hideHUD(false)
    stopFreeze()
end)
-- === DEV: Foto- und Führerscheinprozess simulieren (nur für Entwickler!) ===

-- 1. Kompletten Aufnahmeprozess simulieren (Kamera, Freeze, Foto nach Delay)
RegisterCommand("mtjtest_photo", function()
    TriggerEvent('mtj_fahrschule:client:photoPrepare')
end, false)

-- 2. Foto SOFORT machen (egal ob Overlay/Cam aktiv, nur das Server-Event)
RegisterCommand("mtjtest_photoinstant", function()
    TriggerServerEvent('mtj_fahrschule:server:photoPrepared')
end, false)

-- 3. Führerschein-Overlay in der NUI/UI anzeigen (ohne Prüfung!)
RegisterCommand("mtjtest_licenseui", function()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "showLicense", show = true, data = {
        firstname = "Max",
        lastname = "Mustermann",
        birthdate = "01.01.1990",
        height = "178",
        issuedAt = "18.10.2025",
        expiresAt = "18.10.2035",
        category = "B",
        signature = "M. Mustermann",
        photo = "img/logo.png", -- oder ein echtes Bild
        dln = "MTJ1234567"
    }})
end, false)