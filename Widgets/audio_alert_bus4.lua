function widget:GetInfo()
  return {
    name    = "Voice Alert Bus (Queued + Master Volume)",
    desc    = "Serializes voice/UI clips so they never overlap; global Master Volume slider up to 10×",
    author  = "FrequentPilgrim",
    date    = "2025-09-04",
    license = "MIT",
    layer   = 0,
    enabled = true,
  }
end

--------------------------------------------------------------------------------
-- Epic Menu: global master volume for ALL queued alerts
--------------------------------------------------------------------------------
options = options or {}
local OPTIONS_PATH = "Settings/Audio/Audio Alerts"
options_order = options_order or {}
if not options_order or #options_order == 0 then
  options_order = {"voiceAlertMasterVolume"}
else
  table.insert(options_order, 1, "voiceAlertMasterVolume")
end

options.voiceAlertMasterVolume = {
  name  = "Voice Alerts Master Volume",
  desc  = "Global volume multiplier applied to all queued alerts (0.10×–10.00×).",
  type  = "number",
  min   = 0.10, max = 10.00, step = 0.05,
  value = 1.00,
  path  = OPTIONS_PATH,
}

function widget:GetConfigData()
  return {
    voiceAlertMasterVolume = options.voiceAlertMasterVolume and options.voiceAlertMasterVolume.value or 1.00,
  }
end

function widget:SetConfigData(data)
  if not data then return end
  if options.voiceAlertMasterVolume and data.voiceAlertMasterVolume then
    options.voiceAlertMasterVolume.value = tonumber(data.voiceAlertMasterVolume) or 1.00
  end
end

--------------------------------------------------------------------------------
-- Internals
--------------------------------------------------------------------------------
local PlaySoundFile = Spring.PlaySoundFile
local GetTimer      = Spring.GetTimer
local DiffTimers    = Spring.DiffTimers
local VFS_LoadFile  = VFS.LoadFile

-- Little-endian helpers (Lua 5.1 safe)
local function le32(s, i)
  local b1,b2,b3,b4 = s:byte(i, i+3); if not b4 then return nil end
  return b1 + b2*256 + b3*65536 + b4*16777216
end
local function le64(s, i)
  local b1,b2,b3,b4,b5,b6,b7,b8 = s:byte(i, i+7); if not b8 then return nil end
  return b1 + b2*2^8 + b3*2^16 + b4*2^24 + b5*2^32 + b6*2^40 + b7*2^48 + b8*2^56
end

-- WAV PCM duration
local function wavDurationSeconds(path)
  local data = VFS_LoadFile(path)
  if not data or data:sub(1,4) ~= "RIFF" or data:sub(9,12) ~= "WAVE" then return nil end
  local pos, len = 13, #data
  local numCh, sampleRate, bitsPerSample, dataSize
  while pos + 8 <= len do
    local id = data:sub(pos, pos+3); pos = pos + 4
    local sz = le32(data, pos); pos = pos + 4
    if not sz then break end
    if id == "fmt " then
      local fmt = data:byte(pos, pos) + data:byte(pos+1, pos+1)*256
      if fmt ~= 1 then return nil end -- PCM only
      numCh         = data:byte(pos+2, pos+2)
      sampleRate    = le32(data, pos+4)
      bitsPerSample = data:byte(pos+14, pos+14) + (data:byte(pos+15,pos+15) or 0)*256
    elseif id == "data" then
      dataSize = sz
    end
    pos = pos + sz
  end
  if not (numCh and sampleRate and bitsPerSample and dataSize and sampleRate > 0) then return nil end
  local bytesPerSample = (bitsPerSample/8) * numCh
  if bytesPerSample <= 0 then return nil end
  return dataSize / (sampleRate * bytesPerSample)
end

-- OGG Vorbis duration via last OggS granule position
local function oggVorbisDurationSeconds(path)
  local data = VFS_LoadFile(path); if not data then return nil end
  local p = data:find("vorbis", 1, true); if not p then return nil end
  local sampleRate = le32(data, p + 11) -- 'vorbis'(6) + version(4) + channels(1) + sampleRate(4)
  if not sampleRate or sampleRate <= 0 then return nil end
  local lastPos, pos = nil, 1
  while true do
    local i = data:find("OggS", pos, true)
    if not i then break end
    lastPos = i; pos = i + 1
  end
  if not lastPos then return nil end
  local granule = le64(data, lastPos + 6)
  if not granule or granule < 0 then return nil end
  return granule / sampleRate
end

local function guessDurationSeconds(path)
  local lower = path:lower()
  if lower:sub(-4) == ".wav" then
    return wavDurationSeconds(path)
  elseif lower:sub(-4) == ".ogg" then
    return oggVorbisDurationSeconds(path)
  end
  return nil
end

-- Bus state
local Bus = {
  queue          = {},
  playing        = false,
  current        = nil,
  tStart         = nil,
  tNow           = nil,
  fallback       = 2.0,       -- used if we can’t parse length
  defaultVolume  = 1.0,
  defaultChannel = "ui",      -- unify routing so mixer behavior is consistent
  masterGain     = 1.0,       -- driven by the slider
  lastByKey      = {},        -- optional dedupe book-keeping
}

-- Public API: WG.VoiceBus.play(path, {volume=, channel=, duration=, priority=, key=, cooldown=})
-- Queue-only behavior by design: items are always enqueued and played sequentially.
local function enqueue(path, opts)
  -- Respect end-of-match hard lock (if another widget has locked the bus)
  if WG and WG.VoiceBus and WG.VoiceBus._locked then
    return false
  end

  opts = opts or {}
  local dur = opts.duration or guessDurationSeconds(path) or Bus.fallback
  local item = {
    path     = path,
    volume   = (opts.volume and tonumber(opts.volume)) or Bus.defaultVolume,
    channel  = (opts.channel ~= nil) and opts.channel or Bus.defaultChannel, -- may be nil
    duration = dur,
    priority = (opts.priority and tonumber(opts.priority)) or 0,
    key      = opts.key,
    cooldown = (opts.cooldown and tonumber(opts.cooldown)) or 0,
  }

  -- Optional dedupe by key+cooldown (if caller uses it)
  if item.key and item.cooldown > 0 then
    local now  = GetTimer()
    local last = Bus.lastByKey[item.key]
    if last and DiffTimers(now, last) < item.cooldown then
      return false
    end
  end

  -- Stable insert by priority (higher earlier)
  local inserted = false
  for i = #Bus.queue, 1, -1 do
    if (Bus.queue[i].priority or 0) >= item.priority then
      table.insert(Bus.queue, i + 1, item); inserted = true; break
    end
  end
  if not inserted then table.insert(Bus.queue, 1, item) end
  return true
end

local function startNext()
  Bus.current = table.remove(Bus.queue, 1)
  if not Bus.current then
    Bus.playing = false
    return
  end
  Bus.playing = true
  Bus.tStart  = GetTimer()
  -- PlaySoundFile(file, volume[, x[, y[, z[, sx[, sy[, sz[, channel]]]]]]])
  local vol = (Bus.current.volume or 1.0) * (Bus.masterGain or 1.0)
  PlaySoundFile(Bus.current.path, vol, nil, nil, nil, nil, nil, nil, Bus.current.channel)
  if Bus.current.key then Bus.lastByKey[Bus.current.key] = Bus.tStart end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------
function widget:Initialize()
  -- Bind slider to masterGain (persisted + live updates)
  if options.voiceAlertMasterVolume then
    Bus.masterGain = tonumber(options.voiceAlertMasterVolume.value) or 1.0
    options.voiceAlertMasterVolume.OnChange = function(self)
      -- Some Epic Menu builds pass the control table as `self`; others pass the value.
      local v = (type(self) == "table" and self.value) or self
      Bus.masterGain = tonumber(v) or 1.0
      -- Uncomment for visual confirmation:
      -- Spring.Echo(('game_message: Voice Alerts Master Volume = x%.2f'):format(Bus.masterGain))
    end
  end

  Bus.tNow = GetTimer()
  WG.VoiceBus = {
    play  = enqueue,
    busy  = function() return Bus.playing or (#Bus.queue > 0) end,
    clear = function() Bus.queue = {} end,

    -- Optional programmatic helpers
    setGain            = function(mult) Bus.masterGain = tonumber(mult) or Bus.masterGain end,
    getGain            = function() return Bus.masterGain end,
    setDefaultChannel  = function(ch) Bus.defaultChannel = ch end,
    getDefaultChannel  = function() return Bus.defaultChannel end,
  }
end

function widget:Shutdown()
  if WG and WG.VoiceBus then WG.VoiceBus = nil end
end

function widget:Update()
  Bus.tNow = GetTimer()
  if not Bus.playing then
    if #Bus.queue > 0 then startNext() end
    return
  end
  if DiffTimers(Bus.tNow, Bus.tStart) >= (Bus.current.duration or Bus.fallback) then
    Bus.playing = false
    Bus.current = nil
    startNext()
  end
end
