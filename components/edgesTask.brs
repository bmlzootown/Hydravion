sub init()
  m.top.functionname = "request"
  m.top.response = ""
  m.etime = 9999
  m.edge = ""
end sub

function request()
  unparsed = m.top.edges
  edges = ParseJSON(unparsed)

  registry = RegistryUtil()
  cfduid = registry.read("cfduid", "hydravion")
  sails = registry.read("sails", "hydravion")
  cookies = "__cfduid=" + cfduid + "; sails.sid=" + sails
  m.https = CreateObject("roUrlTransfer")
  m.https.RetainBodyOnError(true)
  m.https.setCertificatesFile("common:/certs/ca-bundle.crt")
  m.https.initClientCertificates()
  m.https.AddHeader("Cookie", cookies)
  port = CreateObject("roMessagePort")
  m.https.SetMessagePort(port)

  for each edge in edges.edges
    url = "https://" + edge.hostname
    m.https.SetUrl(url)
    if (m.https.AsyncGetToString())
      start_date = CreateObject("roDateTime")
      start_time = start_date.GetMilliseconds()
      event = wait(1500, m.https.GetPort())
      if type(event) = "roUrlEvent"
        end_date = CreateObject("roDateTime")
        end_time = end_date.GetMilliseconds()
        time = end_time - start_time
        if time < m.etime then
          m.etime = time
          m.edge = edge.hostname
        end if
      end if
    end if
  end for

  m.top.bestEdge = m.edge

end function
