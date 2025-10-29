--- Spring

---@class Spring : Class
---@overload fun():Spring
---@field x number  -- The current value of the spring
---@field v number  -- The current velocity of the spring
---@field damp number  -- Damping factor
---@field tension number  -- Tension factor
local Spring = {}
Spring.__index = Spring

---Create a new Spring
---@param x number? Initial value (default 0)
---@param damp number? Damping factor (default 0.8)
---@param tension number? Tension factor (default 0.2)
function Spring.new(x, tension, damp)
    local self = {}
    self.x = x or 0
    self.v = 0
    self.target_x = self.x
    self.damp = damp or 20
    self.tension = tension or 500
    return setmetatable(self, Spring)
end

---Push the spring with a force, optionally override damp and tension
---@param force number
---@param damp number? Optional override for damping
---@param tension number? Optional override for tension
function Spring:pull(force, damp, tension)
    if damp then self.damp = damp end
    if tension then self.tension = tension end
    self.v = self.v + force * 100
end

---Update the spring (call every frame)
---@param dt number
function Spring:update(dt)
    local a = -self.tension * (self.x - self.target_x) - self.damp * self.v
    self.v = self.v + a * dt
    self.x = self.x + self.v * dt
end

--- Shaker

---@class ShakeInstance
local ShakeInstance = {}
ShakeInstance.__index = ShakeInstance

function ShakeInstance.new(amplitude, duration, frequency)
    local self = {}
    self.amplitude = amplitude or 0
    self.duration = duration or 0
    self.frequency = frequency or 60
    self.samples = {}
    self.start_time = love.timer.getTime() * 1000
    self.t = 0
    self.shaking = true
    local sample_count = math.max(1, math.floor((self.duration / 1000) * self.frequency))
    for i = 1, sample_count do
        self.samples[i] = 2 * love.math.random() - 1
    end
    return setmetatable(self, ShakeInstance)
end

function ShakeInstance:update(dt)
    self.t = love.timer.getTime() * 1000 - self.start_time
    if self.t > self.duration then self.shaking = false end
end

function ShakeInstance:noise(s)
    if s >= #self.samples then return 0 end
    return self.samples[math.floor(s) + 1] or 0
end

function ShakeInstance:decay(t)
    if t > self.duration then return 0 end
    return (self.duration - t) / self.duration
end

function ShakeInstance:get_amplitude(t)
    if not t then
        if not self.shaking then return 0 end
        t = self.t
    end
    local s = (t / 1000) * self.frequency
    local s0 = math.floor(s)
    local s1 = s0 + 1
    local k = self:decay(t)
    return self.amplitude * (self:noise(s0) + (s - s0) * (self:noise(s1) - self:noise(s0))) * k
end

---@class Shaker : Class
---@overload fun(): Shaker
local Shaker = {}
Shaker.__index = Shaker

function Shaker.new()
    local self = {}
    self.horizontal_shakes = {}
    self.vertical_shakes = {}
    self.last_horizontal_shake_amount = 0
    self.last_vertical_shake_amount = 0
    self.h_shake, self.v_shake = 0, 0
    return setmetatable(self, Shaker)
end

function Shaker:update(dt)
    local horizontal_shake_amount, vertical_shake_amount = 0, 0
    for i = #self.horizontal_shakes, 1, -1 do
        self.horizontal_shakes[i]:update(dt)
        horizontal_shake_amount = horizontal_shake_amount + self.horizontal_shakes[i]:get_amplitude()
        if not self.horizontal_shakes[i].shaking then table.remove(self.horizontal_shakes, i) end
    end
    for i = #self.vertical_shakes, 1, -1 do
        self.vertical_shakes[i]:update(dt)
        vertical_shake_amount = vertical_shake_amount + self.vertical_shakes[i]:get_amplitude()
        if not self.vertical_shakes[i].shaking then table.remove(self.vertical_shakes, i) end
    end
    self.h_shake = self.h_shake - self.last_horizontal_shake_amount + horizontal_shake_amount
    self.v_shake = self.v_shake - self.last_vertical_shake_amount + vertical_shake_amount
    self.last_horizontal_shake_amount = horizontal_shake_amount
    self.last_vertical_shake_amount = vertical_shake_amount
end

function Shaker:shake(intensity, duration, frequency, axes)
    axes = axes or 'XY'
    axes = string.upper(axes)
    if string.find(axes, 'X') then
        table.insert(self.horizontal_shakes,
            ShakeInstance.new(intensity, duration * 1000, frequency))
    end
    if string.find(axes, 'Y') then
        table.insert(self.vertical_shakes,
            ShakeInstance.new(intensity, duration * 1000, frequency))
    end
end

---------------------------------------------------------------------------------------------


---@class Camera : Class
---@overload fun(w?:number, h?:number):Camera ---Create a new Camera
---@field private x number
---@field private y number
---@field private scale number
---@field private angle number
---@field private width number
---@field private height number
---@field private shaker Shaker
---@field private shake_x number
---@field private shake_y number
---@field private spring Spring
---@field private spring_shake_x number
---@field private spring_shake_y number
---@field private spring_shake_dir number
---@field private target table|nil
---@field private flash_timer number
---@field private flash_duration number
---@field private follow_lead_x number
---@field private follow_lead_y number
---@field private target_x number
---@field private target_y number
---@field private deadzone_x number
---@field private deadzone_y number
---@field private deadzone_w number
---@field private deadzone_h number
---@field private lerp number|nil
---@field private _last_target_x number
---@field private _last_target_y number
---@field private bounds_min_x number|nil
---@field private bounds_min_y number|nil
---@field private bounds_max_x number|nil
---@field private bounds_max_y number|nil
local deg2rad = math.pi / 180
local rad2deg = 180 / math.pi

local function round(v)
    return math.floor(v + 0.5)
end

local function lerp(a, b, t)
    return a * (1.0 - t) + b * t
end

local Camera = {}
Camera.__index = Camera

function Camera.new(w, h)
    local self = {}
    self.bounds_min_x = nil
    self.bounds_min_y = nil
    self.bounds_max_x = nil
    self.bounds_max_y = nil

    self.x = 0
    self.y = 0
    self.scale = 1
    self.angle = 0
    self.width, self.height = w, h

    self.lead_offset_x, self.lead_offset_y = 0, 0
    self.last_x, self.last_y = self.x, self.y
    self.target_lead_x, self.target_lead_y = 0, 0
    self.dir_x, self.dir_y = 0, 0
    self.spring_shake_dir = 0
    self.target = nil

    self.flash_timer = 0
    self.flash_duration = 0
    self.flash_color = { 1, 1, 1, 1 }

    self.follow_lead_x, self.follow_lead_y = 0, 0
    self.target_x = self.x
    self.target_y = self.y
    self.deadzone_x = 0
    self.deadzone_y = 0
    self.deadzone_w = 0
    self.deadzone_h = 0
    self.cos_angle = math.cos(self.angle)
    self.sin_angle = math.sin(self.angle)
    self.lerp = 1
    self._last_target_x = self.target_x
    self._last_target_y = self.target_y


    self.shaker = Shaker.new()
    self.shake_x, self.shake_y = 0, 0
    self.spring = Spring.new()
    self.spring_shake_x, self.spring_shake_y = 0, 0

    return setmetatable(self, Camera)
end

function Camera:set_deadzone(x, y, w, h)
    self.deadzone_x = x or 0
    self.deadzone_y = y or 0
    self.deadzone_w = w or 0
    self.deadzone_h = h or 0
end

---Set the camera position directly
---@param x number
---@param y number
function Camera:set_position(x, y)
    self.x = x or self.x
    self.y = y or self.y
end

function Camera:get_position(x, y)
    return self.x, self.y
end

---Flash the camera (white or custom color)
---@param duration number|nil
function Camera:flash(duration)
    self.flash_timer = duration
    self.flash_duration = duration
end

---@type fun(r, g, b, a)
---@overload fun(color)
function Camera:set_flash_color(r, g, b, a)
    if type (r) == 'table' then
        self.flash_color = r
    else
        self.flash_color[1] = r
        self.flash_color[2] = g
        self.flash_color[3] = b
        self.flash_color[4] = a
    end
end

---Set camera movement bounds
---@param min_x number
---@param min_y number
---@param max_x number
---@param max_y number
function Camera:set_bounds(min_x, min_y, max_x, max_y)
    self.bounds_min_x = min_x
    self.bounds_min_y = min_y
    self.bounds_max_x = max_x
    self.bounds_max_y = max_y
end

---Set a follow style (presets for deadzone)
---@param style string | "platformer" | "center" | "wide" | "side_scroller"
function Camera:set_follow_style(style)
    if style == "platformer" then
        self:set_deadzone(-10, -10, 20, 20)
    elseif style == "side_scroller" then
        self:set_deadzone(-20, -30, 20, 60)
    elseif style == "center" then
        self:set_deadzone(0, 0, 0, 0)
    elseif style == "wide" then
        self:set_deadzone(-100, -50, 200, 100)
    else
        self:set_deadzone(0, 0, 0, 0)
    end
end

---@param lerp number
function Camera:set_lerp(lerp)
    self.lerp = lerp
end

---make the camera follow a specific target
---@param target table<{ x: number, y: number}>
function Camera:set_target(target)
    self.target = target
    assert(self.target.x and self.target.y, 'invalid target')
end

---Set the camera to follow a specific position
---@param x number
---@param y number
function Camera:follow(x, y)
    self.target = nil
    self.target_x = x
    self.target_y = y
end

---@param dt number
function Camera:update(dt)
    self.cos_angle = math.cos(self.angle)
    self.sin_angle = math.sin(self.angle)

    if self.flash_timer > 0 then
        self.flash_timer = self.flash_timer - dt
    end

    self.shaker:update(dt)
    self.spring:update(dt)
    self.spring_shake_x = self.spring.x * math.cos(self.spring_shake_dir)
    self.spring_shake_y = self.spring.x * math.sin(self.spring_shake_dir)

    -- Deadzone
    local tx, ty = self.target_x, self.target_y
    if self.target and self.target.x and self.target.y then
        tx, ty = self.target.x, self.target.y
        self.target_x, self.target_y = tx, ty
    end

    local left = self.x + self.deadzone_x
    local right = left + self.deadzone_w
    local top = self.y + self.deadzone_y
    local bottom = top + self.deadzone_h
    local move_x, move_y = self.x, self.y

    if self.deadzone_w > 0 and self.deadzone_h > 0 then
        if tx <= left then move_x = tx - self.deadzone_x end
        if tx >= right then move_x = tx - (self.deadzone_x + self.deadzone_w) end
        if ty <= top then move_y = ty - self.deadzone_y end
        if ty >= bottom then move_y = ty - (self.deadzone_y + self.deadzone_h) end
    else
        move_x, move_y = tx, ty
    end

    --- experimental stuff !!
    -- if self.follow_lead_x ~= 0 or self.follow_lead_y ~= 0 then
    --     local dir_x = math.sign(tx - self._last_target_x)
    --     local dir_y = math.sign(ty - self._last_target_y)
    --
    --     if self.dir_x ~= dir_x or self.dir_y ~= dir_y then
    --         self.target_lead_x = self.follow_lead_x * dir_x
    --         self.target_lead_y = self.follow_lead_y * dir_y
    --         self.dir_x = dir_x
    --         self.dir_y = dir_y
    --     end
    --
    --     self.lead_offset_x = math.lerp(self.lead_offset_x, self.target_lead_x, math.min(1, dt * 10))
    --     self.lead_offset_y = math.lerp(self.lead_offset_y, self.target_lead_y, math.min(1, dt * 10))
    --
    --     move_x = move_x + self.lead_offset_x
    --     move_y = move_y + self.lead_offset_y
    -- end
    --------------------------------------------


    if self.lerp < 1 then
        local t = math.pow(dt, 1 - self.lerp)
        self.x = lerp(self.x, move_x, t)
        self.y = lerp(self.y, move_y, t)
    else
        self.x, self.y = move_x, move_y
    end

    if self.bounds_min_x and self.bounds_max_x and self.bounds_min_y and self.bounds_max_y then
        local hw = (self.width or game_width) / 2
        local hh = (self.height or game_height) / 2
        self.x = math.max(self.bounds_min_x + hw, math.min(self.x, self.bounds_max_x - hw))
        self.y = math.max(self.bounds_min_y + hh, math.min(self.y, self.bounds_max_y - hh))
    end

    self._last_target_x = tx
    self._last_target_y = ty
    self.last_x = self.x
    self.last_y = self.y

    self.x = round(self.x)
    self.y = round(self.y)
end

-- function Camera:set_follow_lead(x, y)
--     self.follow_lead_x = x
--     self.follow_lead_y = y or x
-- end

function Camera:draw_flash()
    if self.flash_timer > 0 then
        local alpha = self.flash_timer / self.flash_duration
        love.graphics.setColor(self.flash_color[1], self.flash_color[2], self.flash_color[3],
            alpha * self.flash_color[4]
        love.graphics.rectangle("fill", 0, 0, self.width, self.height)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

---Shake the camera
---@param duration number
---@param intensity number
---@param frequency number
---@param axes 'xy' | 'x' | 'y'
function Camera:shake(duration, intensity, frequency, axes)
    intensity = intensity or 5
    frequency = frequency or 60
    self.shaker:shake(intensity, duration, frequency, axes)
end

---Shake the camera in a specific direction
---@param angle number angle in radians
---@param force number
---@param damp number|nil
---@param tension number|nil
function Camera:spring_shake(angle, force, damp, tension)
    self.spring_shake_dir = angle
    self.spring:pull(force, damp, tension)
end

---@return number, number
function Camera:get_mouse_position()
    local mx, my = love.mouse.getPosition()
    return self:to_world_pos(mx, my)
end

function Camera:to_world_pos(x, y)
    x = x - self.width / 2
    y = y - self.height / 2

    x = x / self.scale
    y = y / self.scale

    local cos_a = self.cos_angle
    local sin_a = self.sin_angle
    local rx = cos_a * x - sin_a * y
    local ry = sin_a * x + cos_a * y

    local sx = self.x + self.shaker.h_shake + self.spring_shake_x
    local sy = self.y + self.shaker.v_shake + self.spring_shake_y
    rx = rx + sx
    ry = ry + sy
    return rx, ry
end

---@param angle number radians
function Camera:set_angle(angle)
    self.angle = angle
end

---@return number
function Camera:get_angle()
    return self.angle
end

---@param delta number
function Camera:rotate(delta)
    self.angle = self.angle + delta
end

---@param rotation number degrees
function Camera:set_rotation(rotation)
    self.angle = rotation * deg2rad
end

---@param scale number
function Camera:set_zoom(scale)
    self.scale = scale
end

---@return number
function Camera:get_zoom()
    return self.scale
end

function Camera:attach()
    love.graphics.push()
    love.graphics.translate(self.width / 2, self.height / 2)
    love.graphics.rotate(-self.angle)
    love.graphics.scale(self.scale)

    local sx = self.x
    local sy = self.y
    sx = sx + self.shaker.h_shake
    sy = sy + self.shaker.v_shake
    sx = sx + self.spring_shake_x
    sy = sy + self.spring_shake_y
    love.graphics.translate(-math.floor(sx), -math.floor(sy))
end

function Camera:detach()
    love.graphics.pop()
end

--- draws the deadzone and stuff
function Camera:draw_debug()
    if self.deadzone_w > 0 and self.deadzone_h > 0 then
        local dzx = self.x + self.deadzone_x
        local dzy = self.y + self.deadzone_y
        love.graphics.setColor(1, 0, 0, 0.3)
        love.graphics.rectangle("line", dzx, dzy, self.deadzone_w, self.deadzone_h)
        love.graphics.setColor(1, 0, 0, 0.1)
        love.graphics.rectangle("fill", dzx, dzy, self.deadzone_w, self.deadzone_h)
    end

    love.graphics.setColor(0, 1, 0, 0.5)
    love.graphics.line(self.x - 1000, self.y, self.x + 1000, self.y)
    love.graphics.line(self.x, self.y - 1000, self.x, self.y + 1000)
    love.graphics.setColor(1, 1, 1, 1)
end

return setmetatable(Camera, { __call = function(_, ...) return Camera.new(...) end })
