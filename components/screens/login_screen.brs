function init()
  m.login_text = m.top.findNode("login_text")
  if m.login_text <> invalid
    m.login_text.font.size = 50
  end if

  m.qrCode = m.top.findNode("qrCode")
  m.expirationTimerLabel = m.top.findNode("expirationTimerLabel")
  m.expirationTimer = m.top.findNode("expirationTimer")
  m.orLabel = m.top.findNode("orLabel")
  m.orLine = m.top.findNode("orLine")
  m.orLine2 = m.top.findNode("orLine2")
  m.manualEntryLabel = m.top.findNode("manualEntryLabel")
  m.verificationUriBox = m.top.findNode("verificationUriBox")
  m.verificationUriLabel = m.top.findNode("verificationUriLabel")
  ' Set smaller font for URL to prevent truncation
  if m.verificationUriLabel <> invalid
    m.verificationUriLabel.font.size = 20
  end if
  m.enterCodeLabel = m.top.findNode("enterCodeLabel")
  m.userCodeBox = m.top.findNode("userCodeBox")
  m.userCodeLabel = m.top.findNode("userCodeLabel")
  
  ' Set horizAlignment programmatically to ensure it's applied
  m.contentSectionWrapper = m.top.findNode("contentSectionWrapper")
  if m.contentSectionWrapper <> invalid
    m.contentSectionWrapper.horizAlignment = "center"
  end if
  m.contentSection = m.top.findNode("contentSection")
  if m.contentSection <> invalid
    m.contentSection.horizAlignment = "center"
    m.contentSection.vertAlignment = "center"
  end if
  
  ' Set vertAlignment and horizAlignment programmatically for dividerSection and manualEntrySection
  m.dividerSection = m.top.findNode("dividerSection")
  if m.dividerSection <> invalid
    m.dividerSection.horizAlignment = "center"
    m.dividerSection.vertAlignment = "center"
  end if
  m.manualEntrySection = m.top.findNode("manualEntrySection")
  if m.manualEntrySection <> invalid
    m.manualEntrySection.horizAlignment = "center"
    m.manualEntrySection.vertAlignment = "center"
  end if
  
  ' Center the labels inside manualEntrySection
  if m.manualEntryLabel <> invalid
    m.manualEntryLabel.horizAlign = "center"
  end if
  if m.enterCodeLabel <> invalid
    m.enterCodeLabel.horizAlign = "center"
  end if

  m.showingManualEntry = false
  
  ' Timer to trigger next field change asynchronously
  m.nextTimer = createObject("roSGNode", "Timer")
  m.nextTimer.repeat = false
  m.nextTimer.duration = 0.1
  m.nextTimer.observeField("fire", "onNextTimerFire")
  
  ' Timer for countdown display
  m.countdownTimer = createObject("roSGNode", "Timer")
  m.countdownTimer.repeat = true
  m.countdownTimer.duration = 1.0
  m.countdownTimer.observeField("fire", "onCountdownTimerFire")
  
  ' Observe reset field to restart OAuth flow
  m.top.observeField("reset", "onReset")
  
  ' Observe visible field to start OAuth flow when screen becomes visible
  m.top.observeField("visible", "onVisibleChanged")
  
  ' Track if OAuth flow has been started to avoid starting it multiple times
  m.oauthFlowStarted = false
  
  ' Start OAuth flow if screen is already visible
  if m.top.visible = true
    startOAuthFlow()
    m.oauthFlowStarted = true
  end if
end function

sub onVisibleChanged(obj)
  if m.top.visible = true and not m.oauthFlowStarted
    ' Screen became visible and OAuth flow hasn't started yet
    startOAuthFlow()
    m.oauthFlowStarted = true
  else if m.top.visible = false
    ' Screen hidden - stop OAuth flow and reset flag
    if m.oauthTask <> invalid
      m.oauthTask.control = "STOP"
    end if
    m.countdownTimer.control = "stop"
    m.oauthFlowStarted = false
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
    m.showingManualEntry = false
    m.field = ""
    
    ' Clear the next field so it can trigger again
    m.top.next = ""
    
    ' Stop existing OAuth task if running
    if m.oauthTask <> invalid
      m.oauthTask.control = "STOP"
    end if
    m.countdownTimer.control = "stop"
    
    ' Reset OAuth flow flag so it can start again
    m.oauthFlowStarted = false
    
    ' Restart OAuth flow
    startOAuthFlow()
    m.oauthFlowStarted = true
    
    ' Reset the field
    m.top.reset = false
  end if
end sub

sub refreshQRCode()
  ' Stop existing OAuth task if running
  if m.oauthTask <> invalid
    m.oauthTask.control = "STOP"
  end if
  m.countdownTimer.control = "stop"
  
  ' Switch back to timer view
  m.expirationTimerLabel.text = "Time Remaining:"
  m.expirationTimer.text = "--:--"
  m.expirationTimerLabel.visible = true
  m.expirationTimer.visible = true
  
  ' Clear manual entry fields temporarily
  m.verificationUriLabel.text = ""
  m.userCodeLabel.text = ""
  m.orLabel.visible = false
  m.orLine.visible = false
  m.orLine2.visible = false
  m.manualEntryLabel.visible = false
  m.verificationUriBox.visible = false
  m.verificationUriLabel.visible = false
  m.enterCodeLabel.visible = false
  m.userCodeBox.visible = false
  m.userCodeLabel.visible = false
  
  ' Restart OAuth flow
  m.oauthFlowStarted = false
  startOAuthFlow()
  m.oauthFlowStarted = true
end sub

sub startOAuthFlow()
  ' Show QR code by default
  m.showingManualEntry = false
  m.qrCode.visible = true
  ' Show timer
  m.expirationTimerLabel.text = "Time Remaining:"
  m.expirationTimerLabel.visible = true
  m.expirationTimer.visible = true
  m.expirationTimer.text = "--:--"
  m.orLabel.visible = false
  m.orLine.visible = false
  m.orLine2.visible = false
  m.manualEntryLabel.visible = false
  m.verificationUriBox.visible = false
  m.verificationUriLabel.visible = false
  m.enterCodeLabel.visible = false
  m.userCodeBox.visible = false
  m.userCodeLabel.visible = false
  
  ' Start OAuth device flow task
  m.oauthTask = createObject("roSGNode", "oauthDeviceTask")
  print "[PROGRESS] Setting up OAuth task observers..."
  m.oauthTask.observeField("userCode", "onUserCodeReady")
  m.oauthTask.observeField("verificationUri", "onVerificationUriReady")
  m.oauthTask.observeField("status", "onOAuthStatusChanged")
  m.oauthTask.observeField("error", "onOAuthError")
  m.oauthTask.observeField("expiresIn", "onExpiresInChanged")
  m.oauthTask.control = "RUN"
  print "[PROGRESS] OAuth task started"
end sub


sub onUserCodeReady(obj)
  userCode = obj.getData()
  if userCode <> invalid and userCode <> ""
    m.userCodeLabel.text = userCode
    print "[PROGRESS] User code: " + userCode
  end if
end sub

sub onVerificationUriReady(obj)
  verificationUri = obj.getData()
  if verificationUri <> invalid and verificationUri <> ""
    m.verificationUriLabel.text = verificationUri
    m.orLabel.visible = true
    m.orLine.visible = true
    m.orLine2.visible = true
    m.manualEntryLabel.visible = true
    m.verificationUriBox.visible = true
    m.verificationUriLabel.visible = true
    m.enterCodeLabel.visible = true
    m.userCodeBox.visible = true
    m.userCodeLabel.visible = true
    print "[PROGRESS] Verification URI: " + verificationUri
  end if
end sub

sub onOAuthStatusChanged(obj)
  status = obj.getData()
  print "[PROGRESS] OAuth status changed: " + status
  ' If status is QR_CODE_READY, set the QR code text on the component
  if status = "QR_CODE_READY" and m.oauthTask <> invalid
    verificationUriComplete = m.oauthTask.verificationUriComplete
    if verificationUriComplete <> invalid and verificationUriComplete <> ""
      ' The qrCode node is the library's QRCode component
      ' Just set the text field - the component will automatically generate the QR code
      m.qrCode.text = verificationUriComplete
    end if
  end if
  status = obj.getData()
  if status = "QR_CODE_READY"
    m.countdownTimer.control = "start"
    ' Show timer
    m.expirationTimerLabel.visible = true
    m.expirationTimer.visible = true
  else if status = "AUTHENTICATED"
    m.countdownTimer.control = "stop"
    m.expirationTimer.text = ""
    m.expirationTimerLabel.visible = false
    m.expirationTimer.visible = false
    ' Proceed to main screen
    time = CreateObject("roDateTime")
    nextValue = "beep" + time.AsSeconds().ToStr()
    m.top.next = nextValue
    print "[PROGRESS] OAuth authentication complete, proceeding to main screen"
  end if
end sub

sub onOAuthError(obj)
  error = obj.getData()
  if error = "TIMEOUT" or error = "EXPIRED"
    m.countdownTimer.control = "stop"
    ' Automatically refresh QR code
    refreshQRCode()
  else if error <> invalid and error <> ""
    m.countdownTimer.control = "stop"
    ' Automatically refresh QR code
    refreshQRCode()
  end if
end sub

sub onExpiresInChanged(obj)
  expiresIn = obj.getData()
  if expiresIn <> invalid and expiresIn <> ""
    m.expiresInSeconds = Val(expiresIn)
  end if
end sub

sub onCountdownTimerFire()
  if m.expiresInSeconds <> invalid
    if m.expiresInSeconds > 0
      minutes = m.expiresInSeconds \ 60
      seconds = m.expiresInSeconds mod 60
      timeText = minutes.ToStr() + ":" + Right("0" + seconds.ToStr(), 2)
      m.expirationTimer.text = timeText
      m.expiresInSeconds = m.expiresInSeconds - 1
    else
      m.countdownTimer.control = "stop"
      ' Automatically refresh QR code when timer expires
      refreshQRCode()
    end if
  end if
end sub

' Manual entry removed - OAuth device flow only

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
  ' No key handling needed - auto-refresh handles everything
  return false
end function

' Old showInstructions function removed - no longer needed
