function init()
  m.device = CreateObject("roDeviceInfo")
  m.category_screen = m.top.findNode("category_screen")
  m.content_screen = m.top.findNode("content_screen")
  m.details_screen = m.top.findNode("details_screen")
  m.login_screen = m.top.findNode("login_screen")

  m.videoplayer = m.top.findNode("videoplayer")
  m.liveplayer = m.top.findNode("liveplayer")
  initializeVideoPlayer()
  initializeLivePlayer()

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
  m.video_task.setField("url", url)
  m.video_task.observeField("response", "onPlayVideo")
  m.video_task.control = "RUN"
end sub

sub onPlayVideo(obj)
  m.details_screen.visible = false
  m.videoplayer.visible = true
  m.videoplayer.setFocus(true)
  m.selected_media.url = obj.getData().GetEntityEncode().Replace("&quot;","").DecodeUri()
  m.videoplayer.content = m.selected_media
  m.videoplayer.control = "play"
end sub

sub initializeVideoPlayer()
  m.videoplayer.EnableCookies()
	m.videoplayer.setCertificatesFile("common:/certs/ca-bundle.crt")
	m.videoplayer.initClientCertificates()
  m.videoplayer.notificationInterval = 1
  m.videoplayer.observeField("position", "onPlayerPositionChanged")
  m.videoplayer.observeField("state", "onPlayerStateChanged")
end sub

sub initializeLivePlayer()
  m.liveplayer.EnableCookies()
	m.liveplayer.setCertificatesFile("common:/certs/ca-bundle.crt")
	m.liveplayer.initClientCertificates()
  m.liveplayer.notificationInterval = 1
  m.liveplayer.observeField("position", "onPlayerPositionChanged")
  m.liveplayer.observeField("state", "onLivePlayerStateChanged")
end sub

sub onPlayerPositionChanged(obj)
  ? "Position: ", obj.getData()
end sub

sub onPlayerStateChanged(obj)
  ? "State: ", obj.getData()
  state = obj.getData()
  if state = "finished"
    closeVideo()
  end if
end sub

sub onLivePlayerStateChanged(obj)
  ? "State: ", obj.getData()
  state = obj.getData()
  if state = "error"
    ? m.liveplayer.errorMsg
    showLiveError()
  else if state = "finished"
    closeStream()
  end if
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
  m.details_screen.content = m.selected_media
  m.content_screen.visible = false
  m.details_screen.visible = true
end sub

sub onCategorySelected(obj)
  list = m.category_screen.findNode("category_list")
  item = list.content.getChild(obj.getData())
  ' Load feed from here for specific sub
  m.content_screen.setField("feed_name", item.title)
  loadFeed(item.feed_url)
end sub

sub loadFeed(url)
  m.feed_task = createObject("roSGNode", "urlTask")
  m.feed_task.setField("url", url)
  m.feed_task.observeField("response", "onFeedResponse")
  m.feed_task.control = "RUN"
end sub

sub onFeedResponse(obj)
  unparsed_json = obj.getData()
  m.content_screen.setField("feed_data", unparsed_json)
  m.category_screen.visible = false
  m.content_screen.visible = true
end sub

sub onCategoryResponse(obj)
  response = obj.getData()
  json = ParseJSON(response)

  contentNode = createObject("roSGNode", "ContentNode")
  for each subscription in json
    node = createObject("roSGNode", "category_node")
    node.title = subscription.plan.title
    node.feed_url = "https://www.floatplane.com/api/creator/videos?creatorGUID=" + subscription.creator
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
  m.top.getScene().dialog.close = true
  json = obj.getData()
  feed = ParseJSON(json)
  liveUrl = feed[0].livestream.streamPath
  vidUrl = "https://cdn1.floatplane.com" + liveUrl + "/playlist.m3u8"

  videoContent = createObject("roSGNode", "ContentNode")
  videoContent.url = vidURL
  videoContent.quality = true
  videoContent.streamformat = "big-hls"

  m.content_screen.visible = false
  m.liveplayer.visible = true
  m.liveplayer.setFocus(true)
  'm.liveplayer.content = vidUrl
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
    else if m.login_screen.visible
      m.login_screen.visible = true
      m.login_screen.setFocus(true)
      return true
    end if
  else if key = "options" and press
    if m.videoplayer.visible = false
      if m.content_screen.visible = true
        showOptions()
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
