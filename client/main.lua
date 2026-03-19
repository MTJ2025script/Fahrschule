-- Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

-- mtj_fahrschule/client/main.lua
-- Visuelle Marker, GTA-Hint, Ideallinie, Debounce, robuster Praxis-Start
-- - Aktualisiert selectedCat bei stateSync/booked
-- - Startet Praxis via ESX Callback oder Event-Fallback
-- - Nutzt Config.ResourceName als Prefix
-- - Keine os.*-Nutzung (rein über GetGameTimer)

local RESOURCE = (Config and Config.ResourceName) or ((GetCurrentResourceName and GetCurrentResourceName()) or 'mtj_fahrschule')
local RESNAME  = RESOURCE

local selectedCat = nil
local lastInteract = { booking = 0, theory = 0, practice = 0 }
local INTERACT_COOLDOWN_MS = 1200

local function nowMs()
  local ok, t = pcall(GetGameTimer)
  if ok and type(t) == 'number' then return t end
  return 0
end

if math.clamp == nil then
  function math.clamp(v, a, b)
    if v < a then return a elseif v > b then return b else return v end
  end
end

local function dbg_enabled(chan)
  if not (Config and Config.Debug) then return false end
  if Config.Debug.Enable == true then return (Config.Debug[chan] ~= false) end
  return (Config.Debug[chan] == true)
end
local function dbg(chan, ...)
  if dbg_enabled(chan) then
    local p = {}
    for i=1,select('#', ...) do p[#p+1] = tostring(select(i,...)) end
    print(('[%s][client/main][%s] %s'):format(RESNAME, tostring(chan), table.concat(p,' ')))
  end
end
local function log(...)
  local p = {}
  for i=1,select('#', ...) do p[#p+1] = tostring(select(i,...)) end
  print(('[%s][client/main] %s'):format(RESNAME, table.concat(p,' ')))
end

-- ESX
local ESX = nil
local function tryGetESX()
  if ESX then return ESX end
  pcall(function() TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end) end)
  return ESX
end
CreateThread(function() tryGetESX() end)

-- ========= UI LIVE SYNC =========
local _mtj_ui_sync = { lastPush = 0 }
local function shallowMerge(dst, src)
  if type(dst)~='table' or type(src)~='table' then return end
  for k,v in pairs(src) do dst[k] = v end
end
local function safeSendNui(m) if type(m)~='table' then return end pcall(function() SendNUIMessage(m) end) end
local function safeSetNui(b1,b2) pcall(function() SetNuiFocus((b1==true),(b2==true)) end) end

local function pushUiConfig(force)
  local t = nowMs()
  if not force and (t - (_mtj_ui_sync.lastPush or 0)) < 600 then return end
  _mtj_ui_sync.lastPush = t

  local ui = (Config and Config.UI) or {}
  local labels = (Config and Config.Labels) or {}
  local prices = (Config and Config.Prices) or {}
  local markerUI = (Config and Config.MarkerUI) or {}
  local categories = (labels and labels.Categories) or { car='PKW', bike='Motorrad', truck='LKW', heli='Hubschrauber', plane='Flugzeug' }

  safeSendNui({
    action = 'uiConfig',
    ui = {
      name         = ui.Name or 'Fahrschule',
      schriftzug   = ui.Schriftzug or ui.Name or '',
      slogan       = ui.Slogan or '',
      logo         = Config.UILogo or Config.LogoURL or ui.Logo or '',
      bookingTitle = ui.BookingTitle or 'Fahrschule-Buchen',
      rightPane    = ui.RightPane or {}
    },
    labels = labels,
    prices = prices,
    categories = categories,
    markerUI = {
      accentColor = markerUI.accentColor,
      airAccent   = markerUI.airAccent,
      idealColor  = markerUI.idealColor,
    }
  })
end

CreateThread(function()
  Wait(300)
  pushUiConfig(true)
end)

RegisterNetEvent(RESOURCE..':client:UIConfigSync', function(payload)
  if type(payload) ~= 'table' then return end
  if payload.UI and type(payload.UI)=='table' then Config.UI = Config.UI or {}; shallowMerge(Config.UI, payload.UI) end
  if payload.Labels and type(payload.Labels)=='table' then Config.Labels = Config.Labels or {}; shallowMerge(Config.Labels, payload.Labels) end
  if payload.Prices and type(payload.Prices)=='table' then Config.Prices = Config.Prices or {}; shallowMerge(Config.Prices, payload.Prices) end
  pushUiConfig(true)
end)

-- Consume stateSync/booked to update selectedCat (+ optional UI-Merges)
RegisterNetEvent(RESOURCE..':client:stateSync', function(state)
  if type(state)=='table' then
    if state.category and type(state.category)=='string' and state.category ~= '' then
      selectedCat = state.category
      dbg('Practice', 'stateSync set selectedCat =', selectedCat)
    end
    if state.ui and type(state.ui)=='table' then Config.UI = Config.UI or {}; shallowMerge(Config.UI, state.ui) end
    if state.labels and type(state.labels)=='table' then Config.Labels = Config.Labels or {}; shallowMerge(Config.Labels, state.labels) end
    if state.prices and type(state.prices)=='table' then Config.Prices = Config.Prices or {}; shallowMerge(Config.Prices, state.prices) end
    pushUiConfig(true)
  end
end)
RegisterNetEvent(RESOURCE..':client:booked', function(category, token)
  if category and type(category)=='string' and category ~= '' then
    selectedCat = category
    dbg('Practice', 'booked set selectedCat =', selectedCat, ' token=', tostring(token))
  end
end)

-- Wrapper: vor jedem UI-Open aktuelle Config ins NUI pushen
local function sendUiAndOpen(payload)
  pushUiConfig(true)
  safeSendNui(payload)
end

-- Helpers
local function toVec3(v)
  if not v then return nil end
  local t=type(v)
  if t=='table' then
    if v.x~=nil and v.y~=nil and v.z~=nil then return tonumber(v.x),tonumber(v.y),tonumber(v.z) end
    if tonumber(v[1]) and tonumber(v[2]) and tonumber(v[3]) then return tonumber(v[1]),tonumber(v[2]),tonumber(v[3]) end
  elseif t=='userdata' then
    local ok1,x=pcall(function() return v.x end); local ok2,y=pcall(function() return v.y end); local ok3,z=pcall(function() return v.z end)
    if ok1 and ok2 and ok3 and x and y and z then return tonumber(x),tonumber(y),tonumber(z) end
    local ok4,i1=pcall(function() return v[1] end); local ok5,i2=pcall(function() return v[2] end); local ok6,i3=pcall(function() return v[3] end)
    if ok4 and ok5 and ok6 and tonumber(i1) and tonumber(i2) and tonumber(i3) then return tonumber(i1),tonumber(i2),tonumber(i3) end
  else
    local ok,s=pcall(function() return tostring(v) end)
    if ok and type(s)=='string' then
      local inner=s; local i1=s:find('%('); local i2=s:find(')'); if i1 and i2 and i2>i1 then inner=s:sub(i1+1,i2-1) end
      local nums={}; for num in inner:gmatch('[-+]?%d+%.?%d*') do nums[#nums+1]=tonumber(num); if #nums>=3 then break end end
      if #nums>=3 then return nums[1],nums[2],nums[3] end
      local a,b,c=s:match('([-+]?%d+%.?%d*)%D+([-+]?%d+%.?%d*)%D+([-+]?%d+%.?%d*)')
      if a and b and c then a=tonumber(a); b=tonumber(b); c=tonumber(c); if a and b and c then return a,b,c end end
    end
  end
  dbg('Markers','toVec3 failed for', tostring(v))
  return nil
end

local function getMarkerUI()
  local ui = (Config and Config.MarkerUI) or {}
  return {
    enabled         = ui.enabled ~= false,
    pulse           = ui.pulseEnabled ~= false,
    accentBar       = ui.accentBar ~= false,
    bgColor         = ui.bgColor or { r=0,g=0,b=0,a=210 },
    innerBgColor    = ui.innerBgColor or { r=20,g=20,b=20,a=220 },
    accentColor     = ui.accentColor or { r=0,g=200,b=200,a=210 },
    textFont        = ui.textFont or 4,
    fontScaleFactor = tonumber(ui.fontScaleFactor) or 1.0,
    baseScaleFactor = tonumber(ui.baseScaleFactor) or 1.0,
    minScale        = tonumber(ui.minScale) or 0.65,
    maxScale        = tonumber(ui.maxScale) or 1.05,
    showKeyLabel    = ui.showKeyLabel ~= false,
    keyLabelMap     = ui.keyLabelMap or {},
    hintTemplate    = ui.hintTemplate or '~INPUT_CONTEXT~ Drücke E',
    airAccent       = ui.airAccent or { r=0, g=200, b=200, a=200 },
    idealColor      = ui.idealColor or (Config and Config.IdealLine and Config.IdealLine.air and Config.IdealLine.air.color) or { r=0, g=200, b=200, a=120 },
    drawDistanceMin = ui.drawDistanceMin
  }
end

local function controlCodeToLabel(code, map)
  local c=tonumber(code) or 38
  if map and map[tostring(c)] then return tostring(map[tostring(c)]) end
  local d={ [38]='E',[23]='F',[22]='SPACE',[47]='G',[244]='M',[29]='B' }
  return d[c] or 'E'
end

local function drawWorldMarker(x,y,z, baseScale, color, mkType, markerUI)
  if not x or not y or not z then return end
  mkType = tonumber(mkType) or 1
  local sx,sy,sz = 1.8,1.8,1.8
  if type(baseScale)=='table' then
    if baseScale.x then sx,sy,sz = tonumber(baseScale.x) or sx, tonumber(baseScale.y) or sy, tonumber(baseScale.z) or sz end
    if tonumber(baseScale[1]) then sx,sy,sz = tonumber(baseScale[1]), tonumber(baseScale[2]), tonumber(baseScale[3]) end
  elseif type(baseScale)=='number' then sx,sy,sz = baseScale,baseScale,baseScale end
  sx = sx * (markerUI.baseScaleFactor or 1.0)
  sy = sy * (markerUI.baseScaleFactor or 1.0)
  sz = sz * (markerUI.baseScaleFactor or 1.0)
  local pulse = markerUI.pulse and (1.0 + 0.18 * math.sin((nowMs()/700) * math.pi * 2)) or 1.0
  local dx,dy,dz = sx * pulse, sy * pulse, math.max(0.4, sz * (0.9 + 0.15 * pulse))
  local r,g,b,a = (color and color.r) or 0, (color and color.g) or 180, (color and color.b) or 255, (color and color.a) or 180
  DrawMarker(mkType, x, y, z - 0.6, 0.0,0.0,0.0, 0.0,0.0,0.0, dx,dy,dz, r,g,b,a, false, true, 2, false, nil, nil, false)
end

local function drawGTAHint(x,y,z, template, markerUI, keyLabel)
  if not x or not y or not z then return end
  local tpl = tostring(template or '~INPUT_CONTEXT~ Drücke E')
  local cleaned = tpl
  if markerUI.showKeyLabel and keyLabel and keyLabel ~= '' then
    cleaned = cleaned:gsub('%s*~INPUT_CONTEXT~%s*', '{KEY} ')
  else
    cleaned = cleaned:gsub('%s*~INPUT_CONTEXT~%s*', '')
  end
  cleaned = cleaned:gsub('~',''):gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$','')
  local text = cleaned:gsub('{KEY}',''):gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$','')
  local ok,sx,sy = World3dToScreen2d(x, y, z + 1.1) if not ok then return end
  local cam = GetGameplayCamCoords()
  local dx,dy,dz = x - cam.x, y - cam.y, (z + 1.1) - cam.z
  local dist = math.max(1.0, math.sqrt(dx*dx + dy*dy + dz*dz))
  local scaleBase = math.clamp(1.0 / (dist * 0.08), markerUI.minScale or 0.65, markerUI.maxScale or 1.05)
  local fontScale = 0.42 * scaleBase * (markerUI.fontScaleFactor or 1.0)
  local textLen = string.len(text)
  local textWidth = math.max(0.04, (textLen * 0.0065) * (fontScale * 1.2))
  local textHeight = 0.032 * (fontScale * 1.1)
  local keyBoxW = 0.035 * (fontScale)
  local keyBoxH = textHeight + 0.006
  local centerX = sx
  local keyX = centerX - (textWidth/2) - keyBoxW/2 - 0.006
  local textX = keyX + (keyBoxW/2) + 0.006 + (textWidth/2)
  local bg = markerUI.bgColor or { r=0,g=0,b=0,a=210 }
  local inner = markerUI.innerBgColor or { r=20,g=20,b=20,a=220 }
  local accent = markerUI.accentColor or { r=0,g=200,b=200,a=210 }
  DrawRect(textX, sy + 0.002, textWidth + 0.014, textHeight + 0.012, bg.r,bg.g,bg.b,bg.a)
  DrawRect(textX, sy + 0.002, textWidth + 0.010, textHeight + 0.008, inner.r,inner.g,inner.b,inner.a)
  DrawRect(keyX, sy + 0.002, keyBoxW + 0.006, keyBoxH + 0.006, 10,10,10,220)
  DrawRect(keyX, sy + 0.002, keyBoxW + 0.002, keyBoxH + 0.002, accent.r,accent.g,accent.b,accent.a)
  SetTextFont(markerUI.textFont or 4); SetTextProportional(1); SetTextScale(fontScale*0.95, fontScale*0.95); SetTextCentre(true)
  SetTextColour(0,0,0,255); BeginTextCommandDisplayText('STRING'); AddTextComponentString(tostring(keyLabel or 'E')); EndTextCommandDisplayText(keyX, sy - 0.001)
  SetTextFont(markerUI.textFont or 4); SetTextProportional(1); SetTextScale(fontScale, fontScale); SetTextCentre(true)
  SetTextColour(0,0,0,200); BeginTextCommandDisplayText('STRING'); AddTextComponentString(text); EndTextCommandDisplayText(textX + 0.0012, sy + 0.0015)
  SetTextFont(markerUI.textFont or 4); SetTextProportional(1); SetTextScale(fontScale, fontScale); SetTextCentre(true)
  SetTextColour(255,255,255,255); SetTextDropShadow(2,0,0,0,200); SetTextOutline()
  BeginTextCommandDisplayText('STRING'); AddTextComponentString(text); EndTextCommandDisplayText(textX, sy - 0.001)
end

local function drawIdealLineForCategory(category, markerUI)
  if not Config or not Config.IdealLine or not Config.IdealLine.enabled then return end
  local cfg = Config.IdealLine or {}
  local isAir = (category == 'plane' or category == 'heli')
  if not isAir and not (cfg.ground and cfg.ground.enabled) then return end
  local route = Config.Routes and Config.Routes[category]
  if not route or #route < 2 then return end
  local step = isAir and (cfg.air and cfg.air.step or 24.0) or (cfg.ground and cfg.ground.step or 12.0)
  local sizeVec = isAir and (cfg.air and cfg.air.size or vec3(1.2,1.2,1.2)) or (cfg.ground and cfg.ground.size or vec3(1.2,1.2,0.4))
  local colorCfg = isAir and ((cfg.air and cfg.air.color) or markerUI.idealColor) or ((cfg.ground and cfg.ground.color) or markerUI.idealColor)
  if not colorCfg then colorCfg = { r=0, g=200, b=200, a=120 } end
  local points = {}
  for i=1, #route-1 do
    local a = route[i].pos; local b = route[i+1].pos
    local ax,ay,az = toVec3(a); local bx,by,bz = toVec3(b)
    if ax and bx then
      local dx,dy,dz = bx-ax, by-ay, bz-az
      local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
      local segments = math.max(1, math.floor(dist / step))
      for s=0,segments do
        local t = s/segments
        points[#points+1] = { x = ax + dx*t, y = ay + dy*t, z = az + dz*t }
        if #points >= (cfg.maxPoints or 1200) then break end
      end
      if #points >= (cfg.maxPoints or 1200) then break end
    end
  end
  local nowT = (GetGameTimer and GetGameTimer() or nowMs()) / 1000
  local alphaPulse = 0.5 + 0.5 * math.sin(nowT * 2.1)
  local baseA = colorCfg.a or 120
  local aVal = math.floor(baseA * (0.6 + 0.4 * alphaPulse))
  local cam = GetGameplayCamCoords()
  local cull = cfg.cullDistance or 220.0
  for i=1,#points do
    local p = points[i]
    local px,py,pz = p.x, p.y, p.z + ((cfg.ground and cfg.ground.zOffset) or 0)
    if Vdist(cam.x, cam.y, cam.z, px, py, pz) <= cull then
      local sx,sy,sz = sizeVec.x or sizeVec[1] or 1.2, sizeVec.y or sizeVec[2] or 1.2, sizeVec.z or sizeVec[3] or 1.2
      DrawMarker(1, px, py, pz - 0.5, 0,0,0, 0,0,0, sx, sy, sz, colorCfg.r or 0, colorCfg.g or 200, colorCfg.b or 200, aVal, false, true, 2, false, nil, nil, false)
    end
  end
end

-- Praxis-Start: ESX Callback oder Raw-Fallback
local function tryCanStartPractice(category, cb)
  tryGetESX()
  local prefix = (Config and Config.ResourceName) or RESOURCE
  if ESX and ESX.TriggerServerCallback then
    ESX.TriggerServerCallback(prefix .. ':server:canStartPractice', function(ok, vehModel, npcModel, reason)
      if cb then cb(ok, vehModel, npcModel, reason) end
    end, category)
    return
  end
  local resultEvent = prefix .. ':client:canStartPracticeRawResult'
  local called = false
  RegisterNetEvent(resultEvent)
  AddEventHandler(resultEvent, function(ok, reasonOrNil, vehModel, npcModel)
    if called then return end
    called = true
    if cb then cb(ok, vehModel, npcModel, reasonOrNil) end
  end)
  TriggerServerEvent(prefix .. ':server:canStartPracticeRaw', category)
  CreateThread(function() Wait(2000); if not called then called = true; if cb then cb(false, nil, nil, 'timeout') end end end)
end

-- Guard duplicate loops
if _mtj_points_active then dbg('Markers','marker loop already active; skipping') else _mtj_points_active = true end

-- Config cache for the main draw loop (refreshed every ~1 s to avoid reading Config every frame)
local _mc = { ts = -9999, ok = false }
local function _refreshMarkerCache()
    if not (Config and Config.Points) then _mc.ok = false; return end
    local ui = getMarkerUI()
    local dd = tonumber((Config and Config.DrawDistance) or 25.0) or 25.0
    _mc.markerUI     = ui
    _mc.drawDist     = (ui.drawDistanceMin and math.max(dd, ui.drawDistanceMin)) or dd
    _mc.interactDist = tonumber((Config and Config.InteractDistance) or 2.0) or 2.0
    _mc.keyInteract  = tonumber((Config and Config.KeyInteract) or 38) or 38
    _mc.markerType   = tonumber((Config and Config.MarkerType) or 2) or 2
    local sc = (Config and Config.MarkerScale) or vec3(1.8,1.8,1.8)
    local function _rs(s)
        if type(s)=='table' or type(s)=='userdata' then
            if s.x then return tonumber(s.x) or 1.8, tonumber(s.y) or 1.8, tonumber(s.z) or 1.8 end
            if tonumber(s[1]) and tonumber(s[2]) and tonumber(s[3]) then return tonumber(s[1]),tonumber(s[2]),tonumber(s[3]) end
        end
        return 1.8,1.8,1.8
    end
    _mc.sx, _mc.sy, _mc.sz = _rs(sc)
    _mc.markerColorCfg = (Config and Config.MarkerColor) or { r=0,g=180,b=255,a=180 }
    _mc.ts = nowMs()
    _mc.ok = true
end

-- Main loop
CreateThread(function()
  local deadline = nowMs() + 8000
  while not (Config and Config.Points) and nowMs() < deadline do Wait(50) end

  while true do
    Wait(0)
    if not (Config and Config.Points) then Wait(500) else
      -- Refresh cached config at most once per second
      local t = nowMs()
      if (t - _mc.ts) >= 1000 then _refreshMarkerCache() end
      if not _mc.ok then Wait(200) else

      local markerUI      = _mc.markerUI
      local drawDist      = _mc.drawDist
      local interactDist  = _mc.interactDist
      local keyInteract   = _mc.keyInteract
      local markerType    = _mc.markerType
      local sx, sy, sz    = _mc.sx, _mc.sy, _mc.sz
      local markerColorCfg = _mc.markerColorCfg

      local ped = PlayerPedId(); local pos = GetEntityCoords(ped); local px,py,pz = pos.x,pos.y,pos.z
      local pts = { booking = Config.Points.booking, theory = Config.Points.theory, practice = Config.Points.practice }

      -- Ideal line only during active practice to save CPU
      if _mtj_practice_watch and _mtj_practice_watch.active
          and Config and Config.IdealLine and Config.IdealLine.enabled then
        local cat = selectedCat or 'car'
        drawIdealLineForCategory(cat, markerUI)
      end

      for kind, raw in pairs(pts) do
        if raw then
          local x,y,z = toVec3(raw)
          if x and y and z then
            local dist = Vdist(px,py,pz, x,y,z)
            if dist <= drawDist then
              local useColor = markerColorCfg
              local currentCat = selectedCat or ((Config.UI and Config.UI.DefaultCategory) or 'car')
              if currentCat == 'plane' or currentCat == 'heli' then
                useColor = markerUI.airAccent or markerUI.accentColor or { r=0,g=200,b=200,a=200 }
              end
              drawWorldMarker(x,y,z, { x = sx, y = sy, z = sz }, useColor, markerType, markerUI)
            end

            if dist <= interactDist and markerUI.enabled then
              local keyLabel = controlCodeToLabel(keyInteract, markerUI.keyLabelMap)
              drawGTAHint(x,y,z, markerUI.hintTemplate, markerUI, keyLabel)
              if IsControlJustReleased(0, keyInteract) then
                local now = nowMs()
                if (now - (lastInteract[kind] or 0)) < INTERACT_COOLDOWN_MS then
                  -- debounce
                else
                  lastInteract[kind] = now
                  dbg('Markers','interacted', kind)

                  if kind == 'booking' then
                    sendUiAndOpen({ action='openMenu', labels=Config.Labels, prices=Config.Prices, logo=Config.UILogo or Config.LogoURL, bookingTitle=(Config.UI and Config.UI.BookingTitle) or (Config.UI and Config.UI.Name) or 'Fahrschule' })
                    safeSetNui(true,true)

                  elseif kind == 'theory' then
                    sendUiAndOpen({
                      action='openTheory',
                      labels=Config.Labels,
                      passPct=(Config.Theory and Config.Theory.PassPercentage) or 80,
                      questionsPerTest=(Config.Theory and Config.Theory.QuestionsPerTest) or 25,
                      timerSeconds=(Config.Theory and Config.Theory.TimerSeconds) or 1200,
                      category = selectedCat or ((Config.UI and Config.UI.DefaultCategory) or 'car'),
                      logo = Config.UILogo or Config.LogoURL
                    })
                    safeSetNui(true,true)

                  elseif kind == 'practice' then
                    local category = selectedCat or ((Config.UI and Config.UI.DefaultCategory) or 'car')
                    tryCanStartPractice(category, function(ok, vehModel, npcModel, reason)
                      if ok then
                        TriggerEvent(RESOURCE..':client:StartPractice', category, vehModel, npcModel)
                        TriggerServerEvent(RESOURCE..':server:practiceStart', category)
                      else
                        local msg = reason or ((Config and Config.Labels and Config.Labels.MustBookFirst) or 'Bitte zuerst buchen.')
                        if Config and Config.UseESXNotify and tryGetESX() and ESX.ShowNotification then
                          ESX.ShowNotification(msg)
                        else
                          TriggerEvent('chat:addMessage', { args = { '[Fahrschule]', msg } })
                        end
                      end
                    end)
                  end
                end
              end
            end
          else
            dbg('Markers','invalid point', kind, tostring(raw))
          end
        end
      end
      end -- if _mc.ok
    end
  end
end)

-- === PRACTICE WATCHDOG (UI-neutral) ===
local _mtj_practice_watch = {
  active     = false,
  cat        = nil,
  hadVeh     = false,
  veh        = 0,
  abortSent  = false,
}

local function requestPracticeAbort(reason)
  if _mtj_practice_watch.abortSent then return end
  _mtj_practice_watch.abortSent = true
  dbg('Practice', 'Abort requested:', tostring(reason))
  TriggerEvent(RESOURCE..':client:AbortPractice', reason)
  TriggerServerEvent(RESOURCE..':server:practiceAbort', reason)
end

local function stopPracticeWatch()
  _mtj_practice_watch.active    = false
  _mtj_practice_watch.cat       = nil
  _mtj_practice_watch.hadVeh    = false
  _mtj_practice_watch.veh       = 0
  _mtj_practice_watch.abortSent = false
  dbg('Practice', 'watch stopped')
end

local function startPracticeWatch(category)
  stopPracticeWatch()
  _mtj_practice_watch.active = true
  _mtj_practice_watch.cat    = tostring(category or selectedCat or 'car')

  CreateThread(function()
    dbg('Practice', 'watch start for cat=', _mtj_practice_watch.cat)
    local ped = PlayerPedId()
    local minSpeedKmh = (Config and Config.Practice and Config.Practice.CollisionMinSpeedKmh) or 10.0
    local dropMin     = (Config and Config.Practice and Config.Practice.CollisionMinBodyHealthDrop) or 10.0
    local prevBody    = nil

    while _mtj_practice_watch.active do
      Wait(150)

      ped = PlayerPedId()
      if IsEntityDead(ped) then
        requestPracticeAbort('death')
        stopPracticeWatch()
        break
      end

      local inVeh = IsPedInAnyVehicle(ped, false)
      local veh   = inVeh and GetVehiclePedIsIn(ped, false) or 0
      _mtj_practice_watch.veh = veh

      local cat = _mtj_practice_watch.cat
      local speedKmh = inVeh and (GetEntitySpeed(veh) * 3.6) or (GetEntitySpeed(ped) * 3.6)

      if cat == 'bike' then
        if not inVeh or IsPedRagdoll(ped) then
          requestPracticeAbort(not inVeh and 'bike_left' or 'bike_ragdoll')
          stopPracticeWatch()
          break
        end
        if inVeh then
          local model = GetEntityModel(veh)
          if not IsThisModelABike(model) then
            requestPracticeAbort('bike_not_on_bike')
            stopPracticeWatch()
            break
          end
        end
      else
        if _mtj_practice_watch.hadVeh and (not inVeh) then
          requestPracticeAbort('left_vehicle')
          stopPracticeWatch()
          break
        end
      end

      if inVeh then
        _mtj_practice_watch.hadVeh = true

        local body = GetVehicleBodyHealth(veh) -- 0..1000
        if prevBody then
          local drop = prevBody - body
          if drop >= dropMin and speedKmh >= minSpeedKmh then
            requestPracticeAbort('veh_collision_drop')
            stopPracticeWatch()
            break
          end
        end
        prevBody = body

        if HasEntityCollidedWithAnything(veh) and speedKmh >= (minSpeedKmh + 2.0) then
          requestPracticeAbort('veh_collision_hit')
          stopPracticeWatch()
          break
        end
      end
    end
  end)
end

AddEventHandler(RESOURCE..':client:StartPractice', function(category, vehModel, npcModel)
  startPracticeWatch(category or selectedCat or 'car')
end)
for _,ev in ipairs({
  RESOURCE..':client:EndPractice',
  RESOURCE..':client:PracticeFailed',
  RESOURCE..':client:PracticeAborted'
}) do
  AddEventHandler(ev, function() stopPracticeWatch() end)
end
AddEventHandler('onResourceStop', function(res)
  if res == (GetCurrentResourceName and GetCurrentResourceName() or '') then stopPracticeWatch() end
end)

-- Debug commands
RegisterCommand('mtj_points_status', function()
  log('mtj_points_status')
  if not (Config and Config.Points) then log('Config.Points = nil'); return end
  for k,v in pairs({ booking = Config.Points.booking, theory = Config.Points.theory, practice = Config.Points.practice }) do
    if v then
      local x,y,z = toVec3(v)
      print(('[%s][debug] Point %s -> coords=%.3f, %.3f, %.3f raw=%s'):format(RESNAME, tostring(k), tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0, tostring(v)))
    else
      print(('[%s][debug] Point %s -> MISSING'):format(RESNAME, tostring(k)))
    end
  end
end, false)

RegisterCommand('mtj_mtest', function()
  log('mtj_mtest')
  if not (Config and Config.Points) then log('Config.Points missing'); return end
  CreateThread(function()
    local t0 = GetGameTimer(); local T = 20000
    local markerUI = getMarkerUI()
    local keyLabel = controlCodeToLabel((Config and Config.KeyInteract) or 38, (Config and Config.MarkerUI and Config.MarkerUI.keyLabelMap) or {})
    while GetGameTimer() - t0 < T do
      Wait(0)
      for k,v in pairs({ booking = Config.Points.booking, theory = Config.Points.theory, practice = Config.Points.practice }) do
        if v then
          local x,y,z = toVec3(v)
          if x and y and z then
            drawWorldMarker(x,y,z, (Config and Config.MarkerScale) or vector3(1.8,1.8,1.8), (Config and Config.MarkerColor) or { r=0,g=200,b=200,a=190 }, 1, markerUI)
            drawGTAHint(x,y,z, markerUI.hintTemplate, markerUI, keyLabel)
          end
        end
      end
    end
    log('mtj_mtest ended')
  end)
end, false)

AddEventHandler('onClientResourceStart', function(resName)
  if resName == (GetCurrentResourceName and GetCurrentResourceName() or '') then
    Wait(120); pcall(function() SetNuiFocus(false,false) end); log('resource started - NUI focus cleared')
    pushUiConfig(true)
  end
end)

log('client/main.lua loaded — visuals + robust practice start; selectedCat synced from server.')