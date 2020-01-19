sub init()
  m.top.functionname = "request"
end sub

function request()
  video = createObject("roUrlTransfer")
  video.SetCertificatesFile("common:/certs/ca-bundle.crt")
  video.InitClientCertificates()
  video.SetUrl(m.top.url)
  m3u8 = video.GetToString()
  WriteAsciiFile("tmp:/live.m3u8", m3u8)
  
  m.top.done = true
end function
