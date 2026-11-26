-- Host checks for wards_debuffs.lua (Lua 5.1). Run from the repo root:
--   lua5.1 tests/test_debuffs.lua
-- Checks status IDs, that every look stays inside the DLL's argument ranges,
-- the stack (order, slide, fade, cap), facing math and each look's motion.
-- Not an FFXI test: it cannot show how the looks feel in game.
package.path='./?.lua;'..package.path
local D=require('wards_debuffs')
local fails,passes=0,0
local function check(cond,msg) if cond then passes=passes+1 else fails=fails+1 print('FAIL: '..msg) end end
local function near(a,b,e) return math.abs(a-b)<=(e or 1e-6) end
local function alpha(c) return math.floor(c/16777216) end
local function rgb(c) local x=c%16777216 return math.floor(x/65536),math.floor(x/256)%256,x%256 end

-- Status IDs (Windower resources_data/buffs.lua, Verified 2026-11-23)
local want={paralysis={4},silence={6},curse={9,20},blind={5},sleep={2,19},stun={10},slow={13}}
for name,ids in pairs(want) do
    check(table.concat(D.recipes[name].ids,',')==table.concat(ids,','),'ids '..name)
end
check(#D.order==7,'seven looks')

local s=D.defaults()
check(s.paralysis==true and s.debuffs==true and s.paralysis_flash_every==1.6,'defaults flattened')

-- Every look, sampled over 12 s, stays inside native.ring / native.arc limits.
for _,name in ipairs(D.order) do
    local st=D.new_state() local forced={[name]=true}
    local ok,count=true,0
    for i=0,360 do
        local out=D.frame(st,{},forced,i/30,1/30,s,2.5,2.2,1.2,37)
        for _,it in ipairs(out) do
            count=count+1
            if it.pixels<0 or it.pixels>64 or it.radius<.01 or it.radius>100 then ok=false end
            if it.kind=='arc' then
                if not(it.start>=0 and it.start<360 and it.span>0 and it.span<=360) then ok=false end
                if it.fade<0 or it.fade>1 or it.curve<.5 or it.curve>3 or (it.dir~=1 and it.dir~=-1) then ok=false end
                if it.lead<0 or it.lead>4294967295 or it.tail<0 or it.tail>4294967295 then ok=false end
            elseif it.color<0 or it.color>4294967295 then ok=false end
        end
    end
    check(ok and count>0,'look stays in DLL ranges: '..name)
end

-- Facing: Windower facing 0 east, -pi/2 north, +pi/2 south -> ring angle.
check(near(D.front_degrees(0),0) and near(D.front_degrees(-math.pi/2),90) and near(D.front_degrees(math.pi/2),-90),'facing to ring angle')

-- Silence: centered on the front (sway 0 at t=0), half circle.
local st=D.new_state()
local out=D.frame(st,{6},nil,0,.25,s,2,2,1,90)
local core=out[#out]
check(core.role=='core' and near(core.start,0) and near(core.span,180),'silence half arc centered on facing 90')
check(out[1].role=='glow' and out[2].role=='glow','silence glow is two arcs')
local er,eg=rgb(out[1].lead) local mr,mg,mb=rgb(out[1].tail)
check(er==255 and eg==60 and mr==255 and mg==255 and mb==255,'silence glow red edge to white middle')

-- Stack: order landed, slot height, slide down after one wears off.
s.debuff_fade_in,s.debuff_fade_out=.01,.01
st=D.new_state()
D.frame(st,{4},nil,0,.1,s,2,2,1,0)
D.frame(st,{4,9},nil,.1,.1,s,2,2,1,0)
for i=1,20 do D.frame(st,{4,9},nil,.1+i/30,1/30,s,2,2,1,0) end
check(near(st.entries.paralysis.y,2) and near(st.entries.curse.y,2+.08*2,.002),'curse stacked above paralysis')
for i=1,40 do D.frame(st,{9},nil,1+i/30,1/30,s,2,2,1,0) end
check(st.entries.paralysis==nil and near(st.entries.curse.y,2,.002),'paralysis gone, curse slid down')
-- cap
s.debuff_max=3
out=D.frame(D.new_state(),{4,6,9,5,2,10,13},nil,0,.25,s,2,2,1,0)
local cores=0 for _,it in ipairs(out) do if it.role=='core' then cores=cores+1 end end
check(cores==3+0,'cap 3: three looks drawn (stun/slow have several cores, not in first three)')
s.debuff_max=8 s.debuff_fade_in,s.debuff_fade_out=.3,.6
-- off switches
s.paralysis=false check(#D.frame(D.new_state(),{4},nil,0,.25,s,2,2,1,0)==0,'one look off') s.paralysis=true
s.debuffs=false check(#D.frame(D.new_state(),{4},nil,0,.25,s,2,2,1,0)==0,'all looks off') s.debuffs=true

-- Paralysis: flashes ice blue sometimes, not most of the time; buzz moves the radius.
local flashes,frames,radii=0,0,{}
st=D.new_state()
for i=1,600 do
    out=D.frame(st,{4},nil,i/30,1/30,s,2,2,1,0)
    if #out==2 then
        frames=frames+1
        local r,g,b=rgb(out[1].color)
        if r==120 and g==235 and b==255 then flashes=flashes+1 end
        radii[string.format('%.4f',out[2].radius)]=true
    end
end
local distinct=0 for _ in pairs(radii) do distinct=distinct+1 end
check(flashes>3 and flashes<frames*.25,'paralysis flashes ice blue now and then: '..flashes..'/'..frames)
check(distinct>10,'paralysis buzzes (radius varies)')

-- Curse: the glow gradient turns (start angle moves).
st=D.new_state()
local a1=D.frame(st,{9},nil,1,.25,s,2,2,1,0)[1].start
local a2=D.frame(st,{9},nil,2,.25,s,2,2,1,0)[1].start
check(near((a2-a1)%360,40,.01),'curse shimmer turns 40 deg/s')

-- Blind: arc in front by default; ring shape goes all the way around.
out=D.frame(D.new_state(),{5},nil,0,.25,s,2,2,1,0)
check(near(out[#out].span,220) and near(out[#out].start,(0-110)%360),'blind front arc 220 deg')
check(alpha(out[#out].lead)>0 and select(1,rgb(out[#out].lead))==0,'blind core black')
s.blind_shape='ring' out=D.frame(D.new_state(),{5},nil,0,.25,s,2,2,1,0)
check(near(out[#out].span,360),'blind ring shape') s.blind_shape='arc'

-- Sleep: breathes (radius differs half a period apart).
st=D.new_state()
local r1=D.frame(st,{2},nil,0,.25,s,2,2,1,0)[2].radius
local r2=D.frame(st,{2},nil,2,.25,s,2,2,1,0)[2].radius
check(r2>r1*1.05,'sleep breathes')

-- Stun: count arcs orbiting fast (glow + core each).
out=D.frame(D.new_state(),{10},nil,0,.25,s,2,2,1,0)
check(#out==6,'stun: 3 orbiting arcs x glow+core')

-- Slow: bright orange at the start of a cycle, deep blue near the end,
-- turning faster just after the flash than late in the cycle.
st=D.new_state()
local function slow_at(t) return D.frame(st,{13},nil,t,.25,s,2,2,1,0) end
local o1=slow_at(3.2*5+.05) local r,g,b=rgb(o1[2].lead)
check(r==255 and g==170 and b==70,'slow flashes bright orange')
local o2=slow_at(3.2*5+3.1) r,g,b=rgb(o2[2].lead)
check(b>r and b>100,'slow fades to deep blue')
local function angle(t) return slow_at(t)[2].start end
local early=(angle(3.2*7+.2)-angle(3.2*7+.1))%360
local late=(angle(3.2*7+3.1)-angle(3.2*7+3.0))%360
check(early>late*2,'slow speeds up at the flash and slows as it fades')
check(o1[2].dir==1 and o1[2].fade>0,'slow arcs are comets (bright head)')

print(('Wards debuff checks: %d passed, %d failed'):format(passes,fails))
if fails>0 then os.exit(1) end
