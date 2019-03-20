sub Main()
  screen = createObject("roSGScreen")
  port = createObject("roMessagePort")
  screen.setMessageport(m.port)
  scene = screen.createScene("home_screen")
  scene.observeField("exit", port)
  screen.Show()
  scene.setFocus(true)

  while(true)
    msg = wait(0, port)
    msgType = type(msg)
    if msgType = "roSGScreenEvent"
      if msg.isScreenClosed() then return
    end if
  end while
end sub
