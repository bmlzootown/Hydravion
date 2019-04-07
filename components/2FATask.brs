sub init()
  m.top.functionname = "request"
end sub

function request()
  registry = RegistryUtil()
  cfduid = registry.read("cfduid", "hydravion")
  sails = registry.read("sails", "hydravion")
  cookies = "__cfduid=" + cfduid + "; sails.sid=" + sails

  url = "https://www.floatplane.com/api/auth/checkFor2faLogin"
  https = CreateObject("roUrlTransfer")
  https.RetainBodyOnError(true)
  port = CreateObject("roMessagePort")
  https.SetMessagePort(port)
  https.SetUrl(url)
  https.setCertificatesFile("common:/certs/ca-bundle.crt")
  https.AddHeader("Content-Type", "application/json")
  https.AddHeader("Cookie", cookies)
  https.initClientCertificates()

  data = {
    token: m.top.token
  }

  parsedJson = FormatJson(data)

  if https.AsyncPostFromString(parsedJson)
    while (true)
      event = wait(10000,port)
      if type(event) = "roUrlEvent"
        code = event.GetResponseCode()
        if code = 200
          cookies = event.GetResponseHeadersArray()
          sailssid = GetCookieValueFromHeaders("sails.sid", cookies)
          registry.write("sails", sailssid, "hydravion")
          'print "2FATask done!"
          m.top.updatedCookies = "boop"
        else
          m.top.error = code
        end if
      else if event = invalid
        https.AsyncCancel()
      end if
    end while
  end if
end function

Function GetCookieValueFromHeaders( cookieName As String, headersArray As Object ) As String
   cookieValue = ""
   For Each header in headersArray
      If header[ "Set-Cookie" ] <> invalid And header[ "Set-Cookie" ].InStr( cookieName + "=" ) = 0 Then
         cookieValue = header[ "Set-Cookie" ].Mid( cookieName.Len() + 1 )
         cookieValue = cookieValue.Mid( 0, cookieValue.InStr( ";" ) )
         Exit For
      End If
   Next
   Return cookieValue
End Function
