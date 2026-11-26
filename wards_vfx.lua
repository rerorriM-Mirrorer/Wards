-- Protect-only visual experiments. Animation state is separate from buff
-- detection and native rendering so each effect can be previewed on its own.
local M = {}

local min, max, floor = math.min, math.max, math.floor

M.defaults = {
    protect_shimmer = true,             -- active while Protect is present
    protect_shimmer_opacity = 0.16,     -- maximum core alpha, 0.01-0.40
    protect_shimmer_period = 4.8,       -- seconds between passes, 2-12
    protect_shimmer_duration = 0.75,    -- seconds per pass, 0.25-1.5
}

-- Idle pass tunables. The narrow full-circle band travels vertically across
-- the model; the depth buffer naturally hides the far side of the character.
local FIRST_DELAY = 0.9                -- seconds after Protect becomes active
local BAND_BOTTOM = 0.18              -- fraction of model height
local BAND_TOP = 0.82                 -- fraction of model height
local BAND_RADIUS = 0.72              -- fraction of Wards model-fit radius
local GLOW_PIXELS = 4.5               -- screen pixels
local CORE_PIXELS = 1.25              -- screen pixels
local GLOW_ALPHA = 0.28               -- fraction of core alpha
local FADE_IN = 0.15                  -- seconds
local FADE_OUT = 0.20                 -- seconds
local DOUBLE_EVERY = 4                -- every fourth pass may use two bands
local DOUBLE_DELAY = 0.28             -- fraction of pass duration
local DOUBLE_DURATION = 0.72         -- fraction of pass duration

local function clamp(value, low, high)
    return max(low, min(high, value))
end

local function smooth(value)
    value = clamp(value, 0, 1)
    return value * value * (3 - 2 * value)
end

local function argb(color, alpha)
    return floor(clamp(alpha, 0, 1) * 255 + 0.5) * 16777216
        + floor(color[1] + 0.5) * 65536
        + floor(color[2] + 0.5) * 256
        + floor(color[3] + 0.5)
end

function M.new_shimmer_state()
    return {active = false, next_at = nil, pulse_at = nil, cycle = 0}
end

function M.reset_shimmer(state)
    if not state then return end
    state.active = false
    state.next_at = nil
    state.pulse_at = nil
    state.cycle = 0
end

local function add_band(out, now, started, duration, direction, band,
        radius, height, ground, opacity, color)
    local progress = (now - started) / duration
    if progress < 0 or progress > 1 then return end

    local position = smooth(progress)
    local height_fraction
    if direction > 0 then
        height_fraction = BAND_BOTTOM + (BAND_TOP - BAND_BOTTOM) * position
    else
        height_fraction = BAND_TOP - (BAND_TOP - BAND_BOTTOM) * position
    end

    local envelope = smooth(progress / FADE_IN) * smooth((1 - progress) / FADE_OUT)
    if envelope <= 0.002 then return end

    local offset = ground + height_fraction * height
    local band_radius = radius * BAND_RADIUS
    out[#out + 1] = {
        kind = 'ring', band = band, role = 'glow',
        radius = band_radius, offset = offset, pixels = GLOW_PIXELS,
        color = argb(color, opacity * GLOW_ALPHA * envelope),
    }
    out[#out + 1] = {
        kind = 'ring', band = band, role = 'core',
        radius = band_radius, offset = offset, pixels = CORE_PIXELS,
        color = argb(color, opacity * envelope),
    }
end

-- Returns no more than two logical bands. Each band has one soft glow and
-- one thin core, so the frame uses at most four native rings.
function M.shimmer(state, enabled, now, radius, height, settings, color)
    local out = {}
    if not state or not enabled then
        M.reset_shimmer(state)
        return out
    end
    if type(now) ~= 'number' or type(radius) ~= 'number' or type(height) ~= 'number'
            or radius <= 0 or height <= 0 then
        M.reset_shimmer(state)
        return out
    end

    if not state.active then
        state.active = true
        state.cycle = 0
        state.pulse_at = nil
        state.next_at = now + FIRST_DELAY
    end

    local duration = clamp(tonumber(settings.protect_shimmer_duration) or M.defaults.protect_shimmer_duration,
        0.25, 1.5)
    local period = clamp(tonumber(settings.protect_shimmer_period) or M.defaults.protect_shimmer_period,
        2, 12)
    local opacity = clamp(tonumber(settings.protect_shimmer_opacity) or M.defaults.protect_shimmer_opacity,
        0.01, 0.40)
    local ground = tonumber(settings.ground) or 0.3
    color = color or {65, 130, 255}

    if state.pulse_at and now >= state.pulse_at + duration then
        state.pulse_at = nil
    end

    if not state.pulse_at and now >= state.next_at then
        state.cycle = state.cycle + 1
        state.pulse_at = now
        state.next_at = now + period
    end
    if not state.pulse_at then return out end

    local direction = state.cycle % 2 == 1 and 1 or -1
    add_band(out, now, state.pulse_at, duration, direction, 1,
        radius, height, ground, opacity, color)

    if state.cycle % DOUBLE_EVERY == 0 then
        local second_start = state.pulse_at + duration * DOUBLE_DELAY
        if now >= second_start then
            add_band(out, now, second_start, duration * DOUBLE_DURATION, -direction, 2,
                radius, height, ground, opacity, color)
        end
    end

    return out
end

return M
