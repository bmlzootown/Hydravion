sub init()
  m.top.functionname = "request"
  m.top.response = ""
end sub

function request()
  https = CreateObject("roUrlTransfer")
  https.SetUrl(m.top.url)
  'print m.top.url
  https.setCertificatesFile("common:/certs/ca-bundle.crt")
  https.AddHeader("Accept", "application/json")
  https.AddHeader("User-Agent", "Hydravion (Roku), CFNetwork")
  https.initClientCertificates()

  response = https.GetToString()
  m.top.response = response
end function
