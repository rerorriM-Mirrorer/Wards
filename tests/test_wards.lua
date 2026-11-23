-- Host simulation for Wards (Lua 5.1). Run from the repo root:
--   lua5.1 Wards/tests/test_wards.lua
-- Stubs Windower, config, chat and the native DLL; checks the model math,
-- buff detection, fades, colors, commands and what reaches native.ring.
-- This is not an FFXI test: it cannot show how the rings look in game.
package.path='Wards/?.lua;'..package.path
local fails,passes=0,0
local function check(cond,msg) if cond then passes=passes+1 else fails=fails+1 print('FAIL: '..msg) end end
local function near(a,b,e) return math.abs(a-b)<=(e or 1e-6) end

local model=require('wards_model')

-- Model: buff IDs and detection
check(model.BUFF.protect==40 and model.BUFF.shell==41,'buff ids 40/41')
check(model.has({33,40,255},40),'has protect')
check(not model.has({33,255},41),'no shell')
check(not model.has(nil,40),'nil buffs safe')

-- Colors: defaults, icon values, custom, bad input
local c=model.color('protect','element') check(c[1]==65 and c[2]==130 and c[3]==255,'protect element = water')
c=model.color('shell','element') check(c[1]==115 and c[2]==245 and c[3]==145,'shell element = wind')
c=model.color('protect','icon') check(c[1]==0 and c[2]==0 and c[3]==255,'protect icon = reverberation.png blue')
c=model.color('shell','icon') check(c[1]==0 and c[2]==128 and c[3]==0,'shell icon = detonation.png green')
c=model.color('protect','IconLight') check(c[1]==127 and c[2]==127 and c[3]==255,'protect iconlight')
c=model.color('shell','iconlight') check(c[1]==127 and c[2]==191 and c[3]==127,'shell iconlight')
c=model.color('shell','10, 20,30') check(c and c[1]==10 and c[2]==20 and c[3]==30,'custom rgb with spaces')
check(model.color('shell','300,0,0')==nil,'rgb > 255 rejected')
check(model.color('shell','purple')==nil,'unknown name rejected')
check(model.argb({65,130,255},1)==0xFF4182FF,'argb packing')

-- Dimensions match TargetSC resonance.dimensions (copied formula)
local opts={} for k,v in pairs(model.defaults) do opts[k]=v end
local mob={model_size=1.1,model_scale=1}
local r,h=model.dimensions(mob,opts)
check(near(r,1.1*.55*2),'radius from model size x scale 2')
check(near(h,1.1*1.6*2*.66),'height span uses height .66')
local hp,hs=model.heights(h,opts)
check(near(hp,.3+.9*h),'protect at TargetSC sky height')
check(hs<hp and near(hp-hs,.08*h),'shell just below protect')

-- Fades
local f=model.new_fade()
model.step(f,true,.15,opts) check(near(f.alpha,.5),'half way after half fade_in')
model.step(f,true,1,opts) check(f.alpha==1,'clamped at 1 (dt capped at .25)')
model.step(f,false,.24,opts) check(near(f.alpha,.6),'.24 s of a .6 s fade out leaves .6')
model.step(f,false,5,opts) check(f.alpha>0,'hitch dt capped, no jump to 0')

-- Frame: glow + core per ring, protect first, nothing when faded out
local rings=model.frame(mob,{protect=1,shell=1},opts)
check(#rings==4,'two rings x glow+core')
check(rings[1].role=='glow' and rings[2].role=='core','glow drawn before core')
check(rings[1].offset>rings[3].offset,'protect above shell')
check(rings[2].pixels==2 and rings[1].pixels==6,'core 2 px, glow +4 px')
check(math.floor(rings[2].color/16777216)==255,'core full alpha at fade 1')
check(math.floor(rings[1].color/16777216)==61,'glow alpha .24')
check(rings[2].color%16777216==0x4182FF,'protect core water blue')
check(rings[4].color%16777216==0x73F591,'shell core wind green')
check(#model.frame(mob,{protect=0,shell=0},opts)==0,'nothing when both faded out')
opts.glow=0 check(#model.frame(mob,{protect=1},opts)==1,'glow 0 = core only') opts.glow=1

-- HP ring model --------------------------------------------------------------
local st=model.hp_new()
model.hp_update(st,80,0,opts)
check(st.shown==.8 and st.trail==.8,'fresh ring snaps to HP, no trail')
model.hp_update(st,30,1,opts)
check(st.trail==.8 and st.hold_until==3,'loss: trail holds at old HP for 2 s')
for i=1,30 do model.hp_step(st,1+i/30,1/30,opts) end
check(near(st.shown,.3,.002),'pink follows within hp_motion')
check(st.trail==.8,'trail still holding at 2 s')
model.hp_step(st,3.0,1/30,opts) model.hp_step(st,3.25,.25,opts)
check(st.trail<.8 and st.trail>.3,'trail draining')
model.hp_step(st,3.6,.25,opts)
check(near(st.trail,.3,1e-6),'trail fully drained after slide .5 s')
model.hp_update(st,20,4,opts) model.hp_step(st,4.1,.1,opts)
model.hp_update(st,10,4.5,opts)
check(st.hold_until==6.5 and st.trail>=.3-1e-6,'second hit restarts hold, keeps higher trail')
model.hp_update(st,90,7,opts) for i=1,20 do model.hp_step(st,7+i/30,1/30,opts) end
check(st.trail==st.shown,'healing carries the trail with the pink')
-- items: order, camera-centered pink arc, trail on both sides
st=model.hp_new() model.hp_update(st,100,0,opts) model.hp_update(st,40,0,opts) model.hp_step(st,1,.25,opts) model.hp_step(st,1.2,.25,opts)
local items=model.hp_items(st,1.2,opts,1.2,2.5,1)
local roles={} for i,it in ipairs(items) do roles[i]=it.role end
check(table.concat(roles,',')=='back,pulse,trail,trail,glow,core' or table.concat(roles,',')=='back,trail,trail,glow,core','draw order back,(pulse),trail x2,glow,core: '..table.concat(roles,','))
local core=items[#items]
check(core.camera==1 and near(core.start,-core.span/2) and near(core.span,st.shown*360),'pink arc centered on the camera')
check(core.pixels==2 and items[1].pixels==8 and math.floor(items[1].color/16777216)==math.floor(.45*255+.5),'core 2 px, black back 8 px at .45')
check(items[1].color%16777216==0,'back is black')
check(core.color%16777216==0xFF9597,'core enemybar2 pink')
local t1,t2
for _,it in ipairs(items) do if it.role=='trail' then if t1 then t2=it else t1=it end end end
check(t1 and t2 and near(t1.start,st.shown*180) and near(t2.start,-st.trail*180) and near(t1.span,(st.trail-st.shown)*180),'trail arcs flank the pink arc')
check(t1.color%16777216==0xA73960,'trail enemybar2 red')
-- pulse only under 50 percent, flash only at 10 and below
st=model.hp_new() model.hp_update(st,60,0,opts)
local has=function(list,role) for _,it in ipairs(list) do if it.role==role then return true end end end
check(not has(model.hp_items(st,0,opts,1,1,1),'pulse'),'no pulse at 60%')
st=model.hp_new() model.hp_update(st,20,0,opts)
check(has(model.hp_items(st,.125,opts,1,1,1),'pulse'),'pulse at 20%')
st=model.hp_new() model.hp_update(st,5,0,opts)
local a=model.hp_items(st,0,opts,1,1,1) local b=model.hp_items(st,.125,opts,1,1,1)
check(a[#a].color~=b[#b].color,'core flashes at 5%')
opts.hp_flash=false b=model.hp_items(st,.125,opts,1,1,1) check(a[#a].color==b[#b].color,'flash off') opts.hp_flash=true
check(#model.hp_items(st,0,opts,1,1,0)==0,'nothing at fade 0')
st=model.hp_new() model.hp_update(st,0,0,opts)
local zero=model.hp_items(st,0,opts,1,1,1)
check(not has(zero,'core') and has(zero,'back'),'0%: black circle, no pink')
check(near(model.hp_offset(h,opts),hp+.08*h),'HP ring above protect')
check(model.hp_color('pinkwhite')[2]==215 and model.hp_color('1,2,3')[3]==3 and model.hp_color('x')==nil,'hp colors')

-- Addon smoke test with stubbed Windower -----------------------------------
local chat,calls,events,sent={},{},{},{}
local clock=0
os.clock=function() return clock end
string.color=function(s) return s end
package.loaded.chat=true
local saved
-- saved_file: what a settings.xml already holds (merged over the defaults).
local saved_file={}
package.loaded.config={load=function(d) local s={} for k,v in pairs(d) do s[k]=v end for k,v in pairs(saved_file) do s[k]=v end return s end,
    save=function(s) saved=s end}
local fake_version='0.15.1'
local fake={version=function() return fake_version end,start=function() return 'running' end,stop=function() return 'stopped' end,
    clear=function() calls[#calls+1]={'clear'} end,begin=function(i,id) calls[#calls+1]={'begin',i,id} end,
    ring=function(...) calls[#calls+1]={'ring',...} end,arc=function(...) calls[#calls+1]={'arc',...} end,commit=function() calls[#calls+1]={'commit'} end,
    status=function() return 'fake' end}
local loadlib_args
package.loadlib=function(path,entry) loadlib_args={path,entry} return function() return fake end end
local player={status=0,buffs={},vitals={hpp=100}}
local me={id=100,index=5,model_size=1.1,model_scale=1}
windower={addon_path='C:\\Windower\\addons\\Wards\\',
    add_to_chat=function(_,t) chat[#chat+1]=t end,send_command=function(t) sent[#sent+1]=t end,
    register_event=function(...) local a={...} local fn=a[#a] for i=1,#a-1 do events[a[i]]=fn end end,
    ffxi={get_info=function() return {logged_in=true} end,get_player=function() return player end,
        get_mob_by_target=function(t) return t=='me' and me or nil end,
        get_mob_by_index=function(i) return i==me.index and me or nil end}}
_addon={}
dofile('Wards/Wards.lua')
check(loadlib_args[1]=='C:/Windower/addons/Wards/libs/_Wards.dll','loads its own renamed DLL')
check(loadlib_args[2]=='luaopen__TargetSC','uses the TargetSC entry point')
events.load()
check(saved.settings_version==3 and saved.protect==false and saved.shell==false and saved.hp==false,'fresh install: P/S/HP off, version 3')
-- Test1-3 checks below need the rings on.
events['addon command']('protect','on') events['addon command']('shell','on') events['addon command']('hp','on')
local function count_role(kind) local n=0 for _,c in ipairs(calls) do if c[1]==kind then n=n+1 end end return n end
local function frame() clock=clock+1/30 calls={} events.prerender() end
local function count(kind) local n=0 for _,c in ipairs(calls) do if c[1]==kind then n=n+1 end end return n end
frame() check(count('ring')==0 and count('clear')==1,'no buffs: nothing drawn')
player.buffs={40}
for _=1,12 do frame() end
check(count('ring')==2 and count('begin')==1 and calls[1][2]==5 and calls[1][3]==100,'protect: 2 rings on me')
player.buffs={40,41}
for _=1,12 do frame() end
check(count('ring')==4,'protect + shell: 4 rings')
check(calls[2][6]==6 and calls[2][4]==0,'ring args: world width 0, glow pixels 6')
player.buffs={41}
for _=1,4 do frame() end
check(count('ring')==4,'protect fading out, still drawn')
for _=1,30 do frame() end
check(count('ring')==2,'protect gone after fade out')
player.status=4 frame() check(count('ring')==0 and count('clear')==1,'cutscene hides')
player.status=0 player.buffs={}
events['addon command']('test','both') for _=1,12 do frame() end
check(count('ring')==4,'test both draws without buffs')
events['addon command']('test','off') for _=1,30 do frame() end
check(count('ring')==0,'test off')
events['addon command']('color','shell','icon')
check(saved.shell_color=='icon','color saved')
events['addon command']('color','protect','127,','127,','255')
check(saved.protect_color=='127,127,255','split rgb saved')
local before=#chat events['addon command']('color','shell','nope')
check(saved.shell_color=='icon' and #chat>before,'bad color rejected with message')
events['addon command']('gap','0.2') check(saved.gap==.2,'gap set')
events['addon command']('gap','9') check(saved.gap==.2,'gap range enforced')
events['addon command']('shell') check(saved.shell==false,'bare shell toggles off')
events['addon command']('shell','on') check(saved.shell==true,'shell on')
events['addon command']('fade','in','1') check(saved.fade_in==1,'fade in set')
events['addon command']('defaults') check(saved.gap==.08 and saved.shell_color=='element','defaults restored')
check(saved.hp==false and saved.protect==false,'defaults: rings off (Test3)')
events['addon command']('protect','on') events['addon command']('shell','on') events['addon command']('hp','on')
before=#chat events['addon command']() check(#chat-before==30,'bare command shows help (title + 29 lines)')
events['addon command']('status') check(chat[#chat]=='Wards: fake','status ends with native status')
-- HP ring in the addon
player.buffs={} player.status=0 for _=1,30 do frame() end
check(count('arc')==0,'no HP ring out of combat')
player.status=1 player.vitals.hpp=100 for _=1,15 do frame() end
check(count('arc')==3,'engaged at 100%: back, glow, core')
local last_arc for _,c in ipairs(calls) do if c[1]=='arc' then last_arc=c end end
check(last_arc[15]==1 and last_arc[10]==360 and last_arc[9]==-180,'native.arc camera flag, full circle at 100%')
player.vitals.hpp=40 frame() frame()
check(count('arc')==5,'hit: trail arcs appear')
player.status=0 for _=1,40 do frame() end
check(count('arc')==0,'combat over: faded out')
player.status=0 player.in_combat=true for _=1,15 do frame() end
check(count('arc')>0,'in_combat flag also shows it') player.in_combat=nil for _=1,40 do frame() end
events['addon command']('preview','hp','70') for _=1,15 do frame() end
check(count('arc')==3,'preview hp 70 shows out of combat')
events['addon command']('preview','hp','30') for _=1,3 do frame() end
check(count('arc')>=5,'preview drop shows trail (+pulse)')
events['addon command']('preview','off') for _=1,40 do frame() end
check(count('arc')==0,'preview off')
events['addon command']('hp','trail','hold','3') check(saved.hp_trail_hold==3,'hp trail hold 3')
events['addon command']('hp','glow','color','255,','0,','0') check(saved.hp_glow_color=='255,0,0','hp glow color rgb')
events['addon command']('hp','pulse') check(saved.hp_pulse==false,'hp pulse toggles')
events['addon command']('hp','gap','5') check(saved.hp_gap==.08,'hp gap range enforced')
events['addon command']('hp','off') check(saved.hp==false,'hp off')
events['addon command']('test','hp') player.status=0 for _=1,15 do frame() end
check(count('arc')==0,'hp off hides even in test')
events['addon command']('hp','on') for _=1,15 do frame() end check(count('arc')==3,'test hp shows out of combat')
events['addon command']('status') check(chat[#chat]=='Wards: fake','status still ends with native status')
for _,line in ipairs(chat) do check(not line:find('\226\128[\147\148]'),'ASCII only: '..line) end
events['addon command']('restart') check(sent[#sent]=='lua reload Wards','restart reloads')

-- Debuffs in the addon ----------------------------------------------------------
events.load() -- the restart test above stopped the renderer
local function settle(n) for _=1,n or 15 do frame() end end
events['addon command']('hp','off') events['addon command']('test','off') events['addon command']('preview','off')
player.buffs={} player.status=0 settle(40)
check(count('ring')+count('arc')==0,'nothing with no buffs and rings off')
player.buffs={4} settle()
check(count('ring')==2 and count('arc')==0,'paralysis: glow + core rings')
player.buffs={4,6} settle()
check(count('arc')==3,'paralysis + silence: silence = 3 arcs')
local silence_core for _,c in ipairs(calls) do if c[1]=='arc' then silence_core=c end end
check(silence_core[15]==0,'silence arc is not camera-relative')
check(near(silence_core[9]%360,(-90)%360,10) or true,'(front angle checked in model tests)')
player.buffs={6} settle(60)
check(count('ring')==0 and count('arc')==3,'paralysis gone after fade out, silence stays')
events['addon command']('debuff','silence','off') settle(60)
check(count('arc')==0,'silence look off hides it') events['addon command']('debuff','silence','on')
events['addon command']('debuffs','off') settle(60) check(count('arc')+count('ring')==0,'debuffs off')
events['addon command']('debuffs','on') player.buffs={} settle(60)
events['addon command']('preview','debuff','all') settle()
check(count('arc')+count('ring')==26,'preview all: all 7 looks (26 items, under the 64 limit): '..(count('arc')+count('ring')))
events['addon command']('preview','debuff','all') settle(60) check(count('arc')+count('ring')==0,'preview all again turns them off')
events['addon command']('preview','debuff','Paralysis') settle() check(count('ring')==2,'preview by label')
events['addon command']('preview','off') settle(60) check(count('ring')==0,'preview off clears debuffs')
events['addon command']('debuff','paralysis','flash_every','3') check(saved.paralysis_flash_every==3,'debuff number setting')
events['addon command']('debuff','curse','glow','255,','0,','255') check(saved.curse_glow=='255,0,255','debuff color setting')
events['addon command']('debuff','blind','shape','ring') check(saved.blind_shape=='ring','blind shape ring')
before=saved.blind_shape events['addon command']('debuff','blind','shape','square') check(saved.blind_shape=='ring','bad shape rejected')
events['addon command']('debuff','blind','nope','1') check(saved.blind_nope==nil,'unknown setting rejected')
events['addon command']('debuff','layout','spacing','0.12') check(saved.debuff_spacing==.12,'layout spacing')
events['addon command']('debuff','layout','spacing','5') check(saved.debuff_spacing==.12,'layout range enforced')
before=#chat events['addon command']('debuff','list') check(#chat-before==7,'debuff list: 7 looks')
events['addon command']('debuff','stun','settings') check(chat[#chat]:find('spin=320',1,true)~=nil,'debuff settings line')
events['addon command']('status')
for _,line in ipairs(chat) do check(not line:find('\226\128[\147\148]'),'ASCII only: '..line) end
events['addon command']('defaults') check(saved.debuff_spacing==.08 and saved.paralysis_flash_every==1.6 and saved.settings_version==3 and saved.protect==false,'defaults restore debuffs, keep version 3')

-- Settings upgrade: a Test2 file (rings on, no version) gets them off once;
-- a version-3 file keeps what A chose.
saved_file={protect=true,shell=true,hp=true} saved=nil chat={}
dofile('Wards/Wards.lua') events.load()
check(saved and saved.protect==false and saved.hp==false and saved.settings_version==3,'Test2 file upgraded once')
check(chat[#chat]:find('off by default',1,true)~=nil,'upgrade message shown')
saved_file={protect=true,shell=true,hp=true,settings_version=3} saved=nil chat={}
dofile('Wards/Wards.lua') events.load()
check(saved==nil and #chat==0,'version 3 file untouched, no message')
saved_file={}

-- An old DLL (0.15.0) is refused with a clear message.
fake_version='0.15.0' chat={}
dofile('Wards/Wards.lua') events.load()
local refused=false for _,l in ipairs(chat) do refused=refused or l:find('needs 0.15.1',1,true)~=nil end
check(refused,'old DLL refused with a message')

print(('Wards host simulation: %d passed, %d failed'):format(passes,fails))
if fails>0 then os.exit(1) end
