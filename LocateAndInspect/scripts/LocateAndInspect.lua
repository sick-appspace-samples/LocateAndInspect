
--Start of Global Scope---------------------------------------------------------
print('AppEngine Version: ' .. Engine.getVersion())

local DELAY = 1000 -- ms between visualization steps for demonstration purpose

-- Creating viewer
local viewer = View.create()

-- Setting up graphical overlay attributes
local textDeco = View.TextDecoration.create():setSize(40):setPosition(20, 40)

local teachDecoration = View.ShapeDecoration.create():setLineWidth(5):setPointSize(5)
teachDecoration:setPointType('DOT'):setLineColor(0, 0, 255) -- Blue color scheme for "Teach" mode

local passDecoration = View.ShapeDecoration.create():setPointSize(5):setLineWidth(5)
passDecoration:setPointType('DOT'):setLineColor(0, 255, 0) -- Green color scheme for "Pass" mode

local failDecoration = View.ShapeDecoration.create():setPointSize(5):setLineWidth(5)
failDecoration:setPointType('DOT'):setLineColor(255, 0, 0) -- Red color scheme for "Fail" results

-- Create edge matcher
local matcher = Image.Matching.EdgeMatcher.create()
matcher:setEdgeThreshold(50)
local wantedDownsampleFactor = 2
matcher:setDownsampleFactor(wantedDownsampleFactor)

-- Creating fixture for automatic pose adjustment of inspection region
local fixt = Image.Fixture.create()

--End of Global Scope-----------------------------------------------------------

--Start of Function and Event Scope---------------------------------------------

---@param img Image
---@param rect Shape
---@return Image.PixelRegion[]
local function inspectLetters(img, rect)
  local inspectRegion = rect:toPixelRegion(img)
  local inspectRegionBinarized = img:threshold(110, 255, inspectRegion)
  local letterBlobs = inspectRegionBinarized:findConnected(40, 200)
  return letterBlobs
end

---@param img Image
---@return Point[]
---@return Image.PixelRegion[]
local function teach(img)
  viewer:clear()
  viewer:addImage(img)
  -- Adding "Teach" text overlay
  viewer:addText('Teach', textDeco)

  -- Defining teach region
  local teachRectCenter = Point.create(305, 145)
  local teachRect = Shape.createRectangle(teachRectCenter, 260, 130, 0)
  local teachRegion = teachRect:toPixelRegion(img)

  -- Check if wanted downsample factor is supported by device
  local minDsf,_ = matcher:getDownsampleFactorLimits(img)
  if (minDsf > wantedDownsampleFactor) then
    print("Cannot use downsample factor " .. wantedDownsampleFactor .. " will use " .. minDsf .. " instead")
    matcher:setDownsampleFactor(minDsf)
  end

  -- Teaching
  local teachPose = matcher:teach(img, teachRegion)

  -- Viewing model points overlayed over teach image
  local modelPoints = matcher:getModelPoints() -- Model points in model's local coord syst
  local teachPoints = Point.transform(modelPoints, teachPose)
  viewer:addShape(teachPoints, teachDecoration)

  -- Setting up inspection region
  local inspectRectCenter = Point.create(302, 66)
  local inspectRect = Shape.createRectangle(inspectRectCenter, 240, 33, 0)
  viewer:addShape(inspectRect, teachDecoration)

  --Configuring fixture
  fixt:setReferencePose(teachPose)
  fixt:appendShape('inspectRect', inspectRect)

  -- Inspecting by counting letter blobs
  local letterBlobs = inspectLetters(img, inspectRect)
  print('Letters in teach image = ' .. #letterBlobs)
  viewer:present()
  return modelPoints, letterBlobs
end

---@param img Image
---@param modelPoints Point
---@param letterBlobs Image.PixelRegion[]
local function match(img, modelPoints, letterBlobs)
  viewer:clear()
  viewer:addImage(img)
  -- Finding object pose
  local poses, _ = matcher:match(img)

  -- Transforming inspect region
  fixt:transform(poses[1])
  local newInspectRect = fixt:getShape('inspectRect')

  -- Inspecting details
  local letterBlobsMatch = inspectLetters(img, newInspectRect)
  print('Letters in live image = ' .. #letterBlobsMatch)

  -- Adding overlays, color schemes depending on result
  local resultDeco
  local result
  if (#letterBlobsMatch == #letterBlobs) then
    resultDeco = passDecoration
    result = 'Pass'
  else
    resultDeco = failDecoration
    result = 'Fail'
  end

  viewer:addText(result, textDeco)

  viewer:addShape(fixt:getShape('inspectRect'), resultDeco)

  -- Viewing model points as overlay
  local livePoints = Point.transform(modelPoints, poses[1])
  viewer:addShape(livePoints, passDecoration)
  viewer:present()
end

local function main()
  -- Loading Teach image from resources and calling teach() function
  local teachImage = Image.load('resources/Teach.bmp')
  local modelPoints, letterBlobs = teach(teachImage)
  Script.sleep(DELAY) -- for demonstration purpose only

  -- Loading images from resource folder and calling match() function
  for i = 1, 3 do
    local liveImage = Image.load('resources/' .. i .. '.bmp')
    match(liveImage, modelPoints, letterBlobs)
    Script.sleep(DELAY) -- for demonstration purpose only
  end

  print('App finished.')
end
--The following registration is part of the global scope which runs once after startup
--Registration of the 'main' function to the 'Engine.OnStarted' event
Script.register('Engine.OnStarted', main)

--End of Function and Event Scope--------------------------------------------------
