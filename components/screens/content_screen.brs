sub init()
  m.content_grid = m.top.FindNode("content_grid")
  m.content_grid.caption1Font.size = 24
  m.content_grid.caption2NumLines = 1
  m.content_grid.caption2Font.size = 18
  m.content_grid.captionLineSpacing = 10.0
  m.header = m.top.FindNode("header")
  m.top.observeField("visible", "onVisibleChange")
  m.top.observeField("feed_node", "onFeedChanged")
  m.content_grid.observeField("itemFocused", "OnFocusItem")
  m.top.observeField("jumpTo", "jumpTo")
end sub

sub onFeedChanged(obj)
  m.header.text = m.top.feed_name
  showpostergrid(m.top.feed_node)
end sub

sub showpostergrid(content)
  m.content_grid.content = content
  m.content_grid.visible = true
  m.content_grid.setFocus(true)
  m.content_grid.jumpToItem = m.top.jumpTo
  ? m.top.jumpTo
end sub

sub OnFocusItem(event)
  m.top.itemIndex = event.getData()
end sub

sub jumpTo(item)
  ? item.getData()
  m.content_grid.jumpToItem = item.getData()
end sub

sub onVisibleChange()
  if m.top.visible = true then
    m.content_grid.setFocus(true)
  end if
end sub
