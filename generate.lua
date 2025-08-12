
-- Only generate path without love

-- package.path = package.path .. ";FS25_Courseplay/scripts/?.lua"
-- package.path = package.path .. ";FS25_Courseplay/scripts/util/?.lua"
-- package.path = package.path .. ";FS25_Courseplay/scripts/test/?.lua"
-- package.path = package.path .. ";FS25_Courseplay/scripts/pathfinder/?.lua"
-- package.path = package.path .. ";FS25_Courseplay/scripts/geometry/?.lua"
-- package.path = package.path .. ";FS25_Courseplay/scripts/courseGenerator/?.lua"
-- package.path = package.path .. ";FS25_Courseplay/scripts/courseGenerator/Geometry/?.lua"
-- package.path = package.path .. ";FS25_Courseplay/scripts/courseGenerator/geometry/?.lua"
-- package.path = package.path .. ";FS25_Courseplay/scripts/courseGenerator/Genetic/?.lua"
-- package.path = package.path .. ";FS25_Courseplay/scripts/courseGenerator/genetic/?.lua"

-- dofile('FS25_Courseplay/scripts/courseGenerator/test/require.lua')
require('CpObject')
require('Logger')
require('CourseGenerator')
require('Util')
require('CacheMap')
require('WrapAroundIndex')
require('CpMathUtil')
require('Dubins')
require('AnalyticSolution')
require('Vector')
require('State3D')
require('Vertex')
require('WaypointAttributes')
require('LineSegment')
require('Polyline')
require('Polygon')
require('Intersection')
require('Slider')
require('Field')
require('FieldworkContext')
require('FieldworkCourse')
require('FieldworkCourseMultiVehicle')
require('FieldworkCourseHelper')
require('FieldworkCourseTwoSided')
require('HeadlandConnector')
require('Offset')
require('Row')
require('RowPattern')
require('Block')
require('Headland')
require('CurvedPathHelper')
require('Center')
require('CenterTwoSided')
require('Island')
require('SplineHelper')
require('AnalyticHelper')
require('Genetic')
require('BlockSequencer')
require('mock-Courseplay')
--------------------------------

require('AdjustableParameter')
require('ToggleParameter')
require('ListParameter')
require('Exporter')

require('mocks.mock-GiantsEngine')
require('mocks.mock-Node')
require('mocks.mock-DebugUtil')
require('mocks.mock-Courseplay')

require('CpUtil')
require('BinaryHeap')
require('ReedsShepp')
require('ReedsSheppSolver')
require('Waypoint')
require('Course')
require('ai.util.AIUtil')

function openIntervalTimer()
end

function readIntervalTimerMs(timer)
    return 0
end

function closeIntervalTimer(timer)
end

function printCallstack()
    print(debug.traceback())
end

require('HybridAStar')
require('AStar')
require('HybridAStarWithAStarInTheMiddle')
require('PathfinderConstraints')

g_Courseplay = {
    globalSettings = {
        getSettings = function()
            return {
                deltaAngleRelaxFactorDeg = {
                    getValue = function()
                        return 10
                    end
                },
                maxDeltaAngleAtGoalDeg = {
                    getValue = function()
                        return 45
                    end
                },
            }
        end
    }
}

local debugTurnPaths = {}

---@class MyPathFinderConstraints : PathfinderConstraintInterface
local MyPathFinderConstraints = CpObject(PathfinderConstraintInterface)
function MyPathFinderConstraints:init(islands)
    self.islands = islands
    self.penalty = 1
end

function MyPathFinderConstraints:isValidNode(node)
    return true
end

function MyPathFinderConstraints:isValidAnalyticSolutionNode(node)
    for _, b in ipairs(self.islands) do
        if b:isInside(node.x, node.y) then
            return false
        end
    end
    return true
end

function MyPathFinderConstraints:getNodePenalty(node)
    for _, b in ipairs(self.islands) do
        if b:isInside(node.x, node.y) then
            return self.penalty
        end
    end
    return 0
end

local function doSomePathfinder(logger, i, vs, vg, islands, turningRadius)
    local start = vs:getEntryEdge():getEndAsState3D()
    local goal = vg:getExitEdge():getBaseAsState3D()
    local yieldAfter = 1000
    local allowReverse = false
    local constraints = MyPathFinderConstraints(islands)
    local pathfinder = HybridAStarWithAStarInTheMiddle({}, yieldAfter)
    local result = pathfinder:start(start, goal, turningRadius, allowReverse, constraints)
    local debugTurnPath = result.path
    if result.done then
        debugTurnPaths[i] = debugTurnPath
    else
        logger:debug("PATHFINDER FAILED")
    end
end

local function applyPathfinder(logger, p, islands, turningRadius)
    debugTurnPaths = {}
    if #p > 1 then
        for i, v, vp, vn in p:vertices() do
            if v:getExitEdge() then
                if v:getAttributes():shouldUsePathfinderToNextWaypoint() then
                    logger:debug("EXIT edge should use path finder to NEXT waypoint")
                    doSomePathfinder(logger, i, v, vn, islands, turningRadius)
                elseif v:getAttributes():isRowEnd() then
                    logger:debug("EXIT edge is ROW END")
                    doSomePathfinder(logger, i, v, vn, islands, turningRadius)
                end
            end
            if v:getEntryEdge() and v:getAttributes():shouldUsePathfinderToThisWaypoint() then
                -- love.graphics.line(v.x, v.y, v:getEntryEdge():getBase().x, v:getEntryEdge():getBase().y)
                logger:debug("ENTRY ENGE should use path finder to THIS waypoint")
                -- doSomePathfinder(i, vp, v, islands)
            end
        end
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Generate the fieldwork course
---------------------------------------------------------------------------------------------------------------------------

function makeFieldFromGeometry(fieldXY, logger)
    local field = CourseGenerator.Field("TemporaryField", 1)

    -- boundary
    for i, p in ipairs(fieldXY.boundary) do
        local x, z = p[1], p[2]
        field.boundary:append(Vertex(x, -z))
    end

    -- islands
    field.islandPoints = {}
    for _, obstacle in ipairs(fieldXY.obstacles) do
        for i, p in ipairs(obstacle) do
            local x, z = p[1], p[2]
            table.insert(field.islandPoints, Vertex(x, -z))
        end
    end

    field.boundary:splitEdges(CourseGenerator.cMaxEdgeLength)
    field.boundary:calculateProperties()
    field:setupIslands()

    return field
end

function generate(fieldXY, workingWidth, nHeadlandPasses, headlandFirst, headlandOverlap, fieldMargin, turningRadius, rowPattern, nRows)

    local logger = Logger('generate', Logger.level.debug)

    local field = makeFieldFromGeometry(fieldXY, logger)

    local turningRadius = turningRadius or 6.0
    local nHeadlandsWithRoundCorners = nHeadlandPasses
    local headlandClockwise = true
    local fieldCornerRadius = turningRadius
    local sharpenCorners = true
    local bypassIslands = true
    local nIslandHeadlandPasses = nHeadlandPasses
    local islandHeadlandClockwise = false
    local autoRowAngle = true
    local rowAngleDeg = 0
    local rowPattern = rowPattern or CourseGenerator.RowPattern.ALTERNATING
    local nRows = nRows or 1
    local leaveSkippedRowsUnworked = false
    local centerClockwise = true
    local spiralFromInside = true
    local evenRowDistribution = true
    local useBaselineEdge = false
    local smallOverlaps = false

    local x1, y1, x2, y2 = field:getBoundingBox()
    -- initially, start in the lower left corner
    local startX, startY = x1 + 10, y1 + 10
    local baselineX, baselineY = startX, startY

    CourseGenerator.clearDebugObjects()
    local context = CourseGenerator.FieldworkContext(field, workingWidth, turningRadius, nHeadlandPasses)
                :setHeadlandsWithRoundCorners(nHeadlandsWithRoundCorners)
                :setHeadlandClockwise(headlandClockwise)
                :setIslandHeadlandClockwise(islandHeadlandClockwise)
                :setHeadlandFirst(headlandFirst)
                :setIslandHeadlands(nIslandHeadlandPasses)
                :setFieldCornerRadius(fieldCornerRadius)
                :setBypassIslands(bypassIslands)
                :setSharpenCorners(sharpenCorners)
                :setAutoRowAngle(autoRowAngle)
                :setRowAngle(math.rad(rowAngleDeg))
                :setEvenRowDistribution(evenRowDistribution)
                :setUseBaselineEdge(useBaselineEdge)
                :setStartLocation(startX, startY)
                :setBaselineEdge(baselineX, baselineY)
                :setEnableSmallOverlapsWithHeadland(smallOverlaps)
                :setFieldMargin(fieldMargin)
                :setHeadlandOverlap(headlandOverlap)

    if rowPattern == CourseGenerator.RowPattern.SKIP then
        context:setRowPattern(CourseGenerator.RowPattern.create(rowPattern, nRows, leaveSkippedRowsUnworked))
    elseif rowPattern == CourseGenerator.RowPattern.SPIRAL then
        context:setRowPattern(CourseGenerator.RowPattern.create(rowPattern, centerClockwise, spiralFromInside))
    elseif rowPattern == CourseGenerator.RowPattern.LANDS then
        context:setRowPattern(CourseGenerator.RowPattern.create(rowPattern, centerClockwise, nRows))
    elseif rowPattern == CourseGenerator.RowPattern.RACETRACK then
        context:setRowPattern(CourseGenerator.RowPattern.create(rowPattern, nRows))
    else
        context:setRowPattern(CourseGenerator.RowPattern.create(rowPattern))
    end

    local generatorFunc = function()
        return CourseGenerator.FieldworkCourse(context)
    end

    local success
    local course
    local errors = {}
    success, course = xpcall(
            generatorFunc,
            function(err)
                context:addError(logger, debug.traceback(err))
                error(nil)
            end)
    if not success then
        io.stdout:flush()
        errors = context:getErrors()
        return
    end

    local path = course:getPath();
    local islands = field:getIslands()
    local islandBoundaries = {}
    for _, i in ipairs(islands) do
        table.insert(islandBoundaries, i:getHeadlands()[1]:getPolygon())  -- i:getBoundary())
    end
    applyPathfinder(logger, path, islandBoundaries, turningRadius)

    -- Export the course
    output = {}

    doWork = false
    areaType = "UNKNOWN"
    for i, v in course:getPath():vertices() do

        if v:getAttributes():isRowStart() then
            doWork = true
            areaType = "ROW"
        end

        if v:getAttributes():getHeadlandPassNumber() then
            doWork = true
            areaType = "HEADLAND"
        end

        if v:getAttributes():isOnConnectingPath() then
            doWork = false
            areaType = "CONNECTING_PATH"
        end

        if debugTurnPaths[i] then
            doWork = false
            areaType = "ROW_TURN"
        end

        startNewSegment = #output == 0 or output[#output].doWork ~= doWork or output[#output].areaType ~= areaType

        if startNewSegment then
            output[1] = {
                doWork = doWork,
                areaType = areaType,
                points = {}
            }
        end

        table.insert(output[#output].points, {x = v.x, y = v.y})

        if debugTurnPaths[i] then
            for _, vt in ipairs(debugTurnPaths[i]) do
                table.insert(output[#output].points, {x = vt.x, y = vt.y})
            end
        end
    end

    -- make sure all logs are now visible
    io.stdout:flush()
    errors = context:getErrors()

    return output, errors
end
