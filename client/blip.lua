-- Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

-- Blip manager that strictly follows Config.Blip:
--  - creates MAIN blip according to Config.Blip (shortRange follows Config.Blip.shortRange)
--  - creates SUB‑BLIPS for booking/theory/practice ONLY if Config.Blip.showSubPoints == true
--  - safe guards, robust to different Config.Points formats, and debug logs
--  - removes subblips on refresh/stop
--
-- Replace your existing client/blip.lua with this file, then run: refresh && restart mtj_fahrschule

local function RES() return (Config and Config.ResourceName) or GetCurrentResourceName() or 'mtj_fahrschule' end
local function ev(suffix) return RES() .. ':' .. suffix end
local function onEventBoth(suffix, cb)
  local dyn = ev('client:' .. suffix)
  local fix = 'mtj_fahrschule:client:' .. suffix
  RegisterNetEvent(dyn); AddEventHandler(dyn, cb)
  if fix ~= dyn then RegisterNetEvent(fix); AddEventHandler(fix, cb) end
end

local mainBlip = 0
local subBlips = { booking = 0, theory = 0, practice = 0 }
local routeBlip = 0

local function dbg(...)
  if Config and Config.Debug and Config.Debug.Markers then
    local parts = {}
    for i=1, select('#', ...) do parts[#parts+1] = tostring(select(i, ...)) end
    print(('[%s][blip] %s'):format(RES(), table.concat(parts, ' ')))
  end
end
local function log(...)
  local parts = {}
  for i=1, select('#', ...) do parts[#parts+1] = tostring(select(i, ...)) end
  print(('[%s][blip] %s'):format(RES(), table.concat(parts, ' ')))
end

-- Robust toVec3: returns a vector3 or nil
local function toVec3(v)
  if not v then return nil end
  if type(v) == 'table' then
    if v.x ~= nil and v.y ~= nil and v.z ~= nil then
      return vector3(tonumber(v.x) + 0.0, tonumber(v.y) + 0.0, tonumber(v.z) + 0.0)
    end
    if tonumber(v[1]) and tonumber(v[2]) and tonumber(v[3]) then
      return vector3(tonumber(v[1]) + 0.0, tonumber(v[2]) + 0.0, tonumber(v[3]) + 0.0)
    end
  end
  -- userdata (vec3/vec4)
  if type(v) == 'userdata' then
    local ok1, x = pcall(function() return v.x end)
    local ok2, y = pcall(function() return v.y end)
    local ok3, z = pcall(function() return v.z end)
    if ok1 and ok2 and ok3 and x and y and z then
      return vector3(tonumber(x) + 0.0, tonumber(y) + 0.0, tonumber(z) + 0.0)
    end
    local ok4,i1 = pcall(function() return v[1] end)
    local ok5,i2 = pcall(function() return v[2] end)
    local ok6,i3 = pcall(function() return v[3] end)
    if ok4 and ok5 and ok6 and tonumber(i1) and tonumber(i2) and tonumber(i3) then
      return vector3(tonumber(i1) + 0.0, tonumber(i2) + 0.0, tonumber(i3) + 0.0)
    end
  end

  -- try parsing tostring like "vec4(x, y, z, w)" or "vector4(x, y, z, w)"
  local ok, s = pcall(function() return tostring(v) end)
  if ok and type(s) == 'string' then
    local i1 = s:find('%(')
    local i2 = s:find(')')
    local inner = s
    if i1 and i2 and i2 > i1 then inner = s:sub(i1+1, i2-1) end
    local nums = {}
    for num in inner:gmatch('[-+]?%d+%.?%d*') do
      nums[#nums+1] = tonumber(num)
      if #nums >= 3 then break end
    end
    if #nums >= 3 then
      return vector3(nums[1] + 0.0, nums[2] + 0.0, nums[3] + 0.0)
    end
  end

  return nil
end

local function getCategoryBlipCfg(category)
  local def = { sprite = (Config and Config.RouteBlipSprite) or 615, color = (Config and Config.RouteBlipColor) or 3, scale = 0.95 }
  if not Config or not Config.CategoryBlips then return def end
  local cfg = Config.CategoryBlips[category]
  if not cfg then return def end
  return { sprite = cfg.sprite or def.sprite, color = cfg.color or def.color, scale = cfg.scale or def.scale }
end

local function waitForConfig(timeoutMs)
  local deadline = GetGameTimer() + (timeoutMs or 10000)
  while GetGameTimer() < deadline do
    if Config and (Config.Blip or next(Config)) then return true end
    Wait(50)
  end
  return (Config ~= nil)
end

local function waitUntilSession(timeoutMs)
  local deadline = GetGameTimer() + (timeoutMs or 10000)
  while not NetworkIsSessionStarted() and GetGameTimer() < deadline do Wait(100) end
  local ped = PlayerPedId()
  while (not ped or ped == 0 or not DoesEntityExist(ped)) and GetGameTimer() < deadline do
    Wait(100); ped = PlayerPedId()
  end
end

local function createMainBlip()
  if not Config or not Config.Blip or Config.Blip.enabled == false then
    dbg('createMainBlip: disabled in config')
    return false
  end

  -- Prefer Config.Blip.position, else fallback to Config.Points.booking
  local posv = Config.Blip.position or (Config.Points and Config.Points.booking) or nil
  local pos = toVec3(posv)
  if not pos then
    dbg('createMainBlip: invalid position (Config.Blip.position and fallback missing)')
    return false
  end

  if mainBlip ~= 0 and DoesBlipExist(mainBlip) then pcall(RemoveBlip, mainBlip); mainBlip = 0 end
  mainBlip = AddBlipForCoord(pos.x, pos.y, pos.z)
  if mainBlip == 0 then dbg('createMainBlip: AddBlipForCoord failed'); return false end

  pcall(function()
    SetBlipSprite(mainBlip, Config.Blip.sprite or 498)
    SetBlipDisplay(mainBlip, 4)
    SetBlipScale(mainBlip, Config.Blip.scale or 0.9)
    SetBlipColour(mainBlip, Config.Blip.color or 3)
    -- Respect Config.Blip.shortRange for MAIN blip
    SetBlipAsShortRange(mainBlip, (Config.Blip.shortRange == true))
    SetBlipRoute(mainBlip, false) -- never route on main blip
    SetBlipHighDetail(mainBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Blip.name or (Config.UIName or 'Fahrschule'))
    EndTextCommandSetBlipName(mainBlip)
  end)

  log(('createMainBlip: set at %.3f, %.3f, %.3f (shortRange=%s)'):format(pos.x, pos.y, pos.z, tostring(Config.Blip.shortRange)))
  return true
end

local function createSubBlipFromPoint(kind, point, label)
  local pos = toVec3(point)
  if not pos then return 0 end
  local sprite = (Config and Config.Blip and Config.Blip.sub and Config.Blip.sub.sprite) or 280
  local scale  = (Config and Config.Blip and Config.Blip.sub and Config.Blip.sub.scale) or 0.7
  local color  = (Config and Config.Blip and Config.Blip.sub and Config.Blip.sub.color) or 3

  local b = AddBlipForCoord(pos.x, pos.y, pos.z)
  if b ~= 0 then
    pcall(function()
      SetBlipSprite(b, sprite)
      SetBlipDisplay(b, 4)
      SetBlipScale(b, scale)
      SetBlipColour(b, color)
      -- Sub-blips shortRange behaviour: default to main's behaviour unless overridden with Config.Blip.subShortRange
      local shortRange = (Config and Config.Blip and (Config.Blip.subShortRange == true or Config.Blip.shortRange == true)) or false
      SetBlipAsShortRange(b, shortRange)
      SetBlipRoute(b, false)
      BeginTextCommandSetBlipName('STRING')
      AddTextComponentString(label or '')
      EndTextCommandSetBlipName(b)
    end)
    dbg('createSubBlip', kind, pos.x, pos.y, pos.z)
  end
  return b
end

local function clearRouteBlip()
  if routeBlip ~= 0 and DoesBlipExist(routeBlip) then pcall(RemoveBlip, routeBlip); routeBlip = 0 end
end

local function removeNonPersistentBlips()
  for k,b in pairs(subBlips) do
    if b ~= 0 and DoesBlipExist(b) then pcall(RemoveBlip, b); subBlips[k] = 0 end
  end
  clearRouteBlip()
end

local function removeAllBlips()
  removeNonPersistentBlips()
  if mainBlip ~= 0 and DoesBlipExist(mainBlip) then pcall(RemoveBlip, mainBlip); mainBlip = 0 end
end

local function setRouteBlip(point, category)
  clearRouteBlip()
  local pos = toVec3(point); if not pos then return end
  local cfg = getCategoryBlipCfg(category)
  routeBlip = AddBlipForCoord(pos.x, pos.y, pos.z)
  if routeBlip == 0 then return end
  pcall(function()
    SetBlipSprite(routeBlip, cfg.sprite or ((Config and Config.RouteBlipSprite) or 615))
    SetBlipDisplay(routeBlip, 4)
    local isAir = (category == 'heli' or category == 'plane')
    local scale = (cfg.scale or 0.95); if isAir then scale = math.max(scale, 1.3) end
    SetBlipScale(routeBlip, scale)
    SetBlipColour(routeBlip, cfg.color or ((Config and Config.RouteBlipColor) or 3))
    SetBlipAsShortRange(routeBlip, false)
    SetBlipHighDetail(routeBlip, true)
    SetBlipRoute(routeBlip, (Config and Config.ShowRoute == true))
    BeginTextCommandSetBlipName('STRING'); AddTextComponentString('Prüfung – Nächster Punkt'); EndTextCommandSetBlipName(routeBlip)
  end)
  dbg(('setRouteBlip: %.3f %.3f %.3f cat=%s showRoute=%s'):format(pos.x, pos.y, pos.z, tostring(category), tostring(Config and Config.ShowRoute)))
end

local function refreshBlips()
  removeNonPersistentBlips()
  local ok = createMainBlip()
  if ok then
    -- Create sub-blips for the three station points ONLY if Config.Blip.showSubPoints == true
    if Config and Config.Points and Config.Blip and Config.Blip.showSubPoints == true then
      -- Booking
      if Config.Points.booking then
        local labelBooking = (Config.Blip.sub and (Config.Blip.sub.bookingName or 'Buchung')) or 'Buchung'
        subBlips.booking = createSubBlipFromPoint('booking', Config.Points.booking, labelBooking)
      end
      -- Theory
      if Config.Points.theory then
        subBlips.theory = createSubBlipFromPoint('theory', Config.Points.theory, (Config.Blip.sub and Config.Blip.sub.theoryName) or 'Theorie')
      end
      -- Practice
      if Config.Points.practice then
        subBlips.practice = createSubBlipFromPoint('practice', Config.Points.practice, (Config.Blip.sub and Config.Blip.sub.practiceName) or 'Praxis')
      end
      dbg('refreshBlips: sub-blips created (showSubPoints=true)')
    else
      dbg('refreshBlips: sub-blips skipped (Config.Blip.showSubPoints != true)')
    end
  end
end

-- Resource lifecycle (client)
AddEventHandler('onClientResourceStart', function(res)
  if res ~= GetCurrentResourceName() then return end
  dbg('Resource started – waiting for Config & Session...')
  CreateThread(function()
    waitUntilSession(15000)
    if not waitForConfig(10000) then dbg('Config Timeout'); return end
    local ok, err = pcall(refreshBlips); if not ok then dbg('refreshBlips error:', tostring(err)) end
  end)
end)

AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() then
    dbg('Resource stop – removing all blips')
    removeAllBlips()
  end
end)

-- Also refresh after player spawns (useful if map/hud wasn’t ready on resource start)
AddEventHandler('playerSpawned', function()
  CreateThread(function()
    waitUntilSession(5000)
    if waitForConfig(2000) then pcall(refreshBlips) end
  end)
end)

-- Public events/commands to refresh from elsewhere if needed
onEventBoth('refreshBlips', function() waitUntilSession(2000); if waitForConfig(1000) then refreshBlips() end end)
onEventBoth('setRouteBlip', function(payload) if waitForConfig(1000) and payload and payload.pos then setRouteBlip(payload.pos, payload.category) end end)
onEventBoth('clearRouteBlip', function() clearRouteBlip() end)

RegisterCommand('fahrschule_blip_refresh', function()
  CreateThread(function()
    waitUntilSession(5000)
    if waitForConfig(2000) then pcall(refreshBlips) end
  end)
end, false)

dbg('client/blip.lua loaded (MAIN blip follows Config.Blip; sub-blips created only if Config.Blip.showSubPoints == true; robust start)')