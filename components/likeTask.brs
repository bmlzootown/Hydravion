sub init()
    m.top.functionname = "request"
    m.top.response = ""
  end sub
  
  function request()
    registry = RegistryUtil()
    sails = registry.read("sails", "hydravion")
    cookies = "sails.sid=" + sails

    appInfo = createObject("roAppInfo")
    version = appInfo.getVersion()
    useragent = "Hydravion (Roku) v" + version + ", CFNetwork"
  
    https = CreateObject("roUrlTransfer")
    https.RetainBodyOnError(true)
    port = CreateObject("roMessagePort")
    https.SetMessagePort(port)
    if m.top.do = "like"
        https.SetUrl("https://beta.floatplane.com/api/v3/content/like")
    else
        https.SetUrl("https://beta.floatplane.com/api/v3/content/dislike")
    end if
    https.setCertificatesFile("common:/certs/ca-bundle.crt")
    https.AddHeader("Content-Type", "application/json")
    https.AddHeader("User-Agent", useragent)
    https.AddHeader("Cookie", cookies)
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
  end function
  