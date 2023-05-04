sub init()
  m.top.functionname = "request"
  m.top.response = ""
end sub

function request()
  registry = RegistryUtil()
  sails = registry.read("sails", "hydravion")
  if sails = invalid then
    m.top.error = "Invalid SAILS cookie!"
  end if
  cookies = "sails.sid=" + sails

  appInfo = createObject("roAppInfo")
  version = appInfo.getVersion()
  useragent = "Hydravion (Roku) v" + version + ", CFNetwork"

  https = CreateObject("roUrlTransfer")
  https.RetainBodyOnError(true)
  port = CreateObject("roMessagePort")
  https.SetMessagePort(port)
  https.SetUrl(m.top.url)
  https.setCertificatesFile("common:/certs/ca-bundle.crt")
  https.AddHeader("Accept", "application/json")
  https.AddHeader("User-Agent", useragent)
  https.AddHeader("Cookie", cookies)
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

  'https.AsyncGetToString()
  'event = wait(5000,port)
  'if event = invalid then
  ''  m.top.error = "invalid"
  ''  https.AsyncCancel()
  'else
  ''  if type(event) = "roUrlEvent"
  ''    code = event.GetResponseCode()
  ''    if code = 200
  ''      m.top.response = event.GetString()
  ''    else
  ''      m.top.error = event.GetString()
  ''    end if
  ''  end if
  'end if
end function
