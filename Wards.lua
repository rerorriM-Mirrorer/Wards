-- Wards: a Protect ring and a Shell ring drawn in 3D around your own
-- character while those buffs are on you, and (Test2) an enemybar2-style HP
-- ring above them while you are in combat. A first test of status visuals
-- built on TargetSC's native ring renderer. Author: A.
_addon.name='Wards'
_addon.author='A'
_addon.version='0.2.0-test2'
_addon.commands={'wards'}

require('chat')
local config=require('config')
local model=require('wards_model')

local settings=config.load(model.defaults)
local addon_path=windower.addon_path:gsub('\\','/')

local function say(text) windower.add_to_chat(207,'Wards: '..text) end

-- Native renderer. Wards ships its own copy of TargetSC's DLL renamed to
-- libs/_Wards.dll. The DLL draws one character per frame, so sharing
-- TargetSC's copy would make the two addons erase each other's rings;
-- a renamed file loads as a separate copy with its own frame. The entry
-- point inside is still called luaopen__TargetSC, so it is loaded with
-- package.loadlib (file name and entry point given separately) rather than
-- require (which would look for luaopen__Wards).
local native,renderer_error,renderer_started
do
    local loader,err=package.loadlib(addon_path..'libs/_Wards.dll','luaopen__TargetSC')
    if loader then
        local ok,result=pcall(loader)
        if ok and type(result)=='table' and type(result.version)=='function' then
            local need={'start','stop','clear','begin','ring','arc','commit','status'}
            for _,name in ipairs(need) do
                if type(result[name])~='function' then renderer_error='DLL is missing '..name end
            end
            -- Test2 needs 0.15.1: arcs measured from the camera (HP ring).
            local ok_v,version=pcall(result.version)
            if not renderer_error and (not ok_v or version~='0.15.1') then
                renderer_error='libs/_Wards.dll is '..tostring(version)..', Wards needs 0.15.1 (close the game and replace it)'
            end
            if not renderer_error then native=result end
        else renderer_error=tostring(result) end
    else renderer_error=tostring(err) end
end

local function start_renderer()
    if not native then say('Renderer unavailable: '..tostring(renderer_error)) return false end
    if not renderer_started then
        local status=native.start()
        renderer_started=type(status)=='string' and status:match('^running')~=nil
        if not renderer_started then say('Renderer did not start: '..tostring(status)) end
    end
    return renderer_started
end
local function clear() if native then native.clear() end end

-- Per-ring fade state and test overrides (test = show even without the buff).
local fades={protect=model.new_fade(),shell=model.new_fade(),hp=model.new_fade()}
local test={protect=false,shell=false,hp=false}
local hp_state=model.hp_new()
local preview_hp=nil -- //wards preview hp <n>: shows the ring with this HP% instead of yours
local last_clock,next_frame=nil,0

-- The player's own entity, only when it is safe to draw on: logged in, not
-- in a cutscene/event (status 4), and the entity index still belongs to us.
local function self_mob()
    local info=windower.ffxi.get_info()
    if not info or not info.logged_in then return nil end
    local player=windower.ffxi.get_player()
    if not player or player.status==4 then return nil end
    local me=windower.ffxi.get_mob_by_target('me')
    if not me or not me.id or me.id==0 or not me.index or me.index==0 then return nil end
    local live=windower.ffxi.get_mob_by_index(me.index)
    if not live or live.id~=me.id then return nil end
    return me,player
end

-- The HP ring's combat fade uses its own in/out times.
local hp_fade_opts={}
setmetatable(hp_fade_opts,{__index=function(_,k)
    if k=='fade_in' then return settings.hp_fade_in elseif k=='fade_out' then return settings.hp_fade_out end
end})
local function draw()
    local now=os.clock()
    if now<next_frame then return end
    next_frame=now+1/30 -- 30 updates a second, same as TargetSC's classic cadence
    local dt=last_clock and now-last_clock or 0
    last_clock=now
    if not settings.enabled or not renderer_started then return end
    local me,player=self_mob()
    if not me then
        fades.protect.alpha,fades.shell.alpha,fades.hp.alpha=0,0,0
        model.hp_reset(hp_state)
        clear() return
    end
    local want_p=settings.protect and (test.protect or model.has(player.buffs,model.BUFF.protect))
    local want_s=settings.shell and (test.shell or model.has(player.buffs,model.BUFF.shell))
    local alphas={protect=model.step(fades.protect,want_p,dt,settings),shell=model.step(fades.shell,want_s,dt,settings)}
    local rings,radius,height=model.frame(me,alphas,settings)
    -- HP ring: in combat (engaged, or Windower's in_combat flag), or test/preview.
    local in_combat=player.status==1 or player.in_combat==true
    local want_hp=settings.hp and (in_combat or test.hp or preview_hp~=nil)
    local hp_alpha=model.step(fades.hp,want_hp,dt,hp_fade_opts)
    local items={}
    if hp_alpha>0 then
        model.hp_update(hp_state,preview_hp or (player.vitals and player.vitals.hpp) or 100,now,settings)
        model.hp_step(hp_state,now,dt,settings)
        items=model.hp_items(hp_state,now,settings,radius,model.hp_offset(height,settings),hp_alpha)
    else model.hp_reset(hp_state) end
    if #rings==0 and #items==0 then clear() return end
    native.begin(me.index,me.id)
    for _,a in ipairs(items) do
        native.arc(a.radius,a.offset,0,a.color,a.color,a.pixels,0,a.start,a.span,0,1,1,1,a.camera)
    end
    for _,r in ipairs(rings) do native.ring(r.radius,r.offset,0,r.color,r.pixels) end
    native.commit()
end

-- Commands. Each command is its own small handler (WORKFLOW convention).
local help_lines={
    {'help','Show this list.'},
    {'status','Version, renderer, buffs seen and every setting.'},
    {'on | off','Turn all Wards drawing on or off.'},
    {'protect [on|off]','Show or hide the Protect ring (bare = toggle).'},
    {'shell [on|off]','Show or hide the Shell ring (bare = toggle).'},
    {'test <protect|shell|both|off>','Show rings without the buff, for tuning.'},
    {'color <protect|shell> <element|icon|iconlight|R,G,B>','Ring color (element = TargetSC Water / Wind).'},
    {'height <0.25-3>','Height span, like TargetSC height (default 0.66).'},
    {'scale <0.25-3>','Ring size, like TargetSC scale (default 2).'},
    {'level <0-1.5>','Protect ring position in the span (default 0.90 = sky ring).'},
    {'gap <0-0.5>','Shell ring distance below Protect (default 0.08).'},
    {'ground <0-1>','Yalms above the feet where the span starts (default 0.3).'},
    {'opacity <0-1>','Core line opacity (default 1).'},
    {'glow <0-3>','Glow strength, 0 = none (default 1).'},
    {'width <1-8>','Core line width in pixels (default 2).'},
    {'fade <in|out> <0.05-3>','Fade seconds (defaults in 0.3, out 0.6).'},
    {'hp [on|off]','HP ring above Protect, shown in combat (bare = toggle).'},
    {'hp <setting> <value>','Tune the HP ring; //wards hp settings lists them.'},
    {'test hp','Show the HP ring out of combat (toggle).'},
    {'preview hp <0-100> | preview off','HP ring at a chosen HP%; lower it to see the trail.'},
    {'defaults','Restore every setting to its default.'},
    {'restart | unload','Reload or unload Wards.'},
}
local function help()
    windower.add_to_chat(0,('Wards '.._addon.version..' - Protect and Shell rings'):color(167))
    for _,line in ipairs(help_lines) do
        windower.add_to_chat(0,('//wards '):color(200)..line[1]:color(207)..(' -> '):color(200)..line[2]:color(0))
    end
end
local function onoff(value,name)
    if value==nil then return not settings[name] end -- bare command toggles
    if value=='on' or value=='off' then return value=='on' end
    say('Use //wards '..name..' [on|off].')
end
local hp_order -- HP setting names, in display order (filled in below)
local function status()
    local _,player=self_mob()
    local buffs=player and player.buffs
    say(('v%s; enabled=%s renderer=%s; protect=%s shell=%s; test protect=%s shell=%s'):format(_addon.version,
        tostring(settings.enabled),native and (renderer_started and 'running' or 'stopped') or ('unavailable ('..tostring(renderer_error)..')'),
        tostring(settings.protect),tostring(settings.shell),tostring(test.protect),tostring(test.shell)))
    say(('buffs seen: Protect=%s Shell=%s; fade alpha protect=%.2f shell=%.2f'):format(
        tostring(model.has(buffs,model.BUFF.protect)),tostring(model.has(buffs,model.BUFF.shell)),fades.protect.alpha,fades.shell.alpha))
    say(('color protect=%s shell=%s; height=%.2f scale=%.2f level=%.2f gap=%.2f ground=%.2f'):format(
        settings.protect_color,settings.shell_color,settings.height,settings.scale,settings.level,settings.gap,settings.ground))
    say(('opacity=%.2f glow=%.2f width=%s; fade in=%.2fs out=%.2fs'):format(
        settings.opacity,settings.glow,settings.width,settings.fade_in,settings.fade_out))
    say(('hp ring=%s test=%s preview=%s fade=%.2f shown=%.2f trail=%.2f'):format(tostring(settings.hp),tostring(test.hp),
        tostring(preview_hp or 'off'),fades.hp.alpha,hp_state.shown,hp_state.trail))
    local parts={}
    for _,name in ipairs(hp_order) do parts[#parts+1]=name..'='..tostring(settings['hp_'..name]) end
    say('hp: '..table.concat(parts,' '))
    if native then say(native.status()) end
end
local ranges={height={.25,3},scale={.25,3},level={0,1.5},gap={0,.5},ground={0,1},opacity={0,1},glow={0,3},width={1,8}}
local function set_number(name,value)
    local n,r=tonumber(value),ranges[name]
    if not n or n<r[1] or n>r[2] then say(('Use //wards %s <%s-%s>.'):format(name,r[1],r[2])) return end
    if name=='width' then n=math.floor(n+.5) end
    settings[name]=n config.save(settings)
    say(('%s = %s'):format(name,n))
end
-- HP ring settings: //wards hp <name> <value>. Numbers have ranges, toggles
-- take on|off, colors take a name (pink, pinkwhite, trail, red, black,
-- white) or R,G,B.
local hp_numbers={gap={0,1},opacity={0,1},width={1,16},glow={0,3},glow_opacity={0,1},back_opacity={0,1},
    back_width={1,32},motion={.01,2},trail_opacity={0,1},trail_width={1,16},trail_hold={0,10},trail_slide={.05,5},
    pulse_opacity={0,1},pulse_period={.05,5},flash_period={.05,5},fade_in={.05,3},fade_out={.05,3}}
local hp_toggles={trail=true,pulse=true,flash=true}
local hp_colors={color=true,glow_color=true,trail_color=true,pulse_color=true}
hp_order={'gap','color','opacity','width','glow','glow_color','glow_opacity','back_opacity','back_width','motion',
    'trail','trail_color','trail_opacity','trail_width','trail_hold','trail_slide','pulse','pulse_color','pulse_opacity',
    'pulse_period','flash','flash_period','fade_in','fade_out'}
local function hp_command(name,...)
    local args={...}
    if name==nil or name=='on' or name=='off' then
        if name==nil then settings.hp=not settings.hp else settings.hp=name=='on' end
        config.save(settings) say('HP ring '..(settings.hp and 'on' or 'off')..'.') return
    end
    if name=='settings' then
        say('//wards hp <setting> <value>: '..table.concat(hp_order,', ')..'. Colors: pink, pinkwhite, trail, red, black, white or R,G,B.')
        return
    end
    -- two-word names: "glow color", "trail hold", "fade in"...
    if args[1] and (hp_numbers[name..'_'..args[1]] or hp_colors[name..'_'..args[1]]) then
        name=name..'_'..table.remove(args,1)
    end
    local key='hp_'..name
    if hp_toggles[name] then
        local v=args[1]
        if v==nil then settings[key]=not settings[key] elseif v=='on' or v=='off' then settings[key]=v=='on'
        else say('Use //wards hp '..name..' [on|off].') return end
        config.save(settings) say(('hp %s %s'):format(name,settings[key] and 'on' or 'off')) return
    end
    if hp_colors[name] then
        local value=table.concat(args,'')
        local c=model.hp_color(value)
        if not c then say('Use //wards hp '..name:gsub('_',' ')..' pink|pinkwhite|trail|red|black|white|R,G,B.') return end
        settings[key]=value:lower() config.save(settings)
        say(('hp %s = %s (%d,%d,%d)'):format(name:gsub('_',' '),value:lower(),c[1],c[2],c[3])) return
    end
    local r=hp_numbers[name]
    local n=tonumber(args[1])
    if not r then say('Unknown HP setting '..tostring(name)..'. //wards hp settings lists them.') return end
    if not n or n<r[1] or n>r[2] then say(('Use //wards hp %s <%s-%s>.'):format(name:gsub('_',' '),r[1],r[2])) return end
    settings[key]=n config.save(settings) say(('hp %s = %s'):format(name:gsub('_',' '),n))
end
local handlers={}
handlers.hp=hp_command
handlers.preview=function(kind,value)
    if kind=='off' then preview_hp=nil say('Preview off.') return end
    local n=tonumber(value)
    if kind~='hp' or not n or n<0 or n>100 then say('Use //wards preview hp <0-100> or //wards preview off.') return end
    if preview_hp==nil then model.hp_reset(hp_state) end
    preview_hp=n
    say(('Preview: HP ring at %d%% (lower it again to watch the trail; //wards preview off ends it).'):format(n))
end
handlers.help=help
handlers.status=status
handlers.on=function() settings.enabled=true config.save(settings) start_renderer() say('On.') end
handlers.off=function() settings.enabled=false config.save(settings) clear() say('Off.') end
for _,kind in ipairs({'protect','shell'}) do
    handlers[kind]=function(value)
        local v=onoff(value,kind) if v==nil then return end
        settings[kind]=v config.save(settings) say(kind..' ring '..(v and 'on' or 'off')..'.')
    end
end
handlers.test=function(which)
    if which=='protect' or which=='shell' or which=='hp' then test[which]=not test[which]
    elseif which=='both' then test.protect,test.shell=true,true
    elseif which=='off' then test.protect,test.shell,test.hp=false,false,false
    else say('Use //wards test protect|shell|hp|both|off.') return end
    say(('Test: protect=%s shell=%s hp=%s (test rings ignore buffs and combat).'):format(tostring(test.protect),tostring(test.shell),tostring(test.hp)))
end
handlers.color=function(kind,...)
    local value=table.concat({...},'')
    if (kind~='protect' and kind~='shell') or value=='' then
        say('Use //wards color protect|shell element|icon|iconlight|R,G,B.') return
    end
    if not model.color(kind,value) then say('Unknown color '..value..'. Use element, icon, iconlight or R,G,B (0-255).') return end
    settings[kind..'_color']=value:lower() config.save(settings)
    local c=model.color(kind,value)
    say(('%s color = %s (%d,%d,%d)'):format(kind,value:lower(),c[1],c[2],c[3]))
end
handlers.fade=function(which,value)
    local n=tonumber(value)
    if (which~='in' and which~='out') or not n or n<.05 or n>3 then say('Use //wards fade in|out <0.05-3>.') return end
    settings['fade_'..which]=n config.save(settings) say(('fade %s = %.2fs'):format(which,n))
end
handlers.defaults=function()
    for k,v in pairs(model.defaults) do settings[k]=v end
    config.save(settings) say('All settings restored to defaults.')
end
for name in pairs(ranges) do handlers[name]=function(value) set_number(name,value) end end
local function lifecycle(command)
    say(command=='restart' and 'Restarting.' or 'Unloading.')
    clear() if native and renderer_started then native.stop() renderer_started=false end
    windower.send_command(command=='restart' and 'lua reload Wards' or 'lua unload Wards')
end
handlers.restart=function() lifecycle('restart') end
handlers.unload=function() lifecycle('unload') end

windower.register_event('addon command',function(command,...)
    command=command and command:lower()
    local handler=command and handlers[command]
    if handler then handler(...) return end
    if command then say('Unknown command: '..command) end
    help()
end)
windower.register_event('prerender',draw)
windower.register_event('load',function() if settings.enabled then start_renderer() end end)
windower.register_event('zone change','logout',function()
    fades.protect.alpha,fades.shell.alpha,fades.hp.alpha=0,0,0 model.hp_reset(hp_state) clear()
end)
windower.register_event('unload',function() clear() if native then native.stop() end end)
