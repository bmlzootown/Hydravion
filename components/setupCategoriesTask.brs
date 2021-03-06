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
    node = createObject("roSGNode", "category_node")
    node.title = subscription.plan.title
    'node.feed_url = "https://www.floatplane.com/api/creator/videos?creatorGUID=" + subscription.creator
    node.feed_url = "https://www.floatplane.com/api/v3/content/creator?id=" + subscription.creator
    node.creatorGUID = subscription.creator
    'Grab sub icon
    node.HDPosterURL = loadCacheImage(getImageUrl(subscription.creator))
    contentNode.appendChild(node)
  end for

  m.top.category_node = contentNode
end function

function getImageUrl(creator) as String
  registry = RegistryUtil()
  sails = registry.read("sails", "hydravion")
  cookies = "sails.sid=" + sails
  xfer = CreateObject("roUrlTransfer")
  xfer.setCertificatesFile("common:/certs/ca-bundle.crt")
  xfer.AddHeader("Accept", "application/json")
  xfer.AddHeader("Cookie", cookies)
  xfer.initClientCertificates()
  xfer.SetUrl("https://www.floatplane.com/api/creator/info?creatorGUID=" + creator)
  subInfo = ParseJSON(xfer.GetToString())

  if subInfo[0].cover.childImages[0].path <> invalid
    return subInfo[0].cover.childImages[0].path
  end if
  return subInfo[0].icon.childImages[0].path
end function

function loadCacheImage(url) as String
  registry = RegistryUtil()

  sails = registry.read("sails", "hydravion")
  cookies = "sails.sid=" + sails

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
