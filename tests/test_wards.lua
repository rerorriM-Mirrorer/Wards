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

-- Addon smoke test with stubbed Windower -----------------------------------
local chat,calls,events,sent={},{},{},{}
local clock=0
os.clock=function() return clock end
string.color=function(s) return s end
package.loaded.chat=true
local saved
package.loaded.config={load=function(d) local s={} for k,v in pairs(d) do s[k]=v end return s end,
    save=function(s) saved=s end}
local fake={version=function() return '0.15.0' end,start=function() return 'running' end,stop=function() return 'stopped' end,
    clear=function() calls[#calls+1]={'clear'} end,begin=function(i,id) calls[#calls+1]={'begin',i,id} end,
    ring=function(...) calls[#calls+1]={'ring',...} end,commit=function() calls[#calls+1]={'commit'} end,
    status=function() return 'fake' end}
local loadlib_args
package.loadlib=function(path,entry) loadlib_args={path,entry} return function() return fake end end
local player={status=0,buffs={}}
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
before=#chat events['addon command']() check(#chat-before==#'x'+18,'bare command shows help (title + 18 lines)')
events['addon command']('status') check(chat[#chat]=='Wards: fake','status ends with native status')
for _,line in ipairs(chat) do check(not line:find('\226\128[\147\148]'),'ASCII only: '..line) end
events['addon command']('restart') check(sent[#sent]=='lua reload Wards','restart reloads')

print(('Wards host simulation: %d passed, %d failed'):format(passes,fails))
if fails>0 then os.exit(1) end
