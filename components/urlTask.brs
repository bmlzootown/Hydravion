sub init()
  m.top.functionname = "request"
  m.top.response = ""
end sub

'function request()
''  registry = RegistryUtil()
''  cfduid = registry.read("cfduid", "hydravion")
''  sails = registry.read("sails", "hydravion")
''  cookies = "__cfduid=" + cfduid + "; sails.sid=" + sails
''  https = CreateObject("roUrlTransfer")
''  https.SetUrl(m.top.url)
''  'print m.top.url
''  https.setCertificatesFile("common:/certs/ca-bundle.crt")
''  https.AddHeader("Accept", "application/json")
''  https.AddHeader("Cookie", cookies)
''  https.initClientCertificates()
''
''  response = https.GetToString()
''  m.top.response = response
'end function

function request()
  registry = RegistryUtil()
  cfduid = registry.read("cfduid", "hydravion")
  sails = registry.read("sails", "hydravion")
  cookies = "__cfduid=" + cfduid + "; sails.sid=" + sails

  https = CreateObject("roUrlTransfer")
  https.RetainBodyOnError(true)
  port = CreateObject("roMessagePort")
  https.SetMessagePort(port)
  https.SetUrl(m.top.url)
  https.setCertificatesFile("common:/certs/ca-bundle.crt")
  https.AddHeader("Accept", "application/json")
  https.AddHeader("User-Agent", "Hydravion (Roku)")
  https.AddHeader("Cookie", cookies)
  https.initClientCertificates()

  if https.AsyncGetToString()
    while (true)
      event = wait(10000,port)
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
