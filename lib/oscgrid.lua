-- oscgrid touch osc grid
-- emulator by Steven Noreyko
-- ipad at 192.168.1.148 


local vport = require 'vport'

local oscgrid = {}
oscgrid.__index = oscgrid

oscgrid.LEDarray = {}          -- create the matrix
  for i=1,16 do
    oscgrid.LEDarray[i] = {}     -- create a new row
    for j=1,8 do
      oscgrid.LEDarray[i][j] = 0
    end
  end    
--print ('ledarray 16 16', oscgrid.LEDarray[16][16])


oscgrid.devices = {}
oscgrid.vports = {}
oscgrid.gridkey = {}

oscgrid.oscdest = {"192.168.1.148",9000}

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

function oscgrid.new(id, serial, name)
  local g = setmetatable({}, oscgrid)

  g.id = id
  g.serial = serial
  g.name = name.." "..serial
  g.dev = {}
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

--- set state of single LED on this grid device.
-- @tparam integer x : column index (1-based!)
-- @tparam integer y : row index (1-based!)
-- @tparam integer val : LED brightness in [0, 15]
function oscgrid:led(x, y, val)
-- print ("ex,why,val,LEDarray",x,y,val, oscgrid.LEDarray[3][3])
--  if oscgrid.LEDarray[x][y] ~= val then
--    oscgrid.LEDarray[x][y] = val
    osc.send(oscgrid.oscdest, "/grid/led ".. x .. " " .. y, {val})
--    end
  --grid_set_led(self.dev, x, y, val)
end

--- set state of all LEDs on this grid device.
-- @tparam integer val : LED brightness in [0, 15]
function oscgrid:all(val)
  for i = 1,16 do
    for j = 1,8 do
--      if oscgrid.LEDarray[i][j] ~= val then
--        oscgrid.LEDarray[i][j] = val
        osc.send(oscgrid.oscdest, "/grid/led ".. i .. " " .. j, {val})
--      return
--      end
    end
  end  
  --grid_all_led(self.dev, val)
end

--- update any dirty quads on this grid device.
function oscgrid:refresh()
  --monome_refresh(self.dev)
end

function oscgrid.connect(n)
  local n = n or 1

  return grid.vports[n]
end

--- clear handlers.
function oscgrid.cleanup()
  for i=1,4 do
    Grid.vports[i].key = nil
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


oscgrid.osc_in = function(path, args, from)
  local k
  local pathxy = {}
  for k in string.gmatch(path, "%S+") do
    table.insert(pathxy,k)
  end
  if string.match(path,"/z") ~= "/z" then
    print(path, pathxy[2], pathxy[3])
    oscpath = pathxy[1]
    x = math.floor(pathxy[2])
    y = math.floor(pathxy[3])
    s = math.floor(args[1])
    if oscpath == "/grid/key" then
      oscgrid.gridkey = {x, y, s}
      oscgrid.grid.key(2, x, y, s)
      --osc.send(oscgrid.oscdest, "/grid/led ".. x .. " " .. y, {val})
      --osc.send(oscgrid.oscdest, path, args) 
      --oscgrid.draw(x .. ' ' .. y .. ' ' .. s)

  end
end
end

osc.event = oscgrid.osc_in

oscgrid.grid = {}

oscgrid.grid.key = function(id, x, y, s)
   --print(x,y,s)
   norns.grid.key(id, x,y,s)
end

-- grid add
oscgrid.grid.add = function(id, serial, name)
  local g = oscgrid.new(id,serial,name)
  grid.devices[id] = g
  oscgrid.update_devices()
  if oscgrid.add ~= nil then oscgrid.add(g) end
end

oscgrid.draw = function(text)
  screen.clear()
  screen.move (10,10)
  screen.text(text)
  screen.stroke()
  screen.update()
end


oscgrid.grid.add(2, "m12345", "oscgrid")

return oscgrid
