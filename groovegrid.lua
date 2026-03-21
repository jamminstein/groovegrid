-- groovegrid.lua
-- soulful grid bass / disco funk chicago house
-- 4-voice poly, arp, ripple fx, pulsing metronome row
-- chord progressions, wah, envelope shape
-- ─────────────────────────────────────────────

engine.name = "GrooveGrid"

local g = grid.connect()
local m = midi.connect()

-- OP-XY MIDI
local opxy_out = nil
local function opxy_note_on(note, vel) if opxy_out then opxy_out:note_on(note, vel, params:get("opxy_channel")) end end
local function opxy_note_off(note) if opxy_out then opxy_out:note_off(note, 0, params:get("opxy_channel")) end end

-- ─────────────────────────────────────────────
-- LENNY FACES
-- ─────────────────────────────────────────────
local lenny_faces = {
  "( ́° ˜ʶ ́°)", "( ́̃ ˜ʶ ́°)", "( ́  ̵ʶ ́°)",
  "˕(•ᴥ•)˕", "(ﾉ◦ω◦)ﾉ", "((づ。◦‿◦。))づ",
  "¯\\_((ツ))_/¯", "(́み▰(  み▰) ́)", "ᖜ(⇀※↻)ᖝ",
  "((u('\u0304-'\u0304))u)", "(⋐ş_ş)", "( ́°( ́° ˜ʶ ́°) ́°)",
}

local lenny_pixels = {
  { {2,5},{2,6},{2,11},{2,12},{3,5},{3,11},{4,7},{4,8},{4,9},{4,10},
    {5,6},{5,7},{5,10},{5,11},{6,6},{6,12},{7,7},{7,8},{7,9},{7,10},{7,11} },
  { {1,3},{1,14},{2,4},{2,7},{2,8},{2,9},{2,13},{3,5},{3,6},{3,10},{3,11},
    {4,5},{4,11},{5,7},{5,8},{5,9},{6,7},{6,9},{7,4},{7,13},{8,3},{8,14} },
  { {2,6},{2,7},{2,10},{2,11},{3,5},{3,8},{3,9},{3,12},{4,5},{4,8},{4,9},{4,12},
    {5,6},{5,7},{5,10},{5,11},{6,7},{6,8},{6,9},{6,10},{7,6},{7,11},{8,5},{8,12} },
  { {2,5},{2,6},{2,7},{2,10},{2,11},{2,12},{3,5},{3,7},{3,8},{3,9},{3,10},{3,12},
    {5,6},{5,11},{6,7},{6,8},{6,9},{6,10},{7,7},{7,10} },
}

-- ─────────────────────────────────────────────
-- VOICES
-- ─────────────────────────────────────────────
local voices = {
  { name="Get Lucky",     id=1, bright=12 },
  { name="Da Funk",       id=2, bright=15 },
  { name="Around World",  id=3, bright=8  },
  { name="Harder Better", id=4, bright=10 },
}
local current_voice = 1

local VOICE_ROW  = 1
local PULSE_ROW  = 8
local PLAY_ROWS  = 6
local ROWS, COLS = 8, 16
local MIDI_CH    = 1

-- ─────────────────────────────────────────────
-- SCALES
-- ─────────────────────────────────────────────
local scale_defs = {
  { name="Bb Aeolian",  root=58, intervals={0,2,3,5,7,8,10} },
  { name="E Aeolian",   root=52, intervals={0,2,3,5,7,8,10} },
  { name="D Aeolian",   root=50, intervals={0,2,3,5,7,8,10} },
  { name="A Aeolian",   root=57, intervals={0,2,3,5,7,8,10} },
  { name="G Aeolian",   root=55, intervals={0,2,3,5,7,8,10} },
  { name="Bb Dorian",   root=58, intervals={0,2,3,5,7,9,10} },
  { name="E Dorian",    root=52, intervals={0,2,3,5,7,9,10} },
  { name="D Dorian",    root=50, intervals={0,2,3,5,7,9,10} },
  { name="A Dorian",    root=57, intervals={0,2,3,5,7,9,10} },
  { name="G Dorian",    root=55, intervals={0,2,3,5,7,9,10} },
  { name="Bb Min Pent", root=58, intervals={0,3,5,7,10} },
  { name="E Min Pent",  root=52, intervals={0,3,5,7,10} },
  { name="D Min Pent",  root=50, intervals={0,3,5,7,10} },
  { name="Bb Blues",    root=58, intervals={0,3,5,6,7,10} },
  { name="E Blues",     root=52, intervals={0,3,5,6,7,10} },
  { name="D Blues",     root=50, intervals={0,3,5,6,7,10} },
}

-- ─────────────────────────────────────────────
-- STATE
-- ─────────────────────────────────────────────
local current_scale = nil
local current_lenny = ""
local oct_offset    = -1
local env_shape     = 0.5

local grid_notes   = {}
local grid_bright  = {}
local note_release = {}

local held_notes = {}
local held_order = {}

local arp_on            = false
local arp_active        = false
local arp_index         = 1
local arp_clock         = nil
local arp_divs          = {1/2, 1/4, 1/8, 1/16, 1/32}
local arp_div_names     = {"2nd","4th","8th","16th","32nd"}
local arp_div_idx       = 3
local arp_updown_dir    = 1
local arp_converge_lo   = 1
local arp_converge_hi   = 1
local arp_converge_side = 0
local arp_stutter_count = 0

local arp_modes = {
  { name="up",
    next=function(h,i) return (i%#h)+1 end },
  { name="down",
    next=function(h,i) local n=i-1; if n<1 then n=#h end; return n end },
  { name="up-down",
    next=function(h,i)
      if #h<=1 then return 1 end
      local n=i+arp_updown_dir
      if n>#h then n=#h-1; arp_updown_dir=-1; if n<1 then n=1 end
      elseif n<1 then n=2; arp_updown_dir=1; if n>#h then n=#h end end
      return n end },
  { name="random",
    next=function(h,i)
      if #h<=1 then return 1 end
      local n; repeat n=math.random(#h) until n~=i; return n end },
  { name="drunk",
    next=function(h,i)
      if #h<=1 then return 1 end
      local s={-1,-1,0,1,1}
      local n=i+s[math.random(#s)]
      if n<1 then n=#h elseif n>#h then n=1 end
      return n end },
  { name="skip",
    next=function(h,i) return ((i+1)%#h)+1 end },
  { name="converge",
    next=function(h,i)
      if #h<=1 then return 1 end
      local n
      if arp_converge_side==0 then
        n=arp_converge_lo; arp_converge_lo=arp_converge_lo+1; arp_converge_side=1
      else
        n=arp_converge_hi; arp_converge_hi=arp_converge_hi-1; arp_converge_side=0
      end
      if arp_converge_lo>arp_converge_hi then
        arp_converge_lo=1; arp_converge_hi=#h
      end
      return math.max(1,math.min(#h,n)) end },
  { name="stutter",
    next=function(h,i)
      arp_stutter_count=arp_stutter_count+1
      if arp_stutter_count>=2 then arp_stutter_count=0; return (i%#h)+1 end
      return i end },
}
local arp_mode_idx = 1

local wah_rate  = 2.0
local wah_depth = 4000
local wah_base  = 1000
local wah_cc    = 11  -- MIDI CC for wah depth control
local bpm       = 120.0

-- per-voice octave offsets for layering
local voice_octave_offsets = {0, 0, 0, 0}

-- chord lock state
local chord_lock = false
local locked_chord_idx = 1

local ripples      = {}
local ripple_clock = nil
local pulse_beat   = 0
local pulse_clock  = nil
local pulse_bright = {}
for c = 1, COLS do pulse_bright[c] = 0 end

-- ─────────────────────────────────────────────
-- HELPERS
-- (midi_to_hz and midi_note_on defined here so CHORD PROGRESSIONS can use them)
-- ─────────────────────────────────────────────
local function midi_to_hz(note)
  return 440 * (2 ^ ((note - 69) / 12))
end

local function build_note_pool(scale, oct_low, oct_high)
  local pool, seen = {}, {}
  for oct = oct_low, oct_high do
    for _, iv in ipairs(scale.intervals) do
      local note = scale.root + iv + (oct * 12)
      if note >= 24 and note <= 72 and not seen[note] then
        seen[note] = true; table.insert(pool, note)
      end
    end
  end
  table.sort(pool)
  return pool
end

local function classify_note(note, scale)
  local iv = (note%12 - scale.root%12 + 12) % 12
  if iv==0 then return "root"
  elseif iv==7 then return "fifth"
  elseif iv==6 then return "blue"
  else return "other" end
end

-- ─────────────────────────────────────────────
-- MIDI OUT
-- ─────────────────────────────────────────────
local function midi_note_on(note, vel)
  if m then m:note_on(note, vel or 100, MIDI_CH) end
  opxy_note_on(note, vel or 100)
end

local function midi_note_off(note)
  if m then m:note_off(note, 0, MIDI_CH) end
  opxy_note_off(note)
end

-- ─────────────────────────────────────────────
-- CHORD PROGRESSIONS
-- ─────────────────────────────────────────────
local min7  = {0,3,7,10}
local maj7  = {0,4,7,11}
local dom7  = {0,4,7,10}
local min9  = {0,3,7,10,14}
local sus4  = {0,5,7}
local maj6  = {0,4,7,9}
local dim7  = {0,3,6,9}
local aug   = {0,4,8}
local min11 = {0,3,7,10,17}
local bare5 = {0,7}

local progressions = {
  { name="ii-IV-vi-V",
    chords={{2,min7,"ii"},{5,maj7,"IV"},{9,min7,"vi"},{7,dom7,"V"}} },
  { name="IV-ii-vi-V",
    chords={{5,maj7,"IV"},{2,min7,"ii"},{9,min7,"vi"},{7,dom7,"V"}} },
  { name="ii-IV ghost",
    chords={{2,min9,"ii9"},{5,maj6,"IV6"},{10,dom7,"bVII"},{7,sus4,"Vsus"}} },
  { name="IV-ii inverted",
    chords={{5,maj7,"IV"},{4,dim7,"IVdim"},{2,min7,"ii"},{7,dom7,"V"}} },
  { name="vi descent",
    chords={{9,min7,"vi"},{8,aug,"aug"},{7,dom7,"V"},{5,maj7,"IV"}} },
  { name="house pump",
    chords={{2,bare5,"ii5"},{5,bare5,"IV5"},{2,bare5,"ii5"},{7,sus4,"Vsus"}} },
  { name="funk glitch",
    chords={{2,min9,"ii9"},{3,min7,"bIII"},{5,maj6,"IV6"},{6,dim7,"dimdim"}} },
  { name="modal drift",
    chords={{2,min7,"ii"},{10,dom7,"bVII"},{5,maj7,"IV"},{7,min7,"vm"}} },
  { name="disco ghost",
    chords={{5,maj7,"IV"},{9,min11,"vi11"},{2,min9,"ii9"},{7,dom7,"V"}} },
  { name="deep house",
    chords={{9,min7,"vi"},{5,maj7,"IV"},{9,min7,"vi"},{7,sus4,"Vsus"}} },
  { name="glitch stutter",
    chords={{2,min7,"ii"},{2,min9,"ii9"},{5,maj7,"IV"},{3,dim7,"bIIIdim"}} },
  { name="outer space",
    chords={{2,aug,"iiaug"},{5,maj7,"IV"},{6,dim7,"dimdim"},{7,dom7,"V"}} },
}

local prog_on       = false
local prog_index    = 1
local prog_chord    = 1
local prog_notes    = {}
local prog_clock    = nil
local prog_div_opts = {1, 2, 4}
local prog_div_idx  = 2

local function chord_notes(scale_root, chord_root_offset, intervals, oct)
  local notes = {}
  local base = scale_root + chord_root_offset + (oct * 12)
  for _, iv in ipairs(intervals) do
    local n = base + iv
    while n > 72 do n = n - 12 end
    while n < 24 do n = n + 12 end
    table.insert(notes, n)
  end
  return notes
end

local function prog_build_chord()
  local prog = progressions[prog_index]
  local ch   = prog.chords[prog_chord]
  local oct  = oct_offset + 1
  prog_notes = chord_notes(current_scale.root, ch[1], ch[2], oct)
  if math.random() < 0.3 and #prog_notes > 2 then
    table.remove(prog_notes, math.random(#prog_notes))
  end
  if math.random() < 0.25 then
    local i = math.random(#prog_notes)
    prog_notes[i] = prog_notes[i] + (math.random(2)==1 and 12 or -12)
    prog_notes[i] = math.max(24, math.min(72, prog_notes[i]))
  end
  for i = #prog_notes, 2, -1 do
    local j = math.random(i)
    prog_notes[i], prog_notes[j] = prog_notes[j], prog_notes[i]
  end
end

local function prog_advance()
  if chord_lock then return end  -- skip advance if chord is locked
  local prog = progressions[prog_index]
  prog_chord = (prog_chord % #prog.chords) + 1
  prog_build_chord()
end

local function stop_prog()
  if prog_clock then clock.cancel(prog_clock); prog_clock = nil end
end

local function start_prog()
  stop_prog()
  prog_build_chord()
  prog_clock = clock.run(function()
    while true do
      for _, note in ipairs(prog_notes) do
        engine.voice(current_voice)
        engine.env_shape(env_shape)
        engine.amp(params:get("amp"))
        engine.note_on(midi_to_hz(note), 0.15)
        midi_note_on(note)
        clock.sleep(0.04)
      end
      clock.sync(prog_div_opts[prog_div_idx])
      prog_advance()
    end
  end)
end

-- ─────────────────────────────────────────────
-- LAYOUT
-- ─────────────────────────────────────────────
local function generate_layout(scale, oct_off)
  local notes, bright, rel = {}, {}, {}
  local pool = build_note_pool(scale, oct_off, oct_off+3)
  local n = #pool
  for r = 1, PLAY_ROWS do
    notes[r], bright[r], rel[r] = {}, {}, {}
    local pf = 1 - ((r-1)/(PLAY_ROWS-1))
    for c = 1, COLS do
      if math.random() < 0.15 then
        notes[r][c]=nil; bright[r][c]=0
      else
        local cf = (c-1)/(COLS-1)
        local cb = math.max(0.01, math.min(0.99,
          pf*0.75 + cf*0.25 + (math.random()-0.5)*0.15))
        local idx = math.max(1, math.min(n, math.floor(cb*n+0.5)))
        notes[r][c] = pool[idx]
        local kind = classify_note(pool[idx], scale)
        bright[r][c] = (kind=="root") and 15 or (kind=="fifth") and 12
                    or (kind=="blue") and 9 or math.random(5,10)
        rel[r][c] = 0.05 + math.random()*0.4
      end
    end
  end
  return notes, bright, rel
end

-- build visual representation of all scale-legal notes (dim level 3)
local function build_scale_visual(scale, oct_off)
  local visual = {}
  local pool = build_note_pool(scale, oct_off, oct_off+3)
  local pool_set = {}
  for _, n in ipairs(pool) do pool_set[n] = true end

  for r = 1, PLAY_ROWS do
    visual[r] = {}
    for c = 1, COLS do
      if grid_notes[r] and grid_notes[r][c] and pool_set[grid_notes[r][c]] then
        visual[r][c] = 3  -- dim level for scale-legal notes
      else
        visual[r][c] = 0
      end
    end
  end
  return visual
end

-- ─────────────────────────────────────────────
-- RIPPLE
-- ─────────────────────────────────────────────
local function add_ripple(x, y)
  table.insert(ripples, {x=x, y=y, r=0, age=0})
end

local function update_ripples()
  local alive = {}
  for _, rip in ipairs(ripples) do
    rip.r = rip.r + 0.4; rip.age = rip.age + 1
    if rip.age < 18 then table.insert(alive, rip) end
  end
  ripples = alive
end

local function ripple_brightness(gx, gy, rip)
  local dx = gx-rip.x; local dy = gy-rip.y
  local dist = math.sqrt(dx*dx + dy*dy)
  local diff = math.abs(dist - rip.r)
  if diff < 1.2 then
    local fade = 1 - (rip.age/18)
    local brightness = math.floor(12 * fade * (1 - diff/1.2))
    return math.max(0, math.min(15, brightness))  -- clamp to valid range
  end
  return 0
end

-- ─────────────────────────────────────────────
-- NOTE TRIGGER
-- ─────────────────────────────────────────────
local function trigger_note(note, rel, gx, gy)
  engine.voice(current_voice)
  engine.env_shape(env_shape)
  engine.amp(params:get("amp"))
  -- apply per-voice octave offset
  local octave_shift = voice_octave_offsets[current_voice] * 12
  local shifted_note = note + octave_shift
  engine.note_on(midi_to_hz(shifted_note), rel or 0.3)
  midi_note_on(shifted_note)
  if gx and gy then add_ripple(gx, gy) end
end

-- ─────────────────────────────────────────────
-- WAH
-- ─────────────────────────────────────────────
local function update_wah()
  engine.wah_rate(wah_rate)
  engine.wah_depth(wah_depth)
  engine.wah_base(wah_base)
end

-- ─────────────────────────────────────────────
-- ARPEGGIATOR
-- ─────────────────────────────────────────────
local function arp_next()
  local count = #held_order
  if count == 0 then return end
  local mode = arp_modes[arp_mode_idx]
  arp_index = mode.next(held_order, arp_index)
  arp_index = math.max(1, math.min(count, arp_index))
  local note = held_order[arp_index]
  local gx, gy, rel = nil, nil, 0.1
  for r = 1, PLAY_ROWS do
    for c = 1, COLS do
      if grid_notes[r] and grid_notes[r][c] == note then
        gx=c; gy=r+1; rel=note_release[r][c]; break
      end
    end
  end
  trigger_note(note, rel, gx, gy)
end

local function stop_arp()
  if arp_clock then clock.cancel(arp_clock); arp_clock = nil end
  arp_active = false
  for _, note in ipairs(held_order) do midi_note_off(note) end
end

local function start_arp()
  if arp_clock then clock.cancel(arp_clock) end
  arp_active = true
  arp_clock = clock.run(function()
    while true do
      clock.sync(arp_divs[arp_div_idx])
      if #held_order > 0 then
        arp_active = true
        arp_next()
      else
        arp_active = false
      end
    end
  end)
end

-- ─────────────────────────────────────────────
-- GRID DRAWING
-- ─────────────────────────────────────────────
local function draw_voice_row()
  if not g then return end
  for v = 1, 4 do
    local cs = (v-1)*4+1
    for c = cs, cs+3 do
      g:led(c, VOICE_ROW, v==current_voice and voices[v].bright or 3)
    end
  end
end

local function draw_pulse_row()
  if not g then return end
  for c = 1, COLS do
    g:led(c, PULSE_ROW, pulse_bright[c])
  end
end

local function grid_redraw()
  if not g then return end
  g:all(0)
  draw_voice_row()

  -- build and cache scale visual
  local scale_visual = build_scale_visual(current_scale, oct_offset)

  for r = 1, PLAY_ROWS do
    local gr = r+1
    for c = 1, COLS do
      local base = 0
      if grid_notes[r] and grid_notes[r][c] then
        local key = r.."_"..c
        base = held_notes[key] and 15 or grid_bright[r][c]
      else
        -- show dimly-lit scale-legal notes even when not held
        base = scale_visual[r] and scale_visual[r][c] or 0
      end
      local rval = 0
      for _, rip in ipairs(ripples) do
        rval = math.max(rval, ripple_brightness(c, gr, rip))
      end
      local final = math.min(15, base+rval)
      if final > 0 then g:led(c, gr, final) end
    end
  end
  draw_pulse_row()
  g:refresh()
end

local function start_ripple_clock()
  if ripple_clock then clock.cancel(ripple_clock) end
  ripple_clock = clock.run(function()
    while true do
      clock.sleep(1/30)
      update_ripples()
      grid_redraw()
    end
  end)
end

local function grid_flash_lenny(idx)
  local pixels = lenny_pixels[((idx-1) % #lenny_pixels)+1]
  clock.run(function()
    g:all(0); g:refresh(); clock.sleep(0.1)
    g:all(0)
    for _, px in ipairs(pixels) do
      if px[1]>=1 and px[1]<=ROWS and px[2]>=1 and px[2]<=COLS then
        g:led(px[2], px[1], 15)
      end
    end
    g:refresh(); clock.sleep(0.8)
    g:all(0)
    for _, px in ipairs(pixels) do
      if px[1]>=1 and px[1]<=ROWS and px[2]>=1 and px[2]<=COLS then
        g:led(px[2], px[1], 4)
      end
    end
    g:refresh(); clock.sleep(0.3)
    g:all(0); g:refresh(); clock.sleep(0.2)
    for c = 1, COLS do
      draw_voice_row()
      for r = 1, PLAY_ROWS do
        if grid_notes[r] and grid_notes[r][c] then
          g:led(c, r+1, grid_bright[r][c])
        end
      end
      g:refresh(); clock.sleep(0.03)
    end
  end)
end

-- ─────────────────────────────────────────────
-- PULSE ROW
-- ─────────────────────────────────────────────
local function start_pulse()
  if pulse_clock then clock.cancel(pulse_clock) end
  pulse_clock = clock.run(function()
    while true do
      clock.sync(1/4)
      pulse_beat = (pulse_beat % COLS) + 1
      for c = 1, COLS do
        local dist = math.min(math.abs(c-pulse_beat), COLS-math.abs(c-pulse_beat))
        pulse_bright[c] = dist==0 and 15 or dist==1 and 6 or 0
      end
      clock.run(function()
        for _ = 1, 8 do
          clock.sleep(1/30)
          for c = 1, COLS do
            pulse_bright[c] = math.max(0, pulse_bright[c]-2)
          end
        end
      end)
    end
  end)
end

-- ─────────────────────────────────────────────
-- SCREEN
-- ─────────────────────────────────────────────
function redraw()
  screen.clear()
  screen.aa(1)
  screen.font_face(1)

  screen.font_size(16)
  screen.level(12)
  screen.move(0, 18)
  screen.text(current_scale and current_scale.name or "")

  screen.font_size(8)
  screen.level(5)
  screen.move(128, 18)
  screen.text_right("oct " .. oct_offset)

  screen.font_size(10)
  screen.level(10)
  screen.move(0, 32)
  screen.text(voices[current_voice].name)

  screen.font_size(8)
  screen.level(4)
  screen.move(128, 32)
  local shape_str = env_shape < 0.33 and "plucky"
                 or env_shape < 0.66 and "mid"
                 or "sustained"
  screen.text_right(shape_str)

  -- show per-voice octave offset
  screen.font_size(7)
  screen.level(3)
  screen.move(0, 40)
  local v_off = voice_octave_offsets[current_voice]
  local v_off_str = (v_off > 0 and "+" or "") .. tostring(v_off)
  screen.text("voice oct: " .. v_off_str)

  screen.level(2)
  screen.move(0, 36)
  screen.line(128, 36)
  screen.stroke()

  if prog_on then
    screen.font_size(10)
    screen.level(15)
    screen.move(0, 50)
    screen.text("PROG")
    screen.font_size(7)
    screen.level(8)
    screen.move(40, 50)
    screen.text(progressions[prog_index].name)
    screen.level(5)
    screen.move(40, 61)
    local ch = progressions[prog_index].chords[prog_chord]
    screen.text(ch[3] .. "  " .. prog_div_opts[prog_div_idx] .. "b")

    -- chord lock indicator
    screen.level(chord_lock and 15 or 3)
    screen.move(110, 61)
    screen.text("LOCK")
  elseif arp_on then
    screen.font_size(14)
    screen.level(15)
    screen.move(0, 50)
    screen.text("ARP")
    screen.font_size(8)
    screen.level(8)
    screen.move(40, 50)
    screen.text(arp_div_names[arp_div_idx])
    screen.move(40, 61)
    screen.text(arp_modes[arp_mode_idx].name)
  else
    screen.font_size(8)
    screen.level(3)
    screen.move(0, 50)
    screen.text("arp off")
  end

  screen.font_size(14)
  screen.level(arp_on and 12 or 5)
  screen.move(128, 50)
  screen.text_right(math.floor(bpm) .. " bpm")

  screen.level(4)
  local bar_w = math.floor((wah_depth/7000)*60)
  screen.move(68, 63)
  screen.line(68+bar_w, 63)
  screen.stroke()
  screen.font_size(7)
  screen.level(2)
  screen.move(68, 61)
  screen.text("wah")

  screen.update()
end

-- ─────────────────────────────────────────────
-- GRID INPUT
-- ─────────────────────────────────────────────
function g.key(x, y, z)
  if y == VOICE_ROW then
    if z == 1 then
      local v = math.ceil(x/4)
      if v >= 1 and v <= 4 then
        current_voice = v
        engine.voice(current_voice)
        draw_voice_row()
        g:refresh()
        redraw()
      end
    end
    return
  end

  if y == PULSE_ROW then return end

  local r = y - 1
  if r < 1 or r > PLAY_ROWS then return end
  local note = grid_notes[r] and grid_notes[r][x]
  if not note then return end

  local key = r.."_"..x
  if z == 1 then
    held_notes[key] = note
    local found = false
    for _, v in ipairs(held_order) do if v==note then found=true end end
    if not found then table.insert(held_order, note) end
    if arp_on then
      arp_active = true
    else
      trigger_note(note, note_release[r][x], x, y)
    end
    add_ripple(x, y)
  else
    held_notes[key] = nil
    for i = #held_order, 1, -1 do
      if held_order[i]==note then table.remove(held_order, i) end
    end
    if not arp_on then midi_note_off(note) end
  end
end

-- ─────────────────────────────────────────────
-- NORNS KEYS
-- ─────────────────────────────────────────────
-- track key hold for K2 long-press
local key2_down_time = 0
local key2_threshold = 0.8  -- 800ms for long-press

function key(n, z)
  if n == 1 then
    k1_held = (z == 1)
    return
  elseif n == 2 then
    if z == 1 and k1_held then
      prog_on = not prog_on
      if prog_on then
        prog_index = math.random(#progressions)
        prog_chord = 1
        start_prog()
      else
        stop_prog()
      end
      redraw()
      return
    end
    if z == 1 then
      key2_down_time = 0
      clock.run(function()
        while key2_down_time < key2_threshold and key2_down_time >= 0 do
          clock.sleep(0.05)
          key2_down_time = key2_down_time + 0.05
        end
        if key2_down_time >= key2_threshold and prog_on then
          -- K2 long-press: toggle chord lock
          chord_lock = not chord_lock
          redraw()
        end
      end)
    else
      if key2_down_time < key2_threshold then
        -- K2 short press: new scale
        current_scale = scale_defs[math.random(#scale_defs)]
        current_lenny = lenny_faces[math.random(#lenny_faces)]
        grid_notes, grid_bright, note_release =
          generate_layout(current_scale, oct_offset)
        redraw()
      end
      key2_down_time = -1
    end
  elseif n == 3 then
    if z == 1 then
      arp_on = not arp_on
      if arp_on then start_arp() else stop_arp() end
      redraw()
    end
  end
end

-- ─────────────────────────────────────────────
-- NORNS ENCODERS
-- ─────────────────────────────────────────────
function enc(n, d)
  if n == 1 then
    if prog_on then
      prog_index = (prog_index % #progressions) + 1
      prog_chord = 1
      start_prog()
    elseif arp_on then
      bpm = math.max(40, math.min(240, bpm + d))
      clock.tempo = bpm
    else
      local new_oct = math.max(-2, math.min(2, oct_offset+(d>0 and 1 or -1)))
      if new_oct ~= oct_offset then
        oct_offset = new_oct
        grid_notes, grid_bright, note_release =
          generate_layout(current_scale, oct_offset)
      end
    end

  elseif n == 2 then
    if prog_on then
      prog_div_idx = math.max(1, math.min(#prog_div_opts,
        prog_div_idx + (d>0 and 1 or -1)))
    elseif arp_on then
      arp_div_idx = math.max(1, math.min(#arp_divs,
        arp_div_idx + (d>0 and 1 or -1)))
      arp_mode_idx = util.clamp(arp_mode_idx + (d>0 and 1 or -1), 1, #arp_modes)
      arp_updown_dir    = 1
      arp_converge_lo   = 1
      arp_converge_hi   = math.max(1, #held_order)
      arp_converge_side = 0
      arp_stutter_count = 0
      start_arp()
    else
      local v = math.max(0, math.min(1, params:get("amp") + d*0.02))
      params:set("amp", v)
    end

  elseif n == 3 then
    if math.abs(d) > 3 then
      wah_depth = math.max(200, math.min(7000, wah_depth + d*60))
      update_wah()
    else
      -- E3 fine adjust: control per-voice octave offset
      voice_octave_offsets[current_voice] =
        math.max(-2, math.min(2, voice_octave_offsets[current_voice] + (d>0 and 1 or -1)))
    end
  end

  redraw()
end

-- ─────────────────────────────────────────────
-- MIDI CLOCK IN
-- ─────────────────────────────────────────────
m.event = function(data)
  local msg = midi.to_msg(data)
  if msg.type == "start" or msg.type == "continue" then
    if arp_on then start_arp() end
    if prog_on then start_prog() end
  elseif msg.type == "stop" then
    if arp_on then stop_arp(); start_arp() end
    if prog_on then stop_prog(); start_prog() end
  elseif msg.type == "cc" then
    -- handle wah depth from external MIDI CC
    if msg.cc == wah_cc then
      wah_depth = util.linlin(0, 127, 200, 7000, msg.val)
      update_wah()
    end
  end
end

-- ─────────────────────────────────────────────
-- PARAMS
-- ─────────────────────────────────────────────
local function setup_params()
  params:add_separator("groovegrid")
  params:add_control("amp", "amp",
    controlspec.new(0, 1, "lin", 0.01, 0.8, ""))
  params:set_action("amp", function(v) engine.amp(v) end)
  params:add_control("res", "resonance",
    controlspec.new(0, 1, "lin", 0.01, 0.3, ""))
  params:set_action("res", function(v) engine.res(v) end)
  params:add_option("gg_clock_source", "clock source", {"internal","midi"}, 1)
  params:set_action("gg_clock_source", function(v)
    clock.source = (v==1 and "internal" or "midi")
  end)

  -- per-voice octave offset controls
  params:add_separator("voice octaves")
  for v = 1, 4 do
    params:add_number("voice"..v.."_oct_offset", "voice "..v.." octave",
      -2, 2, 0)
    params:set_action("voice"..v.."_oct_offset", function(val)
      voice_octave_offsets[v] = val
    end)
  end

  -- wah CC control
  params:add_separator("wah & midi")
  params:add_number("wah_cc", "wah CC", 1, 127, 11)
  params:set_action("wah_cc", function(val) wah_cc = val end)
end

-- ─────────────────────────────────────────────
-- INIT
-- ─────────────────────────────────────────────
function init()
  math.randomseed(os.time())

  params:add_separator("OP-XY MIDI")
  params:add{type="number", id="opxy_device", name="OP-XY Device", min=1, max=16, default=2, action=function(v) opxy_out = midi.connect(v) end}
  params:add{type="number", id="opxy_channel", name="OP-XY Channel", min=1, max=16, default=1}
  opxy_out = midi.connect(params:get("opxy_device"))

  current_scale = scale_defs[math.random(#scale_defs)]
  current_lenny = lenny_faces[math.random(#lenny_faces)]
  grid_notes, grid_bright, note_release =
    generate_layout(current_scale, oct_offset)
  setup_params()
  clock.tempo = bpm
  engine.voice(current_voice)
  engine.env_shape(env_shape)
  engine.amp(0.8)
  engine.res(0.3)
  update_wah()
  start_pulse()
  start_ripple_clock()
  redraw()
  if g then grid_flash_lenny(math.random(#lenny_pixels)) end
end

function cleanup()
  stop_arp()
  stop_prog()
  if pulse_clock  then clock.cancel(pulse_clock)  end
  if ripple_clock then clock.cancel(ripple_clock) end
  if m then
    for note = 0, 127 do m:note_off(note, 0, MIDI_CH) end
  end
  if opxy_out then for ch=1,16 do opxy_out:cc(123,0,ch) end end
end