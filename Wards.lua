-- Wards: a Protect ring and a Shell ring drawn in 3D around your own
-- character while those buffs are on you, and (Test2) an enemybar2-style HP
-- ring above them while you are in combat, and (Test3) debuff looks stacked
-- above those. Status visuals built on TargetSC's native ring renderer.
-- Author: A.
_addon.name='Wards'
_addon.author='A'
_addon.version='0.3.3-test6'
_addon.commands={'wards'}

require('chat')
local config=require('config')
local model=require('wards_model')
local vfx=require('wards_vfx')
local dbf=require('wards_debuffs')
local packets=require('packets')

-- Defaults = rings/HP ring (wards_model) + debuffs (wards_debuffs).
-- settings_version: 3 = Test3 upgrade done (see below).
local defaults={settings_version=0}
for k,v in pairs(model.defaults) do defaults[k]=v end
for k,v in pairs(vfx.defaults) do defaults[k]=v end
for k,v in pairs(dbf.defaults()) do defaults[k]=v end
local settings=config.load(defaults)
-- One-time Test3 upgrade: Protect, Shell and the HP ring are now off by
-- default, but a settings file saved by Test1/Test2 already holds them as
-- "on" (Windower only uses defaults for missing settings). Turn them off
-- once; after that the file is version 3 and this never runs again, so
-- //wards protect on etc. stay as you set them.
local upgraded=false
if (tonumber(settings.settings_version) or 0)<3 then
    settings.protect,settings.shell,settings.hp=false,false,false
    settings.settings_version=3
    config.save(settings)
    upgraded=true
end
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
            local need={'start','stop','clear','begin','ring','arc','shield','hex','commit','status'}
            for _,name in ipairs(need) do
                if type(result[name])~='function' then renderer_error='DLL is missing '..name end
            end
            -- 0.16.0 adds the heading-oriented shield and camera-facing hex API.
            -- It retains 0.15.2 SceneHook owner-thunk unload safety.
            local ok_v,version=pcall(result.version)
            if not renderer_error and (not ok_v or version~='0.16.0') then
                renderer_error='libs/_Wards.dll is '..tostring(version)..', Wards needs 0.16.0 (close every game client and replace it)'
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
local test={protect=false,shell=false,hp=false,shimmer=false,expire=false,impact=false}
local hp_state=model.hp_new()
local shimmer_state=vfx.new_shimmer_state()
local expiry_state=vfx.new_expiration_state()
local impact_state=vfx.new_impact_state()
local last_protect_active=false
local preview_hp=nil -- //wards preview hp <n>: shows the ring with this HP% instead of yours
local dbf_state=dbf.new_state()
local preview_debuffs={} -- //wards preview debuff <name>|all: shown without the debuff
local MAX_ITEMS=64 -- the DLL's ring/arc limit per frame
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
        model.hp_reset(hp_state) dbf.reset(dbf_state) vfx.reset_shimmer(shimmer_state)
        vfx.reset_expiration(expiry_state) vfx.reset_impact(impact_state) last_protect_active=false
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
    -- Debuffs: stacked from just above the HP ring's position upward.
    local debuff_items=dbf.frame(dbf_state,player.buffs,preview_debuffs,now,dt,settings,
        model.hp_offset(height,settings)+settings.debuff_gap*height,height,radius,dbf.front_degrees(me.facing))
    local protect_active=model.has(player.buffs,model.BUFF.protect)
    if last_protect_active and not protect_active and settings.protect_expiry_glints then
        vfx.trigger_expiration(expiry_state,now)
    end
    last_protect_active=protect_active
    local protect_color=model.color('protect',settings.protect_color) or model.colors.protect.element
    local expiry_items=vfx.expiration(expiry_state,settings.protect_expiry_glints or test.expire,now,radius,height,settings,protect_color)
    local impact_item=vfx.impact(impact_state,settings.protect_impact or test.impact,now,radius,height,settings)
    -- Pause, rather than reset, the idle cycle during the brief impact surface.
    local shimmer_enabled=settings.protect_shimmer and (test.shimmer or protect_active) and impact_item==nil
    local shimmer_items=impact_item and {} or vfx.shimmer(shimmer_state,shimmer_enabled,now,radius,height,settings,protect_color)
    if #rings==0 and #items==0 and #debuff_items==0 and #shimmer_items==0 and #expiry_items==0 and not impact_item then clear() return end
    native.begin(me.index,me.id)
    local sent=0
    for _,a in ipairs(items) do
        if sent>=MAX_ITEMS then break end
        native.arc(a.radius,a.offset,0,a.color,a.color,a.pixels,0,a.start,a.span,0,1,1,1,a.camera) sent=sent+1
    end
    for _,r in ipairs(rings) do
        if sent>=MAX_ITEMS then break end
        native.ring(r.radius,r.offset,0,r.color,r.pixels) sent=sent+1
    end
    for _,d in ipairs(debuff_items) do
        if sent>=MAX_ITEMS then break end
        if d.kind=='ring' then native.ring(d.radius,d.offset,0,d.color,d.pixels)
        else native.arc(d.radius,d.offset,0,d.lead,d.tail,d.pixels,0,d.start,d.span,d.fade,1,d.curve,d.dir,0) end
        sent=sent+1
    end
    if impact_item and sent<MAX_ITEMS then
        local s=impact_item
        native.shield(s.distance,s.offset,s.radius,s.center,s.edge,s.outline,s.honeycomb,
            s.hex_radius,s.wave,s.wave_width,s.pixels)
        sent=sent+1
    end
    for _,g in ipairs(expiry_items) do
        if sent>=MAX_ITEMS then break end
        native.hex(g.x,g.y,g.z,g.radius,g.rotation,g.color,g.pixels)
        sent=sent+1
    end
    for _,s in ipairs(shimmer_items) do
        if sent>=MAX_ITEMS then break end
        native.ring(s.radius,s.offset,0,s.color,s.pixels)
        sent=sent+1
    end
    native.commit()
end

-- Commands. Each command is its own small handler (WORKFLOW convention).
local help_lines={
    {'help','Show this list.'},
    {'status','Version, renderer, buffs seen and every setting.'},
    {'on | off','Turn all Wards drawing on or off.'},
    {'protect [on|off]','Show or hide the Protect ring (bare = toggle).'},
    {'shimmer [on|off]','Protect idle shimmer, separate from the ring (default on).'},
    {'shimmer opacity <0.01-0.40>','Maximum core alpha (default 0.16).'},
    {'shimmer period <2-12>','Seconds between passes (default 4.8).'},
    {'shimmer duration <0.25-1.5>','Seconds per pass (default 0.75).'},
    {'impact [on|off]','Show a brief shield on incoming physical hits (default on).'},
    {'glints [on|off]','Tiny hex glints when Protect wears off (default on).'},
    {'shell [on|off]','Show or hide the Shell ring (bare = toggle).'},
    {'test <protect|shell|hp|shimmer|expire|impact 1-9999|both|off>','Preview looks without the buff or supply an impact intensity.'},
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
    {'debuffs [on|off]','Debuff looks on yourself (bare = toggle).'},
    {'debuff list','Each debuff look: on/off, showing now.'},
    {'debuff <name> [on|off]','One debuff look on or off (bare = toggle).'},
    {'debuff <name> settings','That debuff\'s settings and values.'},
    {'debuff <name> <setting> <value>','Tune one debuff look.'},
    {'debuff layout <setting> <value>','gap, spacing, max, slide, fade_in, fade_out, front.'},
    {'preview debuff <name|all>','Show a debuff look without the debuff (toggle).'},
    {'defaults','Restore every setting to its default.'},
    {'restart | unload','Reload or unload Wards.'},
}
local function help()
    windower.add_to_chat(0,('Wards '.._addon.version..' - debuff, Protect/Shell and HP rings'):color(167))
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
    say(('v%s; enabled=%s renderer=%s; protect=%s shell=%s shimmer=%s; test protect=%s shell=%s shimmer=%s'):format(_addon.version,
        tostring(settings.enabled),native and (renderer_started and 'running' or 'stopped') or ('unavailable ('..tostring(renderer_error)..')'),
        tostring(settings.protect),tostring(settings.shell),tostring(settings.protect_shimmer),
        tostring(test.protect),tostring(test.shell),tostring(test.shimmer)))
    say(('buffs seen: Protect=%s Shell=%s; fade alpha protect=%.2f shell=%.2f'):format(
        tostring(model.has(buffs,model.BUFF.protect)),tostring(model.has(buffs,model.BUFF.shell)),fades.protect.alpha,fades.shell.alpha))
    say(('color protect=%s shell=%s; height=%.2f scale=%.2f level=%.2f gap=%.2f ground=%.2f'):format(
        settings.protect_color,settings.shell_color,settings.height,settings.scale,settings.level,settings.gap,settings.ground))
    say(('opacity=%.2f glow=%.2f width=%s; fade in=%.2fs out=%.2fs'):format(
        settings.opacity,settings.glow,settings.width,settings.fade_in,settings.fade_out))
    say(('shimmer opacity=%.2f period=%.2fs duration=%.2fs'):format(
        settings.protect_shimmer_opacity,settings.protect_shimmer_period,settings.protect_shimmer_duration))
    say(('impact=%s glints=%s; test impact=%s expire=%s'):format(
        tostring(settings.protect_impact),tostring(settings.protect_expiry_glints),
        tostring(test.impact and impact_state.intensity or 'off'),tostring(test.expire)))
    say(('hp ring=%s test=%s preview=%s fade=%.2f shown=%.2f trail=%.2f'):format(tostring(settings.hp),tostring(test.hp),
        tostring(preview_hp or 'off'),fades.hp.alpha,hp_state.shown,hp_state.trail))
    local parts={}
    for _,name in ipairs(hp_order) do parts[#parts+1]=name..'='..tostring(settings['hp_'..name]) end
    say('hp: '..table.concat(parts,' '))
    local showing,parts2={},{}
    for _,name in ipairs(dbf.order) do
        if dbf_state.entries[name] then showing[#showing+1]=name end
        if settings[name]==false then parts2[#parts2+1]=name end
    end
    say(('debuffs=%s showing: %s; off: %s; preview: %s'):format(tostring(settings.debuffs),
        #showing>0 and table.concat(showing,' ') or 'none',#parts2>0 and table.concat(parts2,' ') or 'none',
        next(preview_debuffs) and table.concat((function() local l={} for _,n in ipairs(dbf.order) do if preview_debuffs[n] then l[#l+1]=n end end return l end)(),' ') or 'off'))
    say(('debuff layout: gap=%s spacing=%s max=%s slide=%s fade_in=%s fade_out=%s front=%s'):format(settings.debuff_gap,
        settings.debuff_spacing,settings.debuff_max,settings.debuff_slide,settings.debuff_fade_in,settings.debuff_fade_out,settings.debuff_front))
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
    if kind=='off' then preview_hp=nil preview_debuffs={} say('Preview off.') return end
    if kind=='debuff' then
        if value=='all' then
            local any=false for _,n in ipairs(dbf.order) do any=any or not preview_debuffs[n] end
            for _,n in ipairs(dbf.order) do preview_debuffs[n]=any or nil end
            say(any and 'Preview: all debuff looks (//wards preview off ends it).' or 'Preview: debuffs off.') return
        end
        local name=dbf.name_for(value)
        if not name then say('Use //wards preview debuff <'..table.concat(dbf.order,'|')..'|all>.') return end
        preview_debuffs[name]=not preview_debuffs[name] or nil
        say(('Preview %s %s.'):format(name,preview_debuffs[name] and 'on' or 'off')) return
    end
    local n=tonumber(value)
    if kind~='hp' or not n or n<0 or n>100 then say('Use //wards preview hp <0-100>, //wards preview debuff <name|all> or //wards preview off.') return end
    if preview_hp==nil then model.hp_reset(hp_state) end
    preview_hp=n
    say(('Preview: HP ring at %d%% (lower it again to watch the trail; //wards preview off ends it).'):format(n))
end
handlers.help=help
handlers.status=status
handlers.on=function() settings.enabled=true config.save(settings) start_renderer() say('On.') end
handlers.off=function()
    settings.enabled=false config.save(settings)
    vfx.reset_shimmer(shimmer_state) vfx.reset_expiration(expiry_state) vfx.reset_impact(impact_state)
    last_protect_active=false clear() say('Off.')
end
for _,kind in ipairs({'protect','shell'}) do
    handlers[kind]=function(value)
        local v=onoff(value,kind) if v==nil then return end
        settings[kind]=v config.save(settings) say(kind..' ring '..(v and 'on' or 'off')..'.')
    end
end
local shimmer_ranges={opacity={.01,.4},period={2,12},duration={.25,1.5}}
handlers.shimmer=function(which,value)
    local range=shimmer_ranges[which]
    if range then
        local n=tonumber(value)
        if not n or n<range[1] or n>range[2] then
            say(('Use //wards shimmer %s <%s-%s>.'):format(which,range[1],range[2])) return
        end
        settings['protect_shimmer_'..which]=n config.save(settings)
        say(('shimmer %s = %.2f'):format(which,n)) return
    end
    local enabled
    if which==nil then enabled=not settings.protect_shimmer
    elseif which=='on' then enabled=true
    elseif which=='off' then enabled=false
    else say('Use //wards shimmer [on|off], opacity <0.01-0.40>, period <2-12>, duration <0.25-1.5>.') return end
    settings.protect_shimmer=enabled
    if not enabled then vfx.reset_shimmer(shimmer_state) end
    config.save(settings) say('Protect shimmer '..(enabled and 'on.' or 'off.'))
end
local function effect_toggle(setting,command,value,label,state)
    local enabled
    if value==nil then enabled=not settings[setting]
    elseif value=='on' then enabled=true
    elseif value=='off' then enabled=false
    else say('Use //wards '..command..' [on|off].') return end
    settings[setting]=enabled
    if not enabled and state=='expiry' then vfx.reset_expiration(expiry_state) end
    if not enabled and state=='impact' then vfx.reset_impact(impact_state);test.impact=false end
    config.save(settings) say(label..' '..(enabled and 'on.' or 'off.'))
end
handlers.impact=function(value) effect_toggle('protect_impact','impact',value,'Protect impact','impact') end
handlers.glints=function(value) effect_toggle('protect_expiry_glints','glints',value,'Protect expiration glints','expiry') end
handlers.test=function(which,value)
    if which=='impact' then
        local intensity=tonumber(value)
        if not intensity or intensity<1 or intensity>9999 or intensity~=math.floor(intensity) then
            say('Use //wards test impact <1-9999>.') return
        end
        test.impact=true
        vfx.trigger_impact(impact_state,intensity,os.clock())
        say(('Impact preview: intensity %d (nonlinear visual response).'):format(intensity)) return
    elseif which=='expire' then
        test.expire=true
        vfx.trigger_expiration(expiry_state,os.clock())
        say('Protect expiration glints preview.') return
    elseif which=='protect' or which=='shell' or which=='hp' or which=='shimmer' then test[which]=not test[which]
    elseif which=='both' then test.protect,test.shell=true,true
    elseif which=='off' then
        test.protect,test.shell,test.hp,test.shimmer,test.expire,test.impact=false,false,false,false,false,false
        vfx.reset_shimmer(shimmer_state) vfx.reset_expiration(expiry_state) vfx.reset_impact(impact_state)
    else say('Use //wards test protect|shell|hp|shimmer|expire|impact <1-9999>|both|off.') return end
    say(('Test: protect=%s shell=%s hp=%s shimmer=%s impact=%s expire=%s.'):format(
        tostring(test.protect),tostring(test.shell),tostring(test.hp),tostring(test.shimmer),tostring(test.impact),tostring(test.expire)))
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
-- Debuff commands --------------------------------------------------------------
local layout_ranges={gap={0,2},spacing={0,1},max={1,12},slide={.01,3},fade_in={.05,3},fade_out={.05,3},front={-360,360}}
local function set_debuff_value(name,key,args)
    local defaults_r=dbf.recipes[name].defaults
    local default=defaults_r[key]
    if default==nil then
        local keys={} for k in pairs(defaults_r) do keys[#keys+1]=k end table.sort(keys)
        say(('%s has no setting %s. Settings: %s.'):format(name,tostring(key),table.concat(keys,', '))) return
    end
    local skey=name..'_'..key
    if type(default)=='number' then
        local n=tonumber(args[1])
        if not n or n<-3600 or n>3600 then say(('Use //wards debuff %s %s <number>.'):format(name,key)) return end
        settings[skey]=n
    elseif key=='shape' then
        if args[1]~='arc' and args[1]~='ring' then say(('Use //wards debuff %s shape arc|ring.'):format(name)) return end
        settings[skey]=args[1]
    else
        local value=table.concat(args,'')
        if not dbf.color(value) then say('Use a color name ('..'black, white, earth, ice, light, darkness, red, yellow'..') or R,G,B.') return end
        settings[skey]=value:lower()
    end
    config.save(settings) say(('%s %s = %s'):format(name,key,tostring(settings[skey])))
end
handlers.debuffs=function(value)
    local v=onoff(value,'debuffs') if v==nil then return end
    settings.debuffs=v config.save(settings) say('Debuff looks '..(v and 'on' or 'off')..'.')
end
handlers.debuff=function(word,...)
    local args={...}
    if word=='list' or word==nil then
        for _,n in ipairs(dbf.order) do
            say(('%s: %s%s (status %s)'):format(n,settings[n]==false and 'off' or 'on',
                dbf_state.entries[n] and ', showing' or '',table.concat(dbf.recipes[n].ids,'/')))
        end return
    end
    if word=='layout' then
        local key=args[1] local r=layout_ranges[key or ''] local n=tonumber(args[2])
        if not r or not n or n<r[1] or n>r[2] then say('Use //wards debuff layout gap|spacing|max|slide|fade_in|fade_out|front <value>.') return end
        settings['debuff_'..key]=n config.save(settings) say(('debuff %s = %s'):format(key,n)) return
    end
    local name=dbf.name_for(word)
    if not name then say('Unknown debuff '..tostring(word)..'. //wards debuff list shows them.') return end
    local first=args[1]
    if first==nil or first=='on' or first=='off' then
        if first==nil then settings[name]=settings[name]==false else settings[name]=first=='on' end
        config.save(settings) say(('%s look %s.'):format(name,settings[name] and 'on' or 'off')) return
    end
    if first=='settings' then
        local keys={} for k in pairs(dbf.recipes[name].defaults) do keys[#keys+1]=k end table.sort(keys)
        local parts={} for _,k in ipairs(keys) do
            local v=settings[name..'_'..k] if v==nil then v=dbf.recipes[name].defaults[k] end
            parts[#parts+1]=k..'='..tostring(v)
        end
        say(name..': '..table.concat(parts,' ')) return
    end
    table.remove(args,1)
    set_debuff_value(name,first,args)
end
handlers.defaults=function()
    for k,v in pairs(defaults) do settings[k]=v end
    settings.settings_version=3
    vfx.reset_shimmer(shimmer_state) vfx.reset_expiration(expiry_state) vfx.reset_impact(impact_state)
    test.expire,test.impact=false,false last_protect_active=false
    config.save(settings) say('All settings restored to defaults.')
end
for name in pairs(ranges) do handlers[name]=function(value) set_number(name,value) end end
local function lifecycle(command)
    say(command=='restart' and 'Restarting.' or 'Unloading.')
    vfx.reset_shimmer(shimmer_state) vfx.reset_expiration(expiry_state) vfx.reset_impact(impact_state)
    last_protect_active=false
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
local function incoming_action(id,data)
    if id~=0x028 or not settings.enabled or not settings.protect_impact then return end
    local ok,packet=pcall(packets.parse,'incoming',data)
    if not ok or type(packet)~='table' then return end
    local category=tonumber(packet.Category)
    -- Restrict the first classifier to completed melee and ranged actions.
    -- Weapon skills, TP moves, magic, hybrid abilities and status effects wait.
    if category~=1 and category~=2 then return end
    local player=windower.ffxi.get_player()
    if not player or not model.has(player.buffs,model.BUFF.protect) then return end
    local me=windower.ffxi.get_mob_by_target('me')
    if not me or not me.id or me.id==0 then return end

    local total=0
    local target_count=tonumber(packet['Target Count']) or 0
    for target_index=1,math.min(target_count,8) do
        local target_key='Target '..target_index
        if tonumber(packet[target_key..' ID'])==me.id then
            local action_count=tonumber(packet[target_key..' Action Count']) or 0
            for action_index=1,math.min(action_count,16) do
                local action_key=target_key..' Action '..action_index
                local message=tonumber(packet[action_key..' Message'])
                local damage=tonumber(packet[action_key..' Param'])
                -- Windower's Actions helper identifies Message 1 / Param as
                -- landed damage for completed melee actions.
                if message==1 and damage and damage>0 then total=total+damage end
            end
        end
    end
    if total>0 then
        local intensity=vfx.damage_to_intensity(total)
        if intensity then vfx.trigger_impact(impact_state,intensity,os.clock()) end
    end
end
windower.register_event('incoming chunk',incoming_action)
windower.register_event('load',function()
    if settings.enabled then start_renderer() end
    if upgraded then say('Test3: Protect, Shell and HP rings are now off by default (//wards protect on, shell on, hp on).') end
end)
windower.register_event('zone change','logout',function()
    fades.protect.alpha,fades.shell.alpha,fades.hp.alpha=0,0,0 model.hp_reset(hp_state) dbf.reset(dbf_state)
    vfx.reset_shimmer(shimmer_state) vfx.reset_expiration(expiry_state) vfx.reset_impact(impact_state)
    last_protect_active=false clear()
end)
windower.register_event('unload',function()
    vfx.reset_shimmer(shimmer_state) vfx.reset_expiration(expiry_state) vfx.reset_impact(impact_state)
    clear() if native then native.stop() end
end)
