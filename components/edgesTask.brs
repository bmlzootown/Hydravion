sub init()
  m.top.functionname = "request"
  m.top.bestEdge = ""
  m.etime = 9999
  m.edge = ""
end sub

function request()
  unparsed = m.top.edges
  edges = ParseJSON(unparsed)

  registry = RegistryUtil()
  sails = registry.read("sails", "hydravion")
  cookies = "sails.sid=" + sails

  for each edge in edges.edges
    m.https = CreateObject("roUrlTransfer")
    'm.https.RetainBodyOnError(true)
    m.https.setCertificatesFile("common:/certs/ca-bundle.crt")
    m.https.initClientCertificates()
    m.https.AddHeader("Cookie", cookies)
    m.https.AddHeader("User-Agent", "Hydravion (Roku), CFNetwork")
    port = CreateObject("roMessagePort")
    m.https.SetMessagePort(port)
    host = edge.hostname.Split(".")
    hostname = host[0] + "-query." + host[1] + "." + host[2]
    url = "https://" + hostname
    ? "[EdgeTask] URL: " + url
    m.https.SetUrl(url)
    start_date = CreateObject("roDateTime")
    start_time = start_date.GetMilliseconds()
    if (m.https.AsyncGetToString())
      event = wait(500, m.https.GetPort())
      if type(event) = "roUrlEvent"
        end_date = CreateObject("roDateTime")
        end_time = end_date.GetMilliseconds()
        time = end_time - start_time
        ? "[EdgeTask] Edge: " + edge.hostname
        ? "[EdgeTask] Time: " + time.ToStr()
        'if time > 0 then
          if time < m.etime then
            m.etime = time
            m.edge = edge.hostname
          end if
        'end if
      end if
    end if
  end for

  m.top.bestEdge = m.edge

end function
