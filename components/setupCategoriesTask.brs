sub init()
  m.top.functionname = "request"
end sub

function request()
  json = ParseJSON(m.top.unparsed)

  'Redundant subscriptions can occur, so let's get rid of them
  trimmed = createObject("roArray",json.Count(),true)
  for each subscription in json
    ? "JSON: " + subscription.creator
    if contains(trimmed, subscription) = false
      trimmed.Push(subscription)
      ? "Adding to Trimmed: " + subscription.creator
    end if
    for each trim in trimmed
      ? "Trimmed: " + trim.creator
    end for
  end for

  'Now let's display the subscriptions so the user can select one
  contentNode = createObject("roSGNode", "ContentNode")
  for each subscription in trimmed
    creator = ParseJSON(getCreatorInfo(subscription.creator))

    apiConfigObj = ApiConfig()
    node = createObject("roSGNode", "category_node")
    node.title = creator.title
    node.feed_url = apiConfigObj.buildApiUrl("/api/v3/content/creator?id=" + subscription.creator)
    node.creatorGUID = subscription.creator
    node.liveInfo = creator.liveStream
    node.icon = loadCacheImage(creator.icon.path)
    'Grab sub icon
    if creator.cover <> invalid
      if creator.cover.childImages.Peek() = invalid
        node.HDPosterURL = loadCacheImage(creator.cover.path)
      else
        node.HDPosterURL = loadCacheImage(creator.cover.childImages[0].path)
      end if
    end if
    contentNode.appendChild(node)
  end for

  m.top.category_node = contentNode
  return ""
end function

function getCreatorInfo(creator) as String
  appInfo = createObject("roAppInfo")
  version = appInfo.getVersion()
  useragent = "Hydravion (Roku) v" + version

  ' Get Bearer token using TokenUtil
  tokenUtilObj = TokenUtil()
  accessToken = tokenUtilObj.getAccessToken()
  if accessToken = invalid then
    return ""
  end if

  xfer = CreateObject("roUrlTransfer")
  xfer.setCertificatesFile("common:/certs/ca-bundle.crt")
  xfer.AddHeader("Accept", "application/json")
  xfer.AddHeader("User-Agent", useragent)
  xfer.AddHeader("Authorization", "Bearer " + accessToken)
  xfer.initClientCertificates()
  xfer.RetainBodyOnError(true)
  port = CreateObject("roMessagePort")
  xfer.SetMessagePort(port)
  apiConfigObj = ApiConfig()
  xfer.SetUrl(apiConfigObj.buildApiUrl("/api/v3/creator/info?id=" + creator))

  result = ""
  if xfer.AsyncGetToString()
    event = wait(10000, port)
    if type(event) = "roUrlEvent" and event.GetResponseCode() = 200
      result = event.GetString()
    end if
  end if
  return result
end function

function getImageUrl(creator) as String
  jsonStr = getCreatorInfo(creator)
  if jsonStr = "" then
    return ""
  end if
  subInfo = ParseJSON(jsonStr)
  if subInfo = invalid or subInfo.Count() = 0 then
    return ""
  end if
  if subInfo[0].cover <> invalid and subInfo[0].cover.childImages <> invalid and subInfo[0].cover.childImages[0] <> invalid and subInfo[0].cover.childImages[0].path <> invalid
    return subInfo[0].cover.childImages[0].path
  end if
  if subInfo[0].icon <> invalid and subInfo[0].icon.childImages <> invalid and subInfo[0].icon.childImages[0] <> invalid
    return subInfo[0].icon.childImages[0].path
  end if
  return ""
end function

function loadCacheImage(url) as String
  appInfo = createObject("roAppInfo")
  version = appInfo.getVersion()
  useragent = "Hydravion (Roku) v" + version

  ' Get Bearer token using TokenUtil
  tokenUtilObj = TokenUtil()
  accessToken = tokenUtilObj.getAccessToken()
  if accessToken = invalid then
    return url
  end if

  fs = createObject("roFileSystem")
  xfer = createObject("roUrlTransfer")
  xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
  xfer.InitClientCertificates()
  xfer.AddHeader("Accept", "application/json")
  xfer.AddHeader("User-Agent", useragent)
  xfer.AddHeader("Authorization", "Bearer " + accessToken)

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
    filename = "cachefs:/" + filename
  end if

  return filename
end function

function contains(trimmed,subscription) as Boolean
  for each subs in trimmed
    if subs.creator = subscription.creator
      ? "FOUND"
      return true
    end if
  end for
  ? "NOT FOUND"
  return false
end function
