sub init()
  m.top.functionname = "request"
end sub

function request()
  feed = ParseJSON(m.top.unparsed_feed)
  postercontent = createObject("roSGNode", "ContentNode")
  if m.top.page <> 0
    'Back page button
    node = createObject("roSGNode", "ContentNode")
    node.HDPosterURL = "pkg:/images/back_page.png"
    node.title = "backpage"
    node.ShortDescriptionLine1 = "Back"
    node.Description = ""
    node.guid = ""
    node.id = ""
    node.streamformat = ""
    postercontent.appendChild(node)
  else
    if m.top.streaming then
      postercontent.appendChild(m.top.stream_node)
    end if
  end if
  for each video in feed
    node = createObject("roSGNode", "ContentNode")
    'node.HDPosterURL = video.thumbnail.childImages[0].path
    node.title = video.title
    node.ShortDescriptionLine1 = video.title
    node.Description = video.description
    node.guid = video.guid
    node.id = video.releaseDate
    node.streamformat = "hls"
    
    'Check to see if thumbnail is cached
    node.HDPosterURL = loadCacheImage(video.thumbnail.childImages[0].path)

    postercontent.appendChild(node)
  end for
  'Next page button
  node = createObject("roSGNode", "ContentNode")
  node.HDPosterURL = "pkg:/images/next_page.png"
  node.title = "nextpage"
  node.ShortDescriptionLine1 = "Next"
  node.Description = ""
  node.guid = ""
  node.id = ""
  node.streamformat = ""
  postercontent.appendChild(node)

  m.top.feed = postercontent
end function

function loadCacheImage(url) as String
  registry = RegistryUtil()
  cfduid = registry.read("cfduid", "hydravion")
  sails = registry.read("sails", "hydravion")
  cookies = "__cfduid=" + cfduid + "; sails.sid=" + sails

  fs = createObject("roFileSystem")
  xfer = createObject("roUrlTransfer")
  xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
  xfer.InitClientCertificates()
  xfer.AddHeader("Accept", "application/json")
  xfer.AddHeader("Cookie", cookies)

  filename = url
  filename = mid(filename, instr(filename, "//") + 1)
  while instr(filename, "/") > 0
    filename = mid(filename, instr(filename, "/") + 1)
  end while

  if not fs.Exists("cachefs:/" + filename) then
    xfer.SetUrl(url)
    xfer.AsyncGetToFile("cachefs:/" + filename)
    filename = url
  else
    filename = "cachefs:/" + url
  end if

  return filename
end function
