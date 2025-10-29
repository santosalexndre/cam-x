
# Camx
an easy to use camera module for love2d with camera shake and deadzone funcionality

* [camera.new](#Camera)
* [camera:update(dt)](#updatedt)
* [camera:set_deadzone(left, top, right, bottom)](#deadzone)
* [camera:set_bounds(left, top, right, bottom)](#bounds)
* [camera:set_lerp(amount)](#lerp)
* [camera:set_target(target)](#set_target)
* [camera:follow(x, y)](#follow)
* [camera:set_position(x, y)](#draw_flash)
* [camera:flash(duration)](#draw_flash)
* [camera:set_flash_color()](#draw_flash)
* [camera:draw_flash()](#draw_flash)
* [camera:shake(duration, intensity, frequency, axes)](#draw_flash)
* [camera:spring_shake(angle, force, tension, dampening)](#draw_flash)
* [camera:set_angle(angle)](#draw_flash)
* [camera:set_rotation(rotation)](#draw_flash)
* [camera:rotate(delta)](#draw_flash)
* [camera:set_zoom(value)](#draw_flash)
* [camera:set_follow_style(style)](#draw_flash)
* [camera:draw_debug()](#draw_flash)
* [camera:attach()](#draw_flash)
* [camera:detach()](#draw_flash)

---
* `camera.new(w, h)` or `camera(w, h)`: creates a new camera, w and h is used to calculate the viewport of your camera
```lua
local Camera = require("camera")

function love.load(dt)
    ww, wh = love.graphics.getDimensions()
    gw, gh = 320, 180
    camera = Camera(gw, gh) -- camera will use the game internal resolution 
end
```
* `camera:set_deadzone(l, t, r, b)`: sets the camera deadzone rect
* `camera:set_bounds(l, t, r, b)`: sets the bound limits for the camera
* `camera:shake(duration, intensity, frequency, axes)`: shakes the camera, axes can optionally be on the 'x' or 'y' axes only
* `camera:spring_shake(angle, force, tension, dampening)`: shakes the camera in a specific direction using a spring
* `camera:update(dt)`: call this in love.update()
* `camera:set_position(x, y)`: sets the camera position to x and y directly (doesn't calculate bounds, deadzones or anything)
* `camera:follow(x, y)`: moves the camera to x and y while respecting the deadzone and bounds
