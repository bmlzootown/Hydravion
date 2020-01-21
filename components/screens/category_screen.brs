function init()
  m.category_list = m.top.findNode("category_list")
  m.icon = m.top.findNode("icon")
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
      m.icon.uri = m.category_list.content.getChild(index).HDPosterURL
    end if
  end if
end sub
