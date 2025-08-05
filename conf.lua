
function love.conf(t)
    headless = false
    if headless then
        t.modules.graphics = false
        t.modules.audio = false
        t.modules.keyboard = false
        t.modules.joystick = false
        t.modules.mouse = false
        t.modules.touch = false
        t.modules.window = false
        t.modules.video = false
        t.modules.image = false
        t.modules.system = false
    end
end