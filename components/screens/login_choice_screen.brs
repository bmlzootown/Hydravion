function init()
  m.title_text = m.top.findNode("title_text")
  m.title_text.font.size = 60

  m.qrCodeButton = m.top.findNode("qrCodeButton")
  m.qrCodeButton.observeField("buttonSelected", "onQRCodeSelected")
  m.qrCodeButton.setFocus(true)

  m.manualButton = m.top.findNode("manualButton")
  m.manualButton.observeField("buttonSelected", "onManualSelected")

  m.qrDescription = m.top.findNode("qrDescription")
  m.manualDescription = m.top.findNode("manualDescription")
end function

sub onQRCodeSelected()
  m.top.choice = "qr"
  m.top.next = "qr_login"
end sub

sub onManualSelected()
  m.top.choice = "manual"
  m.top.next = "manual_login"
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
  if press
    if key = "up"
      if m.manualButton.hasFocus()
        m.manualButton.setFocus(false)
        m.qrCodeButton.setFocus(true)
        m.qrDescription.visible = true
        m.manualDescription.visible = false
        return true
      end if
    else if key = "down"
      if m.qrCodeButton.hasFocus()
        m.qrCodeButton.setFocus(false)
        m.manualButton.setFocus(true)
        m.qrDescription.visible = false
        m.manualDescription.visible = true
        return true
      end if
    else if key = "ok"
      if m.qrCodeButton.hasFocus()
        onQRCodeSelected()
        return true
      else if m.manualButton.hasFocus()
        onManualSelected()
        return true
      end if
    end if
  end if
  return false
end function

