function init()
  m.device = CreateObject("roDeviceInfo")
  m.category_screen = m.top.findNode("category_screen")
  m.content_screen = m.top.findNode("content_screen")
  m.details_screen = m.top.findNode("details_screen")
  m.login_screen = m.top.findNode("login_screen")

  m.feedpage = 0
  m.default_edge = "Edge01-na.floatplane.com"
  m.live = false

  m.videoplayer = m.top.findNode("videoplayer")
  m.liveplayer = m.top.findNode("liveplayer")

  m.login_screen.observeField("next", "onNext")
  m.category_screen.observeField("category_selected", "onCategorySelected")
  m.content_screen.observeField("content_selected", "onContentSelected")
  m.details_screen.observeField("play_button_pressed", "onPlayButtonPressed")

  registry = RegistryUtil()
  if registry.read("cfduid", "hydravion") <> invalid AND registry.read("sails", "hydravion") <> invalid then
    'Check whether cookies are set, if not we login. If found, we head over to onNext()
    onNext("test")
  end if
end function

sub onNext(obj)
  'Now that we have cookies, we can initialize the video/live player
  initializeVideoPlayer()
  initializeLivePlayer()
  'Get Edge Servers if necessary
  registry = RegistryUtil()
  if registry.read("edge", "hydravion") <> invalid then
    'Edge Server already set, skip!
    getSubs(obj)
  else
    'Edge Server not set, do not skip!
    m.edge_task = CreateObject("roSGNode", "urlTask")
    m.edge_task.observeField("response", "onEdges")
    edges = "https://www.floatplane.com/api/edges"
    m.edge_task.setField("url", edges)
    m.edge_task.control = "RUN"
  end if
end sub

sub onEdges(obj)
  'Find best edge server
  m.best_edge = CreateObject("roSGNode", "edgesTask")
  m.best_edge.observeField("bestEdge", "bestEdge")
  m.best_edge.setField("edges", obj.getData())
  m.best_edge.control = "RUN"
end sub

sub bestEdge(obj)
  'Got best edge, set best edge
  registry = RegistryUtil()
  edge = obj.getData()
  if edge = "" then
    'Edge didn't return, so let's just use the default
    registry.write("edge", m.default_edge, "hydravion")
  else if edge.Instr(m.default_edge) > -1 then
    'Edge found, not default, so let's use it
    registry.write("edge", m.default_edge, "hydravion")
  else
    'In case something else happens, just use the default
    registry.write("edge", edge, "hydravion")
  end if
  'Get subs
  getSubs(obj)
end sub

sub getSubs(obj)
  m.login_screen.visible = false
  m.subs_task = CreateObject("roSGNode", "urlTask")
  url = "https://www.floatplane.com/api/user/subscriptions"
  m.subs_task.setField("url", url)
  m.subs_task.observeField("response", "onSubs")
  m.subs_task.control = "RUN"
end sub

sub onSubs(obj)
  m.top.subscriptions = obj.getData()
  m.category_screen.visible = true
  m.category_screen.setFocus(true)
end sub

sub onCategoryResponse(obj)
  response = obj.getData()
  json = ParseJSON(response)

  'Redundant subscriptions can occur, so let's get rid of them
  trimmed = createObject("roArray",json.Count(),true)
  for each subscription in json
    if contains(trimmed, subscription.creator) = false
      trimmed.Push(subscription)
    end if
  end for

  'Now let's display the subscriptions so the user can select one
  contentNode = createObject("roSGNode", "ContentNode")
  for each subscription in trimmed
    node = createObject("roSGNode", "category_node")
    node.title = subscription.plan.title
    node.feed_url = "https://www.floatplane.com/api/creator/videos?creatorGUID=" + subscription.creator
    node.creatorGUID = subscription.creator
    contentNode.appendChild(node)
  end for
  m.category_screen.findNode("category_list").content = contentNode
  m.category_screen.setFocus(true)
end sub

function contains(trimmed,id) as Boolean
  for each subscription in trimmed
    if subscription.creator = id
      return true
    end if
    return false
  end for
  return false
end function

sub onCategorySelected(obj)
  'Load feed for specific subscription
  list = m.category_screen.findNode("category_list")
  item = list.content.getChild(obj.getData())
  m.content_screen.setField("feed_name", item.title)
  'Grab stream info
  m.stream_info = CreateObject("roSGNode", "urlTask")
  url = "https://www.floatplane.com/api/creator/info?creatorGUID=" + item.creatorGUID
  m.stream_info.setField("url", url)
  m.stream_info.observeField("response", "onGetStreamInfo")
  m.stream_info.control = "RUN"

  m.feed_url = item.feed_url
  m.feed_page = 0
end sub

sub onGetStreamInfo(obj)
  info = ParseJSON(obj.getData())
  if info[0].liveStream <> invalid
    if info[0].title <> invalid
      'If stream info found, create node
      node = createObject("roSGNode", "ContentNode")
      node.HDPosterURL = info[0].liveStream.thumbnail.path
      node.title = info[0].liveStream.title
      node.ShortDescriptionLine1 = info[0].liveStream.title
      node.ShortDescriptionLine2 = "Live"
      node.guid = info[0].liveStream.streamPath
      node.id = ""
      node.streamformat = "hls"
      m.content_screen.setField("stream_node", node)

      '#TODO -- check to see if streaming, waiting for API to implement this
      ''m.stream_check = CreateObject("roSGNode", "urlTask")
      ''url = "https://www.floatplane.com/api/creator/list?search=" + info[0].urlname
      ''m.stream_check.setField("url", url)
      ''m.stream_check.observeField("response", "setIfStreaming")
      ''m.stream_check.control = "RUN"
      m.content_screen.setField("streaming", false)
      loadFeed(m.feed_url, m.feed_page)
    else
      m.content_screen.setField("streaming", false)
      loadFeed(m.feed_url, m.feed_page)
    end if
  else
    m.content_screen.setField("streaming", false)
    loadFeed(m.feed_url, m.feed_page)
  end if
end sub

sub loadFeed(url, page)
  'Used to load subscription feed given url and page
  after = 20 * page
  newurl = url + "&fetchAfter=" + after.ToStr() + ""
  m.feed_task = createObject("roSGNode", "urlTask")
  m.feed_task.setField("url", newurl)
  m.feed_task.observeField("response", "onFeedResponse")
  m.feed_task.control = "RUN"
  m.feedpage = page
  m.feedurl = url
end sub

sub onFeedResponse(obj)
  unparsed_json = obj.getData()
  m.content_screen.setField("page", m.feedpage)
  m.content_screen.setField("feed_data", unparsed_json)
  m.category_screen.visible = false
  m.content_screen.visible = true
end sub

sub onContentSelected(obj)
  selected_index = obj.getData()
  m.selected_media = m.content_screen.findNode("content_grid").content.getChild(selected_index)
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
  else
    'User selected video, let's play
    m.details_screen.content = m.selected_media
    m.content_screen.visible = false
    m.details_screen.visible = true
  end if
end sub

sub onPlayButtonPressed(obj)
  if m.live then
    '#TODO -- waiting for API call for isLive
    ' Shouldn't need to handle different resolutions as the given m3u8 has that all added in already
    doLive()
  else
    'Just grab highest resolution supported by TV for now (nobody has 8k yet, right?)
    'We have a check in onPlayerStateChanged so that, if the video doesn't exist for the given resolution, we'll check the next best TV-supported resolution (rinse, lather, repeat)
    supported = m.device.GetSupportedGraphicsResolutions()
    height = strI(supported[supported.Count() - 1].height)
    m.video_task = CreateObject("roSGNode", "urlTask")
    url = "https://www.floatplane.com/api/video/url?guid=" + m.selected_media.guid + "&quality=" + height.Trim() + ""
    m.video_task.setField("url", url)
    m.video_task.observeField("response", "onPlayVideo")
    m.video_task.control = "RUN"
  end if
end sub

sub doLive()
  'json = m.content_screen.getField("feed_data")
  'feed = ParseJSON(json)
  'chanid = feed[0].creator
  'url = "https://www.floatplane.com/api/creator/info?creatorGUID=" + chanid + ""
  'm.chan_task = createObject("roSGNode", "urlTask")
  'm.chan_task.setField("url", url)
  'm.chan_task.observeField("response", "doLiveStuff")
  'm.chan_task.control = "RUN"

  'Grab stream info from earlier
  streamInfo = m.content_screen.getField("stream_node")
  if m.top.getScene().dialog <> invalid
    'If we tried to play the stream from the options dialog, close said dialog
    m.top.getScene().dialog.close = true
  end if
  url = ""
  if streamInfo.guid.Instr("live_abr") > -1
    registry = RegistryUtil()
    url = "https://cdn1.floatplane.com" + streamInfo.guid + "/playlist.m3u8"
  else if streamInfo.guid.Instr("/api/lvs/hls/lvs") > -1
    url = "https://usher.ttvnw.net" + streamInfo.guid
  end if
  ? url
  m.live_task = createObject("roSGNode", "liveTask")
  m.live_task.setField("url", url)
  m.live_task.observeField("done", "loadLiveStuff")
  m.live_task.control = "RUN"
end sub

'sub doLiveStuff(obj)
  'if m.top.getScene().dialog <> invalid
  ''  m.top.getScene().dialog.close = true
  'end if

  'json = obj.getData()
  'feed = ParseJSON(json)
  'url = "https://usher.ttvnw.net" + feed[0].livestream.streamPath
  'm.live_task = createObject("roSGNode", "liveTask")
  'm.live_task.setField("url", url)
  'm.live_task.observeField("done", "loadLiveStuff")
  'm.live_task.control = "RUN"
'end sub

sub loadLiveStuff(obj)
  'It doesn't like loading straight from the url, so we wrote the m3u8 to a file
  videoContent = createObject("roSGNode", "ContentNode")
  videoContent.url = "tmp:/live.m3u8"
  videoContent.streamformat = "big-hls"

  m.content_screen.visible = false
  m.liveplayer.visible = true
  m.liveplayer.setFocus(true)
  m.liveplayer.content = videoContent
  m.liveplayer.control = "play"
end sub

sub onPlayVideo(obj)
  registry = RegistryUtil()
  edge = registry.read("edge", "hydravion")
  ? edge
  m.details_screen.visible = false
  m.videoplayer.visible = true
  m.videoplayer.setFocus(true)
  m.selected_media.url = obj.getData().GetEntityEncode().Replace("&quot;","").Replace(m.default_edge,edge).DecodeUri()
  ? m.selected_media.url
  m.videoplayer.content = m.selected_media
  m.videoplayer.control = "play"
end sub

sub initializeVideoPlayer()
  'Setup video player with proper cookies
  registry = RegistryUtil()
  cfduid = registry.read("cfduid", "hydravion")
  sails = registry.read("sails", "hydravion")
  cookies = "__cfduid=" + cfduid + "; sails.sid=" + sails
  m.videoplayer.EnableCookies()
  m.videoplayer.setCertificatesFile("common:/certs/ca-bundle.crt")
  m.videoplayer.initClientCertificates()
  m.videoplayer.SetConnectionTimeout(60)
  m.videoplayer.AddHeader("Accept", "application/json")
  m.videoplayer.AddHeader("Cookie", cookies)
  m.videoplayer.notificationInterval = 1
  m.videoplayer.observeField("position", "onPlayerPositionChanged")
  m.videoplayer.observeField("state", "onPlayerStateChanged")
  m.videoindex = 0
end sub

sub initializeLivePlayer()
  'Setup live player with proper cookies
  registry = RegistryUtil()
  cfduid = registry.read("cfduid", "hydravion")
  sails = registry.read("sails", "hydravion")
  cookies = "__cfduid=" + cfduid + "; sails.sid=" + sails
  m.liveplayer.EnableCookies()
  m.liveplayer.setCertificatesFile("common:/certs/ca-bundle.crt")
  m.liveplayer.initClientCertificates()
  m.liveplayer.SetConnectionTimeout(60)
  m.liveplayer.AddHeader("Accept", "application/json")
  m.liveplayer.AddHeader("Cookie", cookies)
  m.liveplayer.notificationInterval = 1
  m.liveplayer.observeField("position", "onPlayerPositionChanged")
  m.liveplayer.observeField("state", "onLivePlayerStateChanged")
end sub

sub onPlayerPositionChanged(obj)
  '? "Position: ", obj.getData()
end sub

sub onPlayerStateChanged(obj)
  '? "State: ", obj.getData()
  state = obj.getData()
  if state = "finished"
    'Close video player when finished player
    closeVideo()
  else if state = "error"
    'Video couldn't play
    '-1 HTTP error: malformed headers or HTTP error result
    '-2 Connection timed out
    '-3 Unknown error
    '-4 Empty list; no streams specified to play
    '-5 Media error; the media format is unknown or unsupported
    '-6 DRM error
    ? m.videoplayer.errorCode
    ? m.videoplayer.errorMsg
    if m.videoplayer.errorCode = -3
      m.videoindex = m.videoindex + 1
      supported = m.device.GetSupportedGraphicsResolutions()
      if supported.Count() > m.videoindex
        height = strI(supported[supported.Count() - 1 - m.videoindex].height)
        m.video_task = CreateObject("roSGNode", "urlTask")
        url = "https://www.floatplane.com/api/video/url?guid=" + m.selected_media.guid + "&quality=" + height.Trim() + ""
        '? url
        m.video_task.setField("url", url)
        m.video_task.observeField("response", "onPlayVideo")
        m.video_task.control = "RUN"
      else
        showVideoError()
      end if
    end if
  end if
end sub

sub onLivePlayerStateChanged(obj)
  '? "State: ", obj.getData()
  state = obj.getData()
  if state = "error"
    ? m.liveplayer.errorCode
    ? m.liveplayer.errorMsg
    showLiveError()
  else if state = "finished"
    closeStream()
  else if state = "playing"
    ? "Stream is playing, huzzah!"
  end if
end sub

sub showVideoError()
  m.top.getScene().dialog = createObject("roSGNode", "Dialog")
  m.top.getScene().dialog.title = "Error"
  m.top.getScene().dialog.optionsDialog = true
  m.top.getScene().dialog.iconUri = ""
  m.top.getScene().dialog.message = "Video cannot be played!"
  m.top.getScene().dialog.optionsDialog = true
end sub

sub showLiveError()
  m.top.getScene().dialog = createObject("roSGNode", "Dialog")
  m.top.getScene().dialog.title = "Error"
  m.top.getScene().dialog.optionsDialog = true
  m.top.getScene().dialog.iconUri = ""
  m.top.getScene().dialog.message = "Live stream not found!"
  m.top.getScene().dialog.optionsDialog = true
end sub

sub closeVideo()
  m.videoplayer.control = "stop"
  m.videoplayer.visible = false
  m.details_screen.visible = true
end sub

sub closeStream()
  m.liveplayer.control = "stop"
  m.liveplayer.visible = false
  m.content_screen.visible = true
end sub

sub setIfStreaming(obj)
  info = ParseJSON(obj.getData())
  ''? info[0].urlname
  if info[0].liveStream <> invalid  then
    if info[0].liveStream <> null then
      m.content_screen.setField("streaming", true)
      m.live = true
    else
      m.content_screen.setField("streaming", false)
      m.live = false
      'false'
    end if
    m.content_screen.setField("streaming", false)
    m.live = false
    'false'
  else
    m.content_screen.setField("streaming", false)
    m.live = false
    'false'
  end if
  loadFeed(m.feed_url, m.feed_page)
end sub

sub showOptions()
  'Create dialog and populate it with options
  m.top.getScene().dialog = createObject("roSGNode", "Dialog")
  m.top.getScene().dialog.title = "Options"
  m.top.getScene().dialog.optionsDialog = true
  m.top.getScene().dialog.iconUri = ""
  m.top.getScene().dialog.message = "Select Option"
  m.top.getScene().dialog.buttons = ["Watch Stream","Logout"]
  m.top.getScene().dialog.optionsDialog = true
  m.top.getScene().dialog.observeField("buttonSelected","handleOptions")
end sub

sub showDetailOptions()
  'Grab resolutions available for the video
  m.res_task = CreateObject("roSGNode", "urlTask")
  url = "https://www.floatplane.com/api/video/info?videoGUID=" + m.selected_media.guid
  m.res_task.setField("url", url)
  m.res_task.observeField("response", "makeDetailOptions")
  m.res_task.control = "RUN"
end sub

sub makeDetailOptions(obj)
  'Display available resolutions for selected video
  unparsed = obj.getData()
  info = ParseJSON(unparsed)
  m.dbuttons = createObject("roArray", 4, true)
  for each level in info.levels
    m.dbuttons.Push(level.name)
  end for
  m.top.getScene().dialog = createObject("roSGNode", "Dialog")
  m.top.getScene().dialog.title = "Resolution"
  m.top.getScene().dialog.optionsDialog = true
  m.top.getScene().dialog.iconUri = ""
  m.top.getScene().dialog.message = "Select Stream Resolution"
  m.top.getScene().dialog.buttons = m.dbuttons
  m.top.getScene().dialog.optionsDialog = true
  m.top.getScene().dialog.observeField("buttonSelected","handleDetailOptions")
end sub

sub handleDetailOptions()
  url = ""
  m.video_task = CreateObject("roSGNode", "urlTask")
  url = "https://www.floatplane.com/api/video/url?guid=" + m.selected_media.guid + "&quality=" + m.dbuttons[m.top.getScene().dialog.buttonSelected]
  m.top.getScene().dialog.close = true
  '? url
  m.video_task.setField("url", url)
  m.video_task.observeField("response", "onPlayVideo")
  m.video_task.control = "RUN"
end sub

sub handleOptions()
  if m.top.getScene().dialog.buttonSelected = 0
    doLive()
  else if m.top.getScene().dialog.buttonSelected = 1
    showLogoutDialog()
  end if
end sub

sub showLogoutDialog()
  m.top.getScene().dialog = createObject("roSGNode", "Dialog")
  m.top.getScene().dialog.title = "Logout?"
  m.top.getScene().dialog.optionsDialog = true
  m.top.getScene().dialog.iconUri = ""
  m.top.getScene().dialog.message = "Press OK to logout"
  m.top.getScene().dialog.buttons = ["OK"]
  m.top.getScene().dialog.optionsDialog = true
  m.top.getScene().dialog.observeField("buttonSelected","doLogout")
end sub

sub showLiveDialog()
  m.top.getScene().dialog = createObject("roSGNode", "Dialog")
  m.top.getScene().dialog.title = "Play Live Stream?"
  m.top.getScene().dialog.optionsDialog = true
  m.top.getScene().dialog.iconUri = ""
  m.top.getScene().dialog.message = "Press OK to attempt to play live stream"
  m.top.getScene().dialog.buttons = ["OK"]
  m.top.getScene().dialog.optionsDialog = true
  m.top.getScene().dialog.observeField("buttonSelected","doLive")
end sub

sub doLogout()
  m.top.getScene().dialog.close = true
  registry = RegistryUtil()
  registry.deleteSection("hydravion")
  m.details_screen.visible = false
  m.content_screen.visible = false
  m.category_screen.visible = false
  m.login_screen.visible = true
  m.login_screen.setFocus(true)
  m.login_screen.findNode("username").setFocus(true)
  m.login_screen.findNode("username").text = "username"
  m.login_screen.findNode("password").text = "password"
end sub

function onKeyEvent(key, press) as Boolean
  if key = "back" and press
    if m.details_screen.visible
      m.details_screen.visible = false
      m.content_screen.visible = true
      m.content_screen.setFocus(true)
      return true
    else if m.videoplayer.visible
      m.videoplayer.control = "stop"
      m.videoplayer.visible = false
      m.details_screen.visible = true
      m.details_screen.setFocus(true)
      return true
    else if m.liveplayer.visible
      m.liveplayer.control = "stop"
      m.liveplayer.visible = false
      m.content_screen.visible = true
      m.content_screen.setFocus(true)
      return true
    else if m.content_screen.visible
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
        showLogoutDialog()
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
