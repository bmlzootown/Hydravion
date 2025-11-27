sub init()
  m.top.functionName = "request"
end sub

sub request()
  ' Request device authorization
  deviceAuthResponse = requestDeviceAuthorization()
  if deviceAuthResponse = invalid
    ' Error details are already logged in requestDeviceAuthorization
    ' Set a generic error - the actual error message is in the logs
    m.top.error = "Failed to request device authorization"
    return
  end if
  
  deviceCode = deviceAuthResponse.device_code
  userCode = deviceAuthResponse.user_code
  verificationUriComplete = deviceAuthResponse.verification_uri_complete
  expiresIn = deviceAuthResponse.expires_in
  interval = deviceAuthResponse.interval
  
  ' Pass verification URI to main thread for QR code generation
  m.top.verificationUriComplete = verificationUriComplete
  m.top.userCode = userCode
  m.top.verificationUri = deviceAuthResponse.verification_uri
  m.top.status = "QR_CODE_READY"
  
  print "[OAUTH] OAuth device flow started"
  print "[OAUTH] User code: " + userCode
  
  ' Poll for token
  pollForToken(deviceCode, interval, expiresIn)
end sub

function requestDeviceAuthorization() as Object
  appInfo = createObject("roAppInfo")
  version = appInfo.getVersion()
  useragent = "Hydravion (Roku) v" + version
  
  apiConfigObj = ApiConfig()
  url = apiConfigObj.buildRealmAuthUrl("openid-connect/auth/device")
  https = CreateObject("roUrlTransfer")
  https.RetainBodyOnError(true)
  port = CreateObject("roMessagePort")
  https.SetMessagePort(port)
  https.SetUrl(url)
  https.setCertificatesFile("common:/certs/ca-bundle.crt")
  https.AddHeader("Content-Type", "application/x-www-form-urlencoded")
  https.AddHeader("Accept", "application/json")
  https.AddHeader("User-Agent", useragent)
  https.initClientCertificates()
  
  ' Send client_id as form data
  postData = "client_id=hydravion"
  
  if https.AsyncPostFromString(postData)
    while (true)
      event = wait(10000, port)
      if type(event) = "roUrlEvent"
        code = event.GetResponseCode()
        if code = 200
          response = ParseJSON(event.GetString())
          return response
        else
          responseBody = event.GetString()
          print "[OAUTH] Device authorization error: " + code.ToStr() + " - " + responseBody
          ' Parse error to pass more specific information
          errorResponse = ParseJSON(responseBody)
          if errorResponse <> invalid and errorResponse.error <> invalid
            ' Pass the specific error type to the main thread
            m.top.error = errorResponse.error
          else
            m.top.error = "Failed to request device authorization"
          end if
          return invalid
        end if
      else if event = invalid
        https.AsyncCancel()
        return invalid
      end if
    end while
  end if
  
  return invalid
end function

sub pollForToken(deviceCode as String, intervalSeconds as Integer, expiresInSeconds as Integer)
  ' Convert interval to milliseconds for sleep
  intervalMs = intervalSeconds * 1000
  if intervalMs < 1000
    intervalMs = 1000  ' Minimum 1 second
  end if
  
  ' Calculate expiration time
  startTime = CreateObject("roDateTime")
  startTimeSeconds = startTime.AsSeconds()
  expirationTime = startTimeSeconds + expiresInSeconds
  
  ' Poll until token is received or expired
  while (true)
    ' Check if expired
    currentTime = CreateObject("roDateTime")
    currentTimeSeconds = currentTime.AsSeconds()
    if currentTimeSeconds >= expirationTime
      m.top.error = "TIMEOUT"
      m.top.status = "TIMEOUT"
      print "[OAUTH] OAuth device flow expired"
      return
    end if
    
    ' Calculate remaining time
    remainingSeconds = expirationTime - currentTimeSeconds
    m.top.expiresIn = remainingSeconds.ToStr()
    
    ' Request token
    tokenResponse = requestToken(deviceCode)
    if tokenResponse <> invalid
      ' Success! Store tokens
      registry = RegistryUtil()
      registry.write("access_token", tokenResponse.access_token, "hydravion")
      registry.write("refresh_token", tokenResponse.refresh_token, "hydravion")
      
      ' Store expiration time (current time + expires_in)
      tokenExpirationTime = currentTimeSeconds + tokenResponse.expires_in
      registry.write("token_expires_at", tokenExpirationTime.ToStr(), "hydravion")
      
      ' Store refresh token expiration
      ' If refresh_expires_in is 0, use 30-day idle limit (will be extended on each refresh)
      if tokenResponse.refresh_expires_in <> invalid and tokenResponse.refresh_expires_in > 0
        refreshExpirationTime = currentTimeSeconds + tokenResponse.refresh_expires_in
        registry.write("refresh_token_expires_at", refreshExpirationTime.ToStr(), "hydravion")
        refreshDays = tokenResponse.refresh_expires_in \ 86400
        print "[OAUTH] Refresh token expires in " + refreshDays.ToStr() + " days (from API)"
      else
        refreshExpirationTime = currentTimeSeconds + (30 * 24 * 60 * 60)  ' 30 days in seconds
        registry.write("refresh_token_expires_at", refreshExpirationTime.ToStr(), "hydravion")
        print "[OAUTH] Refresh token has 30-day idle limit (refresh_expires_in=0), expiration set to 30 days from now"
      end if
      
      m.top.status = "AUTHENTICATED"
      print "[OAUTH] OAuth authentication successful"
      return
    end if
    
    ' Wait before next poll
    sleep(intervalMs)
  end while
end sub

function requestToken(deviceCode as String) as Object
  appInfo = createObject("roAppInfo")
  version = appInfo.getVersion()
  useragent = "Hydravion (Roku) v" + version
  
  apiConfigObj = ApiConfig()
  url = apiConfigObj.buildRealmAuthUrl("openid-connect/token")
  https = CreateObject("roUrlTransfer")
  https.RetainBodyOnError(true)
  port = CreateObject("roMessagePort")
  https.SetMessagePort(port)
  https.SetUrl(url)
  https.setCertificatesFile("common:/certs/ca-bundle.crt")
  https.AddHeader("Content-Type", "application/x-www-form-urlencoded")
  https.AddHeader("Accept", "application/json")
  https.AddHeader("User-Agent", useragent)
  https.initClientCertificates()
  
  ' Send grant_type and device_code as form data
  postData = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Adevice_code&client_id=hydravion&device_code=" + https.Escape(deviceCode)
  
  if https.AsyncPostFromString(postData)
    while (true)
      event = wait(10000, port)
      if type(event) = "roUrlEvent"
        code = event.GetResponseCode()
        if code = 200
          response = ParseJSON(event.GetString())
          return response
        else if code = 400
          ' 400 might mean authorization_pending (user hasn't authorized yet)
          ' or expired_token, or other errors
          responseBody = event.GetString()
          errorResponse = ParseJSON(responseBody)
          if errorResponse <> invalid and errorResponse.error <> invalid
            if errorResponse.error = "authorization_pending"
              ' User hasn't authorized yet, continue polling
              return invalid
            else if errorResponse.error = "expired_token"
              m.top.error = "EXPIRED"
              m.top.status = "EXPIRED"
              return invalid
            else
              ' Other error
              print "[OAUTH] Token request error: " + errorResponse.error
              return invalid
            end if
          end if
          return invalid
        else
          responseBody = event.GetString()
          print "[OAUTH] Token request error: " + code.ToStr() + " - " + responseBody
          return invalid
        end if
      else if event = invalid
        https.AsyncCancel()
        return invalid
      end if
    end while
  end if
  
  return invalid
end function

