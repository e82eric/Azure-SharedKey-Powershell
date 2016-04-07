$ErrorActionPreference = "stop"

function new_announcer {
	$obj = New-Object PSObject
	$obj | Add-Member -Type ScriptMethod Write { param(
		$message
	)
		Write-Host "$($message)" -ForegroundColor White
	}
	$obj | Add-Member -Type ScriptMethod Info { param(
		$message
	)
		Write-Host "INFO: $($message)" -ForegroundColor White
	}
	$obj | Add-Member -Type ScriptMethod Verbose { param(
		$message
	)
		Write-Host "VERBOSE: $($message)" -ForegroundColor Green
	}
	$obj | Add-Member -Type ScriptMethod Error { param(
		$message
	)
		Write-Host "ERROR: $($message)" -ForegroundColor Red
	}
	$obj | Add-Member -Type ScriptMethod Debug { param(
		$message
	)
		Write-Host "DEBUG: $($message)" -ForegroundColor Yellow
	}
	$obj | Add-Member -Type ScriptMethod ApiTrace { param($actionName, $callParams)
		$callParamsArr = [array]@()
		$callParams.Keys | % { $callParamsArr += "$($_): $($callParams[$_])" }
		$callParamsStr = [string]::Join(", ", $callParamsArr)
		$this.Verbose("Api trace, action: $($actionName), $($callParamsStr)")
	}
	$obj
}
