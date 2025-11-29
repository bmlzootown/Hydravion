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
  
    apiConfigObj = ApiConfig()
    https = CreateObject("roUrlTransfer")
    https.RetainBodyOnError(true)
    port = CreateObject("roMessagePort")
    https.SetMessagePort(port)
    if m.top.do = "like"
        https.SetUrl(apiConfigObj.buildApiUrl("/api/v3/content/like"))
    else
        https.SetUrl(apiConfigObj.buildApiUrl("/api/v3/content/dislike"))
    end if
    https.setCertificatesFile("common:/certs/ca-bundle.crt")
    https.AddHeader("Content-Type", "application/json")
    https.AddHeader("User-Agent", useragent)
    https.AddHeader("Authorization", "Bearer " + accessToken)
    https.initClientCertificates()

    body = {"contentType": "blogPost", "id": m.top.id }
    postJSON = FormatJson(body)
  
    if https.AsyncPostFromString(postJSON)
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
  