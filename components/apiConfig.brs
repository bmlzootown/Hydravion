' API Configuration Utility

function ApiConfig() as Object
  apiConfigObj = {
    environment: "prod"
    
    ' Base URLs for different environments
    baseUrls: {
      prod: "https://www.floatplane.com"
      preprod: "https://pp.floatplane.com"
    }
    
    ' Auth server URL
    authBaseUrl: "https://auth.floatplane.com"
    
    ' Realm names for different environments
    realms: {
      prod: "floatplane"
      preprod: "floatplane-pp"
    }
    
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
    
    ' Get the realm name for the current environment
    getRealm: function() as String
      if m.environment = "preprod"
        return m.realms.preprod
      else
        return m.realms.prod
      end if
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
    
    ' Build a realm-specific auth URL (e.g., /realms/{realm}/protocol/...)
    buildRealmAuthUrl: function(path as String) as String
      realm = m.getRealm()
      ' Remove leading slash from path if present, we'll add it after realm
      if path.Left(1) = "/"
        path = path.Mid(1)
      end if
      realmPath = "/realms/" + realm + "/protocol/" + path
      return m.buildAuthUrl(realmPath)
    end function
  }
  
  return apiConfigObj
end function

