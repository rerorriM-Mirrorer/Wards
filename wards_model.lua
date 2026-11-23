-- Wards model: pure math and state, no Windower calls, so it can be tested
-- on a computer without FFXI. Wards.lua feeds it the player and the buff
-- list each frame and sends the rings it returns to the native renderer.
-- Author: A.
local M={}
local min,max,floor,sqrt=math.min,math.max,math.floor,math.sqrt
local function clamp(x,a,b) return max(a,min(b,x)) end

-- Status IDs from Windower resources (resources_data/buffs.lua):
-- 40 = Protect, 41 = Shell. Protect II-V and Shell II-V use the same IDs.
M.BUFF={protect=40,shell=41}

-- Color choices. `element` is TargetSC's own element color (Water for
-- Protect, Wind for Shell), the one its Reverberation / Detonation rings use.
-- `icon` is the solid color of TargetSC's images/skillchain/reverberation.png
-- and detonation.png; `iconlight` is the lighter edge tint in those icons
-- (halfway to white).
M.colors={
    protect={element={65,130,255},icon={0,0,255},iconlight={127,127,255}},
    shell={element={115,245,145},icon={0,128,0},iconlight={127,191,127}},
}

-- Visual tunables (E6). Units in the comments; every one can be changed in
-- game with a //wards command and is saved in data/settings.xml.
M.defaults={
    enabled=true,
    protect=true,          -- draw the Protect ring (on/off)
    shell=true,            -- draw the Shell ring (on/off)
    protect_color='element', -- element | icon | iconlight | R,G,B
    shell_color='element',
    height=0.66,           -- same meaning as TargetSC's `height` (default .66)
    scale=2,               -- same meaning as TargetSC's `scale` (ring size)
    ground=0.3,            -- yalms above the feet where the span starts (TargetSC ground_height .3)
    level=0.90,            -- Protect ring position: fraction of the height span (TargetSC sky ring = .90)
    gap=0.08,              -- Shell ring distance below Protect, fraction of the height span
    opacity=1,             -- core line opacity 0-1
    glow=1,                -- glow strength 0-3 (0 = no glow); glow alpha = .24 x glow, width +4 px x glow
    width=2,               -- core line width in pixels (TargetSC width 2)
    fade_in=0.3,           -- seconds to fade in when the buff lands
    fade_out=0.6,          -- seconds to fade out when the buff wears off
}

function M.argb(c,alpha)
    return floor(clamp(alpha,0,1)*255+.5)*16777216+floor(c[1]+.5)*65536+
        floor(c[2]+.5)*256+floor(c[3]+.5)
end

-- Resolve a saved color setting to {r,g,b}. Returns nil for bad input.
function M.color(kind,value)
    value=tostring(value or ''):lower():gsub('%s+','')
    local named=M.colors[kind] and M.colors[kind][value]
    if named then return {named[1],named[2],named[3]} end
    local r,g,b=value:match('^(%d+),(%d+),(%d+)$')
    r,g,b=tonumber(r),tonumber(g),tonumber(b)
    if r and g and b and r<=255 and g<=255 and b<=255 then return {r,g,b} end
end

-- Same sizing as TargetSC resonance.dimensions(): ring radius and height
-- span both come from the model's size, so a Galka and a Tarutaru each get
-- rings that fit them. Returns radius, height (yalms).
function M.dimensions(mob,opts)
    local size=tonumber(mob.model_size) or 0
    local scale=tonumber(mob.model_scale) or 1
    if scale<=0 then scale=1 end
    local extent=size>.05 and size*scale or 1.15*(.5/max(scale,.18))
    local radius_extent=extent
    if radius_extent>1.15 then radius_extent=1.15+sqrt(radius_extent-1.15)*.62 end
    return clamp(radius_extent*.55,.4,12)*opts.scale,
        clamp(extent*1.6,.65,30)*opts.scale*opts.height
end

-- Ring heights above the feet. Protect sits where TargetSC's sky ring rests
-- (ground + level x span); Shell sits `gap` x span below it.
function M.heights(height,opts)
    local protect=opts.ground+opts.level*height
    return protect,protect-opts.gap*height
end

-- True when the buff list (get_player().buffs: an array of status IDs)
-- contains the given ID.
function M.has(buffs,id)
    if type(buffs)~='table' then return false end
    for _,b in pairs(buffs) do if b==id then return true end end
    return false
end

-- Fade state for one ring: `alpha` moves toward 1 while wanted and toward 0
-- when not, at the fade_in / fade_out rates. dt is seconds since last frame.
function M.new_fade() return {alpha=0} end
function M.step(f,wanted,dt,opts)
    dt=clamp(dt or 0,0,.25) -- a hitch (zoning, alt-tab) must not jump a fade
    if wanted then f.alpha=min(1,f.alpha+dt/max(.01,opts.fade_in))
    else f.alpha=max(0,f.alpha-dt/max(.01,opts.fade_out)) end
    return f.alpha
end
local function smooth(x) x=clamp(x,0,1) return x*x*(3-2*x) end

-- Build the frame: a list of rings {radius,offset,pixels,color}, glow first
-- then the thin core, exactly like TargetSC's ring() helper. `alphas` holds
-- each ward's current fade (0-1).
function M.frame(mob,alphas,opts)
    local out={}
    local radius,height=M.dimensions(mob,opts)
    local hp,hs=M.heights(height,opts)
    local function ring(h,c,a)
        a=smooth(a)
        if a<=.002 then return end
        local glow=clamp(opts.glow,0,3)
        if glow>0 then
            out[#out+1]={radius=radius,offset=h,pixels=opts.width+4*glow,color=M.argb(c,a*opts.opacity*.24*glow),role='glow'}
        end
        out[#out+1]={radius=radius,offset=h,pixels=opts.width,color=M.argb(c,a*opts.opacity),role='core'}
    end
    ring(hp,M.color('protect',opts.protect_color) or M.colors.protect.element,alphas.protect or 0)
    ring(hs,M.color('shell',opts.shell_color) or M.colors.shell.element,alphas.shell or 0)
    return out,radius,height
end

return M
