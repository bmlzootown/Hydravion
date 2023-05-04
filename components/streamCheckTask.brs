sub init()
  m.top.functionname = "request"
  m.top.response = ""
end sub

function request()
  appInfo = createObject("roAppInfo")
  version = appInfo.getVersion()
  useragent = "Hydravion (Roku) v" + version + ", CFNetwork"

  registry = RegistryUtil()
  sails = registry.read("sails", "hydravion")
  cookies = "sails.sid=" + sails

  response = fetch({
    url: m.top.url,
    timeout: 3000,
    method: "GET",
    headers: {
        "User-Agent": useragent,
        "Cookie": cookies
    }
  })
  ''? response.status
  if response.ok
    if response.status <> 200
      m.top.error = "false"
      ''? response.text()
    else
      m.top.response = "true"
    end if
  else
    m.top.error = "false"
    ''? response.text()
  end if
end function

'' Usage of roku-fetch (https://github.com/briandunnington/roku-fetch)
function fetch(options)
    timeout = options.timeout
    if timeout = invalid then timeout = 0

    response = invalid
    port = CreateObject("roMessagePort")
    re = CreateObject("roUrlTransfer")
    re.SetCertificatesFile("common:/certs/ca-bundle.crt")
    re.InitClientCertificates()
    re.RetainBodyOnError(true)
    re.SetMessagePort(port)
    if options.headers <> invalid
        for each header in options.headers
            val = options.headers[header]
            if val <> invalid then re.addHeader(header, val)
        end for
    end if
    if options.method <> invalid
        re.setRequest(options.method)
    end if
    re.SetUrl(options.url)

    requestSent = invalid
    if options.body <> invalid
        requestSent = re.AsyncPostFromString(options.body)
    else
        requestSent = re.AsyncGetToString()
    end if
    if (requestSent)
        msg = wait(timeout, port)
        status = -999
        body = "(TIMEOUT)"
        headers = {}
        if (type(msg) = "roUrlEvent")
            status = msg.GetResponseCode()
            headersArray = msg.GetResponseHeadersArray()
            for each headerObj in headersArray
                for each headerName in headerObj
                    val = {
                        value: headerObj[headerName]
                        next: invalid
                    }
                    current = headers[headerName]
                    if current <> invalid
                        prev = current
                        while current <> invalid
                            prev = current
                            current = current.next
                        end while
                        prev.next = val
                    else
                        headers[headerName] = val
                    end if
                end for
            end for
            body = msg.GetString()
            if status < 0 then body = msg.GetFailureReason()
        end if

        response = {
            _body: body,
            status: status,
            ok: (status >= 200 AND status < 300),
            headers: headers,
            text: function()
                return m._body
            end function,
            json: function()
                return ParseJSON(m._body)
            end function,
            xml: function()
                if m._body = invalid then return invalid
                xml = CreateObject("roXMLElement") '
                if NOT xml.Parse(m._body) then return invalid
                return xml
            end function
        }
    end if

    return response
end function
