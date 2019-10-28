-- mangl
--
-- arc required.
--
-- ----------
--
-- based on the script angl
-- by @tehn and the
-- engine: glut by @artfwo
--
-- ----------
--
-- load samples via param menu
--
-- ----------
--
-- mangl is a 4 track granular
-- sample player.
--
-- arc ring 1 = speed
-- arc ring 2 = pitch
-- arc ring 3 = grain size
-- arc ring 4 = density
--
-- norns key1 = alt
-- norns key2 = enable/disable
--                voice
-- norns key3 = next track
--
-- norns enc1 = volume
--
-- nb: key3 will only advance to
-- the next track if there is a
-- sample loaded. otherwise
-- returns to track 1.
--
-- ----------
--
-- holding alt and turning a ring,
-- or pressing a button,
-- performs a secondary
-- function.
--
-- alt + ring1 = scrub
-- alt + ring2 = fine tune
-- alt + ring3 = spread
-- alt + ring4 = jitter
--
-- alt + key2 = loop in/out
-- alt + key3 = loop clear
--
-- nb: loop in/out is set in
-- one button press. loop in
-- on press, loop out on release.
--
-- ----------
--
-- @justmat v1.3
--
-- llllllll.co/t/21066

engine.name = 'Glut'

--local a = arc.connect(1)
local a = include('lib/oscarc')

local tau = math.pi * 2
local VOICES = 4
local positions = {-1,-1,-1,-1}
local tracks = {"one", "two", "three", "four"}
local track = 1
local alt = false

local last_enc = 0
local time_last_enc = 0

local scrub_sensitivity = 450
local was_playing = false
local track_speed = {0, 0, 0, 0}

local loops = {}
for i = 1, VOICES do
  loops[i] = {
    state = 0,
    dir = 1
  }
end

local loop_in = {nil, nil, nil, nil}
local loop_out = {nil, nil, nil, nil}


local function hold_track_speed(n)
  -- remember track speed and direction while scrubbing audio file
  local speed = params:get(n .. "speed")
  if speed ~= 0 then
    track_speed[n] = speed
    if speed < 0 then
      loops[n].dir = -1
    else
      loops[n].dir = 1
    end
  end
end


local function scrub(n, d)
  -- scrub playback position
  hold_track_speed(n)
  params:set(n .. "speed", 0)
  was_playing = true
  engine.seek(n, positions[n] + d / scrub_sensitivity)
end


local function clear_loop(track)
  loop_in[track] = nil
  loop_out[track] = nil
  loops[track].state = 0
end


function loop_pos()
  -- keeps playback inside the loop
  for i = 1, VOICES do
    if loops[i].state == 1 then
      if loops[i].dir == -1 then
        if positions[i] <= loop_in[i] then
          positions[i] = loop_out[i]
          engine.seek(i, loop_out[i])
        end
      else
        if positions[i] >= loop_out[i] then
          positions[i] = loop_in[i]
          engine.seek(i, loop_in[i])
        end
      end
    end
  end
end


function init()
  -- polls
  for v = 1, VOICES do
    local phase_poll = poll.set('phase_' .. v, function(pos) positions[v] = pos end)
    phase_poll.time = 0.025
    phase_poll:start()
  end

  params:add_separator()

  local sep = ": "

  params:add_taper("reverb_mix", "*" .. sep .. "mix", 0, 100, 20, 0, "%")
  params:set_action("reverb_mix", function(value) engine.reverb_mix(value / 100) end)

  params:add_taper("reverb_room", "*" .. sep .. "room", 0, 100, 50, 0, "%")
  params:set_action("reverb_room", function(value) engine.reverb_room(value / 100) end)

  params:add_taper("reverb_damp", "*" .. sep .. "damp", 0, 100, 50, 0, "%")
  params:set_action("reverb_damp", function(value) engine.reverb_damp(value / 100) end)
  
  params:add_separator()
  for i = 1, VOICES do
    params:add_file(i .. "sample", i .. sep .. "sample")
    params:set_action(i .. "sample", function(file) engine.read(i, file) end)
  end

  params:add_separator()
  params:add_option("alt_behavior", "alt behavior", {"momentary", "toggle"}, 1)
  
  for v = 1, VOICES do
    params:add_separator()

    params:add_option(v .. "play", v .. sep .. "play", {"off","on"}, 1)
    params:set_action(v .. "play", function(x) engine.gate(v, x-1) end)

    params:add_taper(v .. "volume", v .. sep .. "volume", -60, 20, -12, 0, "dB")
    params:set_action(v .. "volume", function(value) engine.volume(v, math.pow(10, value / 20)) end)

    params:add_taper(v .. "speed", v .. sep .. "speed", -300, 300, 0, 0, "%")
    params:set_action(v .. "speed", function(value) engine.speed(v, value / 100) end)

    params:add_taper(v .. "jitter", v .. sep .. "jitter", 0, 500, 0, 5, "ms")
    params:set_action(v .. "jitter", function(value) engine.jitter(v, value / 1000) end)

    params:add_taper(v .. "size", v .. sep .. "size", 1, 500, 100, 5, "ms")
    params:set_action(v .. "size", function(value) engine.size(v, value / 1000) end)

    params:add_taper(v .. "density", v .. sep .. "density", 0, 512, 20, 6, "hz")
    params:set_action(v .. "density", function(value) engine.density(v, value) end)

    params:add_taper(v .. "pitch", v .. sep .. "pitch", -24, 24, 0, 0, "st")
    params:set_action(v .. "pitch", function(value) engine.pitch(v, math.pow(0.5, -value / 12)) end)

    params:add_taper(v .. "spread", v .. sep .. "spread", 0, 100, 0, 0, "%")
    params:set_action(v .. "spread", function(value) engine.spread(v, value / 100) end)

    params:add_taper(v .. "fade", v .. sep .. "att / dec", 1, 9000, 1000, 3, "ms")
    params:set_action(v .. "fade", function(value) engine.envscale(v, value / 1000) end)
  end

  params:read()
  params:bang()
  -- arc redraw metro
  local arc_redraw_timer = metro.init()
  arc_redraw_timer.time = 0.1
  arc_redraw_timer.event = function() arc_redraw() end
  arc_redraw_timer:start()
  -- norns redraw metro
  local norns_redraw_timer = metro.init()
  norns_redraw_timer.time = 0.025
  norns_redraw_timer.event = function() redraw() end
  norns_redraw_timer:start()
  -- loop metro
  local loop_timer = metro.init()
  loop_timer.time = 0.005
  loop_timer.event = function() loop_pos() end
  loop_timer:start()
end

-- norns

function key(n, z)
  if n == 1 then
    hold_track_speed(track)
    if params:get("alt_behavior") == 1 then
      alt = z == 1 and true or false
    elseif z == 1 and params:get("alt_behavior") == 2 then
      alt = not alt
    elseif z == 0 and was_playing then
      params:set(track .. "speed", track_speed[track])
      was_playing = false
    end
  end

  if alt then
    -- key 2 sets the loop_in and loop_out points
    -- loop_in on press, loop_out on release
    if n == 2 then
      if z == 1 then
        if loop_in[track] == nil then
          if loops[track].dir == -1 then
            loop_out[track] = positions[track]
          else
            loop_in[track] = positions[track]
          end
        end
      else
        if loops[track].dir == -1 then
          loop_in[track] = positions[track]
          positions[track] = loop_out[track]
          engine.seek(track, loop_out[track])
          loops[track].state = 1
        else
          loop_out[track] = positions[track]
          positions[track] = loop_in[track]
          engine.seek(track, loop_in[track])
          loops[track].state = 1
        end
      end
    -- key 3 clears the currently selected track
    elseif n == 3 then
      clear_loop(track)
    end
  else
    -- key 2 activates and deactivates the currently selected voice
    if n == 2 and z == 1 then
      params:set(track .. "play", params:get(track .. "play") == 2 and 1 or 2)
    -- key 3 advances track, or wraps to 1 if no sample is loaded
    elseif n == 3 and z == 1 then
      if params:get((track % VOICES) + 1 .. "sample") == "-" then
        track = 1
      else
        track = (track % VOICES) + 1
      end
    end
  end
end


function enc(n, d)
  if n == 1 then
    params:delta(track .. "volume", d)
  end
  last_enc = n
  time_last_enc = util.time()
end


function redraw()
  screen.aa(1)
  screen.clear()
  screen.move(123, 10)
  screen.font_face(25)
  screen.font_size(6)
  screen.level(1)
  if params:get(track .. "sample") == "-" then
    screen.text_right("-")
  else
    screen.text_right(string.match(params:get(track .. "sample"), "[^/]*$"))
  end

  screen.move(64, 36)
  screen.level(params:get(track .. "play") == 2 and 15 or 3)
  screen.font_face(10)
  screen.font_size(30)
  screen.text_center(tracks[track])

  if util.time() - time_last_enc < .6 and last_enc == 1 then
    screen.level(2)
    screen.move(10, 10)
    screen.font_face(25)
    screen.font_size(6)
    screen.text(string.format("%.2f", params:get(track .. "volume")))
  end

  screen.move(20, 50)
  screen.font_size(6)
  screen.font_face(25)
  screen.level(2)
  screen.text_center(alt and "scrub" or "speed")
  screen.move(50, 50)
  screen.text_center(alt and "fine" or "pitch")

  screen.move(80, 50)
  screen.text_center(alt and "spread" or "size")
  screen.move(110, 50)
  screen.text_center(alt and "jitter" or "density")

  screen.level(params:get(track .. "play") == 2 and 15 or 3)
  screen.move(20, 60)
  screen.font_size(8)
  screen.font_face(1)
  screen.text_center(alt and "-" or string.format("%.2f", params:get(track .. "speed")))
  screen.move(50, 60)
  screen.text_center(string.format("%.2f", params:get(track .. "pitch")))

  screen.move(80, 60)
  screen.text_center(string.format("%.2f", alt and params:get(track .. "spread") or params:get(track .. "size")))
  screen.move(110, 60)
  screen.text_center(string.format("%.2f", alt and params:get(track .. "jitter") or params:get(track .. "density")))

  screen.move(track == 3 and 100 or 90, 36)
  screen.level(loops[track].state == 1 and 12 or 0)
  screen.font_size(12)
  screen.font_face(12)
  screen.text("L")

  screen.update()
end

-- arc

function a.delta(n, d)
  if alt then
    if n == 1 then
      scrub(track, d)
      params:set(n .. "speed", track_speed[n])
    elseif n == 2 then
      params:delta(track .. "pitch", d / 20)
    elseif n == 3 then
      params:delta(track .. "spread", d / 10)
    elseif n == 4 then
      params:delta(track .. "jitter", d / 10)
    end
  else
    if n == 1 then
      params:delta(track .. "speed", d / 10)
      hold_track_speed(track)
    elseif n == 2 then
      params:delta(track .. "pitch", d / 2)
    elseif n == 3 then
      params:delta(track .. "size", d / 10)
    elseif n == 4 then
      params:delta(track .. "density", d / 10)
    end
  end
end


function arc_redraw()
  a:all(0)
  a:segment(1, positions[track] * tau, tau * positions[track] + 0.2, 15)
  local pitch = params:get(track .. "pitch") / 10
  if pitch > 0 then
    a:segment(2, 0.5, 0.5 + pitch, 15)
  else
    a:segment(2, pitch - 0.5, -0.5, 15)
  end
  if alt == true then
    local spread = params:get(track .. "spread") / 40
    local jitter = params:get(track .. "jitter") / 80
    a:segment(3, 0.5, 0.5 + spread, 15)
    a:segment(4, 0.5, 0.5 + jitter, 15)
  else
    local size = params:get(track .. "size") / 80
    local density = params:get(track .. "density") / 82
    a:segment(3, 0.5, 0.5 + size, 15)
    a:segment(4, 0.5, 0.5 + density, 15)
  end
  a:refresh()
end
