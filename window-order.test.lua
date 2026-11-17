local sourceFile=assert(io.open('lib/window.lua'))
local source=sourceFile:read('*a'); sourceFile:close()
source=source:gsub("('[^'\r\n]*'):format",'(%1):format')

local activated,messages,warnings,sent,sleeps={},{},{},{},{}
local saved=0
local env=setmetatable({
    shared_settings={windows={binds={
        ['1']={names='One Backup'}, ['2']={names='Two'}, ['3']={names='Missing Three'},
    }}},
    hotkeys_native={activate_window=function(name,process)
        assert(process=='pol.exe'); activated[#activated+1]=name
        return name=='One' or name=='Two'
    end},
    windower={send_command=function(command) sent[#sent+1]=command end},
    coroutine={sleep=function(value) sleeps[#sleeps+1]=value end},
    writeMessage=function(value) messages[#messages+1]=value end,
    writeWarning=function(value) warnings[#warnings+1]=value end,
    saveSettings=function() saved=saved+1 end,
    text_number=tostring, text_player=tostring, text_warning=tostring,
    text_yellow=tostring, text_green=tostring,
},{__index=_G})

local chunk=assert(loadstring(source)); setfenv(chunk,env); chunk()
env.command_window('order',{'set','2','1','3'})
assert(saved==1 and table.concat(env.shared_settings.windows.order,',')=='2,1,3')
assert(sent[1]=='send @others hk reload')

sent={}
env.command_window('order',{'activate'})
assert(table.concat(activated,',')=='Two')
assert(sent[1]=='send Two hk window order continue 1 3')
env.command_window('order',{'continue','1','3'})
assert(table.concat(activated,',')=='Two,One')
assert(sent[2]=='send One hk window order continue 3')
env.command_window('order',{'continue','3'})
assert(table.concat(activated,',')=='Two,One,Missing,Three')
assert(#sleeps==2 and sleeps[1]==0.1 and sleeps[2]==0.1)
assert(#warnings==1 and warnings[1]:find('slot #3',1,true))

activated={}; sent={}; env.hotkeys_native.activate_window=function(name) activated[#activated+1]=name; return true end
env.command_window('order',{'activate','1','2'})
assert(table.concat(activated,',')=='One' and sent[1]=='send One hk window order continue 2')
env.command_window('order',{'continue','2'})
assert(table.concat(activated,',')=='One,Two')

local before=env.shared_settings.windows.order
env.command_window('order',{'set','1','1'})
assert(env.shared_settings.windows.order==before and #warnings==2)

env.command_window('order',{'clear'})
assert(env.shared_settings.windows.order==nil and saved==2)
print('PASS: saved and one-off window activation ordering')
