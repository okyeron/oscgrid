local vport = require 'vport'

local oscarc = {}
oscarc.__index = oscarc

local oscsourceip = "10.0.1.11"
local oscsourceport = 9000

oscarc.devices = {}
oscarc.vports = {}

oscarc.oscdest = {oscsourceip,oscsourceport}

oscarc.arcLEDarray = {}          -- create the matrix
  for i=1,4 do  -- ring
    oscarc.arcLEDarray[i] = {}     -- create a new row
    for j=1,64 do  -- leds
      oscarc.arcLEDarray[i][j] = 0
    end
  end  
    

for i=1,4 do
  oscarc.vports[i] = {
    name = "none",
    device = nil,

    delta = nil,
    key = nil,

    led = vport.wrap_method('led'),
    all = vport.wrap_method('all'),
    refresh = vport.wrap_method('refresh'),
    segment = vport.wrap_method('segment'),
  }
end


function oscarc.new(id, serial, name)
  local device = setmetatable({}, oscarc)

  device.id = id
  device.serial = serial
  device.name = name.." "..serial
  device.dev = {}
  device.delta = nil -- delta event callback
  device.key = nil -- key event callback
  device.remove = nil -- device unpludevice callback
  device.port = nil
  
  -- autofill next postiion
  local connected = {}
  for i=1,4 do
    table.insert(connected, arc.vports[i].name)
  end
  if not tab.contains(connected, device.name) then
    for i=1,4 do
      if arc.vports[i].name == "none" then
        arc.vports[i].name = device.name
        break
      end
    end
  end
  return device
end

--- set state of single LED on this arc device.
-- @tparam integer ring : ring index (1-based!)
-- @tparam integer x : led index (1-based!)
-- @tparam integer val : LED brightness in [0, 15]
function oscarc:led(ring, x, val)
  oscarc.arcLEDarray[ring][x] = util.clamp(val,0,15)
  --osc.send(oscarc.oscdest, "/ring/led ".. ring .. " " .. x, {val})
  --arc_set_led(self.dev, ring, x, val)
end

--- set state of all LEDs on this arc device.
-- @tparam integer val : LED brightness in [0, 15]
function oscarc:all(val)
  for i = 1,4 do -- ring
    for j = 1,64 do -- leds
      oscarc.arcLEDarray[i][j] = val
      --osc.send(oscarc.oscdest, "/ring/led ".. i .. " " .. j, {val})
    end
  end  
  --arc_all_led(self.dev, val)
end

--- update any dirty quads on this arc device.
function oscarc:refresh()
  for i = 1,4 do -- ring
    for j = 1,64 do -- leds
      osc.send(oscarc.oscdest, "/ring/led ".. i .. " " .. j, {oscarc.arcLEDarray[i][j]})
    end
  end  

  --monome_refresh(self.dev)
end

--- static callback when any arc device is added;
-- user scripts can redefine
-- @static
-- @param dev : an arc table
function oscarc.add(dev)
  print("arc added:", dev.id, dev.name, dev.serial)
end

--- static callback when any arc device is removed;
-- user scripts can redefine
-- @static
-- @param dev : an arc table
function oscarc.remove(dev) end


--- create an anti-aliased point to point arc 
-- segment/range on a sepcific LED ring.
-- each point can be a decimal, LEDs will fade for in between values. 
-- @tparam integer ring : ring index (1-based)
-- @tparam number from : from angle in radians
-- @tparam number to : to angle in radians
-- @tparam integer level : LED brightness in [0, 15]
function oscarc:segment(ring, from, to, level)
  local tau = math.pi * 2

  local function overlap(a, b, c, d)
    if a > b then
      return overlap(a, tau, c, d) + overlap(0, b, c, d)
    elseif c > d then
      return overlap(a, b, c, tau) + overlap(a, b, 0, d)
    else
      return math.max(0, math.min(b, d) - math.max(a, c))
    end
  end

  local function overlap_segments(a, b, c, d)
    a = a % tau
    b = b % tau
    c = c % tau
    d = d % tau

    return overlap(a, b, c, d)
  end

  local m = {}
  local sl = tau / 64

  for i=1, 64 do
    local sa = tau / 64 * (i - 1)
    local sb = tau / 64 * i

    local o = overlap_segments(from, to, sa, sb)
    m[i] = util.round(o / sl * level)
    self:led(ring, i, m[i])
  end
end



local t = 0
local dt = 1
local newdelta = 0

oscarc.osc_in = function(path, args, from, ar_id)
  local k
  local pathxy = {}
  for k in string.gmatch(path, "%S+") do
    table.insert(pathxy,k)
  end
  --print (path)
  oscpath = pathxy[1]
  if oscpath == "/arc/enc" then
    n = math.floor(pathxy[2])
    delta = math.floor(args[1])
    
    -- collect fast deltas for quick spins
    local t1 = util.time()
    dt = t1 - t
    t = t1
    newdelta = newdelta + delta
    if dt > .025 then
      oscarc.arc.delta(ar_id, n, newdelta)
      --print (newdelta)
      newdelta = 0
    end
    --oscarc.draw(n .. ' ' .. delta)
  end
end

oscarc.arc = {}

oscarc.arc.delta = function(id, n, delta)
  local device = arc.devices[id]

  if device ~= nil then
    if device.delta then
      device.delta(n, delta)
      _norns.arc.delta(id, n, delta)
    end

    if device.port then
      if oscarc.vports[device.port].delta then
        oscarc.vports[device.port].delta(n, delta)
      end
    end
  else
    error('no entry for arc '..id)
  end
end


oscarc.arc.key = function(id, n, s)
  local device = Arc.devices[id]

  if device ~= nil then
    if device.key then
      device.key(n, s)
      _norns.arc.key(id, n, s)
    end

    if device.port then
      if Arc.vports[device.port].key then
        Arc.vports[device.port].key(n, s)
      end
    end
  else
    error('no entry for arc '..id)
  end
end


function oscarc.connect(n)
  local n = n or 1
  return arc.vports[n]
  
end
--- clear handlers
function oscarc.cleanup()
  for i=1,4 do
    arc.vports[i].delta = nil
    arc.vports[i].key = nil
  end

  for _, dev in pairs(arc.devices) do
    dev:all(0)
    dev:refresh()
    dev.delta = nil
    dev.key = nil
  end
end

function oscarc.update_devices()
  -- reset vports for existing devices
  --oscarc.list = {}
  for _, device in pairs(arc.devices) do
    device.port = nil
  end

  -- connect available devices to vports
  for i=1,4 do
    arc.vports[i].device = nil

    for _, device in pairs(arc.devices) do
      if device.name == arc.vports[i].name then
        arc.vports[i].device = device
        device.port = i
      end
    end
  end
end


-- arc add
oscarc.arc.add = function(id, serial, name)
  local g = oscarc.new(id, serial, name)
  arc.devices[id] = g
  oscarc.update_devices()
  if oscarc.add ~= nil then oscarc.add(g) end
end

oscarc.arc.remove = function(id)
  if arc.devices[id] then
    if arc.remove ~= nil then
      arc.remove(arc.devices[id])
    end
    if arc.devices[id].remove then
      arc.devices[id].remove()
    end
  end
  arc.devices[id] = nil
  arc.update_devices()
end


oscarc.draw = function(text)
  screen.clear()
  screen.move (10,10)
  screen.text(text)
  screen.stroke()
  screen.update()
end


return oscarc