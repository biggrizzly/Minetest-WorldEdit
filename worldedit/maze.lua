--
-- "maze" class
--

maze = { sizex = 10, sizey = 10, walls = {}, entrance = nil, drillers = {}, solver = nil, solver_steps = 0, elliptic = false }

local maze_wall = 0 -- wall
local maze_air = 1 -- air
local maze_good = 2 -- good path
local maze_wrong = 3 -- wrong path
local maze_none = 4 -- undrillable

local message = print

if minetest ~= nil then
  message = minetest.chat_send_all
end

function maze:hide_wrong()
  local n = 0
  for j=1, self.sizey do
    for i=1, self.sizex do
      if (self.walls[i][j] == maze_wrong) then
        self.walls[i][j] = maze_air
      elseif (self.walls[i][j] == maze_good) then
        n = n + 1
      end
    end
  end
  return n
end

function maze:hide_solver()
  for j=1, self.sizey do
    for i=1, self.sizex do
      if (self.walls[i][j] == maze_wrong) or (self.walls[i][j] == maze_good) then
        self.walls[i][j] = maze_air
      end
    end
  end
end

-- returns "should_we_stop" = true/false and "maze_solved" = true/false
function maze:solve_one_step(o)
  local i, j
  self.solver = self.solver or o
  if (self.solver == nil) then -- init the solver, place it on the entrance
    self.solver = { x = self.entrance.x, y = self.entrance.y }
    self:hide_solver()
    self.solver_steps = 0
    self.walls[self.solver.x][self.solver.y] = maze_good
  else -- move the solver
    local candidates, n = self:move_candidates(self.solver.x, self.solver.y)
    self.solver_steps = self.solver_steps + 1
    if n > 0 then
      if candidates.down then
        self.solver.y = self.solver.y + 1
      elseif candidates.up then
        self.solver.y = self.solver.y - 1
      elseif candidates.right then
        self.solver.x = self.solver.x + 1
      elseif candidates.left then
        self.solver.x = self.solver.x - 1
      end
      self.walls[self.solver.x][self.solver.y] = maze_good
      if (self.solver.x + 1 == self.sizex) and (self.walls[self.solver.x + 1][self.solver.y] == maze_air) then
        self.walls[self.solver.x + 1][self.solver.y] = maze_good
        return true, true
      end
    else -- we come back
      self.walls[self.solver.x][self.solver.y] = maze_wrong
      local candidates, n = self:escape_candidates(self.solver.x, self.solver.y)
      if n > 0 then
        if candidates.down then
          self.solver.y = self.solver.y + 1
        elseif candidates.up then
          self.solver.y = self.solver.y - 1
        elseif candidates.right then
          self.solver.x = self.solver.x + 1
        elseif candidates.left then
          self.solver.x = self.solver.x - 1
        end
      else
        return true, false
      end
    end
  end
  return false, false
end

function maze:show_maze()
  local i, j
  if table.getn(self.walls) == 0 then
    self:init_size()
  end
  print()
  for j=1, self.sizey do
    for i=1, self.sizex do
      local value = self.walls[i][j]
      if value == maze_wall then
        io.write("O")
      elseif value == maze_air then
        io.write(" ")
      elseif value == maze_good then
        io.write("+")
      elseif value == maze_wrong then
        io.write("-")
      elseif value == maze_none then
        io.write("X")
      end
    end
    io.write("\n")
  end
  print()
end

function maze:init_size(x, y, iselliptic, fixed_entrance_y)
  local i, j
  self.sizex = x or 10
  self.sizey = y or 10
  self.walls = {}
  self.solver = nil
  self.solver_steps = 0
  self.drillers = {}
  for i=1, self.sizex do
    self.walls[i] = {}
    for j=1, self.sizey do
      self.walls[i][j] = maze_wall
    end
  end
  self.entrance = { x = 1, y = fixed_entrance_y or math.random(2, self.sizey - 1) }
  self.entrance = { x = 1, y = fixed_entrance_y or math.random(2, self.sizey - 1) }
  self.elliptic = iselliptic or self.elliptic
  if self.elliptic then
    self:create_tower()
    while (self.walls[self.entrance.x][self.entrance.y] == maze_none) do
      self.entrance.x = self.entrance.x + 1
    end
    self.entrance.x = self.entrance.x + 1
  else
    self.entrance.x = self.entrance.x + 1
  end
  self.walls[self.entrance.x][self.entrance.y] = maze_air
  self.walls[self.entrance.x - 1][self.entrance.y] = maze_none
end

-- exclude some borders (maze_none) in order to obtain an elliptis maze
function maze:create_tower()
  local y = 0
  local h = self.sizex / 2
  local yc = 0
  for i=1, self.sizex do
    for j=1, self.sizey do
      x = math.abs(i - h - 0.5)
      y = math.sqrt(h^2 - x^2) * self.sizey / self.sizex
      yc = math.abs(self.sizey / 2 - j + 0.5)
      if y - yc <= 0 then
        self.walls[i][j] = maze_none
      end
    end
  end
end

function maze:new (o)
  o = o or {}   -- create object if user does not provide one
  setmetatable(o, self)
  self.__index = self
  return o
end

function maze:drill_candidates(posx, posy)
  local candidates = {}
  candidates.down  = (posy + 1 < self.sizey) 
                    and (self.walls[posx][posy + 1] == maze_wall)
                    and (self.walls[posx + 1][posy + 1] == maze_wall)
                    and (self.walls[posx - 1][posy + 1] == maze_wall)
                    and (self.walls[posx][posy + 2] == maze_wall)
  candidates.up    = (posy - 1 > 1) 
                    and (self.walls[posx][posy - 1] == maze_wall)
                    and (self.walls[posx + 1][posy - 1] == maze_wall)
                    and (self.walls[posx - 1][posy - 1] == maze_wall)
                    and (self.walls[posx][posy - 2] == maze_wall)
  candidates.right = (posx + 1 < self.sizex) 
                    and (self.walls[posx + 1][posy] == maze_wall)
                    and (self.walls[posx + 1][posy + 1] == maze_wall)
                    and (self.walls[posx + 1][posy - 1] == maze_wall)
                    and (self.walls[posx + 2][posy] == maze_wall)
  candidates.left  = (posx - 1 > 1) 
                    and (self.walls[posx - 1][posy] == maze_wall)
                    and (self.walls[posx - 1][posy + 1] == maze_wall)
                    and (self.walls[posx - 1][posy - 1] == maze_wall)
                    and (self.walls[posx - 2][posy] == maze_wall)  
  local n
  local keys, values
  n = 0
  for keys, values in pairs(candidates) do
    if values then n = n + 1 end
  end
  return candidates, n
end

function maze:move_candidates(posx, posy)
  local candidates = {}
  candidates.down  = (posy + 1 < self.sizey) 
                    and (self.walls[posx][posy + 1] == maze_air)
  candidates.up    = (posy - 1 > 1) 
                    and (self.walls[posx][posy - 1] == maze_air)
  candidates.right = (posx + 1 < self.sizex) 
                    and (self.walls[posx + 1][posy] == maze_air)
  candidates.left  = (posx - 1 > 1) 
                    and (self.walls[posx - 1][posy] == maze_air)
  local n
  local keys, values
  n = 0
  for keys, values in pairs(candidates) do
    if values then n = n + 1 end
  end
  return candidates, n
end

function maze:escape_candidates(posx, posy)
  local candidates = {}
  candidates.down  = (posy + 1 < self.sizey) 
                    and (self.walls[posx][posy + 1] == maze_good)
  candidates.up    = (posy - 1 > 1) 
                    and (self.walls[posx][posy - 1] == maze_good)
  candidates.right = (posx + 1 < self.sizex) 
                    and (self.walls[posx + 1][posy] == maze_good)
  candidates.left  = (posx - 1 > 1) 
                    and (self.walls[posx - 1][posy] == maze_good)
  local n
  local keys, values
  n = 0
  for keys, values in pairs(candidates) do
    if values then n = n + 1 end
  end
  return candidates, n
end

--
-- "driller" class
--

driller = { posx = 2, posy = 2, splitproba = 25, maze = nil, dead = false }

function driller:new (newmaze, templatedriller)
  local o = {}   -- create object if user does not provide one
  local nd = templatedriller or self 
  setmetatable(o, self)
  self.__index = self
  o.maze = newmaze
  o.posx = o.maze.entrance.x
  o.posy = o.maze.entrance.y
  --o.maze.walls[o.posx][o.posy] = maze_air
  table.insert(o.maze.drillers, o)
  return o
end

function driller:teleport () --teleport to the first drillable place
  if self.maze == nil then
    self.dead = true
    return false
  else
    local i, j, taby, cell
    -- goal : going from 1 to sizex randomly...
    local choicex = {}
    for i=1, self.maze.sizex do
      choicex[i] = 0
    end
    for i=1, self.maze.sizex do
      repeat
        local k = math.random(self.maze.sizex)
        if choicex[k] == 0 then
          choicex[k] = i
          break
        end
      until false
    end
    local choicey = {}
    for i=1, self.maze.sizey do
      choicey[i] = 0
    end
    for i=1, self.maze.sizey do
      repeat
        local k = math.random(self.maze.sizey)
        if choicey[k] == 0 then
          choicey[k] = i
          break
        end
      until false
    end
    for i=1, self.maze.sizex do
      for j = 1, self.maze.sizey do
        local value = self.maze.walls[choicex[i]][choicey[j]]
        if (value ~= maze_wall) and (value ~= maze_none) then
          local candidates, n = self.maze:drill_candidates(choicex[i], choicey[j])
          if n > 0 then
            self.posx = choicex[i]
            self.posy = choicey[j]
            self.dead = false
            return true
          end
        end
      end
    end
    self.dead = true
    return false
  end
end

function driller:move ()
  if self.maze == nil then
    self.dead = true
    return false
  else
    local candidates, n = self.maze:drill_candidates(self.posx, self.posy)
    
    if n > 1 then -- should we split ?
      if math.random(100) <= driller.splitproba then -- we use the main splitproba, not the self one...
        local nd = driller:new(self.maze, self)
      end
    end
    
    if n > 0 then
      r = math.random(n) -- where will we go ?
      n = 0
      for keys, values in pairs(candidates) do
        if values then 
          n = n + 1 
          if n == r then
            if keys == "up" then
              self.posy = self.posy - 1
            elseif keys == "down" then
              self.posy = self.posy + 1
            elseif keys == "left" then
              self.posx = self.posx - 1
            elseif keys == "right" then
              self.posx = self.posx + 1
            end
            self.maze.walls[self.posx][self.posy] = maze_air
            break
          end
        end
      end
      return true
    else
      self.dead = true
      return false
    end
  end
end


-- Dig the maze ; Returns the number of steps necessary to complete the digging

function maze:dig_it ()
  
  local mazedone = false
  local steps = 0
  repeat 
    steps = steps + 1
    for i, ad in pairs(self.drillers) do
      ad:move()
      if ad.dead then
        table.remove(self.drillers, i)
      end
    end
    
    mazedone = false
    if table.getn(self.drillers) == 0 then
      d = driller:new(self)
      if not d:teleport() then
        mazedone = true
      end
    end
  until mazedone
  
  return steps
end

-- create two holes near from the upper-left and the down-right
-- returns the pos of the entrance
function maze:create_exits ()
  local pos = { x = self.entrance.x - 1, y = self.entrance.y }
  self.walls[pos.x][pos.y] = maze_air
  for j = self.sizey - 1, 2, -1 do
    if (self.walls[self.sizex - 1][j] ~= maze_wall) and (self.walls[self.sizex - 1][j] ~= maze_none) then
      self.walls[self.sizex][j] = maze_air
      break
    end
  end
  return pos
end

-- returns if the maze is solved and the path length
-- it lets the path visible (maze_good)
function maze:solve_it()
  local should_we_stop, maze_solved = false, false
  self.solver = nil
  repeat
    should_we_stop, maze_solved = self:solve_one_step()
  until should_we_stop
  if maze_solved then
    local length = self:hide_wrong()
    return maze_solved, length
  else
    return maze_solved
  end
end

-- digs a maze, solves it and ensures that the length path is high enough
-- returns the length path
function maze:create_complex_maze(hide_path, iselliptic, fixed_entrance_y)
  local length = 0
  local tries = 0
  local length_limit = 0
  local maze_solved = false
  hide_path = hide_path or false
  self.iselliptic = iselliptic or false 
  repeat 
    self:init_size(self.sizex, self.sizey, self.iselliptic, fixed_entrance_y)
    length_limit = math.floor(self.sizex * self.sizey * ((1000 - 850 - tries) / 1000))
    local steps = self:dig_it()
    message("maze digged, steps required = "..steps)
    self:create_exits() -- must be called before solveit because solveit search for the entrance
    --self:show_maze()
    maze_solved, length = self:solve_it()
    if maze_solved then
      length = self:hide_wrong()
      if length >= length_limit then
        message("maze solved, path length accepted = "..length.."/"..length_limit)
      else
        message("maze solved, but path length refused = "..length.."/"..length_limit)
      end
    else
      length = 0
      message("maze not solved")
      --self:show_maze()
    end
    tries = tries + 1
  until length >= length_limit
  if hide_path then
    message("hiding the path")
    self:hide_solver()
  else 
    message("not hiding the path")
  end
  return length
end


local worldedit = worldedit or {}


function worldedit.insert_maze(pos1, pos2, node_wall_name, node_path_name, elliptic, multi, path_width, fixed_exits)
  
  local mh = worldedit.manip_helpers

  pos1, pos2 = worldedit.sort_pos(pos1, pos2)
  
  elliptic = false or elliptic 
  multi = false or multi
  fixed_exits = false or fixed_exits
  path_width = tonumber(path_width)

  local manip, area = mh.init(pos1, pos2)
  local data = mh.get_empty_data(area)
  local extent = { x = pos2.x - pos1.x + 1, y = pos2.y - pos1.y + 1, z = pos2.z - pos1.z + 1}
  
  if path_width > 1 and path_width < 5 then
    extent = { x = math.floor(extent.x / path_width), y = extent.y, z = math.floor(extent.z / path_width) }
  else
    path_width = 1
  end
  
  if fixed_exits then
    exit_pos = math.floor(extent.z / 2)
  else
    exit_pos = nil
  end
  
  minetest.chat_send_all("Maze size : "..extent.x.."/"..extent.y.."/"..extent.z)
  
  local amaze = maze:new()
  amaze:init_size(extent.x, extent.z, elliptic, exit_pos)
  
  local idwall = minetest.get_content_id(node_wall_name)
  local idair = minetest.get_content_id("air")
  local idfloor = idwall -- minetest.get_content_id("dirt")
  local idpath = minetest.get_content_id(node_path_name)
  local put_floor = false
  for y = pos1.y, pos2.y do
    if ((y - pos1.y) % 4) == 0 then
      if multi then
        put_floor = true
        if (pos2.y - y) < 4 then
          break
        end
        local length = amaze:create_complex_maze(false, elliptic, exit_pos)
        minetest.chat_send_all("Maze path length : "..length)
      elseif (y == pos1.y) then 
        put_floor = true
        local length = amaze:create_complex_maze(false, elliptic, exit_pos)
        minetest.chat_send_all("Maze path length : "..length)
      else
        put_floor = false
      end
    else
      put_floor = false
    end
    for z = pos1.z, pos2.z do
      for x = pos1.x, pos2.x do
        local vi = area:index(x, y, z)
        local wpos = { x = x - pos1.x + 1, z = z - pos1.z + 1 }
        if path_width > 1 then
          wpos = { x = math.ceil(wpos.x / path_width), z = math.ceil(wpos.z / path_width) }
        end
        if wpos.x <= amaze.sizex and wpos.z <= amaze.sizey then
          local value = amaze.walls[wpos.x][wpos.z]
          if value ~= maze_wall then
            if put_floor then 
              if value == maze_good then
                data[vi] = idpath
              elseif value == maze_none then
                if y ~= pos1.y then
                  data[vi] = idair
                end
              else
                data[vi] = idfloor
              end
            else
              data[vi] = idair
            end
          else
            data[vi] = idwall
          end
        else
          data[vi] = idair
        end
      end
    end
  end    

  mh.finish(manip, data)

  return worldedit.volume(pos1, pos2)
end
