function init()
  m.login_text = m.top.findNode("login_text")
  m.login_text.font.size = 80

  m.username = m.top.findNode("username")
  m.username.observeField("buttonSelected","onInputUsername")
  m.username.setFocus(true)

  m.password = m.top.findNode("password")
  m.password.observeField("buttonSelected","onInputPassword")

  m.loginButton = m.top.findNode("login")
  m.loginButton.observeField("buttonSelected","onLoginButton")

  m.keyboard = m.top.findNode("inputKeyboard")
  m.keyboard.visible = false
  m.field = ""
end function

sub onInputUsername()
  m.field = "username"
  m.keyboard.text = ""
  m.keyboard.textEditBox.secureMode = false
  m.keyboard.visible = true
  m.keyboard.setFocus(true)
end sub

sub onInputPassword()
  m.field = "password"
  m.keyboard.text = ""
  m.keyboard.textEditBox.secureMode = true
  m.keyboard.visible = true
  m.keyboard.setFocus(true)
end sub

sub onLoginButton()
  'print m.username.text
  'print m.password.text
  m.login_task = createObject("roSGNode", "loginTask")
  m.login_task.setField("username", m.username.text)
  m.login_task.setField("password", m.private)
  m.login_task.observeField("cookies", "onCookies")
  m.login_task.observeField("error", "onError")
  m.login_task.control = "RUN"
end sub

sub onCookies(obj)
  'print "login_screen passed?"
  'print obj
  print "passed login_screen"
  m.needstwoFA = m.login_task.needstwoFA
  if m.needstwoFA = true
    ? m.needstwoFA
    preparetwoFALogin()
  else
    ? "Couldn't find needs2FA"
    m.top.next = "beep"
  end if
end sub

sub preparetwoFALogin()
  m.top.getScene().dialog = createObject("roSGNode", "Dialog")
  m.top.getScene().dialog.title = "2FactorAuthentication"
  m.top.getScene().dialog.optionsDialog = true
  m.top.getScene().dialog.iconUri = ""
  m.top.getScene().dialog.message = "2FA code is needed to continue!"
  m.top.getScene().dialog.buttons = ["OK"]
  m.top.getScene().dialog.optionsDialog = true
  m.top.getScene().dialog.observeField("buttonSelected","getCodeKeyboard")
end sub

sub getCodeKeyboard()
  m.top.getScene().dialog.close = true
  m.field = "twoFA"
  m.keyboard.text = ""
  m.keyboard.textEditBox.secureMode = false
  m.keyboard.visible = true
  m.keyboard.setFocus(true)
end sub

sub dotwoFALogin()
  token = m.twoFA
  m.twoFA_task = createObject("roSGNode", "twoFATask")
  m.twoFA_task.setField("token", token)
  m.twoFA_task.observeField("updatedCookies", "updatedCs")
  m.twoFA_task.observeField("error", "ontwoFAError")
  m.twoFA_task.control = "RUN"
end sub

sub updatedCs()
  m.top.next = "beep"
end sub

sub ontwoFAError(obj)
  code = obj.getData()
  getCodeKeyboard()
end sub

sub onError(obj)
  code = obj.getData()
  msg = ""
  if code = "400"
    'Username too short (at least 4)
    msg = "Username should be at least 4 characters long!"
    m.username.text = "derp"
    m.password.text = "thatwaseasy"
  else if code = "401"
    'Incorrect credentials
    msg = "Wrong username/password combination!"
    m.username.text = "properusername"
    m.password.text = "actualpassword"
  else
    msg = "Well... This is awkward. I blame you."
    m.username.text = "idontknow"
    m.password.text = "wakeup"
  end if
  showErrorDialog(msg)
end sub

sub showErrorDialog(msg)
  m.top.getScene().dialog = createObject("roSGNode", "Dialog")
  m.top.getScene().dialog.title = "Login Error"
  m.top.getScene().dialog.optionsDialog = true
  m.top.getScene().dialog.iconUri = ""
  m.top.getScene().dialog.message = msg
  m.top.getScene().dialog.buttons = ["OK"]
  m.top.getScene().dialog.optionsDialog = true
  m.top.getScene().dialog.observeField("buttonSelected","closeDialog")
end sub

sub closeDialog()
  m.top.getScene().dialog.close = true
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
  if press
    if key = "up"
      if m.loginButton.hasFocus()
        m.loginButton.setFocus(false)
        m.password.setFocus(true)
        return true
      else if m.password.hasFocus()
        m.password.setFocus(false)
        m.username.setFocus(true)
        return true
      end if
    else if key = "down"
      if m.username.hasFocus()
        m.username.setFocus(false)
        m.password.setFocus(true)
        return true
      else if m.password.hasFocus()
        m.password.setFocus(false)
        m.loginButton.setFocus(true)
        return true
      end if
    else if key = "play"
      if m.field = "username"
        if m.keyboard.text <> ""
          m.username.text = m.keyboard.text
        end if
        m.keyboard.visible = false
        m.username.setFocus(true)
        return true
      else if m.field = "password"
        if m.keyboard.text <> ""
          m.private = m.keyboard.text
          asterisk = box("****************")
          length = m.keyboard.text.Len()
          m.password.text = asterisk.Left(length)
        end if
        m.keyboard.visible = false
        m.password.setFocus(true)
        return true
      else if m.field = "twoFA"
        if m.keyboard.text <> ""
          m.twoFA = m.keyboard.text
          m.keyboard.visible = false
          dotwoFALogin()
          return true
        end if
      end if
    else if key = "back"
      if m.keyboard.visible = true
        if m.field = "username"
          if m.keyboard.text <> ""
            m.username.text = m.keyboard.text
          end if
          m.keyboard.visible = false
          m.username.setFocus(true)
          return true
        else if m.field = "password"
          if m.keyboard.text <> ""
            m.private = m.keyboard.text
            asterisk = box("****************")
            length = m.keyboard.text.Len()
            m.password.text = asterisk.Left(length)
          end if
          m.keyboard.visible = false
          m.password.setFocus(true)
          return true
        else if m.field = "twoFA"
          if m.keyboard.text <> ""
            m.twoFA = m.keyboard.text
            m.keyboard.visible = false
            dotwoFALogin()
            return true
          end if
        end if
      else
        m.username.setFocus(true)
        return true
      end if
    else if key = "ok"
      return true
    end if
  return false
  end if
end function
