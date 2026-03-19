-- Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

-- enrollment.lua
-- Foto nur am Fotopunkt mit E. Server validiert (auch wenn pending=false).
-- Hysterese + Debounce, einmaliger Timeout-Fehler statt Spam.

local RES = (Config and Config.ResourceName) or (GetCurrentResourceName and GetCurrentResourceName()) or 'mtj_fahrschule'
local SERVER_CAPTURE_EVENT = RES..':server:enrollCaptureNow'   -- ggf. anpassen

-- Zonen-/Einstellungen
local HYSTERESIS_M = 0.7
local IDLE_DEBOUNCE_MS = 600
local REARM_AFTER_START_MS = 1200
local SHORT_TIMEOUT_MS = 6000       -- Wartezeit auf irgendeine Server-Reaktion (prepare/denied/done)
local KEY_PRIMARY  = (Config and (Config.License and Config.License.Enrollment and Config.License.Enrollment.Key) or Config.KeyInteract) or 38
local KEY_CONTEXT  = 51

-- State
local ENR = { pending=false, awaiting=false, gotPrepare=false, startedAt=0 }
local currentCat = 'car'
local insideZone = false
local canInteract = true
local lastEAt = 0
local responded = false -- irgendeine Server-Reaktion eingetroffen (prepare/cleanup/done/denied)

-- Helpers
local function now() local ok,t=pcall(GetGameTimer); return ok and t or (os.time()*1000) end
local function notify(level, text, dur)
  local d = tonumber(dur or (Config and Config.NotifyDuration) or 2500) or 2500
  if Config and Config.UseESXNotify then
    pcall(function() TriggerEvent('esx:showNotification', tostring(text or '')) end)
  else
    pcall(function() SendNUIMessage({ action='notify', level=level or 'info', text=tostring(text or ''), duration=d }) end)
  end
end
local function help(text)
  AddTextEntry('MTJ_ENROLL_HELP', text or 'Drücke E für das Foto')
  DisplayHelpTextThisFrame('MTJ_ENROLL_HELP', false)
end
local function dbg(...) print(('[%s][enroll] %s'):format(RES, table.concat({...}, ' '))) end

-- Kategorie/State vom Server übernehmen
RegisterNetEvent(RES..':client:stateSync', function(state)
  if type(state)=='table' and type(state.category)=='string' and state.category~='' then currentCat = state.category end
end)
RegisterNetEvent(RES..':client:booked', function(category)
  if type(category)=='string' and category~='' then currentCat = category end
end)

-- Fototermin gesetzt
RegisterNetEvent(RES..':client:enrollStart', function(category)
  ENR.pending = true
  ENR.awaiting = false
  ENR.gotPrepare = false
  responded = false
  if type(category)=='string' and category~='' then currentCat = category end
  notify('info', (Config and Config.Labels and (Config.Labels.EnrollGoToOffice or Config.Labels.EnrollPressE))
                 or 'Bitte gehe zum Fotopunkt in der Fahrschule, um deinen Führerschein zu erhalten.', 6500)
  dbg('enrollStart pending=true cat='..tostring(currentCat))
end)

-- Handshake beginnt (ACK sendet enroll_capture.lua)
RegisterNetEvent(RES..':client:photoPrepare', function()
  ENR.gotPrepare = true
  responded = true
  dbg('photoPrepare -> gotPrepare=true')
  local freezeSec = tonumber((Config and Config.License and Config.License.Enrollment and Config.License.Enrollment.FreezeSeconds) or 0) or 0
  if freezeSec > 0 then
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    CreateThread(function()
      Wait(math.floor(freezeSec*1000))
      FreezeEntityPosition(ped, false)
    end)
  end
end)

-- Optional: Server lehnt ab (wenn implementiert)
RegisterNetEvent(RES..':client:enrollDenied', function(msg)
  responded = true
  ENR.awaiting = false
  notify('error', tostring(msg or 'Kein Fototermin offen.'), 3000)
  dbg('enrollDenied: '..tostring(msg or ''))
  -- in aktueller Zone erst wieder nach Exit erlaubt
  canInteract = false
end)

-- Cleanup/Ende
RegisterNetEvent(RES..':client:photoCleanup', function()
  ENR.awaiting = false
  responded = true
  FreezeEntityPosition(PlayerPedId(), false)
  dbg('photoCleanup awaiting=false')
end)

RegisterNetEvent(RES..':client:enrollDone', function(success, msg)
  ENR.awaiting = false
  ENR.pending = false
  responded = true
  if msg and msg ~= '' then notify(success and 'success' or 'error', msg, 3500) end
  dbg('enrollDone success='..tostring(success)..' msg='..tostring(msg or ''))
  -- Interaktion wieder erst nach Zone-Exit
  canInteract = false
end)

local function startCapture(category)
  if ENR.awaiting then return end
  ENR.awaiting = true
  ENR.gotPrepare = false
  ENR.startedAt = now()
  responded = false
  canInteract = false         -- in dieser Zone bis Reaktion gesperrt
  notify('info', 'Foto wird aufgenommen …', 1000)
  TriggerServerEvent(SERVER_CAPTURE_EVENT, category)
  dbg('capture -> TriggerServerEvent('..SERVER_CAPTURE_EVENT..', '..tostring(category)..')')

  -- kurzer Gesamt-Timeout (auch wenn pending=false): ein EINZIGER Fehler, kein Spam
  CreateThread(function()
    local t0 = now()
    while ENR.awaiting and (now() - t0 < SHORT_TIMEOUT_MS) do
      if responded or ENR.gotPrepare then return end
      Wait(120)
    end
    if ENR.awaiting and not responded and not ENR.gotPrepare then
      ENR.awaiting = false
      notify('error', 'Fotoaufnahme nicht möglich oder nicht freigeschaltet. Bitte nach der Praxis erneut versuchen.', 3500)
      dbg('capture short-timeout no response')
      -- erneute Interaktion erst nach Zone-Exit
      canInteract = false
    end
  end)
end

-- Fotopunkt-Loop mit Hysterese + Debounce
CreateThread(function()
  while not (Config and Config.License and Config.License.Enrollment and Config.License.Enrollment.Location) do Wait(100) end
  local loc    = Config.License.Enrollment.Location
  local dd     = (Config.License.Enrollment.DrawDistance or Config.DrawDistance or 25.0)
  local id     = (Config.License.Enrollment.InteractDistance or Config.InteractDistance or 2.0)
  local exitD  = id + HYSTERESIS_M
  local use3D  = (Config.License.Enrollment.Use3DText ~= false)

  dbg(('loop ready @%.2f,%.2f,%.2f id=%.2f exitD=%.2f key=%s/%s'):format(loc.x,loc.y,loc.z,id,exitD,tostring(KEY_PRIMARY),tostring(KEY_CONTEXT)))

  while true do
    Wait(0)
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local x,y,z = loc.x+0.0, loc.y+0.0, loc.z+0.0
    local dist = Vdist(p.x,p.y,p.z, x,y,z)

    if dist <= dd then
      DrawMarker(1, x, y, z - 0.95, 0.0,0.0,0.0, 0.0,0.0,0.0, 0.9,0.9,0.35, 0,200,255, 185, false,true,2,false,nil,nil,false)
    end

    -- Hysterese-Ein/Aus
    if not insideZone and dist <= id then
      insideZone = true
      if not ENR.awaiting then canInteract = true end
      dbg(('zone ENTER dist=%.2f pending=%s'):format(dist, tostring(ENR.pending)))
    elseif insideZone and dist > exitD then
      insideZone = false
      canInteract = true   -- wieder erlaubt
      dbg(('zone EXIT dist=%.2f'):format(dist))
    end

    if use3D and insideZone then
      local txt = (Config and Config.Labels and (Config.Labels.EnrollPressE or 'Drücke E für das Foto')) or 'Drücke E für das Foto'
      help(txt)
    end

    if insideZone then
      local pressed = IsControlJustPressed(0, KEY_PRIMARY) or IsControlJustPressed(0, KEY_CONTEXT)
      if pressed then
        local t = now()
        if (t - lastEAt) < IDLE_DEBOUNCE_MS then goto continue end
        lastEAt = t

        if not canInteract then
          if (t - ENR.startedAt) < REARM_AFTER_START_MS then goto continue end
        end

        -- Immer versuchen: Server validiert (auch wenn ENR.pending=false)
        startCapture(currentCat or 'car')
      end
    end
    ::continue::
  end
end)

print(('[%s][client] enrollment.lua loaded (Foto am Punkt mit E/INPUT_CONTEXT, server-validated, Hysterese+Debounce)'):format(RES))