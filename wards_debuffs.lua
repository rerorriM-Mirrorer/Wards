-- Wards debuffs: a "recipe book" of debuff looks plus the stack that places
-- them. Pure Lua with no Windower calls, so it runs in host tests.
--
-- Each recipe has: ids (status IDs from Windower resources/buffs.lua), its
-- own tunables (saved flat as <name>_<key>, e.g. paralysis_flash_every) and
-- a draw function. A draw function gets a context c:
--   c.t      seconds (clock)          c.r    ring radius (yalms)
--   c.h      this debuff's height     c.span the character's height span
--   c.a      fade 0-1 (already eased) c.front angle (degrees) the character faces
--   c.o      this recipe's settings (key without the name prefix)
-- and adds rings/arcs with the helpers below. Adding a new debuff = adding
-- one recipe here; the stack, previews, toggles and commands pick it up.
-- Author: A.
local D={}
local min,max,floor,sin,cos,pi=math.min,math.max,math.floor,math.sin,math.cos,math.pi
local function clamp(x,a,b) return max(a,min(b,x)) end
local function smooth(x) x=clamp(x,0,1) return x*x*(3-2*x) end
local function frac(x) return x-floor(x) end
-- Repeatable "random" 0-1 from a number (same input, same output), so the
-- buzz and spark timing are irregular but testable.
local function hash(n) return frac(sin(n*12.9898+78.233)*43758.5453) end
D.hash=hash

-- Named colors usable in any debuff color setting (or R,G,B).
-- earth/ice/light/darkness are TargetSC's element colors (resonance.lua).
D.colors={black={0,0,0},white={255,255,255},earth={176,114,48},ice={120,235,255},
    light={255,255,255},darkness={25,14,52},red={255,60,60},yellow={255,235,60}}
function D.color(value)
    value=tostring(value or ''):lower():gsub('%s+','')
    local named=D.colors[value]
    if named then return {named[1],named[2],named[3]} end
    local r,g,b=value:match('^(%d+),(%d+),(%d+)$')
    r,g,b=tonumber(r),tonumber(g),tonumber(b)
    if r and g and b and r<=255 and g<=255 and b<=255 then return {r,g,b} end
end
local function mix(a,b,k) k=clamp(k,0,1) return {a[1]+(b[1]-a[1])*k,a[2]+(b[2]-a[2])*k,a[3]+(b[3]-a[3])*k} end
local function argb(c,alpha)
    return floor(clamp(alpha,0,1)*255+.5)*16777216+floor(clamp(c[1],0,255)+.5)*65536+
        floor(clamp(c[2],0,255)+.5)*256+floor(clamp(c[3],0,255)+.5)
end
D.argb=argb
local function col(c,key) return D.color(c.o[key]) or {255,255,255} end

-- Drawing helpers. Items are plain tables Wards.lua sends to the DLL:
-- ring = native.ring(radius,offset,0,color,pixels)
-- arc  = native.arc(radius,offset,0,lead,tail,pixels,0,start,span,fade,1,curve,dir,0)
--        (lead -> tail across the arc with dir -1; dir 1 + fade makes the end bright)
local function ring(out,r,h,px,c,a,role)
    if a<=.002 then return end
    out[#out+1]={kind='ring',radius=r,offset=h,pixels=px,color=argb(c,a),role=role}
end
local function arc(out,r,h,px,lead,tail,a,start,span,role,fade,curve,dir)
    if a<=.002 or span<=.05 then return end
    start=start%360
    out[#out+1]={kind='arc',radius=r,offset=h,pixels=px,lead=argb(lead,a),tail=argb(tail,a),
        start=start,span=min(span,360),fade=fade or 0,curve=curve or 1,dir=dir or -1,role=role}
end

D.order={'paralysis','silence','curse','blind','sleep','stun','slow'}
D.recipes={}
local R=D.recipes

-- Paralysis: bright yellow ring that buzzes (tiny size jitter every frame);
-- its yellow glow flashes ice blue at irregular moments, sometimes twice,
-- like electricity.
R.paralysis={ids={4},label='Paralysis',
    defaults={color='255,235,60',glow='255,215,40',flash='ice',width=2,glow_width=8,glow_opacity=.3,
        buzz=.012,flash_every=1.6,flash_length=.12,flash_opacity=.75},
    draw=function(c,out)
        local o=c.o
        local frame=floor(c.t*30)
        local r=c.r*(1+o.buzz*(hash(frame)*2-1))
        -- one flash somewhere in every flash_every window, sometimes a double
        local k=floor(c.t/o.flash_every)
        local start=k*o.flash_every+hash(k+.37)*max(0,o.flash_every-o.flash_length*3)
        local dt=c.t-start
        local flashing=(dt>=0 and dt<o.flash_length) or
            (hash(k+.71)>.5 and dt>=o.flash_length*1.6 and dt<o.flash_length*2.4)
        if flashing then
            ring(out,r,c.h,o.glow_width+2,col(c,'flash'),o.flash_opacity*c.a,'glow')
        else
            ring(out,r,c.h,o.glow_width,col(c,'glow'),o.glow_opacity*c.a*(.85+.15*hash(frame+.5)),'glow')
        end
        ring(out,r,c.h,o.width,col(c,'color'),c.a,'core')
    end}

-- Silence: a near-white green half arc in front of the character (their
-- facing, not the camera), its glow white in the middle and red at both
-- ends, swaying gently back and forth.
R.silence={ids={6},label='Silence',
    defaults={color='210,255,210',glow_mid='white',glow_edge='red',span=180,width=3,glow_width=10,
        glow_opacity=.4,sway=8,sway_period=3},
    draw=function(c,out)
        local o=c.o
        local center=c.front+o.sway*sin(2*pi*c.t/max(.1,o.sway_period))
        local half=o.span/2
        arc(out,c.r,c.h,o.glow_width,col(c,'glow_edge'),col(c,'glow_mid'),o.glow_opacity*c.a,center-half,half,'glow')
        arc(out,c.r,c.h,o.glow_width,col(c,'glow_mid'),col(c,'glow_edge'),o.glow_opacity*c.a,center,half,'glow')
        local cc=col(c,'color')
        arc(out,c.r,c.h,o.width,cc,cc,c.a,center-half,o.span,'core')
    end}

-- Curse: purple ring; its glow is a white-to-purple gradient that turns
-- around the ring (a shimmer sweeping as it rotates), breathing slightly.
R.curse={ids={9,20},label='Curse',
    defaults={color='150,60,220',glow='200,110,255',shimmer='white',width=2,glow_width=8,glow_opacity=.4,
        spin=40,pulse_period=2.5},
    draw=function(c,out)
        local o=c.o
        local phase=o.spin*c.t
        local breath=.75+.25*sin(2*pi*c.t/max(.1,o.pulse_period))
        local g,s=col(c,'glow'),col(c,'shimmer')
        arc(out,c.r,c.h,o.glow_width,g,s,o.glow_opacity*breath*c.a,phase,180,'glow')
        arc(out,c.r,c.h,o.glow_width,s,g,o.glow_opacity*breath*c.a,phase+180,180,'glow')
        ring(out,c.r,c.h,o.width,col(c,'color'),c.a,'core')
    end}

-- Blind: murky black, like TargetSC's level-3 Darkness rings: a black core
-- under layers of dark violet haze that slowly breathe. Shape `arc` (front of
-- the character, default) or `ring` (all the way around).
R.blind={ids={5},label='Blind',
    defaults={shape='arc',color='black',murk='darkness',span=220,width=4,opacity=.85,murk_width=22,
        murk_opacity=.35,breath_period=3.5},
    draw=function(c,out)
        local o=c.o
        local full=tostring(o.shape)=='ring'
        local span=full and 360 or o.span
        local start=full and 0 or c.front-span/2
        local breath=.8+.2*sin(2*pi*c.t/max(.1,o.breath_period))
        local m,k=col(c,'murk'),col(c,'color')
        local layers={{1,.35},{.6,.6},{.35,1}}
        for _,l in ipairs(layers) do
            arc(out,c.r,c.h,max(1,o.murk_width*l[1]),m,m,o.murk_opacity*l[2]*breath*c.a,start,span,'murk')
        end
        arc(out,c.r,c.h,o.width,k,k,o.opacity*c.a,start,span,'core')
    end}

-- Sleep: lavender ring with a pale-blue glow, breathing slowly (the glow
-- swells and the ring grows and shrinks a few percent).
R.sleep={ids={2,19},label='Sleep',
    defaults={color='190,160,255',glow='170,210,255',width=2,glow_width=10,glow_opacity=.35,
        breath_period=4,breath_size=.04},
    draw=function(c,out)
        local o=c.o
        local k=.5-.5*cos(2*pi*c.t/max(.1,o.breath_period))
        local r=c.r*(1-o.breath_size+2*o.breath_size*k)
        ring(out,r,c.h,o.glow_width,col(c,'glow'),o.glow_opacity*(.4+.6*k)*c.a,'glow')
        ring(out,r,c.h,o.width,col(c,'color'),c.a,'core')
    end}

-- Stun (placeholder look, not A's design yet): a few short bright arcs
-- orbiting fast like circling stars, each bobbing up and down a little.
R.stun={ids={10},label='Stun',
    defaults={color='255,250,200',glow='255,230,120',count=3,arc=28,spin=320,width=3,glow_width=9,
        glow_opacity=.45,wobble=.05},
    draw=function(c,out)
        local o=c.o
        local n=clamp(floor(o.count+.5),1,8)
        local phase=o.spin*c.t
        for i=0,n-1 do
            local start=phase+i*360/n
            local h=c.h+o.wobble*c.span*sin(math.rad(phase)*2+i*2.1)
            local g,cc=col(c,'glow'),col(c,'color')
            arc(out,c.r,h,o.glow_width,g,g,o.glow_opacity*c.a,start,o.arc,'glow')
            arc(out,c.r,h,o.width,cc,cc,c.a,start,o.arc,'core')
        end
    end}

-- Slow: comet arcs turning counterclockwise. Each cycle starts with a flash
-- of bright orange, fades through Scission earth-amber to deep blue, and the
-- turning is fast at the flash and slows as it fades.
R.slow={ids={13},label='Slow',
    defaults={bright='255,170,70',mid='earth',deep='20,40,140',cycle=3.2,spin_base=12,spin_boost=70,
        count=3,arc=100,width=3,glow_width=9,glow_opacity=.35},
    draw=function(c,out)
        local o=c.o
        local cyc=max(.2,o.cycle)
        local p=frac(c.t/cyc)
        local color
        if p<.06 then color=col(c,'bright')
        elseif p<.3 then color=mix(col(c,'bright'),col(c,'mid'),(p-.06)/.24)
        else color=mix(col(c,'mid'),col(c,'deep'),smooth((p-.3)/.7)) end
        -- angle = integral of speed base + boost*(1-p)^3, so it is smooth
        -- across cycles; positive = counterclockwise seen from above (Inferred).
        local full=floor(c.t/cyc)
        local angle=full*cyc*(o.spin_base+o.spin_boost/4)+cyc*(o.spin_base*p+o.spin_boost*(1-(1-p)^4)/4)
        local n=clamp(floor(o.count+.5),1,6)
        local faint={color[1],color[2],color[3]}
        for i=0,n-1 do
            local start=angle+i*360/n
            arc(out,c.r,c.h,o.glow_width,color,faint,o.glow_opacity*c.a,start,o.arc,'glow',.9,1.4,1)
            arc(out,c.r,c.h,o.width,color,faint,c.a,start,o.arc,'core',.85,1.4,1)
        end
    end}

-- Layout tunables (E6), saved flat in settings with these names.
D.layout_defaults={
    debuffs=true,           -- draw debuffs at all (on/off)
    debuff_gap=0.10,        -- first debuff: this far above the HP ring position, fraction of the height span
    debuff_spacing=0.08,    -- distance between stacked debuffs, fraction of the height span
    debuff_max=8,           -- most debuffs drawn at once (oldest first)
    debuff_slide=0.25,      -- seconds for rings to glide to a new slot
    debuff_fade_in=0.3,     -- seconds to fade in when a debuff lands
    debuff_fade_out=0.6,    -- seconds to fade out when it wears off
    debuff_front=0,         -- degrees added to the facing direction for front arcs (Silence, Blind)
}
-- All defaults: layout + every recipe's on/off (<name>=true) + tunables.
function D.defaults()
    local d={}
    for k,v in pairs(D.layout_defaults) do d[k]=v end
    for _,name in ipairs(D.order) do
        d[name]=true
        for k,v in pairs(R[name].defaults) do d[name..'_'..k]=v end
    end
    return d
end
-- The settings view a recipe sees: o.key -> settings[name..'_'..key].
local views={}
local function view(settings,name)
    local v=views[name]
    if not v then
        v=setmetatable({},{__index=function(_,k)
            local s=rawget(v,'_s')
            local x=s and s[name..'_'..k]
            if x==nil then x=R[name].defaults[k] end
            return x
        end})
        views[name]=v
    end
    rawset(v,'_s',settings)
    return v
end
function D.name_for(word)
    word=tostring(word or ''):lower()
    if R[word] then return word end
    for name,r in pairs(R) do if r.label:lower()==word then return name end end
end

-- Stack state ---------------------------------------------------------------
-- entries[name] = {alpha, since (order landed), y (current height), want}
function D.new_state() return {entries={},seq=0} end
function D.reset(st) st.entries={} end
local function has_any(buffs,ids)
    if type(buffs)~='table' then return false end
    for _,b in pairs(buffs) do for _,id in ipairs(ids) do if b==id then return true end end end
    return false
end
D.has_any=has_any

-- Update fades and slots, then return the draw items.
-- base_h = height of the first slot; span = character height span; r = radius.
function D.frame(st,buffs,forced,now,dt,settings,base_h,span,r,front)
    dt=clamp(dt or 0,0,.25)
    local out={}
    if not settings.debuffs then st.entries={} return out end
    -- 1) fades and landing order
    for _,name in ipairs(D.order) do
        local want=settings[name]~=false and (has_any(buffs,R[name].ids) or (forced and forced[name]))
        local e=st.entries[name]
        if want and not e then
            st.seq=st.seq+1
            e={alpha=0,since=st.seq}
            st.entries[name]=e
        end
        if e then
            e.want=want and true or false
            if want then e.alpha=min(1,e.alpha+dt/max(.01,settings.debuff_fade_in))
            else e.alpha=max(0,e.alpha-dt/max(.01,settings.debuff_fade_out)) end
            if not want and e.alpha<=0 then st.entries[name]=nil end
        end
    end
    -- 2) slots: oldest at the bottom; a fading-out ring keeps its slot until gone
    local list={}
    for name,e in pairs(st.entries) do list[#list+1]={name=name,e=e} end
    table.sort(list,function(a,b) return a.e.since<b.e.since end)
    local limit=clamp(floor((settings.debuff_max or 8)+.5),1,12)
    local tau=max(.01,settings.debuff_slide)
    for i,item in ipairs(list) do
        local e=item.e
        local target=base_h+(i-1)*settings.debuff_spacing*span
        if not e.y then e.y=target else
            e.y=target+(e.y-target)*math.exp(-dt*3/tau)
            if math.abs(e.y-target)<.001 then e.y=target end
        end
        if i<=limit then
            local c={t=now,r=r,h=e.y,span=span,a=smooth(e.alpha),front=(front or 0)+(settings.debuff_front or 0),
                o=view(settings,item.name)}
            R[item.name].draw(c,out)
        end
    end
    return out
end

-- Facing (Windower mob.facing, radians: 0 east, -pi/2 north, +pi/2 south;
-- Verified from InfoBar's compass table) to the DLL's ring angle in
-- degrees (0 east, 90 north).
function D.front_degrees(facing) return -(tonumber(facing) or 0)*180/pi end

return D
