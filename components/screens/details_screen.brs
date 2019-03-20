sub init()
  m.title = m.top.FindNode("title")
  m.date = m.top.FindNode("date")
  m.description = m.top.FindNode("description")
  m.thumbnail = m.top.FindNode("thumbnail")
  m.play_button = m.top.FindNode("play_button")
  m.top.observeField("visible", "onVisibleChange")
  m.play_button.setFocus(true)
end sub

sub onVisibleChange()
  if m.top.visible = true THEN
    m.play_button.setFocus(true)
  end if
end sub

sub OnContentChange(obj)
  item = obj.getData()
  m.title.text = item.TITLE
  m.thumbnail.uri = item.HDPOSTERURL

  if Len(item.DESCRIPTION) > 600 then
    m.description.text = Left(item.DESCRIPTION, 600) + "..."
  else
    m.description.text = item.DESCRIPTION
  end if

  dt = createObject("roDateTime")
  dt.FromISO8601String(item.id)
  m.date.text = dt.AsDateString("short-month-short-weekday")
end sub
