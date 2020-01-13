sub init()
  m.content_grid = m.top.FindNode("content_grid")
  m.content_grid.caption1Font.size = 24
  m.content_grid.caption2NumLines = 0
  m.header = m.top.FindNode("header")
  m.top.observeField("visible", "onVisibleChange")
  m.top.observeField("feed_data", "onFeedChanged")
end sub

sub onFeedChanged(obj)
  json = obj.getData()
  feed = ParseJSON(json)
  m.header.text = m.top.feed_name
  postercontent = createObject("roSGNode", "ContentNode")
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
    postercontent.appendChild(node)
  end if
  for each video in feed
    node = createObject("roSGNode", "ContentNode")
    node.HDPosterURL = video.thumbnail.childImages[0].path
    node.title = video.title
    node.ShortDescriptionLine1 = video.title
    node.Description = video.description
    node.guid = video.guid
    node.id = video.releaseDate
    node.streamformat = "hls"
    postercontent.appendChild(node)
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
  postercontent.appendChild(node)
  ''
  showpostergrid(postercontent)
end sub

sub showpostergrid(content)
  m.content_grid.content = content
  m.content_grid.visible = true
  m.content_grid.setFocus(true)
end sub

sub onVisibleChange()
  if m.top.visible = true then
    m.content_grid.setFocus(true)
  end if
end sub
