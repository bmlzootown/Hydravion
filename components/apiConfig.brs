' API Configuration Utility

function ApiConfig() as Object
  apiConfigObj = {
    environment: "preprod"
    
    ' Base URLs for different environments
    baseUrls: {
      prod: "https://www.floatplane.com"
      preprod: "https://pp.floatplane.com"
    }
    
    ' Auth server URL
    authBaseUrl: "https://auth.floatplane.com"
    
    getApiBaseUrl: function() as String
      if m.environment = "preprod"
        return m.baseUrls.preprod
      else
        return m.baseUrls.prod
      end if
    end function
    
    ' Get the auth server base URL
    getAuthBaseUrl: function() as String
      return m.authBaseUrl
    end function
    
    ' Build a full API URL from path
    buildApiUrl: function(path as String) as String
      baseUrl = m.getApiBaseUrl()
      if path.Left(1) <> "/"
        path = "/" + path
      end if
      return baseUrl + path
    end function
    
    ' Build a full auth URL from path
    buildAuthUrl: function(path as String) as String
      baseUrl = m.getAuthBaseUrl()
      if path.Left(1) <> "/"
        path = "/" + path
      end if
      return baseUrl + path
    end function
  }
  
  return apiConfigObj
end function

