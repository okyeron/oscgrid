-- physical
-- norns study 4
--
-- grid controls arpeggio
-- midi controls root note
-- ENC2 = bpm
-- ENC3 = scale

engine.name = 'PolyPerc'

music = require 'musicutil'
beatclock = require 'beatclock'


steps = {}
position = 1
transpose = 0

--g = grid.connect()
g = include('lib/oscgrid')

mode = math.random(#music.SCALES)
scale = music.generate_scale_of_length(60,music.SCALES[mode].name,8)

clk = beatclock.new()
clk_midi = midi.connect()
clk_midi.event = clk.process_midi

function init()
  for i=1,16 do
    table.insert(steps,math.random(8))
  end
  grid_redraw()

  clk.on_step = count
  clk.on_select_internal = function() clk:start() end
  clk.on_select_external = function() print("external") end
  clk:add_clock_params()

  params:add_separator()

  clk:start()
end

function enc(n,d)
  if n == 2 then
    params:delta("bpm",d)
  elseif n == 3 then
    mode = util.clamp(mode + d, 1, #music.SCALES)
    scale = music.generate_scale_of_length(60,music.SCALES[mode].name,8)
  end
  redraw()
end

function redraw()
  screen.clear()
  screen.level(15)
  screen.move(0,30)
  screen.text("bpm: "..params:get("bpm"))
  screen.move(0,40)
  screen.text(music.SCALES[mode].name)
  screen.update()
end



g.key = function(x,y,z)
  --print(x,y,z)
  if z == 1 then  
    steps[x] = y
    grid_redraw()
  end
  
end

function grid_redraw()
  g:all(0)
  for i=1,16 do
    g:led(i,steps[i],i==position and 15 or 6)
  end
  g:refresh()
end

function count()
  position = (position % 16) + 1
  engine.hz(music.note_num_to_freq(scale[steps[position]] + transpose))
  grid_redraw()
end

m = midi.connect()
m.event = function(data)
  local d = midi.to_msg(data)
  if d.type == "note_on" then
    transpose = d.note - 60
  end
end
