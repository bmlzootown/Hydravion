sub init()
  m.top.functionname = "request"
  m.postercontent = createObject("roSGNode", "ContentNode")
end sub

function request()
  feed = ParseJSON(m.top.unparsed_feed)
  '? m.top.unparsed_feed
  if type(feed) <> "roArray"
    feed = CreateObject("roArray", 0, true)
  end if
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
    m.postercontent.appendChild(node)
  else
    if m.top.streaming then
      m.postercontent.appendChild(m.top.stream_node)
    end if
  end if
  ' Watch progress is stored against the blog post id, not a video attachment id.
  progressIds = {
    "ids": [],
    "contentType": "blogPost"
  }
  for each media in feed
    node = createObject("roSGNode", "media_node")
    node.title = media.title
    node.ShortDescriptionLine1 = media.title
    node.Description = contentPostBody(media)
    node.id = media.releaseDate
    node.postId = media.id
    poster = contentImagePath(media.thumbnail)
    if poster = ""
      node.HDPosterUrl = "pkg:/images/noThumbnail.png"
    else
      node.HDPosterURL = poster
    end if

    if contentIsNumber(media.likes) then node.likes = media.likes
    if contentIsNumber(media.dislikes) then node.dislikes = media.dislikes
    if type(media.attachmentOrder) = "roArray" then node.attachments = media.attachmentOrder

    metadata = media.metadata
    hasVideo = false
    hasAudio = false
    hasPicture = false
    if type(metadata) = "roAssociativeArray"
      hasVideo = metadata.hasVideo = true
      hasAudio = metadata.hasAudio = true
      hasPicture = metadata.hasPicture = true
    end if

    postType = CreateObject("roArray", 1, true)
    postType.shift()
    node.isAccessible = media.isAccessible <> false
    if node.isAccessible = true
      if hasVideo = true
        node.hasVideo = true
        node.streamformat = "hls"
        postType.push("Video")
        ' List responses omit attachment ids. Keep them when an older payload still sends them.
        if type(media.videoAttachments) = "roArray"
          node.videoAttachments = media.videoAttachments
          node.guid = contentFirstAttachmentId(media.videoAttachments)
        end if
      end if
      if hasAudio = true
        node.hasAudio = true
        postType.push("Audio")
        if type(media.audioAttachments) = "roArray"
          node.audioAttachments = media.audioAttachments
        end if
        if hasVideo = false and (node.guid = "" or node.guid = invalid)
          node.guid = contentFirstAttachmentId(media.audioAttachments)
        end if
      end if
      if hasPicture = true
        node.hasPicture = true
        postType.push("Picture")
        if type(media.pictureAttachments) = "roArray"
          node.pictureAttachments = media.pictureAttachments
        end if
      end if
    end if
    if hasVideo = false and hasAudio = false and hasPicture = false
      postType.push("Text")
    end if

    d = contentPostDurationSeconds(metadata)
    node.duration = d

    time = CreateObject("roDateTime")
    time.FromSeconds(d)
    duration = getTime(time)

    all_postType = postType.join(", ")

    node.postType = all_postType
    node.postDuration = duration

    node.ShortDescriptionLine2 = "" + all_postType + "  " + duration
    node.ShortDescriptionLine1 = node.title
    if node.isAccessible = true and (hasVideo = true or hasAudio = true) and contentIsString(media.id) and media.id <> ""
      progressIds.ids.Push(media.id)
    end if
    m.postercontent.appendChild(node)
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
  m.postercontent.appendChild(node)

  if progressIds.ids.Count() = 0
    m.top.feed = m.postercontent
  else
    getProgress = CreateObject("roSGNode", "postTask")
    apiConfigObj = ApiConfig()
    url = apiConfigObj.buildApiUrl("/api/v3/content/get/progress")
    getProgress.setField("url", url)
    getProgress.setField("body", progressIds)
    getProgress.observeField("response", "gotProgress")
    getProgress.observeField("error", "gotProgressError")
    getProgress.control = "RUN"
  end if

  'm.top.feed = postercontent
  return ""
end function

sub gotProgress(obj)
  progress = ParseJson(obj.getData())
  if type(progress) = "roArray"
    for each p in progress
      if type(p) = "roAssociativeArray"
        for each node in m.postercontent.getChildren(-1, 0)
          if node.postId = p.id
            node.progress = contentProgressToSeconds(p.progress, node.duration)
          end if
        end for
      end if
    end for
  end if

  m.top.feed = m.postercontent
end sub

sub gotProgressError(obj)
  for each node in m.postercontent.getChildren(-1, 0)
    node.progress = 0
  end for

  m.top.feed = m.postercontent
end sub

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

function getTime(dt) as String
  hours = dt.getHours()
  mins = dt.getMinutes()
  seconds = dt.getSeconds()

  sHours = hours.toStr()
  if sHours.len() = 1  then sHours = "0" + sHours

  sMins = mins.toStr()
  if sMins.len() = 1  then sMins = "0" + sMins

  sSecs = seconds.toStr()
  if sSecs.Len() = 1  then sSecs = "0" + sSecs 

  t = ""
  if sHours <> "00"
    t += sHours + ":" + sMins + ":" + sSecs
  else
    t += sMins + ":" + sSecs
  end if
  
  if sHours = "00" and sMins = "00" and sSecs = "00" then
    t = ""
  end if

  return t
end function