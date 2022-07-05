sub init()
  m.content_grid = m.top.FindNode("content_grid")
  'm.content_grid.caption1Font.size = 24
  'm.content_grid.caption2NumLines = 1
  'm.content_grid.caption2Font.size = 18
  'm.content_grid.captionLineSpacing = 10.0
  m.header = m.top.FindNode("header")
  m.hideHeader = m.top.FindNode("hideHeader")
  m.showHeader = m.top.FindNode("showHeader")
  m.cover = m.top.FindNode("cover")
  m.icon = m.top.FindNode("icon")
  'm.liveButton = m.top.FindNode("liveButton")
  m.top.observeField("visible", "onVisibleChange")
  m.top.observeField("feed_node", "onFeedChanged")
  m.content_grid.observeField("itemFocused", "OnFocusItem")
  m.top.observeField("jumpTo", "jumpTo")
  m.visibleCover = true
end sub

sub onFeedChanged(obj)
  m.header.text = m.top.feed_name
  'm.cover.uri = m.creator.HDPOSTERURL
  showpostergrid(m.top.feed_node)
end sub

sub showpostergrid(content)
  m.content_grid.content = content
  m.content_grid.visible = true
  m.content_grid.setFocus(true)
  m.cover.uri = m.top.category_node.HDPOSTERURL
  'm.icon.uri = m.top.category_node.icon
  m.icon.imageUri = m.top.category_node.icon
  m.icon.fixsize = true
  'm.content_grid.jumpToItem = m.top.jumpTo
  '? m.top.jumpTo
end sub

sub OnFocusItem(event)
  m.top.itemIndex = event.getData()
  ? event.getData()
  if event.getData() > 2 and m.visibleCover = true
    m.hideHeader.control = "start"
    m.visibleCover = false
  else if event.getData() < 3 and m.visibleCover = false
    m.showHeader.control = "start"
    m.visibleCover = true
  end if
end sub

sub jumpTo(item)
  ? item.getData()
  'm.content_grid.jumpToItem = item.getData()
end sub

sub onVisibleChange()
  if m.top.visible = true then
    m.content_grid.setFocus(true)
  end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
  if not press then return false

  if key = "up" and m.content_grid.hasFocus()
    return true
  end if

  return false
end function
