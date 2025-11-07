sub init()
  m.top.functionname = "request"
end sub

sub request()
  appInfo = createObject("roAppInfo")
  version = appInfo.getVersion()
  useragent = "Hydravion (Roku) v" + version + ", CFNetwork"

  url = "https://www.floatplane.com/api/v3/auth/login"
  https = CreateObject("roUrlTransfer")
  https.RetainBodyOnError(true)
  port = CreateObject("roMessagePort")
  https.SetMessagePort(port)
  https.SetUrl(url)
  https.setCertificatesFile("common:/certs/ca-bundle.crt")
  https.AddHeader("Content-Type", "application/json")
  https.AddHeader("Accept", "application/json")
  https.AddHeader("User-Agent", useragent)
  https.initClientCertificates()

  data = {
    username: m.top.username,
    password: m.top.password
  }
  
  ' captchaToken is now always required
  if m.top.captchaToken <> invalid and m.top.captchaToken <> ""
    data.captchaToken = m.top.captchaToken
  else
    print "[PROGRESS] ERROR: captchaToken is required but not provided"
    m.top.error = "CAPTCHA_REQUIRED"
    return
  end if

  'print m.top.username
  'print m.top.password

  parsedJson = FormatJson(data)

  if https.AsyncPostFromString(parsedJson)
    while (true)
      event = wait(10000,port)
      if type(event) = "roUrlEvent"
        code = event.GetResponseCode()
        if code = 200
          response = ParseJSON(event.GetString())
          cookies = event.GetResponseHeadersArray()
          sailssid = GetCookieValueFromHeaders("sails.sid", cookies)
          if response <> invalid and response.needs2FA = true
            m.top.needstwoFA = true
          end if
          registry = RegistryUtil()
          registry.write("sails", sailssid, "hydravion")
          print "[PROGRESS] Login successful"
          m.top.cookies = "boop"
        else
          responseBody = event.GetString()
          print "[PROGRESS] Login error: " + code.ToStr() + " - " + responseBody
          ' Check if captcha is required
          if code = 403 or code = 400
            errorResponse = ParseJSON(responseBody)
            if errorResponse <> invalid and errorResponse.message <> invalid
              if errorResponse.message.InStr("captcha") >= 0 or errorResponse.message.InStr("CAPTCHA") >= 0
                m.top.error = "CAPTCHA_REQUIRED"
                exit while
              end if
            end if
          end if
          m.top.error = code.ToStr()
        end if
      else if event = invalid
        https.AsyncCancel()
      end if
    end while
  end if
end sub

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
