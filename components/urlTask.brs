sub init()
  m.top.functionname = "request"
  m.top.response = ""
end sub

function request()
  ' Get Bearer token using TokenUtil
  tokenUtilObj = TokenUtil()
  accessToken = tokenUtilObj.getAccessToken()
  if accessToken = invalid then
    m.top.error = "Not authenticated - please login"
    return ""
  end if

  appInfo = createObject("roAppInfo")
  version = appInfo.getVersion()
  useragent = "Hydravion (Roku) v" + version

  https = CreateObject("roUrlTransfer")
  https.RetainBodyOnError(true)
  port = CreateObject("roMessagePort")
  https.SetMessagePort(port)
  https.SetUrl(m.top.url)
  https.setCertificatesFile("common:/certs/ca-bundle.crt")
  https.AddHeader("Accept", "application/json")
  https.AddHeader("User-Agent", useragent)
  https.AddHeader("Authorization", "Bearer " + accessToken)
  https.initClientCertificates()

  if https.AsyncGetToString()
    while (true)
      event = wait(5000,port)
      if type(event) = "roUrlEvent"
        code = event.GetResponseCode()
        if code = 200
          m.top.response = event.GetString()
        else
          m.top.error = event.GetString()
          ? m.top.error
        end if
      else if event = invalid
        https.AsyncCancel()
      end if
    end while
  end if
  return ""
end function
