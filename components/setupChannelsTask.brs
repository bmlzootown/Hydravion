sub init()
    m.top.functionname = "request"
  end sub
  
  function request()
    json = ParseJSON(m.top.unparsed)
  
    contentNode = createObject("roSGNode", "ContentNode")
    for each channel in json.channels
      node = createObject("roSGNode", "category_node")
      node.title = channel.title
      node.feed_url = "https://www.floatplane.com/api/v3/content/creator?id=" + channel.creator + "&channel=" + channel.id
      node.creatorGUID = channel.creator
      node.icon = channel.icon.path
      if channel.cover.childImages.Peek() = invalid
        node.HDPosterURL = loadCacheImage(channel.cover.path)
      else
        node.HDPosterURL = loadCacheImage(channel.cover.childImages[0].path)
      end if

      contentNode.appendChild(node)
    end for
  
    m.top.category_node = contentNode
  end function
  
  function loadCacheImage(url) as String
    appInfo = createObject("roAppInfo")
    version = appInfo.getVersion()
    useragent = "Hydravion (Roku) v" + version + ", CFNetwork"

    registry = RegistryUtil()
  
    sails = registry.read("sails", "hydravion")
    cookies = "sails.sid=" + sails
  
    fs = createObject("roFileSystem")
    xfer = createObject("roUrlTransfer")
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.AddHeader("Accept", "application/json")
    xfer.AddHeader("User-Agent", useragent)
    xfer.AddHeader("Cookie", cookies)
  
    filename = url
    filename = mid(filename, instr(1, filename, "//") + 1)
    while instr(1, filename, "/") > 0
      filename = mid(filename, instr(1, filename, "/") + 1)
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
  