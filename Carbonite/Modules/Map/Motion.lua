-- Carbonite | Modules / Map / Motion
-- Timing of the map's pan and zoom animation (#246).
--
-- The map used to redraw at Map.mapUpdate (20 per second) no matter what,
-- and its pan/zoom animation moved 1/StepTime of the way per redraw, so
-- dragging and zooming advanced in visible jumps. Now:
--
--   * while the map moves it redraws every frame, capped at 60 per second;
--     at rest it keeps the user's Map.mapUpdate (Interval);
--   * the animation runs on elapsed time. StepTime still counts 0.05 s
--     steps, so 10 steps last 0.5 s as before, and eases out at the end
--     (Step). The formula has no memory: when the target changes midway
--     (several wheel clicks) the animation just carries on from there.
--
-- Public API (pure):
--   Motion.Interval(base, moving) -> seconds between map redraws
--   Motion.Step(stepsLeft, elapsed) -> fraction of the gap to cover, steps left

local Carbonite = _G.Carbonite

local Motion = {}
Carbonite.Modules.Map.Motion = Motion

Motion.STEP_SECONDS = .05
Motion.MOVING_INTERVAL = 1 / 60

function Motion.Interval(base, moving)
    base = base or Motion.STEP_SECONDS
    if moving and base > Motion.MOVING_INTERVAL then
        return Motion.MOVING_INTERVAL
    end
    return base
end

-- Ease-out (quadratic) over the steps left: the gap left is proportional
-- to (time left)^2, so going from `stepsLeft` to `stepsLeft - d` covers
-- 1 - ((stepsLeft - d) / stepsLeft)^2 of the gap.
function Motion.Step(stepsLeft, elapsed)
    if not stepsLeft or stepsLeft <= 0 then return 1, 0 end
    local d = (elapsed or 0) / Motion.STEP_SECONDS
    if d <= 0 then return 0, stepsLeft end
    if d >= stepsLeft then return 1, 0 end
    local left = stepsLeft - d
    local r = left / stepsLeft
    return 1 - r * r, left
end

return Motion
