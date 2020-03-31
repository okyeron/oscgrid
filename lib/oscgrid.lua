local vport = require 'vport'

local oscgrid = {}
oscgrid.__index = oscgrid

local oscsourceip = "10.0.1.11"
local oscsourceport = 9000

oscgrid.LEDarray = {}          -- create the matrix
  for i=1,16 do
    oscgrid.LEDarray[i] = {}     -- create a new row
    for j=1,8 do
      oscgrid.LEDarray[i][j] = 0
    end
  end  
--tab.print (oscgrid.LEDarray)
--print ('ledarray 16 16', oscgrid.LEDarray[16][16])


oscgrid.devices = {}
oscgrid.vports = {}
oscgrid.gridkey = {}

oscgrid.oscdest = {oscsourceip,oscsourceport}

for i=1,4 do
  oscgrid.vports[i] = {
    name = "none",
    device = nil,

    key = nil,

    led = vport.wrap_method('led'),
    all = vport.wrap_method('all'),
    refresh = vport.wrap_method('refresh'),
    rotation = vport.wrap_method('rotation'),

    cols = 0,
    rows = 0,
  }
end

function oscgrid.new(id, serial, name, dev)
  local g = setmetatable({}, oscgrid)

  g.id = id
  g.serial = serial
  g.name = name.." "..serial
  g.dev = dev
  g.key = nil -- key event callback
  g.remove = nil -- device unplug callback
  g.rows = 8
  g.cols = 16
  g.port = nil
  
  
  -- autofill next postiion
  local connected = {}
  for i=1,4 do
    table.insert(connected, grid.vports[i].name)
  end
  if not tab.contains(connected, g.name) then
    for i=1,4 do
      if grid.vports[i].name == "none" then
        grid.vports[i].name = g.name
        --print (g.name, i);
        --tab.print(oscgrid.vports[i])
        break
      end
    end
  end
  return g
end

-- set grid rotation.
-- @tparam integer val : rotation 0,90,180,270 as [0, 3]
function oscgrid:rotation(val)
  --_norns.grid_set_rotation(self.dev, val)
end

--- set state of single LED on this grid device.
-- @tparam integer x : column index (1-based!)
-- @tparam integer y : row index (1-based!)
-- @tparam integer val : LED brightness in [0, 15]
function oscgrid:led(x, y, val)
    -- this should load up array and then refresh sends the values
    --osc.send(oscgrid.oscdest, "/grid/led ".. x .. " " .. y, {val})
    --grid_set_led(self.dev, x, y, val)
    if (x > 0 and x < 17) and (y > 0 and y < 9) then
      oscgrid.LEDarray[x][y] = util.clamp(val,0,15)
    end
    --print("led",self.LEDarray[x][y])
end

--- set state of all LEDs on this grid device.
-- @tparam integer val : LED brightness in [0, 15]
function oscgrid:all(val)
  for i = 1,16 do -- should maybe use g.cols
    for j = 1,8 do -- should maybe use g.rows
      oscgrid.LEDarray[i][j] = val
      --osc.send(oscgrid.oscdest, "/grid/led ".. i .. " " .. j, {val})
    end
  end  
  --grid_all_led(self.dev, val)
end

--- update any dirty quads on this grid device.
function oscgrid:refresh()
  for i = 1,16 do -- should maybe use g.cols
    for j = 1,8 do -- should maybe use g.rows
      osc.send(self.oscdest, "/grid/led ".. i .. " " .. j, {oscgrid.LEDarray[i][j]})
    end
  end  
  --monome_refresh(self.dev)
end



--- static callback when any grid device is added;
-- user scripts can redefine
-- @static
-- @param dev : a Grid table
function oscgrid.add(dev)
  print("grid added:", dev.id, dev.name, dev.serial)
end

--- static callback when any grid device is removed;
-- user scripts can redefine
-- @static
-- @param dev : a Grid table
function oscgrid.remove(dev) end


oscgrid.osc_in = function(path, args, from)
  local k
  local pathxy = {}
  for k in string.gmatch(path, "%S+") do
    table.insert(pathxy,k)
  end
  --print (path)
  oscpath = pathxy[1]
  if oscpath == "/grid/key" then
    x = math.floor(pathxy[2])
    y = math.floor(pathxy[3])
    s = math.floor(args[1])
    oscgrid.gridkey = {x, y, s}
    oscgrid.grid.key(2, x, y, s)
    
    --osc.send(oscgrid.oscdest, "/grid/led ".. x .. " " .. y, {val})
    --osc.send(oscgrid.oscdest, path, args) 
    --oscgrid.draw(x .. ' ' .. y .. ' ' .. s)

  end
end

oscgrid.grid = {}

oscgrid.grid.key = function(id, x, y, s)
  local g = grid.devices[id]
  --tab.print(g)
  if g ~= nil then
    if g.key ~= nil then
      g.key(x, y, s)
      _norns.grid.key(id, x,y,s)
      --print (x, y, s)
    end

    if g.port then
      if oscgrid.vports[g.port].key then
        oscgrid.vports[g.port].key(x, y, s)
        print('oscgrid.vports',x,y,s)
      end
    end
  else
    error('no entry for grid '..id)
  end

  --print(id)
  --print(x,y,s)
  --norns.grid.key(id, x,y,s)
end

function oscgrid.connect(n)
  local n = n or 1
  return grid.vports[n]
end

--- clear handlers.
function oscgrid.cleanup()
  for i=1,4 do
    grid.vports[i].key = nil
  end

  for _, dev in pairs(grid.devices) do
    dev:all(0)
    dev:refresh()
    dev.key = nil
  end
end

--- update devices.
function oscgrid.update_devices()
  -- build list of available devices
  oscgrid.list = {}
  for _,device in pairs(grid.devices) do
    device.port = nil
  end

  -- connect available devices to vports
  for i=1,4 do
    grid.vports[i].device = nil
    grid.vports[i].rows = 0
    grid.vports[i].cols = 0       

    for _,device in pairs(grid.devices) do
      if device.name == grid.vports[i].name then
        grid.vports[i].device = device
        grid.vports[i].rows = device.rows
        grid.vports[i].cols = device.cols
        device.port = i
      end
    end
  end
end


-- grid add
oscgrid.grid.add = function(id, serial, name, dev)
  local g = oscgrid.new(id,serial,name, dev)
  grid.devices[id] = g
  oscgrid.update_devices()
  if oscgrid.add ~= nil then oscgrid.add(g) end
end

-- grid remove
oscgrid.grid.remove = function(id)
  if grid.devices[id] then
    if grid.remove ~= nil then
      grid.remove(grid.devices[id])
    end
    if grid.devices[id].remove then
      grid.devices[id].remove()
    end
  end
  grid.devices[id] = nil
  oscgrid.update_devices()
end

oscgrid.draw = function(text)
  screen.clear()
  screen.move (10,10)
  screen.text(text)
  screen.stroke()
  screen.update()
end

return oscgrid