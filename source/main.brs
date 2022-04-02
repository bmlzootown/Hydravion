sub Main(args as Dynamic)
  screen = createObject("roSGScreen")
  port = createObject("roMessagePort")
  screen.setMessageport(m.port)
  scene = screen.createScene("home_screen")
  scene.observeField("exit", port)
  screen.Show()
  scene.setFocus(true)

  'm.global = screen.getGlobalNode()
  'm.global.addFields( {scene: scene, deeplink: args} )

  if (args.ContentId <> invalid) and (args.MediaType <> invalid)
    scene.setField("deepcontentid", args.ContentId)
  end if

  while(true)
    msg = wait(0, port)
    msgType = type(msg)
    if msgType = "roSGScreenEvent"
      if msg.isScreenClosed() then return
    else if msgType = "roSGNodeEvent"
      field = msg.getField()
      data = msg.getData()
      if field = "exitChannel" and data = true
        END
      end if
    else if msgType = "roInputEvent"
      scene.setField("roInputData", msg.getInfo())
    end if
  end while
end sub
