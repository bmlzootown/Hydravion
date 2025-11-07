function init()
  m.webServer = invalid
  m.top.functionName = "request"
end function

sub request()
  ' Start local web server
  startLocalWebServer()
  
  ' Wait a moment for server to start
  sleep(500)
  
  ' Get device IP address
  deviceInfo = CreateObject("roDeviceInfo")
  ipAddrs = deviceInfo.GetIPAddrs()
  
  serverUrl = invalid
  if ipAddrs <> invalid
    ' Try eth0 first (wired)
    if ipAddrs["eth0"] <> invalid
      serverUrl = "http://" + ipAddrs["eth0"] + ":8888"
    else if ipAddrs["wlan0"] <> invalid
      serverUrl = "http://" + ipAddrs["wlan0"] + ":8888"
    else
      ' Use first available interface
      for each iface in ipAddrs
        serverUrl = "http://" + ipAddrs[iface] + ":8888"
        exit for
      end for
    end if
  end if
  
  if serverUrl = invalid
    serverUrl = "http://127.0.0.1:8888"
  end if
  
  ' Generate QR code URL pointing to local server (no session ID needed)
  qrData = serverUrl
  
  ' Generate QR code image URL using a QR code API
  urlTransfer = CreateObject("roUrlTransfer")
  escapedData = urlTransfer.Escape(qrData)
  qrCodeApiUrl = "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=" + escapedData
  m.top.qrCodeUrl = qrCodeApiUrl
  m.top.status = "QR_CODE_READY"
  
  print "[PROGRESS] QR code generated"
  print "[PROGRESS] Server URL: " + serverUrl
  print "[PROGRESS] User should scan QR code and enter sails.sid cookie"
  
  ' Poll for cookie
  pollForCookie()
end sub

sub startLocalWebServer()
  m.webServer = createObject("roSGNode", "localWebServerTask")
  m.webServer.setField("port", 8888)
  m.webServer.observeField("sailsSid", "onCookieReceived")
  m.webServer.control = "RUN"
end sub

sub onCookieReceived(obj)
  sailsSid = obj.getData()
  if sailsSid <> invalid and sailsSid <> ""
    m.top.sailsSid = sailsSid
    m.top.status = "COOKIE_RECEIVED"
    print "[PROGRESS] Cookie received from QR code: " + sailsSid.Left(20) + "..."
    ' Stop the web server
    if m.webServer <> invalid
      m.webServer.setField("isRunning", false)
      print "[PROGRESS] Stopping web server after receiving cookie"
    end if
    ' Stop polling since we got the cookie
    return
  end if
end sub

sub pollForCookie()
  maxAttempts = 120  ' 2 minutes at 1 second intervals
  wait = 1000  ' 1 second
  
  for i = 0 to maxAttempts - 1
    ' Check if cookie was received (either via observer or polling)
    if m.top.sailsSid <> invalid and m.top.sailsSid <> ""
      ' Cookie received
      if m.top.status <> "COOKIE_RECEIVED"
        m.top.status = "COOKIE_RECEIVED"
        print "[PROGRESS] Cookie received via polling"
      end if
      ' Stop the web server
      if m.webServer <> invalid
        m.webServer.setField("isRunning", false)
        print "[PROGRESS] Stopping web server after receiving cookie"
      end if
      return
    end if
    
    sleep(wait)
  end for
  
  ' Timeout
  if m.top.sailsSid = invalid or m.top.sailsSid = ""
    m.top.status = "TIMEOUT"
    m.top.error = "TIMEOUT"
    print "[PROGRESS] Polling timeout - user did not enter cookie"
    ' Stop the web server on timeout too
    if m.webServer <> invalid
      m.webServer.setField("isRunning", false)
      print "[PROGRESS] Stopping web server after timeout"
    end if
  end if
end sub

