function init()
  m.category_list = m.top.findNode("category_list")
  m.category_list.setFocus(true)
  m.top.observeField("visible", "onVisibleChange")
end function

sub onVisibleChange()
	if m.top.visible = true then
		m.category_list.setFocus(true)
	end if
end sub
