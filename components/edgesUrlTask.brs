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
  https.initClientCertificates()

  response = https.GetToString()
  m.top.response = response
end function
