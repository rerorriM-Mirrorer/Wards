-- Protect-only visual experiments. Animation state is separate from buff
-- detection and native rendering so each effect can be previewed on its own.
local M = {}

local min, max, floor = math.min, math.max, math.floor

M.defaults = {
    protect_shimmer = true,             -- active while Protect is present
    protect_shimmer_opacity = 0.16,     -- maximum core alpha, 0.01-0.40
    protect_shimmer_period = 4.8,       -- seconds between passes, 2-12
    protect_shimmer_duration = 0.75,    -- seconds per pass, 0.25-1.5
    protect_expiry_glints = true,        -- tiny glints when Protect ends
    protect_impact = true,               -- brief shield on physical damage
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


-- Protect expiration glints ---------------------------------------------------
local EXPIRY_DURATION = 0.50             -- seconds
local EXPIRY_GLINTS = 4                  -- count, intentionally restrained
local EXPIRY_START_RADIUS = 0.14         -- fraction of model radius
local EXPIRY_TRAVEL = 0.34               -- fraction of model radius
local EXPIRY_SIZE = 0.045                -- fraction of model radius
local EXPIRY_ALPHA = 0.30                -- maximum ARGB alpha
local EXPIRY_PIXELS = 1.25               -- screen pixels

function M.new_expiration_state()
    return {started_at = nil}
end

function M.trigger_expiration(state, now)
    if not state or type(now) ~= 'number' then return end
    state.started_at = now
end

function M.reset_expiration(state)
    if state then state.started_at = nil end
end

function M.expiration(state, enabled, now, radius, height, settings, color)
    local out = {}
    if not state or not state.started_at or not enabled then
        M.reset_expiration(state)
        return out
    end
    if type(now) ~= 'number' or type(radius) ~= 'number' or type(height) ~= 'number'
            or radius <= 0 or height <= 0 then
        M.reset_expiration(state)
        return out
    end

    local progress = (now - state.started_at) / EXPIRY_DURATION
    if progress < 0 or progress >= 1 then
        M.reset_expiration(state)
        return out
    end
    local envelope = smooth(progress / 0.06) * (1 - smooth(progress))
    if envelope <= 0.002 then return out end

    color = color or {145, 205, 255}
    local pale = {
        floor((color[1] + 225) * 0.5 + 0.5),
        floor((color[2] + 238) * 0.5 + 0.5),
        floor((color[3] + 255) * 0.5 + 0.5),
    }
    local ground = tonumber(settings.ground) or 0.3
    for i = 1, EXPIRY_GLINTS do
        local angle = (i - 1) * (math.pi * 2 / EXPIRY_GLINTS) + 0.37
        local drift = radius * (EXPIRY_START_RADIUS + EXPIRY_TRAVEL * smooth(progress))
        local vertical = height * (0.43 + (i % 3) * 0.035 + 0.08 * progress)
        out[#out + 1] = {
            kind = 'hex',
            x = math.cos(angle) * drift,
            y = math.sin(angle) * drift,
            z = ground + vertical,
            radius = radius * EXPIRY_SIZE * (1 - 0.18 * progress),
            rotation = angle * 0.22,
            color = argb(pale, EXPIRY_ALPHA * envelope),
            pixels = EXPIRY_PIXELS,
        }
    end
    return out
end

-- Physical impact shield ------------------------------------------------------
local IMPACT_DURATION = 0.48             -- seconds the surface remains visible
local RIPPLE_DURATION = 0.32             -- seconds for the honeycomb wave
local RIPPLE_WIDTH = 0.17                -- fraction of shield radius
local SHIELD_RADIUS = 0.90               -- fraction of model-fit radius
local SHIELD_DISTANCE = 0.78             -- fraction of model-fit radius ahead
local SHIELD_HEIGHT = 0.54               -- fraction of model height above ground
local SHIELD_HEX_SIZE = 0.105            -- fraction of shield radius
local SHIELD_RIM_PIXELS = 1.8            -- screen pixels
local IMPACT_CURVE = 1.6                 -- nonlinear intensity response
local IMPACT_FLASH_SECONDS = 0.065       -- initial flash decay

function M.new_impact_state()
    return {started_at = nil, intensity = 1}
end

function M.trigger_impact(state, intensity, now)
    if not state or type(now) ~= 'number' then return false end
    local value = tonumber(intensity)
    if not value or value < 1 or value > 9999 then return false end
    state.intensity = floor(value + 0.5)
    state.started_at = now
    return true
end

function M.reset_impact(state)
    if state then
        state.started_at = nil
        state.intensity = 1
    end
end

function M.intensity_response(intensity)
    local value = clamp(tonumber(intensity) or 1, 1, 9999) / 9999
    return value ^ IMPACT_CURVE
end

-- The incoming action packet exposes landed damage, not counterfactual damage
-- without Protect. This is a visual severity proxy only, not damage prevented.
function M.damage_to_intensity(damage)
    local value = tonumber(damage)
    if not value or value <= 0 then return nil end
    return clamp(floor(value * 10 + 0.5), 1, 9999)
end

function M.impact(state, enabled, now, radius, height, settings)
    if not state or not state.started_at or not enabled then return nil end
    if type(now) ~= 'number' or type(radius) ~= 'number' or type(height) ~= 'number'
            or radius <= 0 or height <= 0 then
        M.reset_impact(state)
        return nil
    end

    local elapsed = now - state.started_at
    if elapsed < 0 or elapsed >= IMPACT_DURATION then
        M.reset_impact(state)
        return nil
    end

    local progress = elapsed / IMPACT_DURATION
    local fade = 1 - smooth(progress)
    local strength = M.intensity_response(state.intensity)
    local flash = math.exp(-elapsed / IMPACT_FLASH_SECONDS)
    local center_alpha = (0.008 + 0.045 * strength) * fade
    local edge_alpha = (0.025 + 0.21 * strength + 0.12 * strength * flash) * fade
    local outline_alpha = (0.04 + 0.40 * strength) * flash * fade
    local honeycomb_alpha = (0.02 + 0.28 * strength) * fade
    local ground = tonumber(settings.ground) or 0.3
    local shield_radius = radius * SHIELD_RADIUS
    local ripple_progress = clamp(elapsed / RIPPLE_DURATION * 1.12, 0, 1.12)

    return {
        kind = 'shield',
        distance = radius * SHIELD_DISTANCE,
        offset = ground + height * SHIELD_HEIGHT,
        radius = math.min(shield_radius, height * 0.38),
        center = argb({65, 130, 255}, center_alpha),
        edge = argb({78, 155, 255}, edge_alpha),
        outline = argb({180, 225, 255}, outline_alpha),
        honeycomb = argb({205, 235, 255}, honeycomb_alpha),
        hex_radius = shield_radius * SHIELD_HEX_SIZE,
        wave = ripple_progress,
        wave_width = RIPPLE_WIDTH,
        pixels = SHIELD_RIM_PIXELS + strength * 1.4,
        intensity = state.intensity,
        strength = strength,
        flash = flash,
    }
end

return M
