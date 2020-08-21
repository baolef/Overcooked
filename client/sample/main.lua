local love = love or {}
local thread
local sendChanName = 'send'
local receiveChanName = 'receive'
local myhandler = require("handler")
-- http://127.0.0.1:8000/ for debug
local lovebird = require("admin.lovebird")

require("admin.class")
require("admin.timewheel")

local Timer

NewImg = love.graphics.newImage
Draw = love.graphics.draw
Pri=love.graphics.print
Rect=love.graphics.rectangle

Music={
    background=love.audio.newSource("res/music/background.mp3","stream"),
    pick=love.audio.newSource("res/music/pick.mp3","static"),
    succ=love.audio.newSource("res/music/succ.mp3","static"),
    fail=love.audio.newSource("res/music/fail.mp3","static")
}

function Music.play_background()
    love.audio.play(Music.background)
end

function Music.play_pick()
    love.audio.play(Music.pick)
end

function Music.play_succ()
    love.audio.play(Music.succ)
end

function Music.play_fail()
    love.audio.play(music.fail)
end


G_dir = {
    up = 0,
    right=1,
    down=2,
    left=3
}

local function initSocket()
    thread = love.thread.newThread("socket.lua")
    local sendChan = love.thread.getChannel(sendChanName)
    local recvChan = love.thread.getChannel(receiveChanName)
    myhandler.init(recvChan, sendChan)

    local _count = 0
    local tooth, idx = Timer:NewTicker(1000, function ()
        print("Ticker: 1000 ms", os.clock()*1000)
        _count = _count + 1
        return _count < 10
    end)
    
    Timer:After(3000, function (dt)
        print("After: 3000 ms", os.clock()*1000)
        tooth:Cancel()
    end)

end

function love.load() --资源加载回调函数，仅初始化时调用一次
    love.graphics.setNewFont(50)
    love.audio.setVolume(1)
    Timer = CreateTimeWheel(100)
    initSocket()
    thread:start(sendChanName, receiveChanName, "127.0.0.1", 9090)
end

function love.draw() --绘图回调函数，每周期调用
    love.graphics.setBackgroundColor(128/255,53/255,38/255)
    love.graphics.print("FPS: " ..tostring(love.timer.getFPS()), 10, 10)
    myhandler.draw()
end

function love.update(dt) --更新回调函数，每周期调用
    lovebird.update()
    TimerUpdate(math.ceil(dt*1000))
    myhandler.update(dt)
end

--键盘检测回调函数，当键盘事件触发是调用
function love.keypressed(k)
    if k=='escape' then
        love.event.quit()
    else
        myhandler.on_keypressed(k)
    end
end

function love.keyreleased(k)
    if k=='escape' then
        love.event.quit()
    else
        myhandler.on_keyreleased(k)
    end
end

--function love.mousepressed(x, y, button)
--    myhandler.on_mousepressed(x, y, button)
--end
