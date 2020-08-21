Width=1250
Height=950

function love.conf(t)
    local love = love or {}
    --设置标题和窗口大小
    t.title = "Overcooked"
    t.console = true
    t.window.width =Width
    t.window.height =Height

--[[    t
                identity = false
                version = 11.3
                accelerometerjoystick = true
                modules = table: 0x1dd8e1d0
                gammacorrect = false
                title = my first love
                externalstorage = false
                appendidentity = false
                console = false
                window = table: 0x1dd8e1a8
                audio = table: 0x1dd9bb70
]]

--[[    t.modules
                font = true
                mouse = true
                image = true
                system = true
                audio = true
                touch = true
                joystick = true
                keyboard = true
                timer = true
                graphics = true
                window = true
                math = true
                data = true
                event = true
                sound = true
                thread = true
                video = true
                physics = true
]]

--[[    t.window
                width = 800
                fullscreen = false
                resizable = false
                usedpiscale = true
                fullscreentype = desktop
                highdpi = false
                vsync = 1
                height = 600
                minwidth = 1
                centered = true
                minheight = 1
                borderless = false
                display = 1
                msaa = 0
]]

--[[    t.audio
                mic = false
                mixwithsystem = true
]]
end