sub init()
  m.top.functionname = "request"
end sub

function request()
  video = createObject("roUrlTransfer")
  video.SetCertificatesFile("common:/certs/ca-bundle.crt")
  video.InitClientCertificates()
  video.SetUrl(m.top.url)
  port = CreateObject("roMessagePort")
  video.SetMessagePort(port)
  if video.AsyncGetToString()
    event = wait(10000, port)
    if type(event) = "roUrlEvent"
      m3u8 = event.GetString()
      if m3u8 <> invalid and m3u8.Len() > 0
        WriteAsciiFile("tmp:/live.m3u8", m3u8)
      end if
    end if
  end if
  m.top.done = true
end function
