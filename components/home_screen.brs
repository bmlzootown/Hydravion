function init()
  m.device = CreateObject("roDeviceInfo")
  m.category_screen = m.top.findNode("category_screen")
  m.content_screen = m.top.findNode("content_screen")
  m.details_screen = m.top.findNode("details_screen")
  m.login_screen = m.top.findNode("login_screen")

  m.feedpage = 0
  m.default_edge = "Edge01-na.floatplane.com"
  m.live = false
  m.playButtonPressed = false

  m.videoplayer = m.top.findNode("videoplayer")

  m.login_screen.observeField("next", "onNext")
  m.category_screen.observeField("category_selected", "onCategorySelected")
  m.content_screen.observeField("content_selected", "onContentSelected")
  m.details_screen.observeField("play_button_pressed", "onPlayButtonPressed")

  m.supported = m.device.GetSupportedGraphicsResolutions()
  m.arrutil = ArrayUtil()

  registry = RegistryUtil()
  if registry.read("cfduid", "hydravion") <> invalid AND registry.read("sails", "hydravion") <> invalid then
    'Check whether cookies are set, if not we login. If found, we head over to onNext()
    onNext("test")
  end if
end function

sub onNext(obj)
  'Now that we have cookies, we can initialize the video/live player
  initializeVideoPlayer()
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
  m.feed_task = createObject("roSGNode", "setupCategoriesTask")
  m.feed_task.setField("unparsed", obj.getData())
  m.feed_task.observeField("category_node", "onCateogrySetup")
  m.feed_task.control = "RUN"
end sub

sub onCateogrySetup(obj)
  m.category_screen.findNode("category_list").content = obj.getData()
  m.category_screen.setFocus(true)
end sub

sub onCategorySelected(obj)
  'Load feed for specific subscription
  list = m.category_screen.findNode("category_list")
  item = list.content.getChild(obj.getData())
  m.content_screen.setField("feed_name", item.title)
  'Grab stream info
  m.stream_cdn = CreateObject("roSGNode", "urlTask")
  url = "https://www.floatplane.com/api/cdn/delivery?type=live&creator=" + item.creatorGUID
  m.stream_cdn.setField("url", url)
  m.stream_cdn.observeField("response", "onGetStreamURL")
  m.stream_cdn.control = "RUN"
  m.creatorGUID = item.creatorGUID

  m.feed_url = item.feed_url
  m.feed_page = 0
end sub

sub onGetStreamURL(obj)
  json = ParseJSON(obj.getData())
  cdn = json.cdn
  uri = json.resource.uri
  if json.resource.data <> invalid
    regexObj = CreateObject("roRegex", "\{(.*?)\}", "i")
    regUri = regexObj.matchAll(uri)
    for i = 0 to regUri.Count() - 1
      data = json.resource.data[regUri[i][1]]
      uri = strReplace(uri, regUri[i][0], data)
    end for
  end if
  m.streamUri = cdn + uri

  m.stream_info = CreateObject("roSGNode", "urlTask")
  url = "https://www.floatplane.com/api/creator/info?creatorGUID=" + m.creatorGUID
  m.stream_info.setField("url", url)
  m.stream_info.observeField("response", "onGetStreamInfo")
  m.stream_info.control = "RUN"
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
      node.Description = info[0].liveStream.description
      node.guid = m.streamUri
      node.id = "live"
      node.streamformat = "hls"
      m.stream_node = node
      'm.content_screen.setField("stream_node", node)

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
  'We will setup the feed node in the setupFeedTask, allowing us to manually cache thumbnail images
  unparsed_json = obj.getData()
  m.setupFeed_task = createObject("roSGNode", "setupFeedTask")
  m.setupFeed_task.setField("unparsed_feed", unparsed_json)
  m.setupFeed_task.setField("streaming", false)
  m.setupFeed_task.setField("stream_node", m.stream_node)
  m.setupFeed_task.setField("page", m.feedpage)
  m.setupFeed_task.observeField("feed", "onFeedSetup")
  m.setupFeed_task.control = "RUN"
end sub

sub onFeedSetup(obj)
  'Feed node has been setup, show it to user
  m.content_screen.setField("page", m.feedpage)
  m.content_screen.setField("feed_node", obj.getData())
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
  else if m.selected_media.id = "live"
    m.live = true
    m.details_screen.content = m.selected_media
    m.content_screen.visible = false
    m.details_screen.visible = true
    m.details_screen.setFocus(true)
  else
    m.live = false
    m.selected_task = CreateObject("roSGNode", "urlTask")
    url = "https://www.floatplane.com/api/video/info?videoGUID=" + m.selected_media.guid
    m.selected_task.setField("url", url)
    m.selected_task.observeField("response", "onSelectedSetup")
    m.selected_task.control = "RUN"
  end if
end sub

sub onSelectedSetup(obj)
  'Got available resolutions for selected video
  unparsed = obj.getData()
  info = ParseJSON(unparsed)
  resolutions = createObject("roArray", 10, true)
  'Push parsed resolutions to array for easy access
  for each level in info.levels
    resolutions.Push(level.name)
  end for
  'Loop through supported resolutions, finding highest available that also exists for video
  height = ""
  for i = m.supported.Count() - 1 to 0 step -1
    tv = (strI(m.supported[i].height)).trim()
    if m.arrutil.contains(resolutions, tv)
      height = tv
      exit for
    end if
  end for
  if height = ""
    height = "720"
  end if

  'Show selected media node for debug
  ? m.selected_media

  m.video_task = CreateObject("roSGNode", "urlTask")
  url = "https://www.floatplane.com/api/video/url?guid=" + m.selected_media.guid + "&quality=" + height.Trim() + ""
  m.video_task.setField("url", url)
  if m.playButtonPressed
    m.video_task.observeField("response", "onPlayVideo")
    m.video_task.control = "RUN"
  else
    'User selected video, let's prebuffer while on detail screen
    m.video_task.observeField("response", "onPreBuffer")
    m.video_task.control = "RUN"
  end if
end sub

sub onPreBuffer(obj)
  'Setup videoplayer for prebuffering while user is on detail screen
  'registry = RegistryUtil()
  'edge = registry.read("edge", "hydravion")
  m.details_screen.visible = false
  m.videoplayer.visible = true
  m.videoplayer.setFocus(true)
  'm.selected_media.url = obj.getData().GetEntityEncode().Replace("&quot;","").Replace(m.default_edge,edge).DecodeUri()
  m.selected_media.url = obj.getData().GetEntityEncode().Replace("&quot;","").DecodeUri()
  ? m.selected_media.url
  m.videoplayer.content = m.selected_media
  m.videoplayer.visible = false
  m.videoplayer.setFocus(false)
  m.videoplayer.control = "prebuffer"
  m.details_screen.content = m.selected_media
  m.content_screen.visible = false
  m.details_screen.visible = true
  m.details_screen.setFocus(true)
end sub

sub onPlayButtonPressed(obj)
  if m.live then
    '#TODO -- waiting for API call for isLive
    ' Shouldn't need to handle different resolutions as the given m3u8 has that all added in already
    doLive()
  else
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
  if m.top.getScene().dialog <> invalid
    'If we tried to play the stream from the options dialog, close said dialog
    m.top.getScene().dialog.close = true
  end if
  url = streamInfo.guid
  ? streamInfo
  'm.live_task = createObject("roSGNode", "liveTask")
  'm.live_task.setField("url", url)
  'm.live_task.observeField("done", "loadLiveStuff")
  'm.live_task.control = "RUN"
  loadLiveStuff(url)
end sub

sub loadLiveStuff(obj)
  'It doesn't like loading straight from the url, so we wrote the m3u8 to a file
  videoContent = createObject("roSGNode", "ContentNode")
  'videoContent.url = "tmp:/live.m3u8"
  'videoContent.url = obj.DecodeUri()
  videoContent.url = "https://video-weaver.atl01.hls.ttvnw.net/v1/playlist/CoIFW1ZVhMI2-A6TBpi8zz9_y3ubEwNYWRLurLWTEfiKGCXQYDUQn-fTnYdvdt5kqvycJ_eivF-oDyZge00GigExTjGWugKiLT21Te_EWTRVAFTGXx4NEue1f27jFSXeAWKU2I7n0g4RBQkJ2tYTC4VVhz_pHEVq2pOLeGd2ktTP4dw2YDOQ0RfM7utuvd1md4-Wiwt4vN-5eYECgTtW2IcJNhvpgrwl5dRozc0gzJk_2bj8sA7aKrRErI1XJ80_UjDF_ErHwpsDM4lzihk96MwEJLK96E6ALIOD2HYYmuHeadh_DBvtqadrbuJ91bHjwL6W7BjUN0BZUAkZKfq5Piv0jL9LiXnTxCSGv9apA2xKXH3Spwu-gP8fXAh7CeC1adxwX1o82ScC-cqBUd736pj-huj_eP02YcFxNJnt2nCOBNbsEDHZxI2zb038kAZgcWw_0jMyc4LzrvKzWCvZeKYaTSXkEvUF6qr7wZ59GeniV6usM_Qb2y0sffhB2bc_zVAzIRHXv5tF2WMOn2WmOGepPEl6tbBfYNI971x9CvzPhLGv-jMpXA_o3xSELkH8UO28vCIsJaJ7lEPiam-HzQ2M-r4R-HZfAD3hNgWYCKpbxEsoN4x1vsmizRIp9sOHhJp5qKncVrQwAPUGc1Mx2G9LCjYojnJpVoXdYTsfrOnMcPP5MGkFgiHDeA9U46i_B20Y4luIv05SAKWZuySMehcV_KdcXbnBcckF8tSD_wsG2-hfxGelmPIMnIRbj-rr_XCVKhXxFwPJASqQRpfBTQr3ioGiXd963J7swR1_cef5R4sVutrm7VD8BkWoKWd0hFi6jumy9KlkoTvMoY7oSpAHKa_BEhArhUxp7I0cXXEH1UaxWfpuGgzcZTpPFWfXE0VxIl8.m3u8"
  videoContent.StreamFormat = "hls"
  videoContent.PlayStart = 999999999
  videoContent.live = true

  m.content_screen.visible = false
  m.videoplayer.visible = true
  m.videoplayer.setFocus(true)
  m.videoplayer.content = videoContent
  m.videoplayer.control = "play"

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
end sub

sub onPlayerPositionChanged(obj)
  ? "Position: ", obj.getData()
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
    error = "[Error " + m.videoplayer.errorCode.ToStr() + "] " + m.videoplayer.errorMsg
    ? error
    if m.videoplayer.errorCode = -3 or m.videoplayer.errorCode = -2 or m.videoplayer.errorCode = -1
      showVideoError()
    end if
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

sub closeVideo()
  m.videoplayer.control = "stop"
  m.videoplayer.visible = false
  'm.details_screen.visible = true
  'm.details_screen.setFocus(true)
  m.content_screen.visible = true
  m.content_screen.setFocus(true)
  m.playButtonPressed = false
end sub

sub setIfStreaming(obj)
  info = ParseJSON(obj.getData())
  ''? info[0].urlname
  if info[0].liveStream <> invalid  then
    if info[0].liveStream <> null then
      m.content_screen.setField("streaming", true)
    else
      m.content_screen.setField("streaming", false)
      'false'
    end if
    m.content_screen.setField("streaming", false)
    'false'
  else
    m.content_screen.setField("streaming", false)
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
  m.dbuttons = createObject("roArray", 10, true)
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
      m.playButtonPressed = false
      return true
    else if m.videoplayer.visible
      m.videoplayer.control = "stop"
      m.videoplayer.visible = false
      'm.content_screen.visible = false
      'm.details_screen.visible = true
      'm.details_screen.setFocus(true)
      m.content_screen.visible = true
      m.details_screen.visible = false
      m.content_screen.setFocus(true)
      m.playButtonPressed = false
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
