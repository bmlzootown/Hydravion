sub init()
  m.top.functionname = "request"
  m.webServer = invalid
end sub

function request()
  ' Generate a unique session ID if not provided
  if m.top.sessionId = invalid or m.top.sessionId = ""
    m.top.sessionId = generateSessionId()
  end if
  
  ' Start local web server
  startLocalWebServer()
  
  ' Wait for server to start and get URL
  ' Poll for server URL (it's set asynchronously)
  maxWait = 10
  waitCount = 0
  serverUrl = invalid
  
  while waitCount < maxWait
    if m.webServer <> invalid
      serverUrl = m.webServer.serverUrl
      if serverUrl <> invalid and serverUrl <> ""
        exit while
      end if
    end if
    sleep(100)
    waitCount = waitCount + 1
  end while
  
  ' Fallback to device IP if server URL not available
  if serverUrl = invalid or serverUrl = ""
    deviceInfo = CreateObject("roDeviceInfo")
    ipAddrs = deviceInfo.GetIPAddrs()  ' Returns associative array
    
    serverIp = "127.0.0.1"  ' Default fallback
    
    if ipAddrs <> invalid
      ' Try to get IP from common interfaces
      if ipAddrs.DoesExist("eth0")
        serverIp = ipAddrs["eth0"]
      else if ipAddrs.DoesExist("wlan0")
        serverIp = ipAddrs["wlan0"]
      else if ipAddrs.Count() > 0
        ' Get first available IP address
        for each iface in ipAddrs
          serverIp = ipAddrs[iface]
          exit for
        end for
      end if
    end if
    
    serverUrl = "http://" + serverIp + ":8888"
    print "[PROGRESS] Using fallback server URL: " + serverUrl
  end if
  
  ' Generate QR code URL pointing to local server
  qrData = serverUrl + "/?session=" + m.top.sessionId
  
  ' Generate QR code image URL using a QR code API
  ' Use roUrlTransfer to escape the URL
  urlTransfer = CreateObject("roUrlTransfer")
  escapedData = urlTransfer.Escape(qrData)
  qrCodeApiUrl = "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=" + escapedData
  m.top.qrCodeUrl = qrCodeApiUrl
  m.top.status = "QR_CODE_READY"
  
  print "[PROGRESS] QR code generated for session: " + m.top.sessionId
  print "[PROGRESS] Server URL: " + serverUrl
  print "[PROGRESS] User should scan QR code and complete CloudFlare challenge"
  
  ' Poll for captchaToken
  pollForCaptchaToken()
  
  ' Only stop web server if authentication was received or there was an error
  ' Don't stop on timeout - user might still be trying to access the page
  if m.webServer <> invalid
    if m.top.status = "AUTH_RECEIVED" or (m.top.error <> invalid and m.top.error <> "TIMEOUT")
      m.webServer.isRunning = false
      print "[PROGRESS] Stopping web server - authentication complete or error occurred"
    else
      print "[PROGRESS] Keeping web server running - user may still be accessing the page"
      ' Keep server running for a bit longer to allow user to complete authentication
      ' The server will stop when the task is destroyed or when explicitly stopped
    end if
  end if
end function

function startLocalWebServer()
  ' Create and start local web server
  m.webServer = createObject("roSGNode", "localWebServerTask")
  m.webServer.setField("port", 8888)
  m.webServer.setField("sessionId", m.top.sessionId)
  m.webServer.control = "RUN"
  
  print "[PROGRESS] Starting local web server..."
end function

function generateSessionId() as String
  ' Generate a unique session ID using timestamp and random number
  dateTime = CreateObject("roDateTime")
  timestamp = dateTime.AsSeconds().ToStr()
  random = Rnd(999999).ToStr()
  return timestamp + "-" + random
end function

function pollForCaptchaToken()
  ' Poll the local server endpoint for the authentication result
  ' Get server URL from web server task
  serverUrl = "http://127.0.0.1:8888"
  if m.webServer <> invalid
    serverUrlFromTask = m.webServer.serverUrl
    if serverUrlFromTask <> invalid and serverUrlFromTask <> ""
      serverUrl = serverUrlFromTask
    end if
  end if
  
  pollUrl = serverUrl + "/api/auth?session=" + m.top.sessionId
  
  appInfo = createObject("roAppInfo")
  version = appInfo.getVersion()
  useragent = "Hydravion (Roku) v" + version + ", CFNetwork"
  
  maxAttempts = 40  ' Poll for up to 2 minutes (40 * 3 seconds)
  attempt = 0
  
  while attempt < maxAttempts
    https = CreateObject("roUrlTransfer")
    https.RetainBodyOnError(true)
    port = CreateObject("roMessagePort")
    https.SetMessagePort(port)
    https.SetUrl(pollUrl)
    https.setCertificatesFile("common:/certs/ca-bundle.crt")
    https.AddHeader("Accept", "application/json")
    https.AddHeader("User-Agent", useragent)
    https.initClientCertificates()
    
    if https.AsyncGetToString()
      event = wait(3000, port)  ' Wait 3 seconds between polls to reduce server load
      if type(event) = "roUrlEvent"
        code = event.GetResponseCode()
        if code = 200
          response = ParseJSON(event.GetString())
          if response <> invalid and response.sailsSid <> invalid and response.sailsSid <> ""
            ' Authentication result received - store it
            m.top.captchaToken = response.sailsSid  ' Reuse field to pass sailsSid
            m.top.status = "AUTH_RECEIVED"
            print "[PROGRESS] Authentication received"
            exit while
          end if
        else if code = 404
          ' Session not found yet, continue polling
          m.top.status = "WAITING"
        else
          print "[PROGRESS] Poll error: " + code.ToStr()
        end if
      end if
    end if
    
    attempt = attempt + 1
  end while
  
  if m.top.captchaToken = invalid or m.top.captchaToken = ""
    m.top.error = "TIMEOUT"
    m.top.status = "TIMEOUT"
    print "[PROGRESS] Polling timeout - authentication not received"
  end if
end function

