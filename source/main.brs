sub Main(args as Dynamic)
  screen = createObject("roSGScreen")
  port = createObject("roMessagePort")
  screen.setMessagePort(port)
  scene = screen.createScene("home_screen")
  scene.observeField("exit", port)
  screen.Show() 
  ' vscode_rale_tracker_entry 
  ' vscode_rdb_on_device_component_entry
  scene.backgroundUri = ""
  scene.backgroundColor = "0x070b10"
  scene.setFocus(true)

  'm.global = screen.getGlobalNode()
  'm.global.addFields( {scene: scene, deeplink: args} )

  if (args.ContentId <> invalid) and (args.MediaType <> invalid)
    scene.setField("deepcontentid", args.ContentId)
  end if

  setupMemoryMonitor(port)

  while(true)
    msg = wait(0, port)
    msgType = type(msg)
    if msgType = "roSGScreenEvent"
      if msg.isScreenClosed() then return
    else if msgType = "roSGNodeEvent"
      field = msg.getField()
      data = msg.getData()
      if field = "exitChannel" and data = true
        END
      end if
    else if msgType = "roInputEvent"
      scene.setField("roInputData", msg.getInfo())
    else if msgType = "roAppMemoryNotificationEvent" or msgType = "roAppMemoryMonitorEvent"
      handleAppMemoryEvent(scene, msg)
    else if msgType = "roDeviceInfoEvent"
      handleDeviceMemoryEvent(scene, msg)
    end if
  end while
end sub

' roAppMemoryMonitor exists on OS 10.5+. Newer queries were added later.
' Devices without it use the older low-general-memory event instead.
sub setupMemoryMonitor(port as Object)
  m.memoryMonitor = invalid
  if osAtLeast(10, 5)
    m.memoryMonitor = CreateObject("roAppMemoryMonitor")
  end if
  if m.memoryMonitor <> invalid
    m.memoryMonitor.SetMessagePort(port)
    warningsOn = m.memoryMonitor.EnableMemoryWarningEvent(true)
    limitPercent = m.memoryMonitor.GetMemoryLimitPercent()
    availableKb = invalid
    if osAtLeast(12, 5) then availableKb = m.memoryMonitor.GetChannelAvailableMemory()
    limits = invalid
    if osAtLeast(13, 0) then limits = m.memoryMonitor.GetChannelMemoryLimit()
    print "[MEMORY] warnings="; warningsOn; " usagePercent="; limitPercent; " availableKb="; availableKb; " limits="; limits
    if warningsOn <> true then enableLowGeneralMemory(port)
  else
    enableLowGeneralMemory(port)
  end if
end sub

sub enableLowGeneralMemory(port as Object)
  m.deviceInfo = CreateObject("roDeviceInfo")
  m.deviceInfo.SetMessagePort(port)
  m.deviceInfo.EnableLowGeneralMemoryEvent(true)
  print "[MEMORY] general level="; m.deviceInfo.GetGeneralMemoryLevel()
end sub

sub handleAppMemoryEvent(scene as Object, msg as Object)
  percent = memoryEventPercent(msg)
  availableKb = invalid
  if m.memoryMonitor <> invalid and osAtLeast(12, 5)
    availableKb = m.memoryMonitor.GetChannelAvailableMemory()
  end if
  print "[MEMORY] app warning percent="; percent; " availableKb="; availableKb
  ' 15.2+ also notifies when usage falls back under a threshold.
  if percent <> invalid and percent < 80 then return
  level = "low"
  if percent <> invalid and percent >= 90 then level = "critical"
  pressure = { level: level }
  if percent <> invalid then pressure.percent = percent
  if availableKb <> invalid then pressure.availableKb = availableKb
  scene.memorypressure = pressure
end sub

sub handleDeviceMemoryEvent(scene as Object, msg as Object)
  info = msg.getInfo()
  if type(info) <> "roAssociativeArray" then return
  level = info.generalMemoryLevel
  if level = invalid or level = "normal" then return
  print "[MEMORY] general level="; level
  scene.memorypressure = { level: level }
end sub

function memoryEventPercent(msg as Object) as Dynamic
  info = msg.getInfo()
  if type(info) = "roAssociativeArray" and info.MemoryUsagePercent <> invalid
    return info.MemoryUsagePercent
  end if
  data = msg.getData()
  if type(data) = "Integer" or type(data) = "Float" or type(data) = "Double" or type(data) = "LongInteger"
    return data
  end if
  if type(data) = "roAssociativeArray" and data.MemoryUsagePercent <> invalid
    return data.MemoryUsagePercent
  end if
  return invalid
end function

function osAtLeast(major as Integer, minor as Integer) as Boolean
  version = CreateObject("roDeviceInfo").GetOSVersion()
  if version = invalid or version.major = invalid then return false
  verMajor = Val(version.major.ToStr())
  verMinor = 0
  if version.minor <> invalid then verMinor = Val(version.minor.ToStr())
  if verMajor > major then return true
  if verMajor = major and verMinor >= minor then return true
  return false
end function
