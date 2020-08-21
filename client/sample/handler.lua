MaxX = 19
MaxY = 19
Step=50

local _M = {}
local jscodec = require("cjson")
jscodec.encode_sparse_array(true)

local sendChan_
local recvChan_
function _M.init(recvChan, sendChan)
    recvChan_ = recvChan
    sendChan_ = sendChan

    _M.status=1 --0 for starting, 1 for wait to start, 2 for playing
    _M.idx=nil
    _M.moving=false

    _M.dir = {}
    _M.Dir=G_dir
    _M.dir["up"] = _M.Dir.up
    _M.dir["down"] = _M.Dir.down
    _M.dir["left"] = _M.Dir.left
    _M.dir["right"] = _M.Dir.right

    _M.cur_dir = _M.Dir.left

    _M.material={}
    _M.material[1]=NewImg("res/material/1.png")
    _M.material[2]=NewImg("res/material/2.png")
    _M.material[3]=NewImg("res/material/3.png")

    _M.cut={}
    _M.cut[1]=NewImg("res/cut/1.png")
    _M.cut[2]=NewImg("res/cut/2.png")
    _M.cut[3]=NewImg("res/cut/3.png")

    _M.dish={}
    _M.dish[4]=NewImg("res/dish/0.png")
    _M.dish[5]=NewImg("res/dish/1.png")
    _M.dish[6]=NewImg("res/dish/2.png")
    _M.dish[7]=NewImg("res/dish/3.png")

    _M.players={}
    _M.players[0]=NewImg("res/players/0.png")
    _M.players[1]=NewImg("res/players/1.png")
    _M.players[2]=NewImg("res/players/2.png")
    _M.players[3]=NewImg("res/players/3.png")

    _M.map={}
    _M.map[0]=NewImg("res/map/0.png")
    _M.map[1]=NewImg("res/map/1.png")
    _M.map[2]=NewImg("res/map/2.png")
    _M.map[3]=NewImg("res/map/3.png")
    --_M.map[4]=NewImg("res/map/4.png")
    _M.map[5]=NewImg("res/map/5.png")
    _M.map[6]=NewImg("res/map/6.png")
    _M.map[7]=NewImg("res/map/7.png")
    _M.map[8]=NewImg("res/map/8.png")
    _M.map[9]=NewImg("res/map/9.png")
    _M.map[10]=NewImg("res/map/10.png")

    _M.mission={}
    _M.mission[5]=NewImg("res/mission/1.png")
    _M.mission[6]=NewImg("res/mission/2.png")
    _M.mission[7]=NewImg("res/mission/3.png")

    _M.background=NewImg("res/background.png")

    _M.m_material={}
    _M.m_cut={}
    _M.m_dish={}
    _M.m_map={}
    _M.m_players={}
    _M.m_mission={}

    _M.time_cook_1=-1
    _M.time_cook_2=-1
    _M.pot_1={}
    _M.pot_2={}
    _M.dish_1=0
    _M.dish_2=0
    _M.score=0
    _M.m_time=-1

    Music.play_background()

end

function _M.update(dt)
    local str = recvChan_:pop()
    if str then
        print("receive:", str) -- 只是回显接收到的封包
        local res = jscodec.decode(str)
        if res.cmd then
            local index = "CMD_" .. res.cmd
            local func = _M[index]
            if func then
                func(res.params)
            else
                print(res.cmd .. " not implemented")
            end
            return
        end
    end
end

function _M.get_location(index)
    local x=((index-1)%MaxX)*Step
    local y=(MaxY-math.ceil(index/MaxX))*Step
    return x,y
end

function _M.draw()
    if _M.status~=2 then
        _M.draw_background()
    elseif _M.status==2 then
        _M.draw_map()
        _M.draw_material()
        _M.draw_cut()
        _M.draw_dish()
        _M.draw_players()
        _M.get_time()
        _M.draw_mission()
        _M.draw_score()
        _M.draw_cook_time()
        _M.draw_cook_item()
    end
end

function _M.draw_background()
    Draw(_M.background,0,0)
end

function _M.draw_map()
    local x,y=0
    for k,v in pairs(_M.m_map) do
        x,y=_M.get_location(k)
        Draw(_M.map[v],x,y)
    end
end

function _M.draw_material()
    local x,y=0
    for k,v in pairs(_M.m_material) do
        x,y=_M.get_location(k)
        Draw(_M.material[v],x,y)
    end
end

function _M.draw_cut()
    local x,y=0
    for k,v in pairs(_M.m_cut) do
        x,y=_M.get_location(k)
        Draw(_M.cut[v],x,y)
    end
end

function _M.draw_dish()
    local x,y=0
    for k,v in pairs(_M.m_dish) do
        x,y=_M.get_location(k)
        Draw(_M.dish[v],x,y)
    end
end

function _M.draw_players()
    local x,y=0
    for _,player in pairs(_M.m_players) do
        x,y=_M.get_location(player.index)
        Draw(_M.players[player.dir],x,y)
        if player.dir~=G_dir.up then
            if player.dir==G_dir.right then
                x=x+30
                y=y+15
            elseif player.dir==G_dir.down then
                x=x+15
                y=y+30
            elseif player.dir==G_dir.left then
                x=x-5
                y=y+15
            end
            if player.hand_material~=0 then
                Draw(_M.material[player.hand_material],x,y,0,0.5,0.5)
            elseif player.hand_cut~=0 then
                Draw(_M.cut[player.hand_cut],x,y,0,0.5,0.5)
            elseif player.hand_dish~=0 then
                Draw(_M.dish[player.hand_dish],x,y,0,0.5,0.5)
            end
        end
    end
end

function _M.draw_mission()
    local x=1000
    local y=25
    for _,mission in pairs(_M.m_mission) do
        Draw(_M.mission[mission],x,y)
        y=y+200
    end
end

function _M.draw_score()
    Pri("Score: ".._M.score,970,700)
end

function _M.draw_cook_time()
    if _M.time_cook_1>0 then        local x,y=_M.get_location(96)
        _M.draw_bar(1-_M.time_cook_1/10,x,y-10)
    end
    if _M.time_cook_2>0 then
        local x,y=_M.get_location(114)
        _M.draw_bar(1-_M.time_cook_2/10,x,y-10)
    end
end

function _M.draw_cook_item()
    if #_M.pot_1>0 then
        local x,y=_M.get_location(96)
        x=x+10
        y=y+20
        for k,v in pairs(_M.pot_1) do
            Draw(_M.cut[v],x,y,0,0.3,0.3)
            x=x+10
        end
    end
    if #_M.pot_2>0 then
        local x,y=_M.get_location(114)
        x=x+10
        y=y+20
        for k,v in pairs(_M.pot_2) do
            Draw(_M.cut[v],x,y,0,0.3,0.3)
            x=x+10
        end
    end
end

function _M.start()
    print("_M.start()")
    _M.status=0
    local req={cmd="start",params={}}
    sendChan_:push(jscodec.encode(req))
end

--function _

function _M.move(dir)
    print("_M.move(dir)")
    local req = {cmd = "move", params = dir}
    sendChan_:push(jscodec.encode(req))
end

function _M.stop_move(dir)
    print("_M.stop_move(dir)")
    local req = {cmd = "stop_move", params = dir}
    sendChan_:push(jscodec.encode(req))
end

function _M.pick()
    print("_M.pick")
    local req = {cmd = "pick", params = {}}
    sendChan_:push(jscodec.encode(req))
end

function _M.operate()
    print("_M.operate")
    local req = {cmd = "operate", params = {}}
    sendChan_:push(jscodec.encode(req))
end

function _M.on_keypressed(key)
    --local req = {
    --    keypress = key
    --}
    --sendChan_:push(jscodec.encode(req))
    --print("_M.on_keypressed(key)")
    if _M.status==1 then
        _M.start()
    elseif _M.status==2 and _M.m_time<0 then
        if key == "up" or key == "down" or key == "left" or key == "right" then
            _M.cur_dir=_M.dir[key]
            _M.move(_M.cur_dir)
        elseif key=="space" then
            _M.pick()
        elseif key=="lalt" then
            _M.operate()
        end
    end
end

function _M.allow_move()
    if _M.idx then
        return _M.m_time<0
    else return true
    end
end

function _M.on_keyreleased(key)
    print("_M.on_keyreleased(key)")
    if _M.status==2 then
        if key == "up" or key == "down" or key == "left" or key == "right" then
            _M.stop_move(_M.dir[key])
        end
    end
end

function _M.on_mousepressed(x, y, button)
    local req = {
        button = button, -- 1: left key,    2:right key,    3: center key
        x = x,
        y = y
    }
    sendChan_:push(jscodec.encode(req))
end

function _M.CMD_appear(params)
    print("_M.CMD_appear(params)")
end

function _M.CMD_refresh(params)
    print("_M.CMD_refresh(params)")
    _M.m_material=params.items.material
    _M.m_map=params.items.map
    _M.m_cut=params.items.cut
    _M.m_dish=params.items.dish
    _M.m_players=params.players
    _M.get_time()

    _M.score=params.items.score
    _M.m_mission=params.items.mission
    _M.time_cook_1=params.items.time_cook_1
    _M.time_cook_2=params.items.time_cook_2
    _M.pot_1=params.items.pot_1
    _M.pot_2=params.items.pot_2
    _M.dish_1=params.items.dish_1
    _M.dish_2=params.items.dish_2



    --_M.draw()
end

function _M.get_time()
    for _,player in pairs(_M.m_players) do
        if player.idx==_M.idx then
            _M.m_time=player.time
        end
        if player.time>=0 then
            local x,y=_M.get_location(player.index)
            _M.draw_bar(1-player.time/5,x,y-10)
        end
    end

end

function _M.draw_bar (per, x,y)
    Rect("line",x,y,50,10)
    Rect("fill",x+2,y+2,per*(50-4),6)
end


--function _M.draw_players(players)
--    local img= nil
--    for _,player in players do
--        if not player.hand then
--            if player.hand== then
--                img=NewImg("")
--            end
--        else
--            img=NewImg("")
--        end
--        Draw(img,(player.x-1)*Size_x,(player.y-1)*Size_y, math.pi*player.dir)
--    end
--end

function _M.CMD_start(params)
    print("_M.CMD_start(params)")
    if _M.status==0 then
        _M.status = 2
        _M.idx=params.idx
        print("start",_M.idx)
    end
end

function _M.CMD_pick(params)
    Music.play_pick()
end

function _M.CMD_fail(params)
    Music.play_fail()
end

function _M.CMD_succ(params)
    Music.play_succ()
end

return _M