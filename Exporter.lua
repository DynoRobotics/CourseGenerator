-- Export the generated course or parts of it
Exporter = CpObject()

---@param fieldworkCourse CourseGenerator.FieldworkCourse
function Exporter:init(fieldworkCourse)
    self.fieldworkCourse = fieldworkCourse
end

--- Export a headland as a CSV file. Only includes the given headland, without the connecting path or transitions.
---@param headlandNumber number The headland to export, 1 is the outermost
---@param filename string The filename to save the CSV file as, under the export/ directory
function Exporter:exportHeadlandAsCsv(headlandNumber, filename)
    local file = io.open('export/' .. filename, 'w')
    for _, v in self.fieldworkCourse:getHeadlandPath():vertices() do
        if v:getAttributes():getHeadlandPassNumber() == headlandNumber and
                not v:getAttributes():isHeadlandTransition() and
                not v:getAttributes():isOnConnectingPath() then
            file:write(string.format('%.2f,%.2f\n', v.x, v.y))
        end
    end
    file:close()
end

-- Export the generated course as a CSV file
---@param filename string The filename to save the CSV file as, under the export/ directory
function Exporter:exportCourseAsCsv(filename, debugTurnPaths)
    local file = io.open('export/' .. filename, 'w')
    for i, v in self.fieldworkCourse:getPath():vertices() do
        -- check if i is a key in debugTurnPaths
        file:write(string.format('%.2f,%.2f\n', v.x, v.y))
        if debugTurnPaths[i] then
            for _, vt in ipairs(debugTurnPaths[i]) do
                file:write(string.format('%.2f,%.2f\n', vt.x, vt.y))
            end
        end
    end
    file:close()
end
