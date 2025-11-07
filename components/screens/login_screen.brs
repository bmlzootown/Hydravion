function init()
  m.login_text = m.top.findNode("login_text")
  m.login_text.font.size = 80

  m.manualEntryButton = m.top.findNode("manualEntryButton")
  m.manualEntryButton.observeField("buttonSelected","onManualEntryButton")

  m.submitHint = m.top.findNode("submitHint")

  m.qrCode = m.top.findNode("qrCode")
  m.qrCodeUrl = m.top.findNode("qrCodeUrl")
  m.qrCodeInstructions = m.top.findNode("qrCodeInstructions")

  m.keyboard = m.top.findNode("inputKeyboard")
  m.keyboard.visible = false
  m.field = ""

  ' Store references to instruction labels for showing/hiding
  m.instructions = m.top.findNode("instructions")
  m.browserInstructions = m.top.findNode("browserInstructions")
  m.instructionsList = m.top.findNode("instructionsList")
  m.instructionsList2 = m.top.findNode("instructionsList2")
  m.instructionsList3a = m.top.findNode("instructionsList3a")
  m.instructionsList3b = m.top.findNode("instructionsList3b")
  m.instructionsList4 = m.top.findNode("instructionsList4")
  m.rokuAppHint = m.top.findNode("rokuAppHint")
  m.rokuAppHint2 = m.top.findNode("rokuAppHint2")

  m.sailsSid = ""
  m.showingManualEntry = false
  
  ' Timer to trigger next field change asynchronously
  m.nextTimer = createObject("roSGNode", "Timer")
  m.nextTimer.repeat = false
  m.nextTimer.duration = 0.1
  m.nextTimer.observeField("fire", "onNextTimerFire")
  
  ' Observe reset field to restart QR code flow
  m.top.observeField("reset", "onReset")
  
  ' Observe visible field to start QR code flow when screen becomes visible
  m.top.observeField("visible", "onVisibleChanged")
  
  ' Track if QR flow has been started to avoid starting it multiple times
  m.qrFlowStarted = false
  
  ' Start QR code flow if screen is already visible
  if m.top.visible = true
    startQRCodeFlow()
    m.qrFlowStarted = true
  end if
end function

sub onVisibleChanged(obj)
  if m.top.visible = true and not m.qrFlowStarted
    ' Screen became visible and QR flow hasn't started yet
    startQRCodeFlow()
    m.qrFlowStarted = true
  else if m.top.visible = false
    ' Screen hidden - stop QR flow and reset flag
    if m.cookieTask <> invalid
      m.cookieTask.control = "STOP"
    end if
    m.qrFlowStarted = false
  end if
end sub

sub onNextTimerFire()
  ' Set next field asynchronously to ensure observer fires
  time = CreateObject("roDateTime")
  m.top.next = "beep" + time.AsSeconds().ToStr()
  print "[PROGRESS] Set next field via timer to: " + m.top.next
  m.nextTimer.control = "stop"
end sub

sub onReset()
  if m.top.reset = true
    ' Reset state
    m.sailsSid = ""
    m.showingManualEntry = false
    m.keyboard.visible = false
    m.field = ""
    
    ' Reset button text
    m.manualEntryButton.text = "Manual Entry"
    
    ' Show QR code and instructions again
    m.qrCode.visible = true
    m.qrCodeUrl.visible = true
    m.qrCodeInstructions.visible = true
    showInstructions()
    
    ' Clear the next field so it can trigger again
    m.top.next = ""
    
    ' Stop existing cookie task if running
    if m.cookieTask <> invalid
      m.cookieTask.control = "STOP"
    end if
    
    ' Reset QR flow flag so it can start again
    m.qrFlowStarted = false
    
    ' Restart QR code flow
    startQRCodeFlow()
    m.qrFlowStarted = true
    
    ' Reset the field
    m.top.reset = false
  end if
end sub

sub startQRCodeFlow()
  ' Show QR code by default
  m.showingManualEntry = false
  m.qrCode.visible = true
  m.qrCodeUrl.visible = true
  m.qrCodeInstructions.visible = true
  m.manualEntryButton.visible = true
  m.manualEntryButton.setFocus(true)
  
  ' Start cookie entry task
  m.cookieTask = createObject("roSGNode", "cookieEntryTask")
  m.cookieTask.observeField("qrCodeUrl", "onQRCodeReady")
  m.cookieTask.observeField("serverUrl", "onServerUrlReady")
  m.cookieTask.observeField("sailsSid", "onCookieReceived")
  m.cookieTask.observeField("status", "onCookieStatusChanged")
  m.cookieTask.observeField("error", "onCookieError")
  m.cookieTask.control = "RUN"
end sub


sub onQRCodeReady(obj)
  qrUrl = obj.getData()
  if qrUrl <> invalid and qrUrl <> ""
    m.qrCode.uri = qrUrl
    m.qrCodeInstructions.text = "Scan the QR code to enter requisite cookie."
    print "[PROGRESS] QR code displayed"
  end if
end sub

sub onServerUrlReady(obj)
  serverUrl = obj.getData()
  if serverUrl <> invalid and serverUrl <> ""
    m.qrCodeUrl.text = serverUrl
    m.qrCodeUrl.visible = true
    print "[PROGRESS] Server URL displayed: " + serverUrl
  end if
end sub

sub onCookieReceived(obj)
  print "[PROGRESS] onCookieReceived called in login screen"
  sailsSid = obj.getData()
  if sailsSid <> invalid and sailsSid <> ""
    if sailsSid.Len() > 20
      print "[PROGRESS] sailsSid value: " + sailsSid.Left(20) + "..."
    else
      print "[PROGRESS] sailsSid value: " + sailsSid
    end if
    m.sailsSid = sailsSid
    ' Store the cookie in registry
    registry = RegistryUtil()
    registry.write("sails", m.sailsSid, "hydravion")
    print "[PROGRESS] Cookie stored in registry"
    
    ' Stop the cookie task (which will stop the web server)
    if m.cookieTask <> invalid
      ' The cookie task will stop the web server when it receives the cookie
      print "[PROGRESS] Cookie task will stop web server"
    end if
    
    print "[PROGRESS] sails.sid cookie received and stored, proceeding to main screen"
    ' Don't clear the field - just set it directly with a unique value
    ' Clearing it triggers the observer with empty value which we now ignore
    time = CreateObject("roDateTime")
    nextValue = "beep" + time.AsSeconds().ToStr()
    print "[PROGRESS] About to set next field to: " + nextValue
    print "[PROGRESS] Current next field value: " + m.top.next
    m.top.next = nextValue
    print "[PROGRESS] Set next field directly to: " + m.top.next
    print "[PROGRESS] Next field InStr('beep') result: " + m.top.next.InStr("beep").ToStr()
  else
    print "[PROGRESS] sailsSid is invalid or empty"
  end if
end sub

sub onCookieStatusChanged(obj)
  status = obj.getData()
  if status = "QR_CODE_READY"
    m.qrCodeInstructions.text = "Scan the QR code to enter requisite cookie."
  else if status = "COOKIE_RECEIVED"
    m.qrCodeInstructions.text = "Cookie received! Logging in..."
  else if status = "TIMEOUT"
    m.qrCodeInstructions.text = "Timeout - use manual entry instead"
  end if
end sub

sub onCookieError(obj)
  error = obj.getData()
  if error = "TIMEOUT"
    m.qrCodeInstructions.text = "Timeout - use manual entry instead"
  end if
end sub

sub onInputSailsCookie()
  m.field = "sailsSid"
  ' Clear the keyboard text
  m.keyboard.text = ""
  m.keyboard.textEditBox.text = ""
  m.keyboard.textEditBox.secureMode = false
  ' Set a high max text length to allow long cookie values
  m.keyboard.maxTextLength = 1000
  if m.keyboard.textEditBox <> invalid
    m.keyboard.textEditBox.maxTextLength = 1000
  end if
  m.keyboard.visible = true
  ' Show the submit hint above the keyboard
  m.submitHint.visible = true
  m.keyboard.setFocus(true)
  ' Hide the "Enter your sails.sid" line and move everything up to that position
  ' Store original positions if not already stored
  if m.originalPositions = invalid
    m.originalPositions = {
      instructions: m.instructions.translation[1],
      browserInstructions: m.browserInstructions.translation[1],
      instructionsList: m.instructionsList.translation[1],
      instructionsList2: m.instructionsList2.translation[1],
      instructionsList3a: m.instructionsList3a.translation[1],
      instructionsList3b: m.instructionsList3b.translation[1],
      instructionsList4: m.instructionsList4.translation[1],
      rokuAppHint: m.rokuAppHint.translation[1],
      rokuAppHint2: m.rokuAppHint2.translation[1]
    }
  end if
  ' Hide the main instruction line
  m.instructions.visible = false
  ' Move "How to get it" section to y=150 and all subsequent lines up relative to it
  ' Calculate the offset needed to move browserInstructions from its original position to y=150
  targetY = 150
  offset = targetY - m.originalPositions.browserInstructions
  print "[PROGRESS] Moving instructions up, offset: " + offset.ToStr() + ", targetY: " + targetY.ToStr()
  
  newPos = createObject("roArray", 2, false)
  newPos[0] = 200
  newPos[1] = targetY
  m.browserInstructions.translation = newPos
  
  newPos = createObject("roArray", 2, false)
  newPos[0] = 220
  newPos[1] = m.originalPositions.instructionsList + offset
  m.instructionsList.translation = newPos
  
  newPos = createObject("roArray", 2, false)
  newPos[0] = 220
  newPos[1] = m.originalPositions.instructionsList2 + offset
  m.instructionsList2.translation = newPos
  
  newPos = createObject("roArray", 2, false)
  newPos[0] = 220
  newPos[1] = m.originalPositions.instructionsList3a + offset
  m.instructionsList3a.translation = newPos
  
  newPos = createObject("roArray", 2, false)
  newPos[0] = 220
  newPos[1] = m.originalPositions.instructionsList3b + offset
  m.instructionsList3b.translation = newPos
  
  newPos = createObject("roArray", 2, false)
  newPos[0] = 220
  newPos[1] = m.originalPositions.instructionsList4 + offset
  m.instructionsList4.translation = newPos
  
  newPos = createObject("roArray", 2, false)
  newPos[0] = 200
  newPos[1] = m.originalPositions.rokuAppHint + offset
  m.rokuAppHint.translation = newPos
  
  newPos = createObject("roArray", 2, false)
  newPos[0] = 200
  newPos[1] = m.originalPositions.rokuAppHint2 + offset
  m.rokuAppHint2.translation = newPos
  ' Hide the button since keyboard is shown
  m.manualEntryButton.visible = false
end sub

sub onManualEntryButton()
  ' User clicked "Manual Entry" - go directly to keyboard input
  m.showingManualEntry = true
  m.qrCode.visible = false
  m.qrCodeUrl.visible = false
  m.qrCodeInstructions.visible = false
  onInputSailsCookie()
end sub


sub performLogin()
  if m.sailsSid = ""
    showErrorDialog("Please enter your sails.sid cookie first")
    return
  end if
  
  ' Store the cookie in registry
  registry = RegistryUtil()
  registry.write("sails", m.sailsSid, "hydravion")
  
  print "[PROGRESS] sails.sid cookie stored, proceeding to main screen"
  ' Clear the next field first
  m.top.next = ""
  ' Use timer to set next field asynchronously to ensure observer fires
  m.nextTimer.control = "start"
end sub

sub showErrorDialog(msg)
  m.top.getScene().dialog = createObject("roSGNode", "SimpleDialog")
  m.top.getScene().dialog.title = "Login Error"
  m.top.getScene().dialog.showCancel = false
  m.top.getScene().dialog.text = msg
  setupDialogPalette()
  m.top.getScene().dialog.observeField("buttonSelected","closeDialog")
end sub

sub closeDialog()
  m.top.getScene().dialog.close = true
end sub

sub setupDialogPalette()
  palette = createObject("roSGNode", "RSGPalette")
  palette.colors = {   DialogBackgroundColor: "0x152130FF"}
  m.top.getScene().dialog.palette = palette
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
  if press
    if key = "play"
      ' Play button submits the cookie when keyboard is visible
      if m.keyboard.visible = true and m.field = "sailsSid"
        if m.keyboard.text <> ""
          m.sailsSid = m.keyboard.text
          m.keyboard.visible = false
          m.submitHint.visible = false
          ' Show instructions again
          showInstructions()
          ' Perform login after entering cookie
          performLogin()
        else
          m.keyboard.visible = false
          m.submitHint.visible = false
          ' Show instructions again
          showInstructions()
          ' Go back to main screen if no text entered
          m.showingManualEntry = false
          m.qrCode.visible = true
          m.qrCodeUrl.visible = true
          m.qrCodeInstructions.visible = true
          m.manualEntryButton.setFocus(true)
        end if
        return true
      end if
    else if key = "back"
      if m.keyboard.visible = true
        if m.field = "sailsSid"
          if m.keyboard.text <> ""
            m.sailsSid = m.keyboard.text
          end if
          m.keyboard.visible = false
          m.submitHint.visible = false
          ' Show instructions again
          showInstructions()
          ' Go back to main screen
          m.showingManualEntry = false
          m.qrCode.visible = true
          m.qrCodeUrl.visible = true
          m.qrCodeInstructions.visible = true
          m.manualEntryButton.setFocus(true)
          return true
        end if
      end if
    end if
  return false
  end if
end function

sub showInstructions()
  ' Show the main instruction line again
  m.instructions.visible = true
  ' Hide submit hint
  m.submitHint.visible = false
  ' Restore original positions when keyboard is hidden
  if m.originalPositions <> invalid
    print "[PROGRESS] Restoring instructions to original positions"
    newPos = createObject("roArray", 2, false)
    newPos[0] = 200
    newPos[1] = m.originalPositions.browserInstructions
    m.browserInstructions.translation = newPos
    
    newPos = createObject("roArray", 2, false)
    newPos[0] = 220
    newPos[1] = m.originalPositions.instructionsList
    m.instructionsList.translation = newPos
    
    newPos = createObject("roArray", 2, false)
    newPos[0] = 220
    newPos[1] = m.originalPositions.instructionsList2
    m.instructionsList2.translation = newPos
    
    newPos = createObject("roArray", 2, false)
    newPos[0] = 220
    newPos[1] = m.originalPositions.instructionsList3a
    m.instructionsList3a.translation = newPos
    
    newPos = createObject("roArray", 2, false)
    newPos[0] = 220
    newPos[1] = m.originalPositions.instructionsList3b
    m.instructionsList3b.translation = newPos
    
    newPos = createObject("roArray", 2, false)
    newPos[0] = 220
    newPos[1] = m.originalPositions.instructionsList4
    m.instructionsList4.translation = newPos
    
    newPos = createObject("roArray", 2, false)
    newPos[0] = 200
    newPos[1] = m.originalPositions.rokuAppHint
    m.rokuAppHint.translation = newPos
    
    newPos = createObject("roArray", 2, false)
    newPos[0] = 200
    newPos[1] = m.originalPositions.rokuAppHint2
    m.rokuAppHint2.translation = newPos
  end if
  ' Show the button again
  m.manualEntryButton.visible = true
end sub
