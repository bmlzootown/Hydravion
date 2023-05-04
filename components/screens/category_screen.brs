function init()
  m.category_list = m.top.findNode("category_list")
  m.channel_list = m.top.findNode("channel_list")
  m.chevron_right = m.top.findNode("chevron-right")
  m.background = m.top.findNode("background")
  m.category_list.setFocus(true)
  m.top.observeField("visible", "onVisibleChange")
  m.category_list.observeField("itemFocused", "onFocusChanged")
end function

sub onVisibleChange()
	if m.top.visible = true then
		m.category_list.setFocus(true)
	end if
end sub

sub onFocusChanged()
  if m.category_list.visible = true
    index = m.category_list.itemFocused
    if index <> -1
      m.background.uri = m.category_list.content.getChild(index).HDPosterURL
      m.highlighted = m.category_list.content.getChild(index)
      getChannels(m.highlighted.creatorGUID)
    end if
  end if
end sub

sub getChannels(id)
  m.subs_task = CreateObject("roSGNode", "urlTask")
  url = "https://www.floatplane.com/api/v3/creator/info?id=" + id
  m.subs_task.setField("url", url)
  m.subs_task.observeField("response", "gotChannels")
  m.subs_task.control = "RUN"
end sub

sub gotChannels(obj)
  m.feed_task = createObject("roSGNode", "setupChannelsTask")
  m.feed_task.setField("unparsed", obj.getData())
  m.feed_task.observeField("category_node", "onChannelsSetup")
  m.feed_task.control = "RUN"
end sub

sub onChannelsSetup(obj)
  m.channel_list.content = obj.getData()
  if obj.getData().getChildCount() < 2
    m.channel_list.visible = false
    m.chevron_right.visible = false
  else 
    m.channel_list.visible = true
    m.chevron_right.visible = true
    m.channel_list.drawFocusFeedback = false
    m.channel_list.opacity = 0.5
  end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
  if not press then return false

  if key = "right" and m.category_list.hasFocus()
    m.channel_list.drawFocusFeedback = true
    m.channel_list.opacity = 1
    m.channel_list.setFocus(true)
    return true
  else if key = "left" OR key = "back"
    if m.channel_list.hasFocus()
      m.channel_list.opacity = 1
      m.category_list.setFocus(true)
      return true
    end if
  end if

  return false
end function
