sub init()
  m.content_grid = m.top.FindNode("content_grid")
  m.header = m.top.FindNode("header")
  m.top.observeField("visible", "onVisibleChange")
end sub

sub onFeedChanged(obj)
  json = obj.getData()
  feed = ParseJSON(json)
  m.header.text = m.top.feed_name
  postercontent = createObject("roSGNode", "ContentNode")
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
