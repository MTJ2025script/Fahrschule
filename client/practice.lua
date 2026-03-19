--[[
========================================================================================================================
  Datei       : client/practice.lua
  Version     : v1.6.1
  Build       : 2025-10-19
  Autor       : MTJ2024
  Lizenz      : Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten.

  Änderungen:
    - Harter Leitweg-Cleanup (Waypoint/GPS/Blip-Route) bei Ende/Abbruch.
    - Luft-Ideallinie bleibt nur während Prüfung aktiv; nach Abbruch blockiert (idealLineBlocked) bis neuem Start.
    - Optionaler Auto-Teleport zu Punkt 1 bei Abbruch (Config.Practice.AbortRespawn).
    - Optionales Stoppen aller UI-Timer bei Abbruch (Config.Practice.StopUITimersOnAbort).
========================================================================================================================
]]--

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
tryGetESX()

local function RES() return (Config and Config.ResourceName) or GetCurrentResourceName() or 'mtj_fahrschule' end
local function ev(path) return RES() .. ':' .. path end
print(('[%s][practice] practice.lua geladen (v1.6.1)'):format(RES()))

-- State
local practiceActive = false
local practiceStartedAt = 0
local currentCategory, routeIndex, route = nil, 0, nil
local vehicle, npc = 0, 0
local blipNext, blipFinish = 0, 0
local cpNext, cpFinish = 0, 0
local errors, errorCounts = {}, {}
local lastHealth, practiceGraceUntil = nil, 0
local ringPrevDistance = nil
local lastGpsBuildIdx = -1

local landingPhase = false
local onGroundAccumMs = 0

local collisionCooldownUntil = 0
local lastBodyHealth = nil
local offRouteSince = 0

local groundArrowThread = nil
local groundArrowActive = false
local groundArrowCfg = nil
local groundArrowPos = nil
local groundArrowNextPos = nil

local idealLineThread = nil
local idealLineActive = false
local idealLinePoints = {}
local idealLineBlocked = false -- nach Abbruch blockiert bis nächster Start

local stationaryAccumMs = 0
local autoAbortMs = 3000

local clientLastMovingTime = 0
local clientLastVehicleTime = 0
local clientHeartbeatThread = nil

-- Helpers
local function now() return GetGameTimer() end
local function unixNowSecs() return (type(os)=='table' and os.time and os.time()) or math.floor(GetGameTimer()/1000) end
local function kmh(ms) return ms * 3.6 end

local function safeTriggerServer(evn, payload) pcall(function() TriggerServerEvent(evn, payload) end) end

local function ownNetworkEntity(ent)
  if not ent or not DoesEntityExist(ent) then return end
  local id = NetworkGetNetworkIdFromEntity(ent)
  if id and id ~= 0 then
    SetNetworkIdExistsOnAllMachines(id, true)
    SetNetworkIdCanMigrate(id, false)
  end
  SetEntityAsMissionEntity(ent, true, true)
end

local function reqModel(m)
  if not m or m == '' then return nil end
  local h = type(m) == 'number' and m or GetHashKey(m)
  if not IsModelInCdimage(h) then return nil end
  RequestModel(h)
  local t = now() + 10000
  while not HasModelLoaded(h) and now() < t do Wait(10) end
  if not HasModelLoaded(h) then return nil end
  return h
end

local function vehicleClassIsAir(veh)
  if veh == 0 or not DoesEntityExist(veh) then return false end
  local cls = GetVehicleClass(veh)
  return (cls == 15 or cls == 16)
end
local function isGroundCategory(cat) return cat == 'car' or cat == 'bike' or cat == 'truck' end
local function isAirCategory(cat) return cat == 'heli' or cat == 'plane' end

-- UI Timer (NUI) stoppen (optional per Config)
local function stopAllUITimers()
  local pr = Config and Config.Practice
  if pr == nil or pr.StopUITimersOnAbort ~= false then
    pcall(function()
      SendNUIMessage({ action = 'stopAllTimers' })
    end)
  end
end

-- Teleport bei Abbruch zu Punkt 1 (oder konfiguriert)
local function respawnToAbortPoint()
  local pr = Config and Config.Practice
  local rx = pr and pr.AbortRespawn
  if not (rx and rx.enabled) then return end
  local dest = (rx.position and rx.position.x and rx.position) or (Config and Config.Points and Config.Points.booking)
  if not dest then return end

  local ped = PlayerPedId()
  local useFade = (rx.fade ~= false)
  local freezeSec = tonumber(rx.freezeSeconds) or 0.0
  
  if useFade then 
    DoScreenFadeOut(400)
    local t = now() + 1200
    while not IsScreenFadedOut() and now() < t do Wait(0) end
  end
  
  -- Update ped reference after potential respawn
  ped = PlayerPedId()
  
  -- Clear tasks and ensure ped is not in vehicle
  ClearPedTasksImmediately(ped)
  if IsPedInAnyVehicle(ped, false) then
    local veh = GetVehiclePedIsIn(ped, false)
    TaskLeaveVehicle(ped, veh, 0)
    Wait(500)
    ped = PlayerPedId() -- Update again after leaving vehicle
  end
  
  FreezeEntityPosition(ped, true)
  RequestCollisionAtCoord(dest.x, dest.y, dest.z)
  SetEntityCoordsNoOffset(ped, dest.x, dest.y, dest.z, false, false, false)
  if dest.w then SetEntityHeading(ped, dest.w) end
  
  local ddl = now() + 1500
  while not HasCollisionLoadedAroundEntity(ped) and now() < ddl do
    RequestCollisionAtCoord(dest.x, dest.y, dest.z)
    Wait(0)
  end
  
  if freezeSec > 0 then Wait(math.floor(freezeSec * 1000)) end
  
  -- Always unfreeze, even if ped changed (get current ped)
  ped = PlayerPedId()
  if DoesEntityExist(ped) then
    FreezeEntityPosition(ped, false)
  end
  
  if useFade then DoScreenFadeIn(400) end
end

-- Blips/Checkpoints helpers
local function safeRemoveBlip(b) if b ~= 0 and b ~= nil then pcall(RemoveBlip, b) end end
local function clearBlips()
  if blipNext   ~= 0 then pcall(SetBlipRoute, blipNext,   false); safeRemoveBlip(blipNext);   blipNext   = 0 end
  if blipFinish ~= 0 then pcall(SetBlipRoute, blipFinish, false); safeRemoveBlip(blipFinish); blipFinish = 0 end
end
local function setBlipName(b, isFinish, nextIdx, total)
  if not b then return end
  BeginTextCommandSetBlipName('STRING')
  if isFinish then AddTextComponentString('Prüfung – Ziel') else
    local n = math.max(1, math.tointeger(nextIdx or 1) or math.floor(nextIdx or 1))
    local t = math.max(1, math.tointeger(total  or 1) or math.floor(total  or 1))
    AddTextComponentString(string.format('Prüfung – Punkt %d/%d', n, t))
  end
  EndTextCommandSetBlipName(b)
end
local function makeBlipAt(pos, cat, isFinish, nextIdx, total)
  if not pos then return 0 end
  local b = AddBlipForCoord(pos.x, pos.y, pos.z)
  local catCfg = (Config and Config.CategoryBlips and Config.CategoryBlips[cat]) or {}
  local sprite = isFinish and ((Config and Config.RouteBlipSpriteEnd) or 434) or (catCfg.sprite or ((Config and Config.RouteBlipSprite) or 615))
  local color  = isFinish and ((Config and Config.RouteBlipColorEnd) or 2)    or (catCfg.color  or ((Config and Config.RouteBlipColor)  or 3))
  local scale  = catCfg.scale or 1.0
  SetBlipSprite(b, sprite)
  SetBlipDisplay(b, 4)
  SetBlipScale(b, scale)
  SetBlipColour(b, color)
  SetBlipAsShortRange(b, false)
  SetBlipRoute(b, false)
  setBlipName(b, isFinish, nextIdx, total)
  return b
end

local function clearCheckpoints()
  if cpNext   ~= 0 and cpNext   ~= nil then pcall(DeleteCheckpoint, cpNext);   cpNext   = 0 end
  if cpFinish ~= 0 and cpFinish ~= nil then pcall(DeleteCheckpoint, cpFinish); cpFinish = 0 end
end

-- Harter Leitweg-Cleanup (alles visuelle stoppen)
local function hardClearGuidance()
  clearBlips()
  clearCheckpoints()
  pcall(SetGpsMultiRouteRender, false)
  pcall(ClearGpsMultiRoute)
  pcall(SetWaypointOff)
  if type(stopDistanceHud) == 'function' then stopDistanceHud() end
  if type(stopGroundArrow) == 'function' then stopGroundArrow() end
  idealLineActive = false
  idealLineThread = nil
  idealLinePoints = {}
end

local function categoryMarker(cat)
  local mk = (Config and Config.CategoryMarkers and Config.CategoryMarkers[cat]) or {}
  return {
    type  = (cat == 'heli' or cat == 'plane') and 45 or (mk.type or 4),
    sx    = (mk.scale and mk.scale.x) or ((cat=='plane' and 16.0) or (cat=='heli' and 12.0) or 3.0),
    sz    = (mk.scale and mk.scale.z) or ((cat=='plane' and 4.0)  or (cat=='heli' and 3.0)  or 1.8),
    r     = (mk.color and mk.color.r) or 255,
    g     = (mk.color and mk.color.g) or 40,
    b     = (mk.color and mk.color.b) or 40,
    a     = (mk.color and mk.color.a) or 220
  }
end

local function ringForceVertical() return not (Config and Config.RingForceVertical == false) end

local function createCheckpointAt(cat, pos, nextPos, isFinish)
  if not pos then return 0 end
  local m = categoryMarker(cat)
  local r,g,b,a = m.r, m.g, m.b, m.a
  if isFinish then r,g,b = 0,255,120 end
  local nx,ny,nz
  if (cat == 'heli' or cat == 'plane') then
    if nextPos then nx,ny = nextPos.x, nextPos.y else nx,ny = pos.x + 5.0, pos.y end
    nz = ringForceVertical() and pos.z or (nextPos and nextPos.z or pos.z)
  else
    nx,ny,nz = (nextPos and nextPos.x or pos.x), (nextPos and nextPos.y or pos.y), (nextPos and nextPos.z or pos.z)
  end
  local id = CreateCheckpoint(m.type, pos.x, pos.y, pos.z, nx, ny, nz, m.sx, r, g, b, a, 0)
  if not (cat == 'heli' or cat == 'plane') then SetCheckpointCylinderHeight(id, m.sz, m.sz, m.sz) end
  SetCheckpointIconRgba(id, 255, 255, 255, 0)
  SetCheckpointRgba(id, r, g, b, a)
  return id
end

local function stopGroundArrow()
  groundArrowActive = false
  groundArrowPos, groundArrowNextPos, groundArrowCfg = nil, nil, nil
  groundArrowThread = nil
end
local function startGroundArrow()
  if groundArrowThread then return end
  groundArrowActive = true
  groundArrowThread = true
  CreateThread(function()
    while practiceActive and groundArrowActive do
      Wait(0)
      if groundArrowPos and groundArrowCfg then
        local arrow = groundArrowCfg
        local rotZ = 0.0
        if groundArrowNextPos then
          local dx = groundArrowNextPos.x - groundArrowPos.x
          local dy = groundArrowNextPos.y - groundArrowPos.y
          rotZ = math.deg(math.atan2(dx, dy)) or 0.0
        end
        DrawMarker(
          arrow.type or 2,
          groundArrowPos.x, groundArrowPos.y, groundArrowPos.z,
          0.0, 0.0, 0.0,
          0.0, 0.0, rotZ,
          (arrow.scale and arrow.scale.x) or 1.0,
          (arrow.scale and arrow.scale.y) or 1.0,
          (arrow.scale and arrow.scale.z) or 1.6,
          (arrow.color and arrow.color.r) or 255,
          (arrow.color and arrow.color.g) or 255,
          (arrow.color and arrow.color.b) or 255,
          (arrow.color and arrow.color.a) or 150,
          false, false, 2, false, nil, nil, false
        )
      end
    end
    stopGroundArrow()
  end)
end

local function buildGpsRouteFrom(startIdx)
  if startIdx == lastGpsBuildIdx then return end
  lastGpsBuildIdx = startIdx
  ClearGpsMultiRoute()
  StartGpsMultiRoute(120, 3, 255, true)
  for i = math.max(2, startIdx), #route do
    local p = route[i].pos
    AddPointToGpsMultiRoute(p.x, p.y, p.z)
  end
  SetGpsMultiRouteRender(true)
end

-- IDEALLINIE builder & drawer
local function rebuildIdealLine(cat)
  idealLinePoints = {}
  if idealLineBlocked then return end -- nach Abbruch blockiert
  local cfg = Config and Config.IdealLine
  if not (cfg and cfg.enabled) then return end
  if not route or (#route < 2) then return end
  local isAir = isAirCategory(cat) or vehicleClassIsAir(vehicle)
  if not isAir and not (cfg.ground and cfg.ground.enabled == true) then return end

  local step = isAir and ((cfg.air and cfg.air.step) or 24.0) or ((cfg.ground and cfg.ground.step) or 12.0)
  local maxPts = cfg.maxPoints or 1200
  local useGroundZ = (not isAir) and (cfg.ground and cfg.ground.useGroundZ ~= false)
  local zOffset = (cfg.ground and cfg.ground.zOffset) or 0.05
  local startI = math.max(2, (routeIndex or 1) + 1)
  local totalAdded = 0
  for i = startI, #route do
    local a = route[i - 1].pos
    local b = route[i].pos
    if a and b then
      local ax, ay, az = a.x, a.y, a.z
      local bx, by, bz = b.x, b.y, b.z
      local dx, dy, dz = (bx - ax), (by - ay), (bz - az)
      local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
      if dist > 0.1 then
        local steps = math.max(1, math.floor(dist / step))
        local inv = 1.0 / steps
        for s = 0, steps do
          local t = s * inv
          local x = ax + dx * t
          local y = ay + dy * t
          local z
          if isAir then
            z = az + dz * t
          else
            if useGroundZ then
              local ok, gz = GetGroundZFor_3dCoord(x, y, az + 50.0, false)
              z = (ok and gz or (az + dz * t)) + zOffset
            else
              z = (az + dz * t) + zOffset
            end
          end
          idealLinePoints[#idealLinePoints + 1] = { x = x, y = y, z = z }
          totalAdded = totalAdded + 1
          if totalAdded >= maxPts then break end
        end
      end
    end
    if totalAdded >= maxPts then break end
  end
end

local function startIdealLineThread()
  if idealLineThread then return end
  if idealLineBlocked then
    idealLineActive = false
    idealLineThread = nil
    idealLinePoints = {}
    return
  end
  idealLineActive = true
  idealLineThread = true
  CreateThread(function()
    while practiceActive and idealLineActive do
      Wait(0)
      if idealLineBlocked then break end
      local cfg = Config and Config.IdealLine
      if not (cfg and cfg.enabled) then goto cont end
      if landingPhase and (cfg.drawInLandingPhase == false) then goto cont end
      local cam = GetGameplayCamCoords()
      local isAirNow = isAirCategory(currentCategory) or vehicleClassIsAir(vehicle)
      if not isAirNow and not (cfg.ground and cfg.ground.enabled == true) then goto cont end
      local size = isAirNow and ((cfg.air and cfg.air.size) or vec3(1.2,1.2,1.2)) or ((cfg.ground and cfg.ground.size) or vec3(1.2,1.2,0.4))
      local color = isAirNow and ((cfg.air and cfg.air.color) or { r=0,g=200,b=200,a=110 }) or ((cfg.ground and cfg.ground.color) or { r=0,g=200,b=200,a=90 })
      local cull = (cfg.cullDistance or 220.0)
      local cullSq = cull * cull
      for i = 1, #idealLinePoints do
        if idealLineBlocked then break end
        local p = idealLinePoints[i]
        local dx, dy, dz = (p.x - cam.x), (p.y - cam.y), (p.z - cam.z)
        local dd = dx*dx + dy*dy + dz*dz
        if dd <= cullSq then
          DrawMarker(1, p.x, p.y, p.z, 0.0,0.0,0.0, 0.0,0.0,0.0, size.x, size.y, size.z, color.r or 0, color.g or 200, color.b or 200, color.a or 110, false,false,2,false,nil,nil,false)
        end
      end
      ::cont::
    end
    idealLineThread = nil
    idealLineActive = false
    idealLinePoints = {}
  end)
end

-- 3D helper text
local function draw3DTextAt(pos, text, height, scale)
  if not pos or not text then return end
  local onScreen, _x, _y = World3dToScreen2d(pos.x, pos.y, pos.z + (height or 2.8))
  if not onScreen then return end
  local camCoords = GetGameplayCamCoords()
  local dx = pos.x - camCoords.x
  local dy = pos.y - camCoords.y
  local dz = pos.z - camCoords.z
  local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
  local sc = math.max(0.60, math.min(1.50, (6.0 / math.max(dist, 0.01))) * (scale or 1.0))
  SetTextFont(4)
  SetTextScale(sc, sc)
  SetTextCentre(true)
  SetTextColour(255, 255, 255, 240)
  SetTextOutline()
  SetTextDropshadow(1, 0, 0, 0, 255)
  BeginTextCommandDisplayText('STRING')
  AddTextComponentSubstringPlayerName(text)
  EndTextCommandDisplayText(_x, _y)
end

local function draw3DNumberAt(pos, idx, total, height, scale)
  local n = math.max(1, math.tointeger(idx or 1) or math.floor(idx or 1))
  local t = math.max(1, math.tointeger(total or 1) or math.floor(total or 1))
  draw3DTextAt(pos, string.format('%d/%d', n, t), height or 3.0, scale or 1.2)
end

-- setNextVisuals
local function setNextVisuals(cat, nextPos, finishPos, nextNextPos)
  local nextIdx = (routeIndex or 0) + 1
  local total = (route and #route or 1) - 1

  if nextPos then
    if blipNext ~= 0 then safeRemoveBlip(blipNext) end
    blipNext = makeBlipAt(nextPos, cat, false, nextIdx, total)
    if Config and Config.ShowRoute == true then
      SetNewWaypoint(nextPos.x, nextPos.y)
    end
  else
    if blipNext ~= 0 then safeRemoveBlip(blipNext); blipNext = 0 end
  end

  if finishPos then
    if blipFinish ~= 0 then safeRemoveBlip(blipFinish) end
    blipFinish = makeBlipAt(finishPos, cat, true)
  else
    if blipFinish ~= 0 then safeRemoveBlip(blipFinish); blipFinish = 0 end
  end

  clearCheckpoints()
  if nextPos   then cpNext   = createCheckpointAt(cat, nextPos, (nextNextPos or finishPos or nextPos), false) end
  if finishPos then cpFinish = createCheckpointAt(cat, finishPos, finishPos, true) end

  if isGroundCategory(cat) and nextPos then
    local arrowCfg = (Config and Config.Markers and Config.Markers.Arrow) or { type=2, scale=vec3(1.0,1.0,1.6), color={ r=255,g=255,b=255,a=150 } }
    groundArrowCfg = arrowCfg
    groundArrowPos = nextPos
    groundArrowNextPos = nextNextPos or finishPos or nextPos
    if not groundArrowThread then startGroundArrow() end
  else
    stopGroundArrow()
  end

  if Config and Config.ShowRoute == true then
    buildGpsRouteFrom(math.max(2, math.tointeger(nextIdx) or math.floor(nextIdx)))
  else
    SetGpsMultiRouteRender(false)
    ClearGpsMultiRoute()
  end

  rebuildIdealLine(cat)
  if #idealLinePoints > 0 then startIdealLineThread() end
end

-- Distance HUD (Top-Bar)
local distanceHudThread = nil
local function drawDistanceOverMinimap(nextPos)
  if not nextPos then return end
  local cfg = (Config and Config.DistanceHUD) or {}
  local ped = PlayerPedId()
  local my = GetEntityCoords(ped)

  local dx, dy, dz = (nextPos.x - my.x), (nextPos.y - my.y), (nextPos.z - my.z)
  local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
  local useKm = (cfg.unit == 'km') or (cfg.unit == 'auto' and dist >= 1000.0)
  local unit = useKm and 'km' or 'm'
  local shown = useKm and (dist / 1000.0) or dist
  local distStr = useKm and string.format('%.1f %s', shown, unit) or string.format('%d %s', math.floor(shown + 0.5), unit)

  local nextI = math.max(1, (routeIndex or 0) + 1)
  local total = math.max(1, (route and #route or 1) - 1)
  local isLast = (nextI >= total)
  local label = isLast and 'Ziel' or string.format('Punkt %d/%d', nextI, total)

  local altitudeStr = ''
  local wantAlt = (cfg.showAltitudeDelta ~= false) and (isAirCategory(currentCategory) or vehicleClassIsAir(vehicle))
  if wantAlt then
    local dzAlt = nextPos.z - my.z
    local sign = (dzAlt >= 0) and '+' or '-'
    altitudeStr = string.format('  Δ%s%dm', sign, math.floor(math.abs(dzAlt) + 0.5))
  end

  local text = string.format('%s — %s%s', label, distStr, altitudeStr)

  local bgColor   = cfg.minimapBackgroundColor or { r=0, g=0, b=0, a=170 }
  local airAccent = (Config and Config.MarkerUI and Config.MarkerUI.airAccent) or { r=0, g=200, b=200, a=220 }
  local defText   = cfg.minimapTextColor or { r=0, g=200, b=255, a=255 }
  local textColor = (isAirCategory(currentCategory) or vehicleClassIsAir(vehicle)) and airAccent or defText
  local accentCol = cfg.accentBarColor or (Config and Config.MarkerUI and Config.MarkerUI.accentColor) or { r=0, g=200, b=255, a=230 }

  local font      = cfg.minimapFont or 4
  local scale     = cfg.minimapScale or 0.45
  local posX      = cfg.minimapX or 0.50
  local posY      = cfg.minimapY or 0.06
  local padX      = 0.015
  local padY      = 0.020
  local accentW   = cfg.accentBarWidth or 0.006

  local len = string.len(text)
  local approxWidth  = math.max(0.12, 0.012 * len * (scale * 2.4)) + padX
  local approxHeight = 0.042 * (scale * 1.8) + padY

  DrawRect(posX, posY, approxWidth, approxHeight, bgColor.r, bgColor.g, bgColor.b, bgColor.a)
  DrawRect(posX, posY, approxWidth * 0.994, approxHeight * 0.992, math.min(255,(bgColor.r or 0)+12), math.min(255,(bgColor.g or 0)+12), math.min(255,(bgColor.b or 0)+12), math.min(255,(bgColor.a or 160)+20))

  local leftX = posX - (approxWidth / 2) + (accentW / 2)
  DrawRect(leftX, posY, accentW, approxHeight * 0.98, accentCol.r or 0, accentCol.g or 200, accentCol.b or 255, accentCol.a or 230)

  SetTextFont(font)
  SetTextProportional(1)
  SetTextScale(scale, scale)
  SetTextCentre(true)
  SetTextColour(textColor.r or 255, textColor.g or 255, textColor.b or 255, textColor.a or 255)
  SetTextDropshadow(2, 0, 0, 0, 200)
  SetTextOutline()
  BeginTextCommandDisplayText('STRING'); AddTextComponentSubstringPlayerName(text); EndTextCommandDisplayText(posX, posY)
end

local function startDistanceHud()
  if distanceHudThread then return end
  distanceHudThread = true
  CreateThread(function()
    while practiceActive and distanceHudThread do
      Wait(0)
      local nextEntry = route and route[routeIndex + 1]
      local next2Entry = route and route[routeIndex + 2]
      local finishEntry = route and route[#route]
      if not landingPhase and nextEntry and nextEntry.pos then
        drawDistanceOverMinimap(nextEntry.pos)
      end
      if not landingPhase then
        if nextEntry and nextEntry.pos then draw3DNumberAt(nextEntry.pos, math.max(1,(routeIndex or 0)+1), math.max(1,(#route-1)), 3.0, 1.2) end
        if next2Entry and next2Entry.pos then draw3DNumberAt(next2Entry.pos, math.max(1,(routeIndex or 0)+2), math.max(1,(#route-1)), 2.6, 1.0) end
        if finishEntry and finishEntry.pos and isAirCategory(currentCategory) then draw3DTextAt(finishEntry.pos, 'Ziel (Luft)', 2.4, 1.0) end
      end
    end
    distanceHudThread = nil
  end)
end
local function stopDistanceHud() distanceHudThread = nil end

-- FinishPractice
local function FinishPractice(reachedEnd)
  -- nach Abbruch (nicht bestanden) Luft-Ideallinie blockieren und UI-Timer stoppen
  if not reachedEnd then
    idealLineBlocked = true
    stopAllUITimers()
  end

  if not practiceActive then
    hardClearGuidance()
    if not reachedEnd then respawnToAbortPoint() end
    return
  end

  practiceActive = false
  landingPhase = false

  hardClearGuidance()

  local durationSec = 0
  if practiceStartedAt and practiceStartedAt > 0 then durationSec = math.max(0, math.floor((now() - practiceStartedAt)/1000)) end
  practiceStartedAt = 0

  if DoesEntityExist(vehicle) then SetVehicleDoorsLockedForAllPlayers(vehicle, false) end
  if DoesEntityExist(vehicle) then
    if IsPedInAnyVehicle(PlayerPedId(), false) then TaskLeaveVehicle(PlayerPedId(), vehicle, 0) end
    if DoesEntityExist(npc) and IsPedInAnyVehicle(npc, false) then TaskLeaveVehicle(npc, vehicle, 0) end
    Wait(500)
    if Config and Config.DeleteVehicleOnEnd then
      if DoesEntityExist(npc) then DeleteEntity(npc) end
      if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    end
  else
    if DoesEntityExist(npc) then DeleteEntity(npc) end
  end
  npc, vehicle = 0, 0

  local maxErr = ((Config and Config.Practice and Config.Practice.MaxErrors) or 5)
  local totalErr = #errors
  local passed = reachedEnd and (totalErr <= maxErr) or false
  local header = passed and ((Config and Config.Labels and Config.Labels.PassedHeader) or 'Bestanden') or ((Config and Config.Labels and Config.Labels.FailedHeader) or 'Nicht bestanden')
  local summary = string.format('%s\n%s: %d/%d', header, (Config and Config.Labels and Config.Labels.PracticeSummary) or 'Fehler', totalErr, maxErr)

  TriggerServerEvent(ev('server:practiceResult'), currentCategory, passed, errors, summary)

  local ts = unixNowSecs()
  local detail = { ts = ts, durationSec = durationSec, errors = errors, summary = summary, category = currentCategory }
  TriggerEvent(ev('client:practiceOutcome'), passed, errors, summary, detail)
  TriggerEvent(ev('client:practiceEnd'), { passed = passed, summary = summary, errors = errors, stats = {
    durationSec = durationSec, totalErrors = totalErr, maxAllowed = maxErr, errorsByType = errorCounts, category = currentCategory
  }})
  TriggerEvent(ev('client:practiceEndedForceCheck'))

  if not passed then respawnToAbortPoint() end

  currentCategory, routeIndex, route = nil, 0, nil
  errors, errorCounts = {}, {}
  lastHealth, practiceGraceUntil = nil, 0
  ringPrevDistance, lastGpsBuildIdx = nil, -1
  offRouteSince = 0
  lastBodyHealth = nil
  collisionCooldownUntil = 0
  stationaryAccumMs = 0
end

local function landingEnabledFor(cat)
  local cfg = (Config and Config.Landing and Config.Landing.enabledFor) or {}
  if type(cfg[cat]) == 'boolean' then return cfg[cat] end
  return isAirCategory(cat)
end

local function startLandingPhase()
  if landingPhase then return end
  landingPhase = true
  TriggerServerEvent(ev('server:landingPhase'), currentCategory)
  onGroundAccumMs = 0
  clearCheckpoints()
  if blipNext ~= 0 then safeRemoveBlip(blipNext); blipNext = 0 end
  if blipFinish ~= 0 then safeRemoveBlip(blipFinish); blipFinish = 0 end
  SetGpsMultiRouteRender(false)
  ClearGpsMultiRoute()
  stopGroundArrow()
  local _, _, _, _, mk, showMarker, hint = (function()
    local L = Config and Config.Landing or {}
    local zones = L.zones or {}
    local z = zones[currentCategory]
    local center = (z and z.center) or L.center or vector3(1335.6023, -3045.3633, 13.9444)
    local radius = (z and z.radius) or L.radius or 40.0
    local minOnGroundSec = L.minOnGroundSec or 2.0
    local maxTaxiKmh = L.maxTaxiSpeedKmh or 15.0
    local mk = L.marker or { type=1, scale=vec3(40.0,40.0,2.5), color={ r=0,g=255,b=120,a=140 } }
    local showMarker = (L.showMarker ~= false)
    local hint = L.hintText or 'Lande im grünen Bereich und steige aus, um die Prüfung zu beenden.'
    return center, radius, minOnGroundSec, maxTaxiKmh, mk, showMarker, hint
  end)()

  tryGetESX()
  if ESX and ESX.ShowHelpNotification then ESX.ShowHelpNotification(hint) else
    BeginTextCommandPrint('STRING'); AddTextComponentSubstringPlayerName(hint); EndTextCommandPrint(4000, true)
  end

  CreateThread(function()
    local center, radius, minOnGroundSec, maxTaxiKmh = (function()
      local L = Config and Config.Landing or {}
      local zones = L.zones or {}
      local z = zones[currentCategory]
      return (z and z.center) or L.center, (z and z.radius) or L.radius, L.minOnGroundSec or 2.0, L.maxTaxiSpeedKmh or 15.0
    end)()
    local lastTick = now()
    while practiceActive and landingPhase do
      Wait(0)
      local thisTick = now()
      local dt = thisTick - lastTick
      lastTick = thisTick
      if showMarker then
        DrawMarker(mk.type or 1, center.x, center.y, center.z, 0.0,0.0,0.0, 0.0,0.0,0.0, (mk.scale and mk.scale.x) or 40.0, (mk.scale and mk.scale.y) or 40.0, (mk.scale and mk.scale.z) or 2.5, (mk.color and mk.color.r) or 0, (mk.color and mk.color.g) or 255, (mk.color and mk.color.b) or 120, (mk.color and mk.color.a) or 140, false, false, 2, false, nil, nil, false)
      end
      local ped = PlayerPedId()
      local pedPos = GetEntityCoords(ped)
      local dx,dy = pedPos.x - center.x, pedPos.y - center.y
      local dist2D = math.sqrt(dx*dx + dy*dy)
      local inVeh = IsPedInAnyVehicle(ped, false)
      local inArea = dist2D <= radius
      if inVeh and DoesEntityExist(vehicle) then
        local speed = kmh(GetEntitySpeed(vehicle))
        local wheelsOnGround = IsVehicleOnAllWheels(vehicle)
        local height = GetEntityHeightAboveGround(vehicle) or 9999.0
        local onGround = wheelsOnGround or (height < 1.5)
        if inArea and onGround and speed <= maxTaxiKmh then onGroundAccumMs = onGroundAccumMs + dt else onGroundAccumMs = 0 end
      end
      if not inVeh then
        if inArea and onGroundAccumMs >= (minOnGroundSec * 1000.0) then
          FinishPractice(true)
          break
        else
          DrawMarker(1, pedPos.x, pedPos.y, pedPos.z-1.0, 0.0,0.0,0.0, 0.0,0.0,0.0, 1.0,1.0,0.5, 255,60,60,120, false,false,2,false,nil,nil,false)
        end
      end
    end
  end)
end

-- Heartbeat (Server-Watchdog)
local function startHeartbeat()
  if clientHeartbeatThread then return end
  clientHeartbeatThread = true
  CreateThread(function()
    while practiceActive do
      local emergencyCfg = (Config and Config.Practice and Config.Practice.Emergency) or {}
      local serverMaxStationary = tonumber(emergencyCfg.MaxStationarySeconds) or nil
      local earlyGraceMs = ((serverMaxStationary and math.floor(serverMaxStationary*1000) + 2000) or 10000)
      local earlyInterval = 1000
      local normalInterval = 2000

      local ped = PlayerPedId()
      local inVeh = false
      local vehEnt = nil
      local ok, iv = pcall(function() return IsPedInAnyVehicle(ped, false) end)
      if ok and iv then inVeh = true; vehEnt = GetVehiclePedIsIn(ped, false) end

      if vehEnt and DoesEntityExist(vehEnt) then
        local speed = GetEntitySpeed(vehEnt) or 0.0
        if speed and speed > 0.6 then clientLastMovingTime = now() end
        clientLastVehicleTime = now()
      else
        local pspd = GetEntitySpeed(ped) or 0.0
        if pspd and pspd > 0.6 then clientLastMovingTime = now() end
      end

      local nowMs = now()
      local sinceStart = (practiceStartedAt and practiceStartedAt > 0) and (nowMs - practiceStartedAt) or (earlyGraceMs + 1)
      local lastVehicleAgeMs, lastMovingAgeMs = 0, 0

      if sinceStart >= earlyGraceMs then
        lastVehicleAgeMs = (clientLastVehicleTime and math.max(0, nowMs - clientLastVehicleTime)) or 0
        lastMovingAgeMs  = (clientLastMovingTime and math.max(0, nowMs - clientLastMovingTime)) or 0
      end

      local isRoof, isFire, body = false, false, nil
      if vehEnt and DoesEntityExist(vehEnt) then
        isRoof = (IsEntityUpsidedown(vehEnt) == true) or (IsVehicleStuckOnRoof(vehEnt) == true)
        isFire = (IsEntityOnFire(vehEnt) == true)
        body = GetVehicleBodyHealth(vehEnt) or nil
      end

      safeTriggerServer(ev('server:practiceHeartbeat'), {
        lastVehicleAgeMs = lastVehicleAgeMs,
        lastMovingAgeMs  = lastMovingAgeMs,
        inVehicle        = inVeh or (sinceStart < earlyGraceMs),
        lastVehicleUnix  = unixNowSecs(),
        lastMovingUnix   = unixNowSecs(),
        onRoof           = isRoof,
        isOnFire         = isFire,
        bodyHealth       = body
      })

      Wait((sinceStart < earlyGraceMs) and earlyInterval or normalInterval)
    end
    clientHeartbeatThread = nil
  end)
end

-- StartPractice
function StartPractice(category, vehicleModel, npcModel)
  pcall(SetWaypointOff)
  idealLineBlocked = false -- nach neuem Start wieder erlauben
  if practiceActive then return end

  local deadline = now() + 6000
  while (not Config or not (Config.Routes and Config.Routes[category])) and now() < deadline do Wait(50) end
  if not category or not (Config and Config.Routes and Config.Routes[category]) or #Config.Routes[category] < 2 then
    print(('[%s][practice] Ungültige/zu kurze Route für %s'):format(RES(), tostring(category)))
    return
  end

  practiceActive = true
  safeTriggerServer(ev('server:practiceStart'), category)
  practiceStartedAt = now()
  landingPhase = false
  onGroundAccumMs = 0
  currentCategory = category
  route = Config.Routes[category]
  routeIndex = 1
  errors, errorCounts = {}, {}
  ringPrevDistance = nil
  lastGpsBuildIdx = -1

  local chosenModel = (vehicleModel and vehicleModel ~= '') and vehicleModel or ((Config and Config.Vehicles and Config.Vehicles[category]) or nil)
  local modelHash = reqModel(chosenModel)
  if not modelHash then practiceActive = false; print(('[%s][practice] Ungültiges Fahrzeugmodell %s'):format(RES(), tostring(chosenModel))); return end

  local spawn = route[1].pos
  if vehicle and DoesEntityExist(vehicle) then practiceActive = false; print(('[%s][practice] Vehicle already exists'):format(RES())); return end

  if _G and _G.mtj_fahrschule_spawn_lock then practiceActive = false; print(('[%s][practice] spawn lock active'):format(RES())); return end
  _G.mtj_fahrschule_spawn_lock = true
  CreateThread(function() Wait(2500); _G.mtj_fahrschule_spawn_lock = false end)

  vehicle = CreateVehicle(modelHash, spawn.x, spawn.y, spawn.z, (spawn.w or 0.0), true, false)
  if not DoesEntityExist(vehicle) then practiceActive = false; print(('[%s][practice] Fahrzeug-Spawn fehlgeschlagen'):format(RES())); return end
  ownNetworkEntity(vehicle)
  if not vehicleClassIsAir(vehicle) then SetVehicleOnGroundProperly(vehicle) end
  SetVehicleDirtLevel(vehicle, 0.0)
  SetVehicleEngineOn(vehicle, true, true, false)
  SetVehicleDoorsLockedForAllPlayers(vehicle, true)

  local nid = NetworkGetNetworkIdFromEntity(vehicle)
  if nid and nid ~= 0 then safeTriggerServer(ev('server:practiceVehicleSpawned'), nid) end

  local ped = PlayerPedId()
  RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
  SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z, false, false, false)
  SetEntityHeading(ped, spawn.w or 0.0)
  local t = now() + 2000
  while not HasCollisionLoadedAroundEntity(ped) and now() < t do RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z); Wait(50) end

  local placed = false
  for i=1,16 do TaskWarpPedIntoVehicle(ped, vehicle, -1); Wait(50); if GetPedInVehicleSeat(vehicle, -1) == ped then placed = true; break end end
  if not placed then SetPedIntoVehicle(ped, vehicle, -1) end

  if npcModel == nil then npcModel = (Config and Config.NPCModel) or 's_m_m_autoshop_01' end
  if npcModel ~= false and npcModel ~= '' then
    local nh = reqModel(npcModel)
    if nh then
      npc = CreatePedInsideVehicle(vehicle, 4, nh, 0, true, false)
      if not DoesEntityExist(npc) or GetPedInVehicleSeat(vehicle, 0) ~= npc then
        if DoesEntityExist(npc) then DeleteEntity(npc) end
        npc = CreatePedInsideVehicle(vehicle, 4, nh, 1, true, false)
      end
      if DoesEntityExist(npc) then
        ownNetworkEntity(npc)
        SetBlockingOfNonTemporaryEvents(npc, true)
        SetEntityInvincible(npc, true)
        SetPedCanBeTargetted(npc, false)
        SetPedCanRagdoll(npc, false)
      end
    end
  end

  FreezeEntityPosition(vehicle, true)
  Wait(math.floor((((Config and Config.Practice and Config.Practice.FreezeAtStartSeconds) or 2.0)) * 1000))
  FreezeEntityPosition(vehicle, false)

  practiceGraceUntil = now() + math.floor((((Config and Config.Practice and Config.Practice.StartGraceSeconds) or 4.0)) * 1000)
  lastHealth = GetEntityHealth(vehicle)
  lastBodyHealth = (DoesEntityExist(vehicle) and GetVehicleBodyHealth(vehicle)) or nil

  local nextp  = route[2] and route[2].pos or nil
  local next2  = route[3] and route[3].pos or nil
  local finish = route[#route].pos
  setNextVisuals(currentCategory, nextp, finish, next2)
  startDistanceHud()

  tryGetESX()
  if ESX and ESX.ShowHelpNotification then ESX.ShowHelpNotification((Config and Config.Labels and Config.Labels.PracticeStartInfo) or 'Praxis gestartet. Folge den Markierungen!') end

  stationaryAccumMs = 0
  clientLastMovingTime = now()
  clientLastVehicleTime = now()

  local initIsRoof, initIsFire, initBody = false, false, nil
  if DoesEntityExist(vehicle) then
    initIsRoof = (IsEntityUpsidedown(vehicle) == true) or (IsVehicleStuckOnRoof(vehicle) == true)
    initIsFire = (IsEntityOnFire(vehicle) == true)
    initBody   = GetVehicleBodyHealth(vehicle) or nil
  end
  safeTriggerServer(ev('server:practiceHeartbeat'), {
    lastVehicleAgeMs = 0, lastMovingAgeMs = 0, inVehicle = true,
    lastVehicleUnix = unixNowSecs(), lastMovingUnix = unixNowSecs(),
    onRoof = initIsRoof, isOnFire = initIsFire, bodyHealth = initBody
  })

  startHeartbeat()

  -- Checks/Progress
  CreateThread(function()
    local checkInterval = ((Config and Config.Practice and Config.Practice.TimeBetweenChecksMs) or 100)
    local speedTol = ((Config and Config.Practice and Config.Practice.SpeedCheckTolerance) or 8.0)
    local damageThresh = ((Config and Config.Practice and Config.Practice.DamageFailThreshold) or 700.0)
    local collisionEnabled = (Config and Config.Practice and Config.Practice.CollisionCheck) == true
    local collisionCooldown = ((Config and Config.Practice and Config.Practice.CollisionCooldownSeconds) or 2.0)
    local collisionMinSpeed = ((Config and Config.Practice and Config.Practice.CollisionMinSpeedKmh) or 10.0)
    local collisionMinBodyDrop = ((Config and Config.Practice and Config.Practice.CollisionMinBodyHealthDrop) or 10.0)
    local offRouteMaxDist = (Config and Config.Practice and Config.Practice.OffRouteDistance) or 120.0
    local offRouteSeconds = (Config and Config.Practice and Config.Practice.OffRouteSeconds) or 8.0
    local emergencyCfg = (Config and Config.Practice and Config.Practice.Emergency) or {}
    local minSpeedActive = (emergencyCfg.MinSpeedActiveKmh ~= nil) and emergencyCfg.MinSpeedActiveKmh or 3.0
    local autoAbortThresholdMs = (emergencyCfg and emergencyCfg.Enabled and tonumber(emergencyCfg.MaxStationarySeconds)) and (math.floor(tonumber(emergencyCfg.MaxStationarySeconds)*1000)) or autoAbortMs

    while practiceActive do
      Wait(checkInterval)
      if not DoesEntityExist(vehicle) then
        errors[#errors+1] = (Config.ErrorNames and Config.ErrorNames.notaustieg) or 'Notausstieg / Fahrzeug ausgefallen'
        errorCounts['notaustieg'] = (errorCounts['notaustieg'] or 0) + 1
        FinishPractice(false)
        break
      end

      local ped = PlayerPedId()
      local eng = GetVehicleEngineHealth(vehicle)
      if IsEntityDead(ped) or IsPedFatallyInjured(ped) or eng <= 0.0 or GetEntityHealth(vehicle) <= 0 or GetEntitySubmergedLevel(vehicle) >= 0.85 then
        errors[#errors+1] = (Config.ErrorNames and Config.ErrorNames.notaustieg) or 'Notausstieg / Fahrzeug ausgefallen'
        errorCounts['notaustieg'] = (errorCounts['notaustieg'] or 0) + 1
        FinishPractice(false)
        break
      end

      local inGrace = now() < practiceGraceUntil

      if not inGrace and lastHealth then
        local hp = GetEntityHealth(vehicle)
        if (lastHealth - hp) > damageThresh then
          errorCounts['damage'] = (errorCounts['damage'] or 0) + 1
          errors[#errors+1] = (Config and Config.ErrorNames and Config.ErrorNames.damage) or 'Fahrzeug stark beschädigt'
        end
        lastHealth = hp
      else
        lastHealth = GetEntityHealth(vehicle)
      end

      if not inGrace then
        local spd = kmh(GetEntitySpeed(vehicle))
        if spd >= (minSpeedActive or 3.0) then
          clientLastMovingTime = now()
          stationaryAccumMs = 0
        else
          stationaryAccumMs = stationaryAccumMs + checkInterval
        end

        local cur = route[routeIndex]
        if cur then
          local limits = Config and Config.SpeedLimits and Config.SpeedLimits[currentCategory]
          local limit = (limits and limits[cur.city and 'city' or 'rural']) or 50
          if kmh(GetEntitySpeed(vehicle)) > (limit + speedTol) then
            errorCounts['speeding'] = (errorCounts['speeding'] or 0) + 1
            errors[#errors+1] = (Config and Config.ErrorNames and Config.ErrorNames.speeding) or 'Überschreitung der Höchstgeschwindigkeit'
          end
        end

        if (Config and Config.Practice and Config.Practice.Emergency and Config.Practice.Emergency.Enabled) and stationaryAccumMs >= (autoAbortThresholdMs or autoAbortMs) then
          errors[#errors+1] = (Config.ErrorNames and Config.ErrorNames.notaustieg) or 'Notausstieg / Fahrzeug ausgefallen'
          errorCounts['notaustieg'] = (errorCounts['notaustieg'] or 0) + 1
          tryGetESX(); if ESX and ESX.ShowNotification then ESX.ShowNotification('Prüfung abgebrochen: Zu lange Stillstand') end
          FinishPractice(false)
          break
        end
      else
        stationaryAccumMs = 0
      end

      if collisionEnabled then
        local nowMs = now()
        local body = GetVehicleBodyHealth(vehicle) or 1000.0
        if lastBodyHealth then
          local drop = (lastBodyHealth - body)
          local spd = kmh(GetEntitySpeed(vehicle))
          if drop >= (collisionMinBodyDrop or 10.0) and spd >= (collisionMinSpeed or 10.0) and nowMs >= (collisionCooldownUntil or 0) then
            errorCounts['collision'] = (errorCounts['collision'] or 0) + 1
            errors[#errors+1] = (Config and Config.ErrorNames and Config.ErrorNames.collision) or 'Kollision / Rammen'
            collisionCooldownUntil = nowMs + math.floor((collisionCooldown or 2.0) * 1000)
          end
        end
        lastBodyHealth = body
      end

      local tgt = route[routeIndex + 1]
      if tgt and tgt.pos then
        local ppos = GetEntityCoords(PlayerPedId())
        local dist = #(ppos - vector3(tgt.pos.x, tgt.pos.y, tgt.pos.z))
        if dist >= (Config and Config.Practice and Config.Practice.OffRouteDistance or 120.0) then
          if offRouteSince == 0 then offRouteSince = now() end
          if (now() - offRouteSince) >= math.floor((Config and Config.Practice and Config.Practice.OffRouteSeconds or 8.0) * 1000) then
            errorCounts['route'] = (errorCounts['route'] or 0) + 1
            errors[#errors+1] = (Config and Config.ErrorNames and Config.ErrorNames.route) or 'Route verlassen / Checkpoint verpasst'
            offRouteSince = now()
          end
        else
          offRouteSince = 0
        end
      else
        offRouteSince = 0
      end
    end
  end)

  rebuildIdealLine(currentCategory)
  startIdealLineThread()

  CreateThread(function()
    while practiceActive do
      Wait(0)
      if landingPhase then Wait(50); goto cont end
      local nextIdx = routeIndex + 1
      local target = route and route[nextIdx]
      if not target or not target.pos then Wait(0); goto cont end

      local ped = PlayerPedId()
      local posToCheck = GetEntityCoords(ped)
      local inVeh = IsPedInAnyVehicle(ped, false)
      if inVeh and DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == ped then
        posToCheck = GetEntityCoords(vehicle)
      end

      if isAirCategory(currentCategory) or vehicleClassIsAir(vehicle) then
        if DoesEntityExist(vehicle) then
          local vpos = GetEntityCoords(vehicle)
          local dx, dy = (vpos.x - target.pos.x), (vpos.y - target.pos.y)
          local horizDist = math.sqrt(dx*dx + dy*dy)
          local m = categoryMarker(currentCategory)
          local ringRadius = math.max(18.0, (m.sx or 18.0))
          local zTol = (m.sz or 4.0) + 15.0
          local zDiff = math.abs(vpos.z - target.pos.z)
          if ringPrevDistance == nil then ringPrevDistance = horizDist end
          if ringPrevDistance > ringRadius and horizDist <= ringRadius and zDiff <= zTol then
            routeIndex = nextIdx
            ringPrevDistance = nil
            local nn = route[routeIndex+1] and route[routeIndex+1].pos or nil
            local finishPos = route[#route].pos
            setNextVisuals(currentCategory, nn, finishPos, route[routeIndex+2] and route[routeIndex+2].pos or nil)
            PlaySoundFrontend(-1, 'RACE_PLACED', 'HUD_AWARDS', true)
            Wait(120)
          else
            ringPrevDistance = horizDist
          end
        end
      else
        local radius = (Config and Config.CheckpointRadius) or 4.0
        local m = categoryMarker(currentCategory)
        local markerHint = (m.sx and m.sx * 0.75) or 0
        if markerHint > radius then radius = markerHint end
        local dx = posToCheck.x - target.pos.x
        local dy = posToCheck.y - target.pos.y
        local dz = posToCheck.z - (target.pos.z or posToCheck.z)
        local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
        if dist <= radius then
          routeIndex = nextIdx
          local nn = route[routeIndex+1] and route[routeIndex+1].pos or nil
          local finishPos = route[#route].pos
          setNextVisuals(currentCategory, nn, finishPos, route[routeIndex+2] and route[routeIndex+2].pos or nil)
          PlaySoundFrontend(-1, 'RACE_PLACED', 'HUD_AWARDS', true)
          Wait(120)
        end
      end

      if routeIndex >= (#route) then
        if landingEnabledFor(currentCategory) then startLandingPhase() else FinishPractice(true) end
        break
      end
      ::cont::
    end
  end)
end

-- Events
RegisterNetEvent(ev('client:StartPractice'), function(category, vehicleModel, npcModel) StartPractice(category, vehicleModel, npcModel) end)
RegisterNetEvent('mtj_fahrschule:client:StartPractice', function(category, vehicleModel, npcModel) StartPractice(category, vehicleModel, npcModel) end)
print(('[%s][practice] Event registriert: %s'):format(RES(), ev('client:StartPractice')))

RegisterNetEvent(ev('client:practiceForceAbort'), function(reasonKey, reasonLabel)
  -- nach Abbruch: Linie blockieren, UI-Timer anhalten, alles aufräumen
  idealLineBlocked = true
  stopAllUITimers()
  hardClearGuidance()
  if not practiceActive then
    respawnToAbortPoint()
    return
  end
  local label = reasonLabel or (Config and Config.ErrorNames and Config.ErrorNames[reasonKey]) or 'Abbruch'
  errors[#errors+1] = label
  errorCounts[reasonKey or 'notaustieg'] = (errorCounts[reasonKey or 'notaustieg'] or 0) + 1
  tryGetESX(); if ESX and ESX.ShowNotification then ESX.ShowNotification('Prüfung abgebrochen: '..label) end
  FinishPractice(false)
end)

-- Handler for watchdog-triggered abort (from main.lua)
RegisterNetEvent(ev('client:AbortPractice'), function(reason)
  -- Watchdog erkannt: death, collision, left_vehicle, etc.
  -- Cleanup + FinishPractice aufrufen
  idealLineBlocked = true
  stopAllUITimers()
  hardClearGuidance()
  
  if not practiceActive then
    -- Praxis ist schon beendet, nur cleanup + respawn
    if DoesEntityExist(npc) then DeleteEntity(npc) end
    if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    npc, vehicle = 0, 0
    respawnToAbortPoint()
    return
  end
  
  -- Praxis ist aktiv, Fehler hinzufügen und beenden
  local reasonKey = tostring(reason or 'notaustieg')
  local label = (Config and Config.ErrorNames and Config.ErrorNames[reasonKey]) or 'Crash / Notausstieg'
  errors[#errors+1] = label
  errorCounts[reasonKey] = (errorCounts[reasonKey] or 0) + 1
  
  tryGetESX()
  if ESX and ESX.ShowNotification then
    ESX.ShowNotification('Prüfung abgebrochen: ' .. label)
  end
  
  FinishPractice(false)
end)

RegisterNetEvent(ev('client:cleanupGuidance'), function() hardClearGuidance() end)

AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() then
    hardClearGuidance()
    pcall(SetWaypointOff)
    if practiceActive then
      FinishPractice(false)
    else
      if DoesEntityExist(npc) then DeleteEntity(npc) end
      if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    end
  end
end)