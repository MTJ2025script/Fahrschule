--[[
========================================================================================================================
  
  ####     #####     ######     ######     #    #     ######     ####       #    #     ######
 #    #    #   #     #          #          ##   #         ##     #    #     ##   #     #
 #  ###    #####     #####      #####      # #  #        ##      #    #     # #  #     #####
 #    #    #  #      #          #          #  # #       ##       #    #     #  # #     #
  ####     #   #     ######     ######     #   ##     ######      ####      #   ##     ######

                                                   M T J 2 0 2 4   S C R I P T S
========================================================================================================================
  Projekt     : Fahr-/Theorie-/Praxis-System (ESX Legacy/Compat)
  Datei       : client/theorie.lua
  Version     : v1.1.1
  Build       : 2025-10-14
  Autor       : MTJ2024
  Lizenz      : Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten.

  Zweck       : Theorie – UI-Finish, Maus-Fokus bis "Schließen", Datenanzeige (NUI + natives Fallback),
                Doppel-Submit-Schutz, serverseitige Speicherung (mit Token), kompatibel zu vorhandenen UI/Event-Namen.

  Hinweise    :
  - NUI Submit erwartet Callback-Name 'mtj_theory_submit' mit Payload { category, total, correct } oder { category, percentage }
  - Ergebnis-Overlay: NUI Messages 'theory-result' und 'theory:result' (beide geschickt, maximale Kompatibilität)
  - Schließen: NUI Callback 'mtj_theory_close' oder Fallback-Command /theoryclose
  - Servercall: TriggerServerEvent(<RES>:server:theoryResult, category, token, passed, scorePct)
  - Token-Quelle: vom Server-Event <RES>:client:booked gespeichert; falls fehlt, per ESX.Callback <RES>:server:getClientState nachziehen
========================================================================================================================
]]--

-- ESX (optional, robust)
local ESX = nil
local function tryGetESX()
  if ESX ~= nil then return ESX end
  local ok, obj = pcall(function()
    if GetResourceState('es_extended') == 'started' and exports['es_extended'] and exports['es_extended'].getSharedObject then
      return exports['es_extended']:getSharedObject()
    end
  end)
  if ok and obj then ESX = obj end
  return ESX
end
local function ensureESX(timeoutMs)
  local dl = GetGameTimer() + (timeoutMs or 3000)
  while ESX == nil and GetGameTimer() < dl do
    tryGetESX()
    Wait(50)
  end
  return ESX ~= nil
end

-- Namespace / Helpers
local function RES() return (Config and Config.ResourceName) or GetCurrentResourceName() or 'mtj_fahrschule' end
local function ev(path) return RES() .. ':' .. path end
local function now() return GetGameTimer() end
local function log(msg) print(string.format('[%s][client/theorie] %s', RES(), tostring(msg or ''))) end

-- State
local theoryActive = false
local theoryStartTick = nil
local theoryCategory = nil
local theoryFinishing = false

local bookedCategory, sessionToken = nil, nil

local resultOpen = false  -- solange true => Maus & UI bleiben aktiv
local controlTick = nil   -- Control-Lock-Thread während Ergebnis offen ist

-- Fokus/Controls
local function setFocus(enable)
  pcall(function() SetNuiFocusKeepInput(false) end)             -- false => Gameplay blockiert
  pcall(function() SetNuiFocus(enable and true or false, enable and true or false) end)
  if enable and SetCursorLocation then pcall(function() SetCursorLocation(0.5, 0.5) end) end
end

local function startControlLock()
  if controlTick then return end
  controlTick = true
  CreateThread(function()
    while resultOpen do
      Wait(0)
      DisableAllControlActions(0)
      -- UI-Eingaben erlauben
      EnableControlAction(0, 1, true)    -- LookLeftRight
      EnableControlAction(0, 2, true)    -- LookUpDown
      EnableControlAction(0, 237, true)  -- LeftClick
      EnableControlAction(0, 238, true)  -- RightClick
      EnableControlAction(0, 239, true)  -- Cursor X
      EnableControlAction(0, 240, true)  -- Cursor Y
      EnableControlAction(0, 241, true)  -- Scroll up
      EnableControlAction(0, 242, true)  -- Scroll down
    end
    controlTick = nil
  end)
end

local function resetCameraAndControls()
  pcall(function() RenderScriptCams(false, true, 300, true, true) end)
  local rc = GetRenderingCam()
  if rc and rc ~= -1 then pcall(function() DestroyCam(rc, false) end) end
  for g=0,2 do EnableAllControlActions(g) end
end

-- Server-State (Token) anfordern, falls lokal nicht gesetzt
local function requestServerStateOnce(cb)
  if not ensureESX(2000) or not (ESX and ESX.TriggerServerCallback) then
    if cb then cb(false) end
    return
  end
  local done = false
  local function try(name)
    if done then return false end
    local ok = pcall(function()
      ESX.TriggerServerCallback(ev(name), function(state)
        done = true
        if type(state) == 'table' then
          if state.category then bookedCategory = state.category end
          if state.token then sessionToken = state.token end
        end
        if cb then cb(true) end
      end)
    end)
    return ok
  end
  -- nacheinander versuchen (kein "or"-Kettenstatement)
  if not try('server:getClientState') then
    if not try('server:getState') then
      try('server:getStatus')
    end
  end
end

-- Start-Hook (optional, falls genutzt)
RegisterNetEvent(ev('client:StartTheory'), function(category)
  theoryActive = true
  theoryCategory = category or 'car'
  theoryStartTick = now()
end)

-- Server -> Client: Booking Echo (Kategorie + Token merken)
RegisterNetEvent(ev('client:booked'), function(category, token)
  bookedCategory = category or bookedCategory
  sessionToken = token or sessionToken
end)

-- Natives Fallback-Result
local function showLocalSummary(passed, total, correct, neededCorrect, allowedErrors, usedSec)
  local header = passed and ((Config and Config.Labels and Config.Labels.PassedHeader) or 'Bestanden')
                         or ((Config and Config.Labels and Config.Labels.FailedHeader) or 'Nicht bestanden')
  local msgFull = string.format('%s\nRichtig: %d/%d (>= %d nötig)\nErlaubte Fehler: %d\nZeit: %ds',
    header, correct, total, neededCorrect, allowedErrors, usedSec)

  tryGetESX()
  if ESX and ESX.ShowAdvancedNotification then
    ESX.ShowAdvancedNotification((Config and (Config.UIName or (Config.UI and Config.UI.Name))) or 'Fahrschule', 'Theorie', msgFull, (Config and (Config.UILogo or (Config.UI and Config.UI.Logo))) or 'CHAR_DEFAULT', 1)
  elseif ESX and ESX.ShowNotification then
    ESX.ShowNotification(msgFull)
  else
    BeginTextCommandThefeedPost('STRING'); AddTextComponentSubstringPlayerName(msgFull); EndTextCommandThefeedPostTicker(false, false)
  end
end

-- Theorie sauber beenden: Daten berechnen, UI öffnen, Fokus/Maus halten, bis Close kommt
local function finishTheory(category, totalQuestions, correctAnswers, percentOpt)
  if theoryFinishing then return end
  theoryFinishing = true

  category = category or theoryCategory or bookedCategory or 'car'
  local total = tonumber(totalQuestions) or ((Config and Config.Theory and Config.Theory.QuestionsPerTest) or 25)
  local correct = math.max(0, math.min(tonumber(correctAnswers) or 0, total))

  -- Prozent ggf. aus Payload übernehmen (falls UI keine Detailzahlen sendet)
  local scorePct = tonumber(percentOpt)
  if not scorePct then
    if total > 0 then
      scorePct = math.floor((correct / total) * 100 + 0.5)
    else
      scorePct = 0
    end
  end

  local passPct = (Config and Config.Theory and Config.Theory.PassPercentage) or 80
  local neededCorrect = math.ceil((total * passPct) / 100.0)
  local allowedErrors = math.max(total - neededCorrect, 0)

  local usedSec = 0
  if theoryStartTick then
    usedSec = math.max(0, math.floor(((now() - theoryStartTick) / 1000.0) + 0.5))
  end

  local passed = (scorePct >= passPct) or (correct >= neededCorrect)

  -- Ergebnis an NUI schicken (zwei Typen zur Kompatibilität)
  local payload = {
    passed = passed,
    totalQuestions = total,
    correctAnswers = correct,
    neededCorrect  = neededCorrect,
    allowedErrors  = allowedErrors,
    passPercent    = passPct,
    usedSeconds    = usedSec,
    scorePercent   = scorePct
  }
  pcall(function() SendNUIMessage({ type = 'theory-result', payload = payload }) end)
  pcall(function() SendNUIMessage({ type = 'theory:result', payload = payload }) end)

  -- Ergebnis-UI "öffnen"/fokussieren: Fokus aktiv bis Close
  resultOpen = true
  setFocus(true)
  startControlLock()

  -- Token sicherstellen (falls Booking-Event verpasst wurde)
  if not sessionToken or sessionToken == '' then
    requestServerStateOnce(function()
      TriggerServerEvent(ev('server:theoryResult'), category, sessionToken, passed, scorePct)
    end)
  else
    TriggerServerEvent(ev('server:theoryResult'), category, sessionToken, passed, scorePct)
  end

  -- Zusätzlich natives Fallback anzeigen
  showLocalSummary(passed, total, correct, neededCorrect, allowedErrors, usedSec)

  -- Status-Flags zurücksetzen (UI bleibt offen bis Close)
  CreateThread(function()
    Wait(200)
    theoryActive = false
    theoryStartTick = nil
    theoryCategory = nil
    theoryFinishing = false
  end)
end

-- NUI Close-Button
RegisterNUICallback('mtj_theory_close', function(_, cb)
  resultOpen = false
  pcall(function() SendNUIMessage({ type = 'theory-close' }) end)
  setFocus(false)
  resetCameraAndControls()
  if cb then cb({ ok = true }) end
end)

-- Fallback-Command, falls NUI nicht reagiert
RegisterCommand('theoryclose', function()
  if resultOpen then
    resultOpen = false
    pcall(function() SendNUIMessage({ type = 'theory-close' }) end)
    setFocus(false)
    resetCameraAndControls()
  end
end, false)

-- NUI Submit-Callback deiner Theorie-UI
-- payload erwartet: { category, total, correct } ODER { category, percentage }
RegisterNUICallback('mtj_theory_submit', function(data, cb)
  if theoryFinishing then if cb then cb({ ok = false, reason = 'finishing' }) end return end

  local category = (data and data.category) or theoryCategory or bookedCategory or 'car'
  local percent  = (data and (tonumber(data.percentage) or tonumber(data.scorePct)))
  local total    = (data and tonumber(data.total)) or (Config and Config.Theory and Config.Theory.QuestionsPerTest) or 25
  local correct  = (data and tonumber(data.correct)) or nil

  finishTheory(category, total, correct or 0, percent)
  if cb then cb({ ok = true }) end
end)

-- Alternativer Trigger (z. B. Debug)
RegisterNetEvent(ev('client:FinishTheory'), function(category, totalQuestions, correctAnswers, percentOpt)
  finishTheory(category, totalQuestions, correctAnswers, percentOpt)
end)

-- Server -> Client: Outcome (optional, nur zur Info/Sync; UI bleibt offen bis der Spieler schließt)
RegisterNetEvent(ev('client:theoryOutcome'), function(passed, scorePct, detail)
  -- Keine UI-Manipulation hier, um Doppelsteuerung zu vermeiden.
  local msg
  if passed then
    msg = (Config and Config.Labels and Config.Labels.TheoryPassed) or 'Theorie bestanden! Gehe zu Punkt 3.'
  else
    msg = (Config and Config.Labels and Config.Labels.TheoryFailed) or 'Theorie nicht bestanden.'
  end
  if scorePct ~= nil then
    msg = string.format('%s (%d%%)', msg, tonumber(scorePct) or 0)
  end
  tryGetESX()
  if ESX and ESX.ShowNotification then ESX.ShowNotification(msg) end
end)

-- Fail-safe bei Resource-Stop
AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  resultOpen = false
  setFocus(false)
  resetCameraAndControls()
end)