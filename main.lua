local Camera = require("camera")

function love.load()
    ww, wh = love.graphics.getDimensions()
    gh, gh = 320, 180

    x, y = 0, 0

    camera = Camera(ww, wh)
    camera:set_deadzone(-30, -30, 60, 60)
end

function love.update(dt)
    if love.keyboard.isDown('left') then
        x = x - 1
    elseif love.keyboard.isDown('right') then
        x = x + 1
    end

    if love.keyboard.isDown('up') then
        y = y - 1
    elseif love.keyboard.isDown('down') then
        y = y + 1
    end

    if love.keyboard.isDown('q') then
        camera:rotate(-1 * dt)
    elseif love.keyboard.isDown('e') then
        camera:rotate(1 * dt)
    end




    camera:follow(x, y)
    camera:update(dt)
end

function love.keypressed(key, scancode, isrepeat)
    if key == 'z' then camera:flash(1) end
    if key == 'x' then camera:shake(1, 10, 100, 'y') end
    if key == 'c' then
        local mx, my = camera:get_mouse_position()
        local dx, dy = mx - camera.x, my - camera.y
        local angle = math.atan2(dy, dx)
        camera:spring_shake(angle, 100)
    end
end

function love.draw()
    camera:attach()
    local mx, my = camera:get_mouse_position()
    love.graphics.circle('fill', x, y, 15)
    love.graphics.circle('fill', mx, my, 15)
    love.graphics.circle('fill', 100, 100, 15)
    camera:draw_debug()
    camera:detach()
    camera:draw_flash()
end
