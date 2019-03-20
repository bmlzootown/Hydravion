sub init()
  m.top.functionname = "request"
  m.top.response = ""
end sub

function request()
  registry = RegistryUtil()
  registry.deleteSection("hydravion")

  https = CreateObject("roUrlTransfer")
  https.SetUrl("http://localhost:8060/keypress/home")
  https.PostFromString("")
end function
