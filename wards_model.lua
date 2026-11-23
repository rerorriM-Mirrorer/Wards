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
    protect=false,         -- draw the Protect ring (on/off; off by default since Test3)
    shell=false,           -- draw the Shell ring (on/off; off by default since Test3)
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
    -- Test2 HP ring (enemybar2 style), above Protect, shown in combat only.
    hp=false,              -- draw the HP ring (on/off; off by default since Test3)
    hp_gap=0.08,           -- distance above the Protect ring, fraction of the height span
    hp_color='pink',       -- pink arc core (enemybar2 main bar pink 255,149,151)
    hp_glow_color='pinkwhite', -- glow under the pink arc (255,215,218)
    hp_opacity=1,          -- pink core opacity 0-1
    hp_width=2,            -- pink core width, pixels
    hp_glow=1,             -- pink glow strength 0-3: width +4 px x glow
    hp_glow_opacity=0.35,  -- pink glow opacity at strength 1
    hp_back_opacity=0.45,  -- the semi-opaque black full circle under everything
    hp_back_width=8,       -- black circle width, pixels
    hp_motion=0.18,        -- seconds for the pink arc to follow a new HP% (enemybar2 .18)
    hp_trail=true,         -- red trail over just-lost HP (on/off)
    hp_trail_color='trail',-- enemybar2 main trail red (167,57,96)
    hp_trail_opacity=1,    -- trail opacity 0-1
    hp_trail_width=4,      -- trail width, pixels
    hp_trail_hold=2,       -- seconds the trail holds before draining (enemybar2 2)
    hp_trail_slide=0.5,    -- seconds the trail takes to drain (enemybar2 .5)
    hp_pulse=true,         -- below 50% a red glow pulses on the circle, stronger as HP falls (on/off)
    hp_pulse_color='red',  -- 220,40,60
    hp_pulse_opacity=0.5,  -- pulse opacity at 0% HP
    hp_pulse_period=0.5,   -- seconds per pulse (enemybar2 main uses .1)
    hp_flash=true,         -- at 10% and below the pink arc flashes toward white (on/off)
    hp_flash_period=0.25,  -- seconds per flash cycle
    hp_fade_in=0.3,        -- seconds to fade in when combat starts
    hp_fade_out=0.8,       -- seconds to fade out when combat ends
}

-- Named colors for the HP ring settings (any can also be R,G,B).
M.hp_colors={pink={255,149,151},pinkwhite={255,215,218},trail={167,57,96},
    red={220,40,60},black={0,0,0},white={255,255,255}}
function M.hp_color(value)
    value=tostring(value or ''):lower():gsub('%s+','')
    local named=M.hp_colors[value]
    if named then return {named[1],named[2],named[3]} end
    local r,g,b=value:match('^(%d+),(%d+),(%d+)$')
    r,g,b=tonumber(r),tonumber(g),tonumber(b)
    if r and g and b and r<=255 and g<=255 and b<=255 then return {r,g,b} end
end

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

-- HP ring state ------------------------------------------------------------
-- shown = the pink arc's fraction (follows target over hp_motion seconds);
-- trail = the red trail's far end: it holds at the old value for hp_trail_hold
-- seconds after a loss, then drains to `shown` over hp_trail_slide seconds.
function M.hp_new() return {fresh=true,shown=1,target=1,trail=1,hold_until=0} end
-- Call when the ring (re)appears or a preview starts: no trail from old HP.
function M.hp_reset(st) st.fresh=true end
function M.hp_update(st,hpp,now,opts)
    local t=clamp((tonumber(hpp) or 100)/100,0,1)
    if st.fresh then
        st.fresh,st.shown,st.target,st.trail,st.hold_until,st.slide_from=false,t,t,t,0,nil
        return
    end
    if t<st.target-1e-6 then
        -- A loss: the trail keeps the highest HP still on screen and holds.
        st.trail=max(st.trail,st.shown,st.target)
        st.hold_until=now+opts.hp_trail_hold
        st.slide_from=nil
    end
    st.target=t
end
function M.hp_step(st,now,dt,opts)
    dt=clamp(dt or 0,0,.25)
    local tau=max(.01,opts.hp_motion)
    st.shown=st.target+(st.shown-st.target)*math.exp(-dt*3/tau) -- ~95% there after hp_motion
    if math.abs(st.shown-st.target)<.0005 then st.shown=st.target end
    if st.trail<st.shown then st.trail=st.shown st.slide_from=nil end -- healing passes the trail
    if st.trail>st.shown and now>=st.hold_until then
        if not st.slide_from then st.slide_from,st.slide_at=st.trail,now end
        local k=smooth((now-st.slide_at)/max(.01,opts.hp_trail_slide))
        st.trail=st.slide_from+(st.shown-st.slide_from)*k
        if k>=1 then st.trail=st.shown st.slide_from=nil end
    end
end

-- HP ring items, drawn in order (bottom first). Arcs are centered on the
-- camera (camera=1): the pink arc shrinks from both ends toward the side
-- facing you, so the last sliver is the one you see. Angles in degrees.
-- `alpha` = the combat fade (0-1).
function M.hp_items(st,now,opts,radius,offset,alpha)
    local out={}
    alpha=smooth(alpha)
    if alpha<=.002 then return out end
    local function arc(start,span,c,a,px,role)
        if a<=.002 or span<=.05 then return end
        out[#out+1]={kind='arc',radius=radius,offset=offset,start=start,span=min(span,360),
            color=M.argb(c,a),pixels=px,camera=1,role=role}
    end
    local shown,trail=st.shown,st.trail
    -- 1) the semi-opaque black circle
    arc(0,360,{0,0,0},opts.hp_back_opacity*alpha,opts.hp_back_width,'back')
    -- 2) low-HP pulse: a red glow on the whole circle below 50%, stronger as HP falls
    if opts.hp_pulse and shown<.5 then
        local depth=1-shown/.5
        local wave=.5+.5*math.sin(2*math.pi*now/max(.05,opts.hp_pulse_period))
        arc(0,360,M.hp_color(opts.hp_pulse_color) or M.hp_colors.red,
            opts.hp_pulse_opacity*depth*(.45+.55*wave)*alpha,opts.hp_back_width,'pulse')
    end
    -- 3) the red trail over just-lost HP, on both sides of the pink arc
    if opts.hp_trail and trail>shown+.001 then
        local c=M.hp_color(opts.hp_trail_color) or M.hp_colors.trail
        local half=(trail-shown)*180
        arc(shown*180,half,c,opts.hp_trail_opacity*alpha,opts.hp_trail_width,'trail')
        arc(-trail*180,half,c,opts.hp_trail_opacity*alpha,opts.hp_trail_width,'trail')
    end
    -- 4) pink-white glow, then 5) the pink core, centered on the camera
    local span=shown*360
    local glow=clamp(opts.hp_glow,0,3)
    if glow>0 then
        arc(-span/2,span,M.hp_color(opts.hp_glow_color) or M.hp_colors.pinkwhite,
            opts.hp_glow_opacity*glow*alpha,opts.hp_width+4*glow,'glow')
    end
    local core=M.hp_color(opts.hp_color) or M.hp_colors.pink
    if opts.hp_flash and shown<=.1 and shown>0 then
        -- square flash: every other half-period the core leans toward white
        if math.floor(now/(max(.05,opts.hp_flash_period)/2))%2==1 then
            core={core[1]+(255-core[1])*.7,core[2]+(255-core[2])*.7,core[3]+(255-core[3])*.7}
        end
    end
    arc(-span/2,span,core,opts.hp_opacity*alpha,opts.hp_width,'core')
    return out
end
-- Height of the HP ring above the feet: hp_gap x span above Protect.
function M.hp_offset(height,opts)
    local protect=M.heights(height,opts)
    return protect+opts.hp_gap*height
end

return M
