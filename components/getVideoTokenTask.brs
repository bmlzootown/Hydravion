sub init()
  m.top.functionName = "getToken"
end sub

sub getToken()
  ' Runs on task thread: safe to call getAccessToken(false) and thus refresh via roUrlTransfer
  tokenUtilObj = TokenUtil()
  accessToken = tokenUtilObj.getAccessToken(false)
  if accessToken <> invalid then
    m.top.accessToken = accessToken
  else
    m.top.error = "Not authenticated - please login"
  end if
  m.top.done = true
end sub
