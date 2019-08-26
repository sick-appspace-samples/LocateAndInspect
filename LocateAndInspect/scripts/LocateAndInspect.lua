--[[----------------------------------------------------------------------------

  Application Name:
  LocateAndInspect

  Summary:
  Matching objects and inspecting image details.

  Description:
  Teaching the shape of "golden" parts and matching identical objects with full
  rotation in the full image. Also inspecting a detail (letter count) on the part
  to verify its correctness.

  How to Run:
  Starting this sample is possible either by running the app (F5) or
  debugging (F7+F10). Setting breakpoint on the first row inside the 'main'
  function allows debugging step-by-step after 'Engine.OnStarted' event.
  Results can be seen in the image viewer on the DevicePage.
  Restarting the Sample may be necessary to show images after loading the webpage.
  To run this Sample a device with SICK Algorithm API and AppEngine >= V2.5.0 is
  required. For example SIM4000 with latest firmware. Alternatively the Emulator
  in AppStudio 2.3 or higher can be used..

  More Information:
  Tutorial "Algorithms - Matching".

------------------------------------------------------------------------------]]
--Start of Global Scope---------------------------------------------------------
print('AppEngine Version: ' .. Engine.getVersion())

local DELAY = 1000 -- ms between visualization steps for demonstration purpose

-- Creating viewer
local viewer = View.create()

-- Setting up graphical overlay attributes
local textDeco = View.TextDecoration.create()
textDeco:setSize(40)
textDeco:setPosition(20, 40)

local teachDecoration = View.ShapeDecoration.create()
teachDecoration:setPointSize(5)
teachDecoration:setLineColor(0, 0, 255) -- Blue color scheme for "Teach" mode
teachDecoration:setPointType('DOT')
teachDecoration:setLineWidth(5)

local passDecoration = View.ShapeDecoration.create()
passDecoration:setPointSize(5)
passDecoration:setLineColor(0, 255, 0) -- Green color scheme for "Pass" mode
passDecoration:setPointType('DOT')
passDecoration:setLineWidth(5)

local failDecoration = View.ShapeDecoration.create()
failDecoration:setPointSize(5)
failDecoration:setLineColor(255, 0, 0) -- Red color scheme for "Fail" results
failDecoration:setPointType('DOT')
failDecoration:setLineWidth(5)

-- Create edge matcher
local matcher = Image.Matching.EdgeMatcher.create()
matcher:setEdgeThreshold(50)
matcher:setDownsampleFactor(2)

-- Creating fixture for automatic pose adjustment of inspection region
local fixt = Image.Fixture.create()

--End of Global Scope-----------------------------------------------------------

--Start of Function and Event Scope---------------------------------------------

--@inspectLetters(img:Image, rect:Shape)
local function inspectLetters(img, rect)
  local inspectRegion = rect:toPixelRegion(img)
  local inspectRegionBinarized = img:threshold(110, 255, inspectRegion)
  local letterBlobs = inspectRegionBinarized:findConnected(40, 200)
  return letterBlobs
end

--@teach(img:Image)
local function teach(img)
  viewer:clear()
  local imageID = viewer:addImage(img)
  -- Adding "Teach" text overlay
  viewer:addText('Teach', textDeco, nil, imageID)

  -- Defining teach region
  local teachRectCenter = Point.create(305, 145)
  local teachRect = Shape.createRectangle(teachRectCenter, 260, 130, 0)
  local teachRegion = teachRect:toPixelRegion(img)

  -- Teaching
  local teachPose = matcher:teach(img, teachRegion)

  -- Viewing model points overlayed over teach image
  local modelPoints = matcher:getEdgePoints() -- Model points in model's local coord syst
  local teachPoints = Point.transform(modelPoints, teachPose)
  for _, point in ipairs(teachPoints) do
    viewer:addShape(point, teachDecoration, nil, imageID)
  end

  -- Setting up inspection region
  local inspectRectCenter = Point.create(302, 66)
  local inspectRect = Shape.createRectangle(inspectRectCenter, 240, 33, 0)
  viewer:addShape(inspectRect, teachDecoration, nil, imageID)

  --Configuring fixture
  fixt:setReferencePose(teachPose)
  fixt:appendShape('inspectRect', inspectRect)

  -- Inspecting by counting letter blobs
  local letterBlobs = inspectLetters(img, inspectRect)
  print('Letters in teach image = ' .. #letterBlobs)
  viewer:present()
  return modelPoints, letterBlobs
end

--@match(img:Image)
local function match(img, modelPoints, letterBlobs)
  viewer:clear()
  local imageID = viewer:addImage(img)
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

  viewer:addText(result, textDeco, nil, imageID)

  viewer:addShape(fixt:getShape('inspectRect'), resultDeco, nil, imageID)

  -- Viewing model points as overlay
  local livePoints = Point.transform(modelPoints, poses[1])
  for _, point in ipairs(livePoints) do
    viewer:addShape(point, passDecoration, nil, imageID)
  end
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
