-- oscgrid/oscarc loader
-- run this to load oscgrid and oscarc into memory

-- you can also use this directly in another script
-- replace grid.connect() with include('lib/oscgrid') 
-- and you're off to the races

-- ar = arc.connect()
-- local ar = include('lib/oscarc')

local touchoscsourceip = "10.0.1.11"
local touchoscsourceport = 9000

local ar

function init()
  connect()

  screen.aa(0)
  redraw()
end


function connect()

  arc.update_devices()
  ar = include('lib/oscarc')
  local ar_id = 2
  ar.arc.add(ar_id, "m54321", "oscarc", {})
  ar.delta = oscarc_delta

  ar.oscdest = {touchoscsourceip,touchoscsourceport}
  
  osc.event = ar.osc_in
end

function oscarc_delta(n, delta)
  --print (n , delta)
  
end

function redraw()
  screen.clear()
  screen.level(15)
  screen.move (0,10)
  screen.text('oscarc loaded')
  
  screen.update()
end