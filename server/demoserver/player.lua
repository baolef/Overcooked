local DIR = Scene.Dir
local MAX_IDLE = 15 --second
local Decode = JScodec.decode
local Encode = JScodec.encode
local public_scene = Scene.new()

Player = Class()

local function __handler(self, pkg)
    local req = Decode(pkg)
    if req.cmd then
        -- 带命令的协议，执行相关的过程
        local cmd = "CMD_" .. req.cmd
        local func = self[cmd]
        if func then
            func(self, req.params)      -- 消息分发执行
        else
            Print(req.cmd .. " not implemented")
        end
        return
    end
    Print("receive:", self.m_idx, pkg) -- 只是回显接收到的封包
end

function Player:ctor(session, ip, port, idx)
    self.m_idx = idx
    self.m_session = session
    self.m_ipaddress = ip
    self.m_port = port
    self.m_curr_dir = DIR.up
    self.m_last_tick = os.clock()
    self.m_message = CreateChannel(__handler, self)
    self.hand_material = 0
    self.hand_cut = 0
    self.hand_dish = 0
    self.time = -1

    self.thing = { null = 0, dish = 5, vegetable1 = 2, vegetable2 = 3, meat = 4 }

end

function Player:dtor()
    Print(self.m_idx, "destroy")
end

function Player:init()

    local cell = public_scene:cell()
    if cell and public_scene:enter(self, cell) then
        self.m_cell = cell
        -- 广播出现
        self:refresh()
    end
end

function Player:get_idx()
    return self.m_idx
end

function Player:get_feature()
    local players = {}
    for k, v in pairs(vector_) do
        local element = {
            idx = v:get_idx(),
            x = v:curr_x(),
            y = v:curr_y(),
            index = public_scene:index(v:curr_x(), v:curr_y()),
            dir = v:curr_dir(),
            hand_material = v.hand_material,
            hand_cut = v.hand_cut,
            hand_dish = v.hand_dish,
            time = v.time
        }
        table.insert(players, element)
    end
    return players
end

function Player:remote_address()
    return self.m_ipaddress .. ":" .. tostring(self.m_port)
end

function Player:close()
    if self.m_cell then
        local info = {
            cmd = "disappear",
            info = self:get_feature(),
        }
        PlayerManager.broadcast(Encode(info))
        public_scene:leave(self, self.m_cell) -- 从地图中删除
        self.m_cell = nil
    end
end

-- 收到Ping, 在线
function Player:online()
    self.m_last_tick = os.clock()
end
-- 心跳超时
function Player:idle_timeout(nowtick)
    return nowtick - self.m_last_tick > MAX_IDLE
end
-- 发送方法
function Player:send(data)
    Print("send", data)
    self.m_session:send(self.m_ipaddress, self.m_port, data)
end

function Player:receive(msg)
    self.m_message:Push(msg)
end

function Player:enter(map, x, y)
    if not map then
        self:place(nil)
    end
    self.m_map = map
end

-- 当前的坐标x
function Player:curr_x()
    local cell = self.m_cell
    if cell then
        return cell.m_x
    end
    return false
end
-- 当前的坐标y
function Player:curr_y()
    local cell = self.m_cell
    if cell then
        return cell.m_y
    end
    return false
end

-- 当前的朝向
function Player.curr_dir(self)
    local cell = self.m_cell
    if cell then
        return self.m_curr_dir -- 在地图中才有方向
    end
    return false
end

function Player:net_package()
    local info = {
        cmd = "get_player_info",
        params = self.m_database,
    }
    return JScodec.encode(info)
end

function Player:CMD_start(params)
    Print("Player:CMD_start(params)")

    local res = {
        cmd = "start",
        params = { idx = self.m_idx }
    }

    self:send(Encode(res))
end

function Player:move(params)
    print("Player:move(params)")
    local x = self.m_cell.m_x
    local y = self.m_cell.m_y
    self.m_curr_dir = params
    local dir = params

    if dir == Scene.Dir.up then
        y = y + 1
    elseif dir == Scene.Dir.right then
        x = x + 1
    elseif dir == Scene.Dir.down then
        y = y - 1
    elseif dir == Scene.Dir.left then
        x = x - 1
    end

    local new_index = public_scene:index(x, y)

    --无障碍
    local cell = public_scene.m_map[new_index]
    if cell == 0 then
        print(x, y)
        self.m_cell.m_x = x
        self.m_cell.m_y = y
    end
    self:refresh()
end

function Player:refresh()
    print("Player:refresh()")
    local info = {
        cmd = "refresh",
        params = {
            items = public_scene:get_item(),
            players = self:get_feature()
        }
    }
    PlayerManager.broadcast(Encode(info))
end

function Player:send_player()
    local info = {
        cmd = "person",
        params = self:get_feature(),
    }
    PlayerManager.broadcast(Encode(info)) -- 第一个出现的对象是自己

end

function Player:CMD_move(params)
    Print("Player:CMD_move(params)")
    self:move(params)
    self.m_move_timer = CTimer.new(200, 200, function(dt_ms)
        self:move(params)
        return true
    end)
end

function Player:CMD_stop_move(params)
    Print("Player:CMD_stop_move()")
    self.m_move_timer:stop()
end

function Player:CMD_operate(params)
    print("CMD_operate(params)")
    local before = self:cell_before()
    local value = public_scene.m_map[before]
    if value > 4 and value < 7 then
        if value == 5 then
            if public_scene.m_material[before] then
                self:cut(before)
            end
        elseif value == 6 then
            local num = 0
            if before == 96 then
                num = 1
            elseif before == 114 then
                num = 2
            end
            self:cook(num)
        end
        self:refresh()
        local res = {
            cmd = "pick",
            params = { idx = self.m_idx }
        }

        self:send(Encode(res))
    end
end

function Player:deliver()
    if self.hand_dish then
        if is_include(self.hand_dish, public_scene.mission) then
            public_scene.score = public_scene.score + 10
            print(#public_scene.mission)
            public_scene:add_mission()
            local res = {
                cmd = "succ",
                params = { idx = self.m_idx }
            }

            self:send(Encode(res))
        else
            local res = {
                cmd = "fail",
                params = { idx = self.m_idx }
            }

            self:send(Encode(res))
        end
        self.hand_dish = 0
    end
end

function is_include(val, tab)
    for k, v in ipairs(tab) do
        if v == val then
            table.remove(tab,k)
            return true
        end
    end
    return false
end

function Player:cut(before)
    print("Player:cut(before)")
    self.time = 4
    self.m_cut_timer = CTimer.new(1000, 0, function(dt_ms)
        self.time = self.time - 1
        if self.time < 0 then
            public_scene.m_cut[before] = public_scene.m_material[before]
            public_scene.m_material[before] = nil
        end
        self:refresh()
        return self.time >= 0
    end)
end

function Player:cook(num)
    if num == 1 and #public_scene.pot_1==3 then
        public_scene.time_cook_1 = 10
        public_scene.cook_timer_1 = CTimer.new(1000, 0, function(dt_ms)
            public_scene.time_cook_1 = public_scene.time_cook_1 - 1
            if public_scene.time_cook_1 < 0 then
                if public_scene.pot_1[1] == public_scene.pot_1[2] and public_scene.pot_1[1] == public_scene.pot_1[3] then
                    public_scene.dish_1 = public_scene.pot_1[1] + 4
                else
                    public_scene.dish_1 = 4
                end
            end
            self:refresh()
            return public_scene.time_cook_1 >= 0
        end)
    elseif num == 2 and #public_scene.pot_2==3 then
        public_scene.time_cook_2 = 10
        public_scene.cook_timer_2 = CTimer.new(1000, 0, function(dt_ms)
            public_scene.time_cook_2 = public_scene.time_cook_2 - 1
            if public_scene.time_cook_2 < 0 then
                if public_scene.pot_2[1] == public_scene.pot_2[2] and public_scene.pot_2[1] == public_scene.pot_2[3] then
                    public_scene.dish_2 = public_scene.pot_2[1] + 4
                else
                    public_scene.dish_4 = 4
                end
            end
            self:refresh()
            return public_scene.time_cook_2 >= 0
        end)
    end
end

function Player:empty_hand()
    return self.hand_material == 0 and self.hand_cut == 0 and self.hand_dish == 0
end



function Player:CMD_pick()
    print("Player:CMD_pick")

    --面朝的格子
    local before = self:cell_before()

    --{ null = 0 , meat = 1, vegetable1 = 2, vegetable2 = 3, wrong_dish=4 , dish1 =5 , dish2 =6 , dish3 =7)


    --空手取未加工食材
    if self.hand_material == 0 and self.hand_cut == 0 and self.hand_dish == 0 then
        --空手与特定地点交互
        print(before,public_scene:index(5, 1),public_scene:index(15, 1))
        if before == public_scene:index(5, 1) or before == public_scene:index(15, 1) then
            --拿起食材，意味着人物所在的格子上出现了食材,所以存入的坐标是index
            self.hand_material = 1
            local res = {
                cmd = "pick",
                params = { idx = self.m_idx }
            }

            self:send(Encode(res))

        elseif before == public_scene:index(3, 1) then

            self.hand_material = 2
            local res = {
                cmd = "pick",
                params = { idx = self.m_idx }
            }

            self:send(Encode(res))

        elseif before == public_scene:index(17, 1) then

            self.hand_material = 3
            local res = {
                cmd = "pick",
                params = { idx = self.m_idx }
            }

            self:send(Encode(res))

        elseif before==public_scene:index(1,6) then
            self.hand_dish=self:pick_from_pot(1)
            local res = {
                cmd = "pick",
                params = { idx = self.m_idx }
            }

            self:send(Encode(res))

        elseif before==public_scene:index(19,6) then
            self.hand_dish=self:pick_from_pot(2)
            local res = {
                cmd = "pick",
                params = { idx = self.m_idx }
            }

            self:send(Encode(res))
        end


        --空手捡起物品
        if public_scene.m_material[before] ~= nil then

            self.hand_material = public_scene.m_material[before]
            public_scene.m_material[before]=nil
            local res = {
                cmd = "pick",
                params = { idx = self.m_idx }
            }

            self:send(Encode(res))

        elseif public_scene.m_cut[before] ~= nil then

            self.hand_cut = public_scene.m_cut[before]
            public_scene.m_cut[before]=nil
            local res = {
                cmd = "pick",
                params = { idx = self.m_idx }
            }

            self:send(Encode(res))

        elseif public_scene.m_dish[before] ~= nil then

            self.hand_dish = public_scene.m_dish[before]
            public_scene.m_dish[before]=nil
            local res = {
                cmd = "pick",
                params = { idx = self.m_idx }
            }

            self:send(Encode(res))

        end




        --手中有物品
    else

        --非交互地点
        if before ~= public_scene:index(1, 6) and before ~= public_scene:index(3, 1) and public_scene:index(5, 1) and before ~= public_scene:index(10, 1)
                and before ~= public_scene:index(15, 1) and before ~= public_scene:index(17, 1)
                and before ~= public_scene:index(19, 6) and before ~= public_scene:index(10, 19) then

            if self.hand_material ~= 0 then

                print(self.hand_material)
                --table.insert(public_scene.m_material, before, self.hand_material)
                public_scene.m_material[before]=self.hand_material
                self.hand_material = 0
                local res = {
                    cmd = "pick",
                    params = { idx = self.m_idx }
                }

                self:send(Encode(res))

            elseif self.hand_cut ~= 0 then

                --table.insert(public_scene.m_cut, before, self.hand_cut)
                public_scene.m_cut[before]=self.hand_cut
                self.hand_cut = 0
                local res = {
                    cmd = "pick",
                    params = { idx = self.m_idx }
                }

                self:send(Encode(res))

            else

                --table.insert(public_scene.m_dish, before, self.hand_dish)
                public_scene.m_dish[before]=self.hand_dish
                self.hand_dish = 0
                local res = {
                    cmd = "pick",
                    params = { idx = self.m_idx }
                }

                self:send(Encode(res))
            end


            --身处可交互的地点
        else

            --手中是切好的食材
            if self.hand_cut ~= 0 then

                if before == public_scene:index(1, 6) then
                    if self:put_in_pot(1, self.hand_cut) then
                        self.hand_cut = 0
                        local res = {
                            cmd = "pick",
                            params = { idx = self.m_idx }
                        }

                        self:send(Encode(res))
                    end


                elseif before == public_scene:index(19, 6) then
                    if self:put_in_pot(2, self.hand_cut) then
                        self.hand_cut = 0
                        local res = {
                            cmd = "pick",
                            params = { idx = self.m_idx }
                        }

                        self:send(Encode(res))
                    end
                end



                --菜板
            elseif self.hand_material ~= 0 then

                if before == public_scene:index(10, 1) then

                    --table.insert(public_scene.m_material, before, self.hand_material)
                    public_scene.m_material[before]=self.hand_material
                    self.hand_material = 0
                    local res = {
                        cmd = "pick",
                        params = { idx = self.m_idx }
                    }

                    self:send(Encode(res))
                end


            elseif self.hand_dish ~= 0 and before == public_scene:index(10, 19) then
                self:deliver()
            end

        end


    end

    self:refresh()

end

function Player:put_in_pot(num, food)
    if num == 1 then
        if #public_scene.pot_1 < 3 then
            table.insert(public_scene.pot_1, food)
            return true
        else
            return false
        end
    elseif num == 2 then
        if #public_scene.pot_2 < 3 then
            table.insert(public_scene.pot_2, food)
            return true
        else
            return false
        end
    else
        return false
    end
end

function Player:pick_from_pot(num)
    if num == 1  then
        if public_scene.time_cook_1 < 0 and public_scene.dish_1~=0 then
            local temp = public_scene.dish_1
            public_scene.pot_1 = {}
            public_scene.dish_1 = 0
            return temp
        end
    elseif num == 2 then
        if public_scene.time_cook_2 < 0 and public_scene.dish_2~=0  then
            local temp = public_scene.dish_2
            public_scene.pot_2 = {}
            public_scene.dish_2 = 0
            return temp
        end
    end
    return 0
end


--面前的格子
function Player:cell_before()

    local x = self:curr_x()
    local y = self:curr_y()
    local dir = self:curr_dir()

    if dir == Scene.Dir.up then
        y = y + 1
    elseif dir == Scene.Dir.right then
        x = x + 1
    elseif dir == Scene.Dir.down then
        y = y - 1
    else
        x = x - 1
    end

    local new_idx = public_scene:index(x, y)
    return new_idx

end
