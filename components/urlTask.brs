sub init()
  m.top.functionname = "request"
  m.top.response = ""
end sub

function request()
  registry = RegistryUtil()
  cfduid = registry.read("cfduid", "hydravion")
  sails = registry.read("sails", "hydravion")
  cookies = "__cfduid=" + cfduid + "; sails.sid=" + sails
  https = CreateObject("roUrlTransfer")
  https.SetUrl(m.top.url)
  'print m.top.url
  https.setCertificatesFile("common:/certs/ca-bundle.crt")
  https.AddHeader("Accept", "application/json")
  https.AddHeader("Cookie", cookies)
  https.initClientCertificates()

  response = https.GetToString()
  m.top.response = response
end function
