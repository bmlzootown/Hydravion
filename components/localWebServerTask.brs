sub init()
  m.top.functionname = "startServer"
  m.serverSocket = invalid  ' Store server socket for Accept calls
  m.clientSockets = {}  ' Store active client sockets by ID
  m.server = invalid  ' Store server socket reference
end sub

sub startServer()
  port = m.top.port
  if port = 0 then port = 8888
  
  ' Get device IP address
  deviceInfo = CreateObject("roDeviceInfo")
  ipAddrs = deviceInfo.GetIPAddrs()  ' Returns associative array of interface -> IP
  
  serverIp = "127.0.0.1"  ' Default fallback
  
  if ipAddrs <> invalid
    ' Try to get IP from common interfaces (eth0, wlan0, or any available)
    if ipAddrs.DoesExist("eth0")
      serverIp = ipAddrs["eth0"]
    else if ipAddrs.DoesExist("wlan0")
      serverIp = ipAddrs["wlan0"]
    else if ipAddrs.Count() > 0
      ' Get first available IP address
      for each iface in ipAddrs
        serverIp = ipAddrs[iface]
        exit for
      end for
    end if
  end if
  
  m.top.serverUrl = "http://" + serverIp + ":" + port.ToStr()
  print "[PROGRESS] Starting local web server on " + m.top.serverUrl
  
  ' Create socket server using roStreamSocket
  ' Based on Playlet's implementation - key differences:
  ' 1. Use setReuseAddr(true) before binding
  ' 2. Use roSocketAddress object for setAddress()
  ' 3. Call notifyReadable(true) after setting message port
  ' 4. Check isReadable() before accepting
  ' 5. Wait for roSocketEvent (not roStreamSocketEvent)
  server = CreateObject("roStreamSocket")
  if server = invalid
    print "[PROGRESS] Failed to create roStreamSocket"
    m.top.isRunning = false
    return
  end if
  
  ' Create message port for handling socket events
  m.port = CreateObject("roMessagePort")
  
  ' Step 1: Set reuse address (critical!)
  if not server.setReuseAddr(true)
    print "[PROGRESS] ERROR: setReuseAddr() failed: " + server.status().ToStr()
    m.top.isRunning = false
    return
  end if
  
  ' Step 2: Create socket address and bind
  addrin = CreateObject("roSocketAddress")
  addrin.setPort(port)
  if not server.setAddress(addrin)
    print "[PROGRESS] ERROR: setAddress() failed: " + server.status().ToStr()
    print "[PROGRESS] Port " + port.ToStr() + " may already be in use"
    print "[PROGRESS] Try closing any existing server or use a different port"
    m.top.isRunning = false
    return
  end if
  
  ' Step 3: Listen with max connections
  if not server.listen(10)
    print "[PROGRESS] ERROR: listen() failed: " + server.status().ToStr()
    m.top.isRunning = false
    return
  end if
  
  ' Step 4: Set message port and notify readable
  server.setMessagePort(m.port)
  server.notifyReadable(true)
  
  ' Store server reference
  m.server = server
  
  print "[PROGRESS] Server listening on port " + port.ToStr()
  print "[PROGRESS] Server address: " + addrin.getAddress()
  
  ' Server setup succeeded - set isRunning to true
  m.top.isRunning = true
    print "[PROGRESS] Web server started, waiting for connections..."
    
    ' Main server loop - based on Playlet's implementation
    ' Key: Check isReadable() before accepting, wait for roSocketEvent
    acceptCount = 0
    
    while m.top.isRunning
      ' Wait for socket events (roSocketEvent, not roStreamSocketEvent!)
      msg = wait(1000, m.port)
      msgType = type(msg)
      
      if msgType = "roSocketEvent" or msg = invalid
        ' Check if server socket is readable (has pending connections)
        if m.server <> invalid and m.server.isReadable()
          print "[PROGRESS] Server socket is readable, accepting connection..."
          clientSocket = m.server.accept()
          
          if clientSocket <> invalid
            acceptCount = acceptCount + 1
            print "[PROGRESS] *** ACCEPTED CONNECTION #" + acceptCount.ToStr() + " ***"
            print "[PROGRESS] Client socket ID: " + clientSocket.GetID().ToStr()
            
            ' Set message port for the client socket
            clientSocket.setMessagePort(m.port)
            clientSocket.notifyReadable(true)
            
            ' Handle the request
            handleRequest(clientSocket)
          else
            ' No connection available - clear readable state to prevent repeated attempts
            print "[PROGRESS] accept() returned invalid - no connection available"
            ' Small delay to prevent tight loop
            sleep(50)
          end if
        end if
      else if msgType = "roSGNodeEvent"
        ' Handle task control events if needed
        info = msg.getInfo()
        if info <> invalid and info.isRunning <> invalid and info.isRunning = false
          exit while
        end if
      end if
    end while
    
    if m.server <> invalid
      m.server.Close()
    end if
    print "[PROGRESS] Web server stopped"
end sub

sub handleRequest(socket as Object)
  print "[PROGRESS] Handling request from client..."
  
  ' Set receive timeout
  socket.SetReceiveTimeout(5000)
  
  ' Read request using Playlet's approach: GetCountRcvBuf() then Receive()
  request = ""
  maxRequestSize = 8192
  
  ' Check how much data is available using GetCountRcvBuf() (Playlet's approach)
  available = socket.GetCountRcvBuf()
  print "[PROGRESS] Data available in buffer: " + available.ToStr() + " bytes"
  
  ' Read available data
  if available > 0
    lengthToRead = available
    if lengthToRead > maxRequestSize then lengthToRead = maxRequestSize
    
    ' Create buffer with the right size (Playlet's approach: set element to resize)
    buffer = CreateObject("roByteArray")
    if buffer.Count() < lengthToRead
      buffer[lengthToRead - 1] = 0
    end if
    
    received = socket.Receive(buffer, 0, lengthToRead)
    if received > 0
      ' Resize buffer to actual received size (set element at index)
      if buffer.Count() <> received
        ' Create new buffer with correct size
        actualBuffer = CreateObject("roByteArray")
        actualBuffer[received - 1] = 0
        ' Copy received data
        for i = 0 to received - 1
          actualBuffer[i] = buffer[i]
        end for
        buffer = actualBuffer
      end if
      request = buffer.ToAsciiString()
      print "[PROGRESS] Received request (" + received.ToStr() + " bytes): " + Left(request, 200)
    else
      print "[PROGRESS] Receive() returned 0 bytes"
    end if
  else
    print "[PROGRESS] No data available in buffer yet, waiting..."
    ' Wait a bit for data to arrive (browser sends request after connecting)
    sleep(200)
    available = socket.GetCountRcvBuf()
    if available > 0
      lengthToRead = available
      if lengthToRead > maxRequestSize then lengthToRead = maxRequestSize
      
      ' Create buffer with the right size
      buffer = CreateObject("roByteArray")
      if buffer.Count() < lengthToRead
        buffer[lengthToRead - 1] = 0
      end if
      
      received = socket.Receive(buffer, 0, lengthToRead)
      if received > 0
        ' Resize buffer to actual received size
        if buffer.Count() <> received
          actualBuffer = CreateObject("roByteArray")
          actualBuffer[received - 1] = 0
          for i = 0 to received - 1
            actualBuffer[i] = buffer[i]
          end for
          buffer = actualBuffer
        end if
        request = buffer.ToAsciiString()
        print "[PROGRESS] Received request after wait (" + received.ToStr() + " bytes): " + Left(request, 200)
      end if
    else
      print "[PROGRESS] Still no data after wait - connection may be empty or closed"
    end if
  end if
  
  if request <> ""
    ' Parse HTTP request
    lines = request.Split(chr(10))
    if lines.Count() > 0
      requestLine = lines[0]
      parts = requestLine.Split(" ")
      if parts.Count() >= 2
        method = parts[0]
        path = parts[1]
        
        ' Check if this is a POST request and read full body if needed
        if method = "POST"
          ' Parse Content-Length header
          contentLength = 0
          for i = 1 to lines.Count() - 1
            line = lines[i]
            if Left(LCase(line), 15) = "content-length:"
              contentLengthStr = line.Mid(16).Trim()
              contentLength = contentLengthStr.ToInt()
              exit for
            end if
          end for
          
          ' Check if we have the full body
          bodyStart = request.InStr(chr(13) + chr(10) + chr(13) + chr(10))
          if bodyStart >= 0
            bodyReceived = request.Len() - bodyStart - 4
            ' If body is incomplete, read more data
            if bodyReceived < contentLength
              print "[PROGRESS] Body incomplete (" + bodyReceived.ToStr() + "/" + contentLength.ToStr() + "), reading more..."
              remaining = contentLength - bodyReceived
              sleep(100)  ' Wait for more data
              available = socket.GetCountRcvBuf()
              if available > 0
                readMore = available
                if readMore > remaining then readMore = remaining
                buffer = CreateObject("roByteArray")
                if buffer.Count() < readMore
                  buffer[readMore - 1] = 0
                end if
                received = socket.Receive(buffer, 0, readMore)
                if received > 0
                  additionalData = buffer.ToAsciiString()
                  request = request + additionalData
                  print "[PROGRESS] Read additional " + received.ToStr() + " bytes"
                end if
              end if
            end if
          end if
        end if
        
        ' Remove query string for routing
        pathParts = path.Split("?")
        route = pathParts[0]
        queryString = ""
        if pathParts.Count() > 1
          queryString = pathParts[1]
        end if
        
        ' Route requests - only cookie entry endpoints
        if route = "/" or route = "/index.html"
          serveHTML(socket, queryString)
        else if route = "/api/auth"
          if method = "POST"
            print "[PROGRESS] Processing POST /api/auth request"
            handlePostAuth(socket, request)
          else
            send404(socket)
          end if
        else
          send404(socket)
        end if
      end if
    end if
  else
    ' No request received - send a simple response anyway
    print "[PROGRESS] No request data received, sending default response"
    serveHTML(socket, "")
  end if
  
  ' Give the response time to be sent before closing
  sleep(50)
  
  ' Close the socket after sending response
  socket.Close()
  print "[PROGRESS] Request handled, socket closed"
  
  ' Small delay to prevent overwhelming the server with rapid requests
  sleep(10)
end sub

sub serveHTML(socket as Object, queryString as String)
  ' Always serve the simple cookie entry page
  htmlContent = getCookieEntryHTML()
  
  ' Send HTTP response
  response = "HTTP/1.1 200 OK" + chr(13) + chr(10)
  response = response + "Content-Type: text/html; charset=utf-8" + chr(13) + chr(10)
  response = response + "Content-Length: " + htmlContent.Len().ToStr() + chr(13) + chr(10)
  response = response + "Access-Control-Allow-Origin: *" + chr(13) + chr(10)
  response = response + chr(13) + chr(10)
  response = response + htmlContent
  
  ' Try SendStr() first, fall back to Send() if needed
  socket.SendStr(response)
  print "[PROGRESS] Response sent to client"
end sub

' Removed handleGetAuth - no longer needed without session IDs

sub handlePostAuth(socket as Object, request as String)
  print "[PROGRESS] handlePostAuth called, request length: " + request.Len().ToStr()
  ' Extract JSON body from request
  bodyStart = request.InStr(chr(13) + chr(10) + chr(13) + chr(10))
  if bodyStart >= 0
    body = request.Mid(bodyStart + 4)
    print "[PROGRESS] Extracted body: " + body
    data = ParseJSON(body)
    
    if data <> invalid
      print "[PROGRESS] JSON parsed successfully"
      ' Check for sailsSid - no session ID needed
      if data.sailsSid <> invalid and data.sailsSid <> ""
        ' Update the top-level field so cookieEntryTask can observe it
        m.top.setField("sailsSid", data.sailsSid)
        print "[PROGRESS] Updated m.top.sailsSid field with value: " + data.sailsSid.Left(20) + "..."
        
        ' Send success response
        jsonResponse = FormatJson({success: true})
        response = "HTTP/1.1 200 OK" + chr(13) + chr(10)
        response = response + "Content-Type: application/json" + chr(13) + chr(10)
        response = response + "Content-Length: " + jsonResponse.Len().ToStr() + chr(13) + chr(10)
        response = response + "Access-Control-Allow-Origin: *" + chr(13) + chr(10)
        response = response + "Connection: close" + chr(13) + chr(10)
        response = response + chr(13) + chr(10)
        response = response + jsonResponse
        print "[PROGRESS] Sending success response: " + jsonResponse
        socket.SendStr(response)
        print "[PROGRESS] Response sent successfully"
      else
        print "[PROGRESS] Missing or empty sailsSid in parsed data"
        send400(socket)
      end if
    else
      print "[PROGRESS] Failed to parse JSON, body was: " + body
      send400(socket)
    end if
  else
    print "[PROGRESS] Could not find body separator in request"
    send400(socket)
  end if
end sub

' Removed legacy token endpoints - only cookie entry is supported now

sub send404(socket as Object)
  response = "HTTP/1.1 404 Not Found" + chr(13) + chr(10)
  response = response + "Content-Type: text/plain" + chr(13) + chr(10)
  response = response + "Content-Length: 9" + chr(13) + chr(10)
  response = response + chr(13) + chr(10)
  response = response + "Not Found"
  socket.SendStr(response)
end sub

sub send400(socket as Object)
  response = "HTTP/1.1 400 Bad Request" + chr(13) + chr(10)
  response = response + "Content-Type: text/plain" + chr(13) + chr(10)
  response = response + "Content-Length: 11" + chr(13) + chr(10)
  response = response + chr(13) + chr(10)
  response = response + "Bad Request"
  socket.SendStr(response)
end sub

' Removed old login HTML - only cookie entry is supported now

function getCookieEntryHTML() as String
  ' Simple HTML page for entering sails.sid cookie
  html = "<!DOCTYPE html><html lang='en'><head><meta charset='UTF-8'><meta name='viewport' content='width=device-width,initial-scale=1.0'><title>Hydravion Cookie Entry</title>"
  html = html + "<style>body{font-family:Arial,sans-serif;max-width:600px;margin:50px auto;padding:20px;background:#1a1a1a;color:#fff}.container{background:#2a2a2a;padding:30px;border-radius:10px}h1{color:#4a9eff}.instructions{margin:20px 0;line-height:1.6;font-size:14px}.status{padding:15px;margin:20px 0;border-radius:5px;background:#3a3a3a;display:none}.success{background:#2a5a2a;color:#4aff4a}.error{background:#5a2a2a;color:#ff4a4a}input{width:100%;padding:10px;margin:10px 0;border:1px solid #4a4a4a;background:#1a1a1a;color:#fff;border-radius:5px;box-sizing:border-box}button{width:100%;padding:12px 20px;background:#4a9eff;color:#fff;border:none;border-radius:5px;cursor:pointer;font-size:16px;margin-top:10px}button:hover{background:#5aaeff}button:disabled{background:#4a4a4a;cursor:not-allowed}.form-group{margin:15px 0}label{display:block;margin-bottom:5px;color:#ccc}</style></head>"
  html = html + "<body><div class='container'><h1>Hydravion Cookie Entry</h1><div class='instructions'><p>Enter your <strong>sails.sid</strong> cookie from floatplane.com</p><p style='font-size:12px;color:#aaa;margin-top:10px'><strong>How to get it:</strong><br>1. Log in to <a href='https://www.floatplane.com' target='_blank' style='color:#4a9eff'>floatplane.com</a><br>2. Open DevTools (F12)<br>3. Go to Application (Chrome) or Storage (Firefox) > Cookies > floatplane.com<br>4. Copy the value of the <strong>sails.sid</strong> cookie</p></div>"
  html = html + "<div id='status' class='status'></div><form id='cookieForm' onsubmit='handleSubmit(event)'><div class='form-group'><label for='sailsSid'>sails.sid Cookie:</label><input type='text' id='sailsSid' name='sailsSid' placeholder='Paste sails.sid cookie value here' required autocomplete='off'></div>"
  html = html + "<button type='submit' id='submitBtn'>Send to Roku</button></form></div>"
  html = html + "<script>const baseUrl=window.location.origin;"
  html = html + "function showStatus(message,isError=false){const statusEl=document.getElementById('status');statusEl.style.display='block';statusEl.className='status '+(isError?'error':'success');statusEl.textContent=message}"
  html = html + "async function handleSubmit(event){event.preventDefault();const btn=document.getElementById('submitBtn');const sailsSid=document.getElementById('sailsSid').value.trim();"
  html = html + "if(!sailsSid){showStatus('Please enter the sails.sid cookie value',true);return}"
  html = html + "btn.disabled=true;btn.textContent='Sending...';showStatus('Sending cookie to Roku...');"
  html = html + "try{const response=await fetch(baseUrl+'/api/auth',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({sailsSid:sailsSid,success:true})});"
  html = html + "const data=await response.json();if(data.success){showStatus('Cookie sent successfully! Your Roku device should receive it.',false);btn.textContent='Sent!'}else{throw new Error('Failed to send cookie')}}"
  html = html + "catch(error){console.error('Error:',error);showStatus('Error sending cookie. Please try again.',true);btn.disabled=false;btn.textContent='Send to Roku'}}</script></body></html>"
  return html
end function

