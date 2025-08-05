
-- Only generate path without love

package.path = package.path .. ";FS25_Courseplay/scripts/?.lua"
package.path = package.path .. ";FS25_Courseplay/scripts/util/?.lua"
package.path = package.path .. ";FS25_Courseplay/scripts/test/?.lua"
package.path = package.path .. ";FS25_Courseplay/scripts/pathfinder/?.lua"
package.path = package.path .. ";FS25_Courseplay/scripts/geometry/?.lua"
package.path = package.path .. ";FS25_Courseplay/scripts/courseGenerator/?.lua"
package.path = package.path .. ";FS25_Courseplay/scripts/courseGenerator/Geometry/?.lua"
package.path = package.path .. ";FS25_Courseplay/scripts/courseGenerator/geometry/?.lua"
package.path = package.path .. ";FS25_Courseplay/scripts/courseGenerator/Genetic/?.lua"
package.path = package.path .. ";FS25_Courseplay/scripts/courseGenerator/genetic/?.lua"
dofile('FS25_Courseplay/scripts/courseGenerator/test/require.lua')
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

function generate(fileName, fieldIndex, workingWidth, nHeadlandPasses, headlandFirst, headlandOverlap)

    local turningRadius = 6.0
    local fieldMargin = 0.0
    local nHeadlandsWithRoundCorners = nHeadlandPasses
    local headlandClockwise = true
    local fieldCornerRadius = turningRadius
    local sharpenCorners = true
    local bypassIslands = true
    local nIslandHeadlandPasses = nHeadlandPasses
    local islandHeadlandClockwise = false
    local autoRowAngle = true
    local rowAngleDeg = 0
    local rowPattern = CourseGenerator.RowPattern.ALTERNATING
    local nRows = 1
    local leaveSkippedRowsUnworked = false
    local centerClockwise = true
    local spiralFromInside = true
    local evenRowDistribution = true
    local useBaselineEdge = false
    local smallOverlaps = false

    local logger = Logger('generate', Logger.level.debug)

    logger:debug('Reading %s...', fileName)
    local savedFields = CourseGenerator.Field.loadSavedFields(fileName)
    local selectedField = savedFields[fieldIndex]

    local x1, y1, x2, y2 = selectedField:getBoundingBox()
    -- initially, start in the lower left corner
    local startX, startY = x1 + 10, y1 + 10
    local baselineX, baselineY = startX, startY

    CourseGenerator.clearDebugObjects()
    local context = CourseGenerator.FieldworkContext(selectedField, workingWidth, turningRadius, nHeadlandPasses)
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
    local islands = selectedField:getIslands()
    local islandBoundaries = {}
    for _, i in ipairs(islands) do
        table.insert(islandBoundaries, i:getHeadlands()[1]:getPolygon())  -- i:getBoundary())
    end
    applyPathfinder(logger, path, islandBoundaries, turningRadius)

    -- export the first headland as CSV
    local exporter = Exporter(course)
    exporter:exportHeadlandAsCsv(1, 'headland-1.csv')
    exporter:exportCourseAsCsv('course.csv', debugTurnPaths)
    exporter:exportCourseAndMetaDataAsCsv('courseAndMetaData.csv', debugTurnPaths)

    -- make sure all logs are now visible
    io.stdout:flush()
    errors = context:getErrors()

    local output = {
        segments = {
            {
                work = false,
                type = "FUJA",
                points = {
                    { x = startX, y = startY, z = 0 },
                    { x = baselineX, y = baselineY, z = 0 },
                },
            }
        },
    };

    return output, errors
end
