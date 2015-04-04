param($adalLibDir = (Resolve-Path "..\libs").Path)

[Reflection.Assembly]::LoadFrom("$adalLibDir\Microsoft.IdentityModel.Clients.ActiveDirectory.dll") | out-null
#[Reflection.Assembly]::LoadFrom("$adalLibDir\Microsoft.IdentityModel.Clients.ActiveDirectory.WindowsForms.dll") | out-null

function new_aad_token_provider { param($resourceAppIdUri, $aadTenant, $subscriptionId)
	$obj = new_aad_token_provider_base $resourceAppIdUri $aadTenant $subscriptionId
  $obj | Add-Member -Type ScriptMethod GetToken {
    $param = @{
      ClientId = $this.ClientId;
      RedirectUri = $this.RedirectUri;
      ResourceAppIdURI = $this.ResourceAppIdUri;
			AadTenant = $this.AadTenant;
			Authority = $this.Authority;
    }

    $tokenFunc = { param($adalConfig)
      try {
        $authContext = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext($adalConfig.Authority, $true)
        $authContext.AcquireToken(
					$adalConfig.ResourceAppIdUri,
					$adalConfig.ClientId,
					$adalConfig.RedirectUri,
					[Microsoft.IdentityModel.Clients.ActiveDirectory.PromptBehavior]::Always,
					"site_id=501358&display=popup")
      } catch {
        $_
      }
    }

    $this._invokeInStaSession($tokenFunc, "adalConfig", $param)
  }
  $obj
}

function new_aad_token_provider_with_login { param($resourceAppIdUri, $aadTenant, $subscriptionId, $loginHint)
	$obj = new_aad_token_provider_base $resourceAppIdUri $aadTenant $subscriptionId
	$obj | Add-Member -Type NoteProperty LoginHint $loginHint
  $obj | Add-Member -Type ScriptMethod GetToken {
    $param = @{
      ClientId = $this.ClientId;
      RedirectUri = $this.RedirectUri;
      ResourceAppIdURI = $this.ResourceAppIdUri;
			AadTenant = $this.AadTenant;
			Authority = $this.Authority;
			LoginHint = $this.LoginHint
    }

    $tokenFunc = { param($adalConfig)
      try {
        $authContext = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext($adalConfig.Authority, $true)
        $authContext.AcquireToken(
					$adalConfig.ResourceAppIdUri,
					$adalConfig.ClientId,
					$adalConfig.RedirectUri,
					[Microsoft.IdentityModel.Clients.ActiveDirectory.PromptBehavior]::Auto,
					(New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier($adalConfig.LoginHint, [Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifierType]::OptionalDisplayableId)),
					"site_id=501358&display=popup")
      } catch {
        $_
      }
    }

    $this._invokeInStaSession($tokenFunc, "adalConfig", $param)
  }
  $obj
}

function new_aad_token_provider_base { param($resourceAppIdUri, $aadTenant, $subscriptionId)
  $obj = New-Object PSObject -Property @{ 
    ClientId = "1950a258-227b-4e31-a9cf-717495945fc2";
    RedirectUri = "urn:ietf:wg:oauth:2.0:oob";
    ResourceAppIdUri = $resourceAppIdUri;
		AadTenant = $aadTenant;
		Authority = "https://login.windows.net/$($aadTenant)";
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
  $obj | Add-Member -Type ScriptMethod GetTokenByRefreshToken { param($refreshToken)
		$authContext = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext($this.Authority, $false)
		$authContext.AcquireTokenByRefreshToken($refreshToken, $this.ClientId, $this.ResourceAppIdURI)
  }
  $obj
}
