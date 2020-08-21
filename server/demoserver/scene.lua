MaxX = 19
MaxY = 19

Feat = Class()
--无，障碍，蔬菜1、2，肉
Feat.origin = { null = 0,    vegetable1=2 , vegetable2 = 3 ,meat = 1,  knife = 5, pot = 6 , out = 7 ,obstacle1=8 ,obstacle2=9 ,obstacle3=10}

function Feat:ctor(obj)
    self.m_idx = obj or Feat.origin.null
end

function Feat:get_idx()
    return self.m_idx
end


Cell = Class()
function Cell:ctor(x, y)
    self.m_x = x
    self.m_y = y
    self.m_vector = {}
    self.m_count = 0
end

function Cell:add(obj)
    local idx = obj:get_idx()
    if not self.m_vector[idx] then
        self.m_vector[idx] = obj
        self.m_count = self.m_count + 1
        return idx
    else
        Print(idx, "duplicated")
    end
    return nil
end

function Cell:del(obj)
    local idx = obj:get_idx()
    if self.m_vector[idx] then
        self.m_vector[idx] = nil
        self.m_count = self.m_count - 1
        return idx
    else
        Print(idx, "not found")
    end
    return nil
end


Scene = Class()

-- 类的静态变量
-- 默认方向
Scene.Dir = {
    up = 0,
    right=1,
    down=2,
    left=3
}

function Scene:ctor(mx, my)
    self.m_max_x = mx or MaxX
    self.m_max_y = my or MaxY
    self.m_matrix = {}          -- 2D的格子数组
    self.m_map = {}
    self.m_players = {}

    self.m_material = {}
    self.m_cut = {}
    self.m_dish = {}

    self.time_cook_1=-1
    self.time_cook_2=-1
    self.pot_1={}
    self.pot_2={}
    self.dish_1=0
    self.dish_2=0

    self.score=0
    self.mission={}

    self:init_matrix()
    self:init_map()
    self:add_mission()
    --self:map_print()
end

function Scene:map_print()
    print(self.m_map[1],self.m_map[2],self.m_map[3])
end

function Scene:pairs()
    return pairs(self.m_players)
end

-- 根据x,y返回所在的单元格
function Scene:cell(x, y)
    if not x or not y then
        x = math.random(8, 12)
        y = math.random(14, 18)
    else
        if x < 1 or x > self.m_max_x then
            return nil
        end
        if y < 1 or y > self.m_max_y then
            return nil
        end
    end

    local index = x + self.m_max_x * (y - 1) -- 下标从1开始

    local cell = self.m_matrix[index]
    if not cell then
        cell = Cell.new(x, y)
        self.m_matrix[index] = cell
    end
    return cell
end

function Scene:enter(player, cell)
    local idx = cell:add(player)
    if idx then
        self.m_players[idx] = player
        return true
    end
    return false
end

function Scene:leave(player, cell)
    local idx = cell:del(player)
    if idx then
        self.m_players[idx] = nil
        return true
    end
    return false
end

--固定的初始地图
function Scene:init_matrix()

    local core1 = self:cell(1,3)
    local item1 = Feat.new(Feat.origin.vegetable1)
    core1:add(item1)

    local core2 = self:cell(1,5)
    local item2 = Feat.new(Feat.origin.meat)
    core2:add(item2)

    local core3 = self:cell(1,9)
    local item3 = Feat.new(Feat.origin.knife)
    core3:add(item3)

    local core4 = self:cell(1,11)
    local item4 = Feat.new(Feat.origin.knife)
    core4:add(item4)

    local core5 = self:cell(1,15)
    local item5 = Feat.new(Feat.origin.meat)
    core5:add(item5)

    local core6 = self:cell(1,17)
    local item6 = Feat.new(Feat.origin.vegetable2)
    core6:add(item6)

    for j=1 , self.m_max_y do

        if j ~= 6 then
            local cell = self:cell(1,j)
            local item = Feat.new(Feat.origin.obstacle)
            cell:add(item)
        else
            local cell = self:cell(1,j)
            local item = Feat.new(Feat.origin.pot)
            cell:add(item)
        end

    end

    for j=1 , self.m_max_y do

        if j ~= 6 then
            local cell = self:cell(19,j)
            local item = Feat.new(Feat.origin.obstacle)
            cell:add(item)
        else
            local cell = self:cell(19,j)
            local item = Feat.new(Feat.origin.pot)
            cell:add(item)
        end

    end

    for i=1 , self.m_max_x do

        if i ~= 10 then
            local cell = self:cell(i,19)
            local item = Feat.new(Feat.origin.obstacle)
            cell:add(item)
        else
            local cell = self:cell(i,19)
            local item = Feat.new(Feat.origin.out)
            cell:add(item)
        end

    end

    for j=1 , 13 do

        local cell = self:cell(7,j)
        local item = Feat.new(Feat.origin.obstacle)
        cell:add(item)

    end

    for j=1 , 13 do

        local cell = self:cell(13,j)
        local item = Feat.new(Feat.origin.obstacle)
        cell:add(item)

    end

    for i = 2, self.m_max_x do
        for j = 2, self.m_max_y do
            --创建格子
            local cell = self:cell(i, j)
            if cell.m_count == 0 then
                local item = Feat.new(Feat.origin.null)
                --为格子添加上方物品
                cell:add(item)
            end
        end
    end

    return self.m_matrix

end

function Scene:index(i, j)
    local index = i + self.m_max_x * (j - 1) -- 下标从1开始
    return index
end

function Scene:get_item()
    return {
        map=self.m_map,
        material=self.m_material,
        cut=self.m_cut,
        dish=self.m_dish,
        time_cook_1=self.time_cook_1,
        time_cook_2=self.time_cook_2,
        pot_1=self.pot_1,
        pot_2=self.pot_2,
        dish_1=self.dish_1,
        dish_2=self.dish_2,
        score=self.score,
        mission=self.mission
    }

end

function Scene:add_mission()
    print(#self.mission)
    while (#self.mission<3) do
        table.insert(self.mission,math.random(5,7))
    end
end


function Scene:init_map()

    --下方横上的特殊地点
    local core1 = self:index(3,1)
    self.m_map [core1]  = Feat.origin.vegetable1

    local core2 = self:index(5,1)
    self.m_map [core2]  = Feat.origin.meat

    local core3 = self:index(10,1)
    self.m_map [core3]  = Feat.origin.knife

    local core4 = self:index(15,1)
    self.m_map [core4]  = Feat.origin.meat

    local core5 = self:index(17,1)
    self.m_map [core5]  = Feat.origin.vegetable2



    --下方横上的obstacles
    for i=2 ,self.m_max_x - 1 do
        if i~=3 and i~=5 and i~=10 and i~=15 and i~=17 and i~=7 and i~=13 then

            local index = self:index(i,1)
            self.m_map [index]  = Feat.origin.obstacle3

        end
    end


    --左边竖
    local core6 = self:index(1,1)
    self.m_map [core6]  = Feat.origin.obstacle1

    for j=2 , self.m_max_y do

        if j ~= 6 then
            local index = self:index(1,j)
            self.m_map [index]  = Feat.origin.obstacle2
        else
            local index = self:index(1,j)
            self.m_map [index]  = Feat.origin.pot
        end

    end

    --右边竖
    local core7 = self:index(19,1)
    self.m_map [core7]  = Feat.origin.obstacle1
    for j=1 , self.m_max_y do

        if j ~= 6 then
            local index = self:index(19,j)
            self.m_map [index]  = Feat.origin.obstacle2
        else
            local index = self:index(19,j)
            self.m_map [index]  = Feat.origin.pot
        end

    end

    --上方横
    for i=2 , self.m_max_x-1 do

        if i ~= 10     then
            local index = self:index(i,19)
            self.m_map [index]  = Feat.origin.obstacle3
        else
            local index = self:index(i,19)
            self.m_map [index]  = Feat.origin.out
        end

    end

    --中左竖
    local core8 = self:index(7,1)
    self.m_map [core8]  = Feat.origin.obstacle1
    for j=2 , 13 do

        local index = self:index(7,j)
        self.m_map [index]  = Feat.origin.obstacle2

    end

    --中右竖
    local core9 = self:index(13,1)
    self.m_map [core9]  = Feat.origin.obstacle1
    for j=2 , 13 do

        local index = self:index(13,j)
        self.m_map [index]  = Feat.origin.obstacle2

    end

    --地砖
    for i = 2, self.m_max_x - 1 do
        for j = 2, self.m_max_y - 1 do

            local index = self:index(i,j)
            self.m_map [index]  = self.m_map [index]  or Feat.origin.null

        end
    end

    return self.m_map

end