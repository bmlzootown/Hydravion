' Validates the access token with the server by calling a lightweight authenticated endpoint.
' 200 = valid, 401 = invalid (tokens cleared). Run in a Task so network is off render thread.
sub init()
  m.top.functionName = "validate"
end sub

sub validate()
  tokenUtilObj = TokenUtil()
  accessToken = tokenUtilObj.getAccessToken(false)
  if accessToken = invalid then
    m.top.isValid = false
    m.top.error = "Not authenticated"
    m.top.done = true
    return
  end if

  appInfo = createObject("roAppInfo")
  version = appInfo.getVersion()
  useragent = "Hydravion (Roku) v" + version
  apiConfigObj = ApiConfig()
  url = apiConfigObj.buildApiUrl("/api/v3/user/subscriptions")

  xfer = CreateObject("roUrlTransfer")
  xfer.RetainBodyOnError(true)
  port = CreateObject("roMessagePort")
  xfer.SetMessagePort(port)
  xfer.SetUrl(url)
  xfer.setCertificatesFile("common:/certs/ca-bundle.crt")
  xfer.AddHeader("Accept", "application/json")
  xfer.AddHeader("User-Agent", useragent)
  xfer.AddHeader("Authorization", "Bearer " + accessToken)
  xfer.initClientCertificates()

  if not xfer.AsyncGetToString() then
    m.top.isValid = false
    m.top.error = "Request failed"
    m.top.done = true
    return
  end if

  event = wait(10000, port)
  if type(event) <> "roUrlEvent" then
    if event = invalid then
      xfer.AsyncCancel()
    end if
    m.top.isValid = false
    m.top.error = "Timeout or cancelled"
    m.top.done = true
    return
  end if

  code = event.GetResponseCode()
  if code = 200 then
    m.top.isValid = true
    m.top.done = true
    return
  end if

  if code = 401 then
    tokenUtilObj = TokenUtil()
    tokenUtilObj.clearTokens()
    m.top.isValid = false
    m.top.error = "Token rejected by server (401)"
  else
    m.top.isValid = false
    m.top.error = "Unexpected response " + code.ToStr()
  end if
  m.top.done = true
end sub
