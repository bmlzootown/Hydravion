sub init()
  m.top.functionname = "request"
  m.postercontent = createObject("roSGNode", "ContentNode")
end sub

function request()
  feed = ParseJSON(m.top.unparsed_feed)
  '? m.top.unparsed_feed
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
  vidIds = {
    "ids":[],
    "contentType":"video"
  }
  for each media in feed
    node = createObject("roSGNode", "media_node")
    node.title = media.title
    node.ShortDescriptionLine1 = media.title
    node.Description = media.text
    node.id = media.releaseDate
    node.postId = media.id
    node.HDPosterURL = media.thumbnail.path
    if media.thumbnail.childImages[0] <> invalid
        node.HDPosterURL = media.thumbnail.childImages[0].path
    end if
    node.likes = media.likes
    node.dislikes = media.dislikes
    node.attachments = media.attachmentOrder
    postType = CreateObject("roArray", 1, true)
    postType.shift()
    if media.metadata.hasVideo = true
        'node = createObject("roSGNode", "ContentNode")
        'node.title = media.title
        'node.ShortDescriptionLine1 = media.title
        'node.Description = media.text
        'node.guid = media.attachmentOrder[0]
        node.videoAttachments = media.videoAttachments
        node.guid = media.videoAttachments[0]
        node.duration = media.metadata.videoDuration
        vidIds.ids.Push(node.guid)
        'node.id = media.releaseDate
        node.streamformat = "hls"
        node.hasVideo = true
        postType.push("Video")
        'Check to see if thumbnail is cached
        'node.HDPosterURL = loadCacheImage(video.thumbnail.childImages[0].path)
        'node.HDPosterURL = media.thumbnail.path
        'if media.thumbnail.childImages[0] <> invalid
        ''    node.HDPosterURL = media.thumbnail.childImages[0].path
        'end if

        'postercontent.appendChild(node)
    end if
    if media.metadata.hasAudio = true
        node.hasAudio = true
        node.audioAttachments = media.audioAttachments
        postType.push("Audio")
    end if
    if media.metadata.hasPicture = true
      node.hasPicture = true
      node.pictureAttachments = media.pictureAttachments
      postType.push("Picture")
    end if
    if media.metadata.hasVideo = false
      if media.metadata.hasAudio = false
        if media.metadata.hasPicture = false
          postType.push("Text")
        end if
      end if
    end if

    d = 0
    if media.metadata.videoDuration = 0
      if media.metadata.audioDuration <> 0
        d = media.metadata.audioDuration
      end if
    else
      d = media.metadata.videoDuration
    end if

    time = CreateObject("roDateTime")
    time.FromSeconds(d)
    duration = getTime(time)

    all_postType = postType.join(", ")

    node.postType = all_postType
    node.postDuration = duration

    node.ShortDescriptionLine2 = "" + all_postType + "  " + duration
    node.ShortDescriptionLine1 = node.title
    m.postercontent.appendChild(node)
  end for
  getProgress = CreateObject("roSGNode", "postTask")
  url = "https://www.floatplane.com/api/v3/content/get/progress"
  getProgress.setField("url", url)
  getProgress.setField("body", vidIds)
  getProgress.observeField("response", "gotProgress")
  getProgress.control = "RUN"

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

  'm.top.feed = postercontent
end function

sub gotProgress(obj)
  progress = ParseJson(obj.getData())
  for each p in progress
    for each node in m.postercontent.getChildren(-1, 0) 
      if node.guid = p.id 
        node.progress = p.progress
      end if
    end for
  end for

  m.top.feed = m.postercontent
end sub

function loadCacheImage(url) as String
  registry = RegistryUtil()
  sails = registry.read("sails", "hydravion")
  cookies = "sails.sid=" + sails

  fs = createObject("roFileSystem")
  xfer = createObject("roUrlTransfer")
  xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
  xfer.InitClientCertificates()
  xfer.AddHeader("Accept", "application/json")
  xfer.AddHeader("User-Agent", "Hydravion (Roku), CFNetwork")
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