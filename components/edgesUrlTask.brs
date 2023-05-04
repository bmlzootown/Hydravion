sub init()
  m.top.functionname = "request"
  m.top.response = ""
end sub

function request()
  appInfo = createObject("roAppInfo")
  version = appInfo.getVersion()
  useragent = "Hydravion (Roku) v" + version + ", CFNetwork"

  https = CreateObject("roUrlTransfer")
  https.SetUrl(m.top.url)
  'print m.top.url
  https.setCertificatesFile("common:/certs/ca-bundle.crt")
  https.AddHeader("Accept", "application/json")
  https.AddHeader("User-Agent", useragent)
  https.initClientCertificates()

  response = https.GetToString()
  m.top.response = response
end function
