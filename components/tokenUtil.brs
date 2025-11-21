'********************************************************************
'**  TokenUtil - OAuth Token Management
'********************************************************************

function TokenUtil() as Object
    tokenUtilObj = {
        
        '** Get access token, refreshing if necessary
        '@return access token string or invalid if not available
        getAccessToken: function() as Dynamic
            registry = RegistryUtil()
            accessToken = registry.read("access_token", "hydravion")
            
            if accessToken = invalid
                print "[TOKEN] No access token found in registry"
                return invalid
            end if
            
            ' Check if token is expired (or about to expire)
            if m.isTokenExpired()
                print "[TOKEN] Access token expired or expiring soon, attempting refresh..."
                ' Try to refresh
                if m.refreshToken()
                    ' Get the new token
                    newToken = registry.read("access_token", "hydravion")
                    print "[TOKEN] Successfully refreshed token"
                    return newToken
                else
                    ' Refresh failed, token invalid
                    print "[TOKEN] Token refresh failed, user must re-authenticate"
                    return invalid
                end if
            end if
            
            ' Log token status for debugging (only occasionally to avoid spam)
            m.logTokenStatus()
            
            return accessToken
        end function
        
        '** Check if access token is expired
        '@return true if expired or missing, false if valid
        isTokenExpired: function() as Boolean
            registry = RegistryUtil()
            expiresAt = registry.read("token_expires_at", "hydravion")
            
            if expiresAt = invalid
                print "[TOKEN] No expiration time found, token considered expired"
                return true
            end if
            
            currentTime = CreateObject("roDateTime")
            currentTimeSeconds = currentTime.AsSeconds()
            expiresAtSeconds = Val(expiresAt)
            
            ' Add 5 minute (300 second) buffer to refresh proactively before actual expiration
            ' This ensures we refresh well before the token expires, reducing failed API calls
            refreshBufferSeconds = 300
            timeUntilExpiration = expiresAtSeconds - currentTimeSeconds
            
            if timeUntilExpiration <= refreshBufferSeconds
                print "[TOKEN] Token expires in " + timeUntilExpiration.ToStr() + " seconds (buffer: " + refreshBufferSeconds.ToStr() + "), will refresh"
                return true
            end if
            
            return false
        end function
        
        '** Refresh the access token using refresh token
        '@return true if successful, false otherwise
        refreshToken: function() as Boolean
            registry = RegistryUtil()
            refreshToken = registry.read("refresh_token", "hydravion")
            
            if refreshToken = invalid
                print "[TOKEN] No refresh token available"
                return false
            end if
            
            ' Check if refresh token is expired
            refreshExpiresAt = registry.read("refresh_token_expires_at", "hydravion")
            if refreshExpiresAt <> invalid
                currentTime = CreateObject("roDateTime")
                currentTimeSeconds = currentTime.AsSeconds()
                refreshExpiresAtSeconds = Val(refreshExpiresAt)
                
                if currentTimeSeconds >= refreshExpiresAtSeconds
                    print "[TOKEN] Refresh token expired (expired at: " + refreshExpiresAtSeconds.ToStr() + ", current: " + currentTimeSeconds.ToStr() + ")"
                    ' Clear tokens
                    m.clearTokens()
                    return false
                else
                    timeUntilRefreshExpiration = refreshExpiresAtSeconds - currentTimeSeconds
                    minutes = timeUntilRefreshExpiration \ 60
                    print "[TOKEN] Refresh token valid, expires in " + minutes.ToStr() + " minutes"
                end if
            else
                print "[TOKEN] No refresh token expiration time found, attempting refresh anyway"
            end if
            
            ' Request new token
            appInfo = createObject("roAppInfo")
            version = appInfo.getVersion()
            useragent = "Hydravion (Roku) v" + version
            
            apiConfigObj = ApiConfig()
            url = apiConfigObj.buildAuthUrl("/realms/floatplane-pp/protocol/openid-connect/token")
            https = CreateObject("roUrlTransfer")
            https.RetainBodyOnError(true)
            port = CreateObject("roMessagePort")
            https.SetMessagePort(port)
            https.SetUrl(url)
            https.setCertificatesFile("common:/certs/ca-bundle.crt")
            https.AddHeader("Content-Type", "application/x-www-form-urlencoded")
            https.AddHeader("Accept", "application/json")
            https.AddHeader("User-Agent", useragent)
            https.initClientCertificates()
            
            ' Send refresh token request
            postData = "grant_type=refresh_token&client_id=hydravion&refresh_token=" + https.Escape(refreshToken)
            
            if https.AsyncPostFromString(postData)
                while (true)
                    event = wait(10000, port)
                    if type(event) = "roUrlEvent"
                        code = event.GetResponseCode()
                        if code = 200
                            response = ParseJSON(event.GetString())
                            if response <> invalid and response.access_token <> invalid
                                ' Store new tokens
                                registry.write("access_token", response.access_token, "hydravion")
                                
                                ' Update expiration time
                                currentTime = CreateObject("roDateTime")
                                currentTimeSeconds = currentTime.AsSeconds()
                                tokenExpirationTime = currentTimeSeconds + response.expires_in
                                registry.write("token_expires_at", tokenExpirationTime.ToStr(), "hydravion")
                                
                                ' Update refresh token if provided
                                if response.refresh_token <> invalid
                                    registry.write("refresh_token", response.refresh_token, "hydravion")
                                end if
                                
                                ' Update refresh token expiration if provided
                                if response.refresh_expires_in <> invalid
                                    refreshExpirationTime = currentTimeSeconds + response.refresh_expires_in
                                    registry.write("refresh_token_expires_at", refreshExpirationTime.ToStr(), "hydravion")
                                    refreshMinutes = response.refresh_expires_in \ 60
                                    print "[TOKEN] Refresh token expires in " + refreshMinutes.ToStr() + " minutes"
                                else
                                    print "[TOKEN] Warning: No refresh_expires_in in response, refresh token expiration not updated"
                                end if
                                
                                accessMinutes = response.expires_in \ 60
                                print "[TOKEN] Token refreshed successfully, new access token expires in " + accessMinutes.ToStr() + " minutes"
                                return true
                            else
                                print "[TOKEN] Invalid refresh response"
                                m.clearTokens()
                                return false
                            end if
                        else
                            responseBody = event.GetString()
                            print "[TOKEN] Token refresh error: " + code.ToStr() + " - " + responseBody
                            ' If refresh fails, clear tokens (likely expired or invalid)
                            m.clearTokens()
                            return false
                        end if
                    else if event = invalid
                        https.AsyncCancel()
                        m.clearTokens()
                        return false
                    end if
                end while
            end if
            
            return false
        end function
        
        '** Clear all stored tokens
        clearTokens: function() as Void
            registry = RegistryUtil()
            registry.delete("access_token", "hydravion")
            registry.delete("refresh_token", "hydravion")
            registry.delete("token_expires_at", "hydravion")
            registry.delete("refresh_token_expires_at", "hydravion")
            ' Also clear old sails cookie if it exists
            registry.delete("sails", "hydravion")
        end function
        
        '** Check if user is authenticated (has valid token)
        '@return true if authenticated, false otherwise
        isAuthenticated: function() as Boolean
            token = m.getAccessToken()
            return token <> invalid
        end function
        
        '** Log token status for debugging/testing
        '   Only logs occasionally to avoid spam
        logTokenStatus: function() as Void
            ' Use a simple counter to log only every 10th call
            if m.logCounter = invalid
                m.logCounter = 0
            end if
            m.logCounter = m.logCounter + 1
            
            ' Log every 10th call (roughly every 10 API calls)
            if m.logCounter mod 10 = 0
                registry = RegistryUtil()
                expiresAt = registry.read("token_expires_at", "hydravion")
                if expiresAt <> invalid
                    currentTime = CreateObject("roDateTime")
                    currentTimeSeconds = currentTime.AsSeconds()
                    expiresAtSeconds = Val(expiresAt)
                    timeUntilExpiration = expiresAtSeconds - currentTimeSeconds
                    minutes = timeUntilExpiration \ 60
                    seconds = timeUntilExpiration mod 60
                    print "[TOKEN] Token valid, expires in " + minutes.ToStr() + "m " + seconds.ToStr() + "s"
                end if
            end if
        end function
        
        '** Get token status for debugging/testing
        '@return object with token status information
        getTokenStatus: function() as Object
            registry = RegistryUtil()
            status = {
                hasAccessToken: false
                hasRefreshToken: false
                accessTokenExpiresAt: invalid
                refreshTokenExpiresAt: invalid
                timeUntilAccessExpiration: invalid
                timeUntilRefreshExpiration: invalid
                isAccessTokenExpired: false
                isRefreshTokenExpired: false
            }
            
            accessToken = registry.read("access_token", "hydravion")
            status.hasAccessToken = (accessToken <> invalid)
            
            refreshToken = registry.read("refresh_token", "hydravion")
            status.hasRefreshToken = (refreshToken <> invalid)
            
            expiresAt = registry.read("token_expires_at", "hydravion")
            if expiresAt <> invalid
                status.accessTokenExpiresAt = expiresAt
                currentTime = CreateObject("roDateTime")
                currentTimeSeconds = currentTime.AsSeconds()
                expiresAtSeconds = Val(expiresAt)
                status.timeUntilAccessExpiration = expiresAtSeconds - currentTimeSeconds
                status.isAccessTokenExpired = m.isTokenExpired()
            end if
            
            refreshExpiresAt = registry.read("refresh_token_expires_at", "hydravion")
            if refreshExpiresAt <> invalid
                status.refreshTokenExpiresAt = refreshExpiresAt
                currentTime = CreateObject("roDateTime")
                currentTimeSeconds = currentTime.AsSeconds()
                refreshExpiresAtSeconds = Val(refreshExpiresAt)
                status.timeUntilRefreshExpiration = refreshExpiresAtSeconds - currentTimeSeconds
                status.isRefreshTokenExpired = (currentTimeSeconds >= refreshExpiresAtSeconds)
            end if
            
            return status
        end function
    }
    
    return tokenUtilObj
end function

