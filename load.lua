-- oscgrid/oscarc loader
-- run this to load oscgrid and oscarc into memory

-- you can also use this directly in another script
-- replace grid.connect() with include('lib/oscgrid') 
-- and you're off to the races

-- g = grid.connect()
-- local g = include('lib/oscgrid')

local touchoscsourceip = "10.0.1.11"
local touchoscsourceport = 9000

local grds = {}
local g
local grid_w
local grid_h
local ar


function init()
  connect()
  get_grid_names()
  --tab.print(grds[1])
  --tab.print(grid.vports[1].device)
  screen.aa(0)
  redraw()
end

function get_grid_names()
  -- Get a list of grid devices
  for id,device in pairs(grid.vports) do
    grds[id] = {name = device.name, id = device.id }
    --grds[id].id = device.id
  end
end

function connect()
  grid.update_devices()
  g = include('lib/oscgrid')
  local g_id = 2
  g.grid.add(g_id, "m12345", "oscgrid", {})
  g.key = oscgrid_key
  grid_w = g.cols
  grid_h = g.rows
  --g:rotation(0)
  
  arc.update_devices()
  ar = include('lib/oscarc')
  local ar_id = 2
  ar.arc.add(ar_id, "m54321", "oscarc", {})
  ar.delta = oscarc_delta

  g.oscdest = {touchoscsourceip,touchoscsourceport}
  ar.oscdest = {touchoscsourceip,touchoscsourceport}

  osc.event = function(path, args, from)
    g.osc_in(path, args, from, g_id)
    ar.osc_in(path, args, from, ar_id)
  end
  
  --print ("cols/rows", grid_w, grid_h)
end


function oscgrid_key(x, y, s)
  if s == 1 then
    --print('keyon')
    --g:led(x,y,15)
    --g:refresh()
  else
    --print('keyoff')
    --g:led(x,y,0)
    --g:refresh()
  end
  --print (x .. ' ' .. y .. ' ' .. s)
end

function oscarc_delta(n, delta)
  --print (n , delta)  
end


function redraw()
  screen.clear()
  screen.level(15)
  screen.move (0,10)
  screen.text('oscgrid loaded')
  
  screen.update()
end