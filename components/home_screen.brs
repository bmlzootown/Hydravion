function init()
  m.device = CreateObject("roDeviceInfo")
  m.category_screen = m.top.findNode("category_screen")
  m.content_screen = m.top.findNode("content_screen")
  m.details_screen = m.top.findNode("details_screen")
  m.login_screen = m.top.findNode("login_screen")
  m.streamCheckTimer = m.top.findNode("stream_timer")

  m.feedpage = 0
  m.live = false
  m.playButtonPressed = false

  m.videoplayer = m.top.findNode("videoplayer")

  m.login_screen.observeField("next", "onNext")
  m.category_screen.observeField("category_selected", "onCategorySelected")
  m.category_screen.observeField("channel_selected", "onChannelSelected")
  m.content_screen.observeField("content_selected", "onContentSelected")
  m.content_screen.observeField("itemIndex", "onItemFocus")
  m.details_screen.observeField("play_button_pressed", "onPlayButtonPressed")
  m.details_screen.observeField("resume_button_pressed", "onResumeButtonPressed")
  m.details_screen.observeField("attachedMediaSelected", "onAttachedMediaSelected")
  m.resume = false
  m.streamCheckTimer.observeField("fire","checkStream")

  m.itemFocus = 0

  m.supported = m.device.GetSupportedGraphicsResolutions()
  
  m.arrutil = ArrayUtil()


  appInfo = createObject("roAppInfo")
  version = appInfo.getVersion()
  m.useragent = "Hydravion (Roku) v" + version

  ' Check for Bearer token using TokenUtil
  tokenUtilObj = TokenUtil()
  if tokenUtilObj.isAuthenticated() then
    'Check whether token is set, if not we login. If found, we head over to onNext()
    m.login_screen.visible = false
    ' Set next field to trigger the login flow (onNext checks for "beep" prefix)
    time = CreateObject("roDateTime")
    m.login_screen.next = "beep" + time.AsSeconds().ToStr()
    ' The observer will fire and call onNext automatically
    'Signal that we are logged in and we have completed launch
    'm.top.signalBeacon("AppDialogComplete")
  else
    ' No token, show login screen directly
    m.login_screen.visible = true
    m.login_screen.setFocus(true)
  end if

  'Signal that launch is complete
  'sleep(200)
  m.top.signalBeacon("AppLaunchComplete")
end function

sub onDeepLinking(obj)
  'showTestDialog()
  m.videoplayer.notificationInterval = 1
  m.videoplayer.observeField("position", "onPlayerPositionChanged")
  m.videoplayer.observeField("state", "onPlayerStateChanged")
  videoContent = createObject("roSGNode", "ContentNode")
  videoContent.url = "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
  videoContent.StreamFormat = "mp4"
  m.videoplayer.visible = true
  m.videoplayer.setFocus(true)
  m.videoplayer.content = videoContent
  m.videoplayer.control = "play"
  'Required for deep linking
  m.top.signalBeacon("AppLaunchComplete")
end sub

sub onRowInput(obj)
  '? "onRowInputEvent: " + obj.getData()
end sub

sub onRoInput(obj)
  ' Handle roInputEvent from main.brs
  ' Currently not implemented
end sub


sub onNext(obj)
  nextValue = m.login_screen.next
  print "[PROGRESS] onNext called, value: " + nextValue
  print "[PROGRESS] onNext - nextValue type: " + type(nextValue)
  if nextValue <> invalid and nextValue <> ""
    print "[PROGRESS] onNext - InStr('beep') result: " + nextValue.InStr("beep").ToStr()
    print "[PROGRESS] onNext - not InStr('beep') = 0: " + (not nextValue.InStr("beep") = 0).ToStr()
  end if
  ' Ignore empty values - these are just field clears, not actual login triggers
  if nextValue = "" or nextValue = invalid
    print "[PROGRESS] Ignoring empty next value"
    return
  end if
  ' Only proceed if the value starts with "beep" (our login trigger)
  if not nextValue.InStr("beep") = 0
    print "[PROGRESS] Ignoring next value that doesn't start with 'beep'"
    return
  end if
  print "[PROGRESS] onNext - proceeding with login flow"
  m.login_screen.visible = false
  'Now that we have cookies, we can initialize the video/live player
  initializeVideoPlayer()

  showUpdateDialog()

  getSubs("")
end sub

sub getSubs(obj)
  m.subs_task = CreateObject("roSGNode", "urlTask")
  apiConfigObj = ApiConfig()
  url = apiConfigObj.buildApiUrl("/api/v3/user/subscriptions")
  m.subs_task.setField("url", url)
  m.subs_task.observeField("response", "onSubs")
  m.subs_task.observeField("error", "onRequestError")
  m.subs_task.control = "RUN"
end sub

sub onSubs(obj)
  m.top.subscriptions = obj.getData()
  m.category_screen.visible = true
  m.category_screen.setFocus(true)
end sub

sub onCategoryResponse(obj)
  m.feed_task = createObject("roSGNode", "setupCategoriesTask")
  m.feed_task.setField("unparsed", obj.getData())
  m.feed_task.observeField("category_node", "onCategorySetup")
  m.feed_task.control = "RUN"
end sub

sub onCategorySetup(obj)
  m.category_screen.findNode("category_list").content = obj.getData()
  if m.category_screen.FindNode("category_list").content.getChildCount() = 0
    closeDialog()
    showMessageDialog("Error", "No subscriptions found!")
    node = createObject("roSGNode", "category_node")
    node.title = "None found!"
    m.category_screen.FindNode("category_list").content.appendChild(node)
  end if
  'm.category_screen.findNode("channel_list").content = obj.getData()
  m.category_screen.setFocus(true)
end sub

sub onCategorySelected(obj)
  'Load feed for specific subscription
  list = m.category_screen.findNode("category_list")
  item = list.content.getChild(obj.getData())
  ? item.title + " [" + item.creatorGUID + "]"
  m.content_screen.setField("feed_name", item.title)
  m.content_screen.setField("category_node", item)

  m.feed_url = item.feed_url
  m.feed_page = 0

  'Grab stream info
  m.stream_cdn = CreateObject("roSGNode", "urlTask")
  if item.liveInfo <> invalid
    apiConfigObj = ApiConfig()
    url = apiConfigObj.buildApiUrl("/api/v3/delivery/info?scenario=live&entityId=" + item.liveInfo.id)
    
    m.stream_cdn.setField("url", url)
    m.stream_cdn.observeField("response", "onGetStreamURL")
    m.stream_cdn.observeField("error", "onGotStreamError")
    m.stream_cdn.control = "RUN"
    m.creatorGUID = item.creatorGUID
  else if item.liveInfo = invalid
    m.content_screen.setField("streaming", false)
    loadFeed(m.feed_url, m.feed_page)
  end if
end sub

sub onChannelSelected(obj)
  'Load feed for specific channel
  list = m.category_screen.findNode("channel_list")
  item = list.content.getChild(obj.getData())
  ? item.title + " [" + item.creatorGUID + "]"
  m.content_screen.setField("feed_name", item.title)
  m.content_screen.setField("category_node", item)

  m.feed_url = item.feed_url
  m.feed_page = 0

  m.creatorGUID = item.creatorGUID
  creatorList = m.category_screen.findNode("category_list")
  creators = creatorList.content.getChildren(-1,0)
  liveInfoID = ""
  for each c in creators
    if m.creatorGUID = c.creatorGUID
      liveInfoID = c.liveInfo.id
    end if
  end for

  'Grab stream info
  m.stream_cdn = CreateObject("roSGNode", "urlTask")
  apiConfigObj = ApiConfig()
  url = apiConfigObj.buildApiUrl("/api/v3/delivery/info?scenario=live&entityId=" + liveInfoID)
  m.stream_cdn.setField("url", url)
  m.stream_cdn.observeField("response", "onGetStreamURL")
  m.stream_cdn.observeField("error", "onGotStreamError")
  m.stream_cdn.control = "RUN"

  'm.content_screen.setField("streaming", false)
  'loadFeed(m.feed_url, m.feed_page)
end sub

sub onGetStreamURL(obj)
  json = ParseJSON(obj.getData())

  cdn = json.groups[0].origins[0].url
  uri = json.groups[0].variants[0].url
  m.streamUri = cdn + uri

  m.stream_info = CreateObject("roSGNode", "urlTask")
  apiConfigObj = ApiConfig()
  url = apiConfigObj.buildApiUrl("/api/creator/info?creatorGUID=" + m.creatorGUID)
  m.stream_info.setField("url", url)
  m.stream_info.observeField("response", "onGetStreamInfo")
  m.stream_info.control = "RUN"
end sub

sub onGotStreamError(obj)
  m.content_screen.setField("streaming", false)
  loadFeed(m.feed_url, m.feed_page)
end sub

sub onGetStreamInfo(obj)
  info = ParseJSON(obj.getData())
  if info[0].liveStream <> invalid
    if info[0].title <> invalid
      'If stream info found, create node
      node = createObject("roSGNode", "ContentNode")
      if info[0].liveStream.thumbnail <> invalid
        node.HDPosterURL = info[0].liveStream.thumbnail.path
      end if
      node.title = "LIVE: " + info[0].liveStream.title
      node.ShortDescriptionLine1 = "LIVE: " + info[0].liveStream.title
      if info[0].liveStream.description <> invalid
        node.Description = info[0].liveStream.description
      end if
      node.guid = m.streamUri
      node.id = "live"
      node.streamformat = "hls"
      m.stream_node = node

      'Start stream check timer'
      checkStream()
      m.streamCheckTimer.control = "start"
      m.isStreaming = false
      loadFeed(m.feed_url, m.feed_page)
    else
      m.isStreaming = false
      loadFeed(m.feed_url, m.feed_page)
    end if
  else
    m.isStreaming = false
    loadFeed(m.feed_url, m.feed_page)
  end if
end sub

sub checkStream()
  'm.stream_node.guid'
  'Check to see if creator is actually streaming'
  m.stream_check = createObject("roSGNode", "streamCheckTask")
  m.stream_check.setField("url", m.streamUri)
  m.stream_check.observeField("response", "isStreaming")
  m.stream_check.observeField("error", "notStreaming")
  m.stream_check.control = "RUN"
end sub

sub notStreaming()
  m.isStreaming = false
  'loadFeed(m.feed_url, m.feed_page)
  ? "Streaming: FALSE"
end sub

sub isStreaming()
  m.isStreaming = true
  m.streamCheckTimer.control = "stop"
  loadFeed(m.feed_url, m.feed_page)
  ? "Streaming: TRUE"
end sub

sub loadFeed(url, page)
  'Used to load subscription feed given url and page
  after = 20 * page
  newurl = url + "&fetchAfter=" + after.ToStr() + ""
  m.feed_task = createObject("roSGNode", "urlTask")
  m.feed_task.setField("url", newurl)
  m.feed_task.observeField("response", "onFeedResponse")
  m.feed_task.observeField("error", "onRequestError")
  m.feed_task.control = "RUN"
  m.feedpage = page
  m.feedurl = url
end sub

sub onFeedResponse(obj)
  'We will setup the feed node in the setupFeedTask, allowing us to manually cache thumbnail images
  unparsed_json = obj.getData()
  m.setupFeed_task = createObject("roSGNode", "setupFeedTask")
  m.setupFeed_task.setField("unparsed_feed", unparsed_json)
  m.setupFeed_task.setField("streaming", m.isStreaming)
  '? m.stream_node
  m.setupFeed_task.setField("stream_node", m.stream_node)
  m.setupFeed_task.setField("page", m.feedpage)
  m.setupFeed_task.observeField("feed", "onFeedSetup")
  m.setupFeed_task.control = "RUN"
end sub

sub onFeedSetup(obj)
  'Set item focus if stream find after timer run'
  if m.itemFocus <> 0
    if m.isStreaming <> INVALID and m.isStreaming
      m.content_screen.setField("jumpTo", m.itemFocus + 1)
    end if
  end if

  'Feed node has been setup, show it to user
  m.content_screen.setField("page", m.feedpage)
  m.content_screen.setField("feed_node", obj.getData())
  m.category_screen.visible = false
  m.content_screen.visible = true
end sub

sub onItemFocus(event)
  ''? "New Item Focus: " + event.getData().ToStr()
  m.itemFocus = event.getData()
end sub

sub onContentSelected(obj)
  selected_index = obj.getData()
  m.selected_media = m.content_screen.findNode("content_grid").content.getChild(selected_index)
  m.selected_index = selected_index
  if m.selected_media.title = "nextpage"
    'User selected next page
    m.feedpage = m.feedpage + 1
    loadFeed(m.feedurl, m.feedpage)
  else if m.selected_media.title = "backpage"
    'User selected back page
    if m.feedpage <> 0
      m.feedpage = m.feedpage - 1
      loadFeed(m.feedurl, m.feedpage)
    end if
  else if m.selected_media.id = "live"
    m.live = true
    m.selected_media.description = removeHtmlTags(m.selected_media.description)
    m.details_screen.content = m.selected_media
    m.content_screen.visible = false
    m.details_screen.visible = true
    m.details_screen.setFocus(true)
  else
    m.live = false
    gpi = CreateObject("roSGNode", "urlTask")
    apiConfigObj = ApiConfig()
    url = apiConfigObj.buildApiUrl("/api/v3/content/post?id=" + m.selected_media.postId)
    gpi.setField("url", url)
    gpi.observeField("response", "onPostInfo")
    gpi.observeField("error", "onRequestError")
    gpi.control = "RUN"
  end if
end sub

sub onPostInfo(obj)
  info = ParseJSON(obj.getData())
  m.selected_media.userInteraction = info.userInteraction
  m.selected_media.videoAttachments = info.videoAttachments
  m.selected_media.audioAttachments = info.audioAttachments
  m.selected_media.pictureAttachments = info.pictureAttachments
  
  ' Update description and duration from post response if available
  if info.text <> invalid then
    m.selected_media.description = removeHtmlTags(info.text)
  else if info.description <> invalid then
    m.selected_media.description = removeHtmlTags(info.description)
  end if
  if info.metadata <> invalid and info.metadata.videoDuration <> invalid then
    m.selected_media.duration = info.metadata.videoDuration
  end if
  '? m.selected_media

  if m.selected_media.hasVideo = true
    ' Skip the old /api/video/info endpoint and go directly to getting delivery info
    ' We'll extract resolution info from the delivery/info response
    getProgress = CreateObject("roSGNode", "postTask")
    apiConfigObj = ApiConfig()
    url = apiConfigObj.buildApiUrl("/api/v3/content/get/progress")
    data = {
      "ids":[m.selected_media.guid],
      "contentType": "video"
    }
    getProgress.setField("url", url)
    getProgress.setField("body", data)
    getProgress.observeField("response", "gotProgress")
    getProgress.observeField("error", "gotProgressError")
    getProgress.control = "RUN"
  else
    m.selected_media.description = removeHtmlTags(m.selected_media.description)
    m.details_screen.content = m.selected_media
    m.content_screen.visible = false
    m.details_screen.visible = true
    m.details_screen.setFocus(true)
  end if
end sub

sub onRequestError(obj)
  errorData = obj.getData()
  
  ' Check if it's a plain string error (like "Not authenticated - please login")
  if type(errorData) = "roString" or type(errorData) = "String"
    ' Check if it's an authentication error
    if errorData.InStr("Not authenticated") >= 0 or errorData.InStr("please login") >= 0
      print "[ERROR] Authentication failed, redirecting to login screen"
      ' Redirect to login screen
      m.category_screen.visible = false
      m.content_screen.visible = false
      m.details_screen.visible = false
      m.login_screen.visible = true
      m.login_screen.setFocus(true)
      ' Re-establish observer in case it was lost
      m.login_screen.observeField("next", "onNext")
      ' Reset the login screen to restart QR code flow
      m.login_screen.setField("reset", true)
      return
    else
      ' Other string error, show as message
      showMessageDialog("Error", errorData)
      return
    end if
  end if
  
  ' Try to parse as JSON
  error = ParseJSON(errorData)
  
  ' Check if JSON parsing failed
  if error = invalid
    ' Not valid JSON, show as plain text
    showMessageDialog("Error", errorData)
    return
  end if
  
  ' Store error info for closeDialog to check
  m.lastError = error
  
  ' Check if it's a structured error with errors array
  if error.errors <> invalid and error.errors.Count() > 0
    ' Check if it's an authentication error
    if error.errors[0].name <> invalid and (error.errors[0].name = "notLoggedInError" or error.errors[0].name.InStr("auth") >= 0)
      print "[ERROR] Authentication error from API, redirecting to login screen"
      ' Redirect to login screen
      m.category_screen.visible = false
      m.content_screen.visible = false
      m.details_screen.visible = false
      m.login_screen.visible = true
      m.login_screen.setFocus(true)
      ' Re-establish observer in case it was lost
      m.login_screen.observeField("next", "onNext")
      ' Reset the login screen to restart QR code flow
      m.login_screen.setField("reset", true)
      return
    end if
    
    ' Other structured error, show dialog
    errorName = error.errors[0].name
    if errorName = invalid then errorName = "Error"
    errorMessage = error.errors[0].message
    if errorMessage = invalid then errorMessage = "An error occurred"
    showMessageDialog(errorName, errorMessage)
  else
    ' Error object but no errors array, show generic message
    showMessageDialog("Error", "An error occurred")
  end if
end sub

sub gotProgress(obj)
  progress = ParseJson(obj.getData())
  if progress[0] <> Invalid
    m.selected_media.progress = progress[0].progress
  end if
  doPreProcessVideoSelected()
end sub

sub gotProgressError(obj)
  m.selected_media.progress = "0"
  doPreProcessVideoSelected()
end sub

sub doPreProcessVideoSelected()
  m.video_pre_task = CreateObject("roSGNode", "urlTask")
  apiConfigObj = ApiConfig()
  url = apiConfigObj.buildApiUrl("/api/v3/delivery/info?scenario=onDemand&entityId=" + m.selected_media.guid)
  m.video_pre_task.setField("url", url)
  m.video_pre_task.observeField("response", "onProcessVideoSelected")
  m.video_pre_task.observeField("error", "onRequestError")
  m.video_pre_task.control = "RUN"
end sub

sub onProcessVideoSelected(obj)
  info = ParseJSON(obj.getData())
  m.info = info
  
  ' Extract resolution info from delivery/info variants
  variants = info.groups[0].variants
  resolutions = createObject("roArray", 10, true)
  twentyonesixty = false

  ' Build resolutions array from variants
  for each variant in variants
    if variant.enabled = true then
      ' Extract resolution from label (e.g., "1080p" -> "1080")
      label = variant.label
      if label <> invalid then
        ' Remove "p" suffix if present
        res = label
        if res.InStr("p") > 0 then
          res = res.Mid(0, res.InStr("p"))
        end if
        ' Handle "4k" special case
        if label.InStr("4k") >= 0 or label.InStr("4K") >= 0 then
          res = "2160"
        end if
        if not m.arrutil.contains(resolutions, res) then
          resolutions.Push(res)
        end if
        ' Check for 2160x1080 (21:9 aspect ratio)
        if variant.width = 2160 and variant.height = 1080 then
          twentyonesixty = true
        end if
      end if
    end if
  end for

  ' Determine best resolution for device
  height = ""
  model = m.device.GetModel()
  ? "getVideoMode: " + FormatJson(m.device.getVideoMode())
  if model = "3700X" or model = "3710X" or model = "3600X"
    for i = m.supported.Count() - 1 to 0 step -1
      tv = (strI(m.supported[i].height)).trim()
      if m.arrutil.contains(resolutions, tv)
        height = tv
        if twentyonesixty = true and height = "1080"
          height = "720"
        end if
        exit for
      end if
    end for
  else 
    ' Try to match video mode with variant labels
    vidMode = m.device.getVideoMode()
    for each variant in variants
      if variant.enabled = true and variant.label <> invalid then
        if vidMode.Instr(variant.label) <> -1 then
          ' Extract resolution from label
          label = variant.label
          if label.InStr("4k") >= 0 or label.InStr("4K") >= 0 then
            height = "2160"
          else if label.InStr("p") > 0 then
            height = label.Mid(0, label.InStr("p"))
          end if
          exit for
        end if
      end if
    end for
  end if
  if height = ""
    height = "720"
  end if

  'Set the resolution to be used as default for video
  m.resolution = height

  cdn = info.groups[0].origins[0].url
  uri = ""

  ' Filter out disabled variants
  enabledVariants = createObject("roArray", variants.Count(), true)
  for each variant in variants
    if variant.enabled = true then
      enabledVariants.Push(variant)
    end if
  end for

  ' Find variant matching selected resolution
  for each variant in enabledVariants
    if variant.label <> invalid and variant.label.Instr(m.resolution) <> -1 then
      uri = variant.url
      exit for
    end if
  end for

  ' Fallback to first enabled variant if no match
  if uri = "" and enabledVariants.Count() > 0 then
    uri = enabledVariants[0].url
  end if

  m.selected_media.url = cdn + uri
  ? m.selected_media.url

  ? "DEFAULT RESOLUTION: " + m.resolution
  if m.playButtonPressed
    'We are just going to pass it some info... No need, really, but I will fix this later
    onPlayVideo(info)
  else
    'User selected video, let's prebuffer while on detail screen
    ''Just gonna needlessly pass info here as well
    onPreBuffer(info)
  end if
end sub

sub onPreBuffer(obj)
  ' Setup details screen when user selects video
  m.videoplayer.content = m.selected_media
  m.details_screen.content = m.selected_media
  m.content_screen.visible = false
  m.details_screen.visible = true
  m.details_screen.setFocus(true)
end sub

sub onResumeButtonPressed(obj)
  if m.live = false then
    m.resume = true
    onPlayButtonPressed(obj)
  end if
end sub

sub onAttachedMediaSelected(obj)
  m.attached_media = m.details_screen.findNode("attachmentsList").content.getChild(obj.getData())

  attachmentTask = CreateObject("roSGNode", "urlTask")
  apiConfigObj = ApiConfig()
  url = apiConfigObj.buildApiUrl("/api/v3/delivery/info?scenario=onDemand&entityId=" + m.attached_media.guid)
  attachmentTask.setField("url", url)
  attachmentTask.observeField("response", "onProcessAttachedMedia")
  m.playButtonPressed = true
  attachmentTask.control = "RUN"
end sub

sub onProcessAttachedMedia(obj)
  info = ParseJSON(obj.getData())

  if m.resolution = invalid then
    m.resolution = "1080"
  end if

  'm.selected_media.url = info.cdn + info.resource.uri
  variants = info.groups[0].variants
  cdn = info.groups[0].origins[0].url
  uri = ""

  for i = 0 to (variants.Count()-1)
    variant = variants[i]
    if variant.enabled = false then
      variants.Delete(i)
    end if
  end for

  for each variant in variants
    if variant.label.Instr(m.resolution) <> -1 then
      uri = variant.url
    end if
  end for

  if uri = "" then
    uri = variants.Peek().url
  end if

  m.selected_media = m.attached_media
  m.selected_media.url = cdn + uri
  ? "Attachment URL: " + m.selected_media.url

  m.videoplayer.content = m.selected_media
  if m.selected_media.isVideo = true
    playAttachedMedia()
  else if m.selected_media.isAudio = true
    m.selected_media.url = info.groups[0].origins[0].url + info.groups[0].variants[0].url
    playAttachedMedia()
  end if
end sub

sub playAttachedMedia()
  m.details_screen.visible = false
  m.videoplayer.visible = true
  m.videoplayer.setFocus(true)
  m.videoplayer.content = m.selected_media
  m.videoplayer.control = "play"
  if m.video_task <> invalid
    m.playButtonPressed = true
  end if
end sub

sub onPlayButtonPressed(obj)
  if m.live then
    doLive()
  else
    if m.resume then
      m.videoplayer.content.PlayStart = m.videoplayer.content.progress
    else
      m.videoplayer.content.PlayStart = 0
    end if
    m.resume = false
    'Prebuffering currently DISABLED
    'Video is already prebuffered, we just need to hide the detail screen, focus on the video player, and play the video
    m.details_screen.visible = false
    m.details_screen.setFocus(false)
    m.videoplayer.visible = true
    m.videoplayer.setFocus(true)
    m.videoplayer.control = "play"
    if m.video_task <> invalid
      m.playButtonPressed = true
    end if
  end if
end sub

sub doLive()
  'Grab stream info from earlier
  streamInfo = m.stream_node
  if streamInfo <> invalid
    if m.top.getScene().dialog <> invalid
      'If we tried to play the stream from the options dialog, close said dialog
      m.top.getScene().dialog.close = true
    end if
    url = streamInfo.guid
    if url.Instr("floatplane") > -1 then
      loadLiveFloat(url)
    else
      m.live_task = createObject("roSGNode", "liveTask")
      m.live_task.setField("url", url)
      m.live_task.observeField("done", "loadLiveStuff")
      m.live_task.control = "RUN"
    end if
  else 
    showMessageDialog("Error", "Individual channels do not currently support livestreams. Go back to subscription screen and select main subscription to watch livestreams.")
  end if
end sub

sub loadLiveFloat(obj)
  'Load livestream from Floatplane CDN'
  videoContent = createObject("roSGNode", "ContentNode")
  videoContent.url = obj
  videoContent.StreamFormat = "hls"
  time = CreateObject("roDateTime")
  now = time.AsSeconds()
  videoContent.PlayStart = now + 999999
  videoContent.live = true

  m.content_screen.visible = false
  m.videoplayer.visible = true
  m.videoplayer.setFocus(true)
  m.videoplayer.content = videoContent
  m.videoplayer.control = "play"
  'm.videoplayer.seek = m.videoplayer.pauseBufferEnd
  m.videoplayer.seek = 999999
end sub

sub loadLiveStuff(obj)
  'Load livestream from 3rd party CDN; doesn't like to load directly, so we have to save it and then read the temporary file'
  videoContent = createObject("roSGNode", "ContentNode")
  videoContent.url = "tmp:/live.m3u8"
  videoContent.StreamFormat = "hls"
  time = CreateObject("roDateTime")
  now = time.AsSeconds()
  videoContent.PlayStart = now + 999999
  videoContent.live = true

  m.content_screen.visible = false
  m.videoplayer.visible = true
  m.videoplayer.setFocus(true)
  m.videoplayer.content = videoContent
  m.videoplayer.control = "play"
  'm.videoplayer.seek = m.videoplayer.pauseBufferEnd
  m.videoplayer.seek = 999999
end sub

sub onPlayVideo(obj)
  if m.resolution <> invalid then
    cdn = m.info.groups[0].origins[0].url
    uri = ""
    for each variant in m.info.groups[0].variants
      if variant.name.Instr(m.resolution) <> -1 then
        uri = variant.url
      end if
    end for
    m.selected_media.url = cdn + uri
  end if

  m.details_screen.visible = false
  m.videoplayer.visible = true
  m.videoplayer.setFocus(true)
  m.videoplayer.content = m.selected_media
  m.videoplayer.control = "play"
end sub

sub setProgress(contentType as String, guid as String, position as Integer)
  videoProgress = CreateObject("roSGNode", "postTask")
  apiConfigObj = ApiConfig()
  url = apiConfigObj.buildApiUrl("/api/v3/content/progress")
  data = {
    "id": guid,
    "contentType": contentType,
    "progress": position
  }
  videoProgress.setField("url", url)
  videoProgress.setField("body", data)
  videoProgress.observeField("response", "didSetProgress")
  videoProgress.observeField("error", "didntSetProgress")
  videoProgress.control = "RUN"
end sub

sub didSetProgress(res)
  ? res.getData()
end sub

sub didntSetProgress(err)
  ? err.getData()
end sub

sub updateSelectedMediaProgressBar(position as Integer)
  m.selected_media.progress = position
  grid = m.content_screen.FindNode("content_grid")
  grid.replaceChild(m.selected_media, m.selected_index)
end sub

sub initializeVideoPlayer()
  'Setup video player with Bearer token
  tokenUtilObj = TokenUtil()
  accessToken = tokenUtilObj.getAccessToken()
  if accessToken = invalid then
    print "[PROGRESS] No access token available for video player"
    return
  end if
  m.videoplayer.EnableCookies()
  m.videoplayer.setCertificatesFile("common:/certs/ca-bundle.crt")
  m.videoplayer.initClientCertificates()
  m.videoplayer.SetConnectionTimeout(30)
  m.videoplayer.AddHeader("User-Agent", m.useragent)
  m.videoplayer.AddHeader("Authorization", "Bearer " + accessToken)
  m.videoplayer.notificationInterval = 1
  m.videoplayer.observeField("position", "onPlayerPositionChanged")
  m.videoplayer.observeField("state", "onPlayerStateChanged")
end sub

sub onPlayerPositionChanged(obj)
  ? "Position: ", obj.getData()
  m.playerPosition = obj.getData()
end sub

sub onPlayerStateChanged(obj)
  ? "State: ", obj.getData()
  state = obj.getData()
  if state = "stopped"
    closeVideo()
    if m.selected_media <> Invalid AND m.selected_media.id <> "live"
      if m.playerPosition <> Invalid
        'Update progress, then update progressBar by refreshing individual video node
        contentType = "video"
        if m.selected_media.isVideo = true then
          contentType = "video"
        else if m.selected_media.isAudio = true then
          contentType = "audio"
        end if
        setProgress(contentType, m.selected_media.guid, m.playerPosition)
        updateSelectedMediaProgressBar(m.playerPosition)
      end if
    end if
  end if
  if state = "finished"
    'Close video player when finished player
      ? m.selected_media
      if m.selected_media <> Invalid AND m.selected_media.id <> "live"
        'Update progress, then update progressBar by refreshing individual video node
        contentType = "video"
        if m.selected_media.isAudio = true then
          contentType = "audio"
        end if
        setProgress(contentType, m.selected_media.guid, m.selected_media.duration + 1)
        updateSelectedMediaProgressBar(m.selected_media.duration + 1)
      end if
      closeVideo()
      m.content_screen.setFocus(true)
  else if state = "error"
    'Video couldn't play
    '-1 HTTP error: malformed headers or HTTP error result
    '-2 Connection timed out
    '-3 Unknown error
    '-4 Empty list; no streams specified to play
    '-5 Media error; the media format is unknown or unsupported
    '-6 DRM error
    error = "[Error " + m.videoplayer.errorCode.ToStr() + "] " + m.videoplayer.errorMsg
    ? error
    showVideoError(m.videoplayer.errorCode.ToStr(), m.videoplayer.errorMsg)
  end if
end sub

sub showVideoError(code, error)
  m.top.getScene().dialog = createObject("roSGNode", "SimpleDialog")
  m.top.getScene().dialog.title = "Error " + code 
  m.top.getScene().dialog.showCancel = false
  m.top.getScene().dialog.text = "Video cannot be played! " + error
  setupDialogPalette()
end sub

sub showTestDialog()
  m.top.getScene().dialog = createObject("roSGNode", "SimpleDialog")
  m.top.getScene().dialog.title = "Deep Linking Test"
  m.top.getScene().dialog.showCancel = false
  m.top.getScene().dialog.text = "This is a test."
  setupDialogPalette()
end sub

sub closeVideo()
  m.resolution = invalid
  m.videoplayer.control = "stop"
  m.videoplayer.visible = false
  m.content_screen.visible = true
  m.content_screen.setFocus(true)
  m.playButtonPressed = false
end sub

sub showOptions()
  m.top.getScene().dialog = createObject("roSGNode", "SimpleDialog")
  m.top.getScene().dialog.title = "Options"
  m.top.getScene().dialog.showCancel = false
  m.top.getScene().dialog.text = "Select Option"
  m.top.getScene().dialog.buttons = ["Watch Stream","Logout"]
  setupDialogPalette()
  m.top.getScene().dialog.observeField("buttonSelected","handleOptions")
end sub

sub showMainOptions()
  m.top.getScene().dialog = createObject("roSGNode", "SimpleDialog")
  m.top.getScene().dialog.title = "Options"
  m.top.getScene().dialog.showCancel = false
  m.top.getScene().dialog.text = "Select Option"
  m.top.getScene().dialog.buttons = ["Logout"]
  setupDialogPalette()
  m.top.getScene().dialog.observeField("buttonSelected","handleMainOptions")
end sub

sub showDetailOptions()
  'Check for attachments
  buttons = createObject("roArray", 10, true)
  buttons.push("Select Resolution")
  if m.selected_media.progress < m.selected_media.duration then
    buttons.push("Mark Watched")
  else
    buttons.push("Mark Unwatched")
  end if
  m.top.getScene().dialog = createObject("roSGNode", "SimpleDialog")
  m.top.getScene().dialog.title = "Options"
  m.top.getScene().dialog.showCancel = false
  m.top.getScene().dialog.text = "Select Option"
  m.top.getScene().dialog.buttons = buttons
  setupDialogPalette()
  m.top.getScene().dialog.observeField("buttonSelected","handleDetailOptions")
end sub

sub handleDetailOptions(obj)
  buttons = m.top.getScene().dialog.buttons
  selectedButton = m.top.getScene().dialog.buttonSelected
  'Determine contentType 
  contentType = "video"
  if m.selected_media.isVideo = true then
    contentType = "video"
  else if m.selected_media.isAudio = true then
    contentType = "audio"
  end if

  if buttons[selectedButton] = "Select Resolution"
    'Select Resolution
    makeResolutionsOptions()
  else if buttons[selectedButton] = "Mark Watched"
    m.selected_media.progress = m.selected_media.duration
    setProgress(contentType, m.selected_media.guid, m.selected_media.progress)
    updateSelectedMediaProgressBar(m.selected_media.progress)
  else if buttons[selectedButton] = "Mark Unwatched"
    m.selected_media.progress = 1
    setProgress(contentType, m.selected_media.guid, m.selected_media.progress)
    updateSelectedMediaProgressBar(m.selected_media.progress)
  end if
end sub

sub makeResolutionsOptions()
  'Grab resolutions available for the video
  m.res_task = CreateObject("roSGNode", "urlTask")
  apiConfigObj = ApiConfig()
  url = apiConfigObj.buildApiUrl("/api/v3/delivery/info?scenario=onDemand&entityId=" + m.selected_media.guid)
  m.res_task.setField("url", url)
  m.res_task.observeField("response", "showResolutionsOptions")
  m.res_task.control = "RUN"
end sub

sub showResolutionsOptions(obj)
  'Display available resolutions for selected video
  info = ParseJSON(obj.getData())
  m.dbuttons = createObject("roArray", 10, true)
  for each variant in info.groups[0].variants
    if variant.enabled = true then
      m.dbuttons.Push(variant.label)
    end if
  end for
  m.top.getScene().dialog = createObject("roSGNode", "SimpleDialog")
  m.top.getScene().dialog.title = "Resolution"
  m.top.getScene().dialog.showCancel = false
  m.top.getScene().dialog.text = "Select Stream Resolution"
  m.top.getScene().dialog.buttons = m.dbuttons
  m.top.getScene().dialog.observeField("buttonSelected","handleResolutionsOptions")
  setupDialogPalette()
end sub

sub handleResolutionsOptions()
  url = ""
  m.video_task = CreateObject("roSGNode", "urlTask")
  selected = m.dbuttons[m.top.getScene().dialog.buttonSelected]
  if selected = "4k"
    m.resolution = "2160"
  else
    m.resolution = Left(selected, Len(selected) - 1)
  end if
  ? "RESOLUTION SELECTED: " + m.resolution
  m.top.getScene().dialog.close = true
  m.content_screen.setFocus(true)
  onPlayVideo(m.resolution)
end sub

sub handleMainOptions()
  ' Determines which option was selected on main screen
  if m.top.getScene().dialog.buttonSelected = 0
    showLogoutDialog()
  else if m.top.getScene().dialog.buttonSelected = 1
    ' Additional option handler if needed
  end if
end sub

sub handleOptions()
  'Determines which option was selected'
  if m.top.getScene().dialog.buttonSelected = 0
    doLive()
  else if m.top.getScene().dialog.buttonSelected = 1
    showLogoutDialog()
  end if
end sub

sub showLogoutDialog()
  m.top.getScene().dialog = createObject("roSGNode", "SimpleDialog")
  m.top.getScene().dialog.title = "Logout?"
  m.top.getScene().dialog.showCancel = false
  m.top.getScene().dialog.text = "Press OK to logout"
  setupDialogPalette()
  m.top.getScene().dialog.observeField("buttonSelected","doLogout")
end sub

sub showLiveDialog()
  m.top.getScene().dialog = createObject("roSGNode", "SimpleDialog")
  m.top.getScene().dialog.title = "Play stream?"
  m.top.getScene().dialog.showCancel = false
  m.top.getScene().dialog.text = "Press OK to play stream"
  setupDialogPalette()
  m.top.getScene().dialog.observeField("buttonSelected","doLive")
end sub

sub showMessageDialog(title, message)
  m.top.getScene().dialog = CreateObject("roSGNode", "SimpleDialog")
  m.top.getScene().dialog.title = title
  m.top.getScene().dialog.showCancel = false
  m.top.getScene().dialog.text = message
  setupDialogPalette()
  m.top.getScene().dialog.observeField("buttonSelected","closeDialog")
end sub

sub closeDialog()
  if m.top.getScene().dialog <> invalid 
    m.top.getScene().dialog.close = true
    ' Check if this was a login error and navigate back to login screen
    if m.lastError <> invalid and m.lastError.errors <> invalid and m.lastError.errors.Count() > 0
      if m.lastError.errors[0].name = "notLoggedInError"
        ' Navigate back to login screen
        m.category_screen.visible = false
        m.content_screen.visible = false
        m.details_screen.visible = false
        m.login_screen.visible = true
        m.login_screen.setFocus(true)
        ' Re-establish observer in case it was lost
        m.login_screen.observeField("next", "onNext")
        ' Reset the login screen to restart QR code flow
        m.login_screen.setField("reset", true)
        ' Set focus on the manual entry button for the new login screen
        manualEntryButton = m.login_screen.findNode("manualEntryButton")
        if manualEntryButton <> invalid
          manualEntryButton.setFocus(true)
        end if
        ' Clear the error reference
        m.lastError = invalid
      end if
    end if
  end if
end sub

sub doLogout()
  'Logs the user out'
  m.top.getScene().dialog.close = true
  registry = RegistryUtil()
  registry.deleteSection("hydravion")
  m.details_screen.visible = false
  m.content_screen.visible = false
  m.category_screen.visible = false
  m.login_screen.visible = true
  m.login_screen.setFocus(true)
  ' Re-establish observer in case it was lost
  m.login_screen.observeField("next", "onNext")
  ' Reset the login screen to restart QR code flow
  m.login_screen.setField("reset", true)
  ' Set focus on the manual entry button for the new login screen
  manualEntryButton = m.login_screen.findNode("manualEntryButton")
  if manualEntryButton <> invalid
    manualEntryButton.setFocus(true)
  end if
end sub

sub showUpdateDialog()
  'Check whether to show update dialog'
  registry = RegistryUtil()
  version = registry.read("version", "hydravion")
  appInfo = createObject("roAppInfo")
  if version <> invalid
    if version <> appInfo.getVersion()
      doUpdateDialog(appInfo)
      registry.write("version", appInfo.getVersion(), "hydravion")
    end if
  else
    registry.write("version", appInfo.getVersion(), "hydravion")
    doUpdateDialog(appInfo)
  end if
end sub

sub doUpdateDialog(appInfo)
  m.top.getScene().dialog = createObject("roSGNode", "SimpleDialog")
  m.top.getScene().dialog.title = "Update " + appInfo.getVersion()
  m.top.getScene().dialog.showCancel = false
  m.top.getScene().dialog.text = "- Workaround for login changes"
  setupDialogPalette()
  m.top.getScene().dialog.observeField("buttonSelected","closeUpdateDialog")
end sub

sub closeUpdateDialog()
  m.top.getScene().dialog.close = true
end sub

sub setupDialogPalette()
  palette = createObject("roSGNode", "RSGPalette")
  palette.colors = {   DialogBackgroundColor: "0x152130FF"}
  m.top.getScene().dialog.palette = palette
end sub

function removeHtmlTags(baseStr as String) as String
    r = createObject("roRegex", "<[^<]+?>", "i")
    return r.replaceAll(baseStr, " ")
end function

function strReplace(basestr As String, oldsub As String, newsub As String) As String
    newstr = ""
    i = 1
    while i <= Len(basestr)
        x = Instr(i, basestr, oldsub)
        if x = 0 then
            newstr = newstr + Mid(basestr, i)
            exit while
        endif
        if x > i then
            newstr = newstr + Mid(basestr, i, x-i)
            i = x
        endif
        newstr = newstr + newsub
        i = i + Len(oldsub)
    end while
    return newstr
end function

function ArrayUtil() as Object
  'Borrowed function(s) from https://github.com/juliomalves/roku-libs because I was too lazy to write my own
  util = {
    contains: function(arr as Object, element as Dynamic) as Boolean
      return m.indexOf(arr, element) >= 0
    end function
    indexOf: function(arr as Object, element as Dynamic) as Integer
      if not m.isArray(arr) then return -1
      size = arr.count()
      if size = 0 then return -1
        for i = 0 to size - 1
          if arr[i] = element then return i
        end for
      return -1
    end function
    isArray: function(arr) as Boolean
      return type(arr) = "roArray"
    end function
  }
  return util
end function

function onKeyEvent(key, press) as Boolean
  if key = "back" and press
    if m.details_screen.visible
      m.details_screen.visible = false
      m.content_screen.visible = true
      m.content_screen.setFocus(true)
      m.itemFocus = m.selected_index
      m.content_screen.setField("itemIndex", m.selected_index)
      m.content_screen.setField("jumpTo", m.selected_index)
      m.playButtonPressed = false
      return true
    else if m.videoplayer.visible
      m.resolution = invalid
      m.videoplayer.control = "stop"
      m.videoplayer.visible = false
      m.content_screen.visible = true
      m.details_screen.visible = false
      m.content_screen.setFocus(true)
      m.content_screen.FindNode("content_grid").setFocus(true)
      m.playButtonPressed = false
      return true
    else if m.content_screen.visible
      m.streamCheckTimer.control = "stop"
      m.itemFocus = 0
      m.content_screen.setField("itemIndex", 0)
      m.content_screen.setField("jumpTo", 0)
      m.content_screen.visible = false
      m.category_screen.visible = true
      m.category_screen.setFocus(true)
      return true
    end if
  else if key = "options" and press
    if m.videoplayer.visible = false
      if m.content_screen.visible = true
        showOptions()
      else if m.details_screen.visible = true
        showDetailOptions()
      else
        showMainOptions()
      end if
      return true
    end if
  else if key = "play" and press
    if m.videoplayer.visible = false
      if m.content_screen.visible = true
        showLiveDialog()
        return true
      end if
    end if
  end if
  return false
end function
