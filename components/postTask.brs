sub init()
    m.top.functionname = "post"
    m.top.response = ""
  end sub
  
  function post()
    registry = RegistryUtil()
    sails = registry.read("sails", "hydravion")
    if sails = invalid then
      m.top.error = "Invalid SAILS cookie!"
    end if
    cookies = "sails.sid=" + sails
  
    https = CreateObject("roUrlTransfer")
    https.RetainBodyOnError(true)
    port = CreateObject("roMessagePort")
    https.SetMessagePort(port)
    https.SetUrl(m.top.url)
    https.setCertificatesFile("common:/certs/ca-bundle.crt")
    https.AddHeader("Content-Type", "text/plain")
    https.AddHeader("User-Agent", "Hydravion (Roku), CFNetwork")
    https.AddHeader("Cookie", cookies)
    https.initClientCertificates()
    
    parsedJson = FormatJson(m.top.body)
    
    if https.AsyncPostFromString(parsedJson)
        while (true)
            event = wait(5000,port)
            if type(event) = "roUrlEvent"
                code = event.GetResponseCode()
                if code = 200
                    m.top.response = event.GetString()
                else
                     m.top.error = event.GetString()
                 end if
            else if event = invalid
                https.AsyncCancel()
            end if
        end while
    end if
  end function
  