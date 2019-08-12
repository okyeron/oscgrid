-- oscgrid test
-- replace grid.connect() with include('lib/oscgrid') 
-- and you're off to the races

--g = grid.connect()
local g = include('lib/oscgrid')


function init()
  screen.aa(0)
  redraw()
end

function key(n,z)
  if n==2 and z==1 then
     redraw()
  end
end


g.key = function(x,y,s)
  if s == 1 then
    --print('keyon')
  else
    --print('keyoff')
  end
    g.draw(x .. ' ' .. y .. ' ' .. s)
 end


function redraw()
  screen.clear()
  screen.level(15)
  screen.move (10,50)
  screen.text('oscgrid')
  
  screen.update()
end