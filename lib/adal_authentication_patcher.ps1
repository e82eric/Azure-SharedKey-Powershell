param($adalLibDir)

[System.Reflection.Assembly]::LoadFrom("$adalLibDir\Microsoft.IdentityModel.Clients.ActiveDirectory.dll") | out-null
[System.Reflection.Assembly]::LoadFrom("$adalLibDir\Microsoft.IdentityModel.Clients.ActiveDirectory.WindowsForms.dll") | out-null

function new_adal_authentication_patcher { param($adalAdTenantId)
  $obj = New-Object PSObject -Property @{ 
    AdalAdTenantId = $adalAdTenantId;
    Token = $null;
    ClientId = "1950a258-227b-4e31-a9cf-717495945fc2";
    RedirectUri = "urn:ietf:wg:oauth:2.0:oob";
    ResourceAppIdURI = "https://management.core.windows.net/";
  }
  $obj | Add-Member -Type ScriptMethod _invokeInStaSession { param($tokenFunc, $paramName, $param)
    $pool = [RunspaceFactory]::CreateRunspacePool(1, 3)
    $pool.ApartmentState = "STA"
    $pool.Open() | Out-Null

    $pipeline  = [Management.Automation.PowerShell]::create()
    $pipeline.RunspacePool = $pool
    $pipeline.AddScript($tokenFunc) | Out-Null
    $pipeline.AddParameter($paramName, $param) | Out-Null
    $result = $pipeline.Invoke()[0]
    $pipeline.Dispose() | Out-Null
    $pool.Close() | Out-Null

    if($result -is [Management.Automation.ErrorRecord]) { throw $result }
    $result
  }
  $obj | Add-Member -Type ScriptMethod execute { param($options)
    $this._renewToken()
		$options.AuthorizationHeader = $this.Token.CreateAuthorizationHeader()
  }
  $obj | Add-Member -Type ScriptMethod _initToken {
    $param = @{
      ClientId = "1950a258-227b-4e31-a9cf-717495945fc2";
      RedirectUri = "urn:ietf:wg:oauth:2.0:oob";
      ResourceAppIdURI = "https://management.core.windows.net/";
      AdalAdTenantId = $this.AdalAdTenantId;
    }

    $tokenFunc = { param($adalConfig)
      try {
        $authority = "https://login.windows.net/$($adalConfig.AdalAdTenantId)"
        $authContext = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext($authority, $true)
        $authContext.AcquireToken($adalConfig.ResourceAppIdURI, $adalConfig.ClientId, $adalConfig.RedirectUri, [Microsoft.IdentityModel.Clients.ActiveDirectory.PromptBehavior]::Always, "site_id=501358&display=popup")
      } catch {
        $_
      }
    }

    $this.Token = $this._invokeInStaSession($tokenFunc, "adalConfig", $param)
  }
  $obj | Add-Member -Type ScriptMethod _renewToken {
    $param = @{
      ClientId = "1950a258-227b-4e31-a9cf-717495945fc2";
      RedirectUri = "urn:ietf:wg:oauth:2.0:oob";
      ResourceAppIdURI = "https://management.core.windows.net/";
      AdalAdTenantId = $this.AdalAdTenantId;
      RefreshToken = $this.Token.RefreshToken
    }

    $tokenFunc = { param($adalConfig)
      try {
        $authority = "https://login.windows.net/$($adalConfig.AdalAdTenantId)"
        $authContext = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext($authority, $true)
        $authContext.AcquireTokenByRefreshToken($adalConfig.RefreshToken, $adalConfig.ClientId, $adalConfig.ResourceAppIdURI)
      } catch {
        $_
      }
    }

    $this.Token = $this._invokeInStaSession($tokenFunc, "adalConfig", $param)
  }
  $obj._initToken()
  $obj
}
