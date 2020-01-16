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
    onNext("test")
  end if
end function

sub onNext(obj)
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

'Find best edge server
sub onEdges(obj)
  m.best_edge = CreateObject("roSGNode", "edgesTask")
  m.best_edge.observeField("bestEdge", "bestEdge")
  m.best_edge.setField("edges", obj.getData())
  m.best_edge.control = "RUN"
end sub

'Set best edge
sub bestEdge(obj)
  registry = RegistryUtil()
  edge = obj.getData()
  if edge = "" then
    registry.write("edge", m.default_edge, "hydravion")
  else if edge.Instr(m.default_edge) > -1 then
    registry.write("edge", m.default_edge, "hydravion")
  else
    registry.write("edge", edge, "hydravion")
  end if
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
  'print obj.getData()
  m.top.subscriptions = obj.getData()
  m.category_screen.visible = true
  m.category_screen.setFocus(true)
end sub

sub onPlayButtonPressed(obj)
  supported = m.device.GetSupportedGraphicsResolutions()
  height = strI(supported[supported.Count() - 1].height)
  m.video_task = CreateObject("roSGNode", "urlTask")
  url = "https://www.floatplane.com/api/video/url?guid=" + m.selected_media.guid + "&quality=" + height.Trim() + ""
  ? url
  '? height
  m.video_task.setField("url", url)
  m.video_task.observeField("response", "onPlayVideo")
  m.video_task.control = "RUN"
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
  registry = RegistryUtil()
  cfduid = registry.read("cfduid", "hydravion")
  sails = registry.read("sails", "hydravion")
  cookies = "__cfduid=" + cfduid + "; sails.sid=" + sails
  m.liveplayer.EnableCookies()
	m.liveplayer.setCertificatesFile("common:/certs/ca-bundle.crt")
	m.liveplayer.initClientCertificates()
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
    closeVideo()
  else if state = "error"
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
    '? m.liveplayer.errorMsg
    showLiveError()
  else if state = "finished"
    closeStream()
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

sub onContentSelected(obj)
  selected_index = obj.getData()
  m.selected_media = m.content_screen.findNode("content_grid").content.getChild(selected_index)
  if m.selected_media.title = "nextpage"
    '? "next page"
    m.feedpage = m.feedpage + 1
    loadFeed(m.feedurl, m.feedpage)
  else if m.selected_media.title = "backpage"
    '? "back page"
    if m.feedpage <> 0
      m.feedpage = m.feedpage - 1
      loadFeed(m.feedurl, m.feedpage)
    end if
  else if m.selected_media.title = "Live"
    doLive()
  else
    '? "real video selected"
    m.details_screen.content = m.selected_media
    m.content_screen.visible = false
    m.details_screen.visible = true
  end if
end sub

sub onCategorySelected(obj)
  list = m.category_screen.findNode("category_list")
  item = list.content.getChild(obj.getData())
  ' Load feed from here for specific sub
  m.content_screen.setField("feed_name", item.title)

  m.stream_info = CreateObject("roSGNode", "urlTask")
  url = "https://www.floatplane.com/api/creator/info?creatorGUID=" + item.creatorGUID
  m.stream_info.setField("url", url)
  m.stream_info.observeField("response", "onGetStreamInfo")
  m.stream_info.control = "RUN"
  'loadFeed(item.feed_url, 0)
  m.feed_url = item.feed_url
  m.feed_page = 0
end sub

sub onGetStreamInfo(obj)
  info = ParseJSON(obj.getData())
  node = createObject("roSGNode", "ContentNode")
  node.HDPosterURL = info[0].liveStream.thumbnail.path
  node.title = info[0].liveStream.title
  node.ShortDescriptionLine1 = info[0].title
  node.ShortDescriptionLine2 = "Live"
  node.guid = info[0].liveStream.streamPath
  node.id = ""
  node.streamformat = "hls"
  m.content_screen.setField("stream_node", node)

  m.stream_check = CreateObject("roSGNode", "urlTask")
  url = "https://www.floatplane.com/api/creator/list?search=" + info[0].title
  m.stream_check.setField("url", url)
  m.stream_check.observeField("response", "setIfStreaming")
  m.stream_check.control = "RUN"
end sub

sub setIfStreaming(obj)
  info = ParseJSON(obj.getData())
  ? info[0].title
  if info[0].liveStream <> invalid  then
    if info[0].liveStream <> null then
      m.content_screen.setField("streaming", true)
    else
      m.content_screen.setField("streaming", false)
    end if
    m.content_screen.setField("streaming", false)
  else
    m.content_screen.setField("streaming", false)
  end if

  loadFeed(m.feed_url, m.feed_page)
end sub

sub loadFeed(url, page)
  after = 20 * page
  newurl = url + "&fetchAfter=" + after.ToStr() + ""
  '? newurl
  m.feed_task = createObject("roSGNode", "urlTask")
  m.feed_task.setField("url", newurl)
  m.feed_task.observeField("response", "onFeedResponse")
  m.feed_task.control = "RUN"
  m.feedpage = page
  m.feedurl = url
  if page <> 0
    '? "Next page loading..."
  end if
end sub

sub onFeedResponse(obj)
  unparsed_json = obj.getData()
  m.content_screen.setField("page", m.feedpage)
  m.content_screen.setField("feed_data", unparsed_json)
  m.category_screen.visible = false
  m.content_screen.visible = true
  if m.feedpage <> 0
    '? "Next page (feed) loaded!"
    '? unparsed_json
  end if
end sub

sub onCategoryResponse(obj)
  response = obj.getData()
  json = ParseJSON(response)

  contentNode = createObject("roSGNode", "ContentNode")
  for each subscription in json
    node = createObject("roSGNode", "category_node")
    node.title = subscription.plan.title
    node.feed_url = "https://www.floatplane.com/api/creator/videos?creatorGUID=" + subscription.creator
    node.creatorGUID = subscription.creator
    contentNode.appendChild(node)
  end for
  m.category_screen.findNode("category_list").content = contentNode
  m.category_screen.setFocus(true)
end sub

sub showOptions()
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
  m.res_task = CreateObject("roSGNode", "urlTask")
  url = "https://www.floatplane.com/api/video/info?videoGUID=" + m.selected_media.guid
  m.res_task.setField("url", url)
  m.res_task.observeField("response", "makeDetailOptions")
  m.res_task.control = "RUN"
end sub

sub makeDetailOptions(obj)
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
  'if m.top.getScene().dialog.buttonSelected = 0
  ''  url = "https://www.floatplane.com/api/video/url?guid=" + m.selected_media.guid + "&quality=360"
  'else if m.top.getScene().dialog.buttonSelected = 1
  ''  url = "https://www.floatplane.com/api/video/url?guid=" + m.selected_media.guid + "&quality=480"
  'else if m.top.getScene().dialog.buttonSelected = 2
  ''  url = "https://www.floatplane.com/api/video/url?guid=" + m.selected_media.guid + "&quality=720"
  'else if m.top.getScene().dialog.buttonSelected = 3
  ''  url = "https://www.floatplane.com/api/video/url?guid=" + m.selected_media.guid + "&quality=1080"
  'else if m.top.getScene().dialog.buttonSelected = 4
  ''  url = "https://www.floatplane.com/api/video/url?guid=" + m.selected_media.guid + "&quality=1440"
  'else if m.top.getScene().dialog.buttonSelected = 5
  ''  url = "https://www.floatplane.com/api/video/url?guid=" + m.selected_media.guid + "&quality=1080"
  'end if
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
  'm.go_home = createObject("roSGNode", "goHome")
  'm.go_home.control = "RUN"
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

sub doLive()
  json = m.content_screen.getField("feed_data")
  feed = ParseJSON(json)
  chanid = feed[0].creator
  url = "https://www.floatplane.com/api/creator/info?creatorGUID=" + chanid + ""
  m.chan_task = createObject("roSGNode", "urlTask")
  m.chan_task.setField("url", url)
  m.chan_task.observeField("response", "doLiveStuff")
  m.chan_task.control = "RUN"
end sub

sub doLiveStuff(obj)
  registry = RegistryUtil()
  edge = registry.read("edge", "hydravion")

  m.top.getScene().dialog.close = true
  json = obj.getData()
  feed = ParseJSON(json)
  vidUrl = "https://" + edge + feed[0].livestream.streamPath

  videoContent = createObject("roSGNode", "ContentNode")
  videoContent.url = vidURL
  videoContent.streamformat = "big-hls"

  m.content_screen.visible = false
  m.liveplayer.visible = true
  m.liveplayer.setFocus(true)
  m.liveplayer.content = videoContent
  m.liveplayer.control = "play"
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
      'showLogoutDialog()
      'showOptions()
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
