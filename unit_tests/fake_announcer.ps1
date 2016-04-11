$ErrorActionPreference = "stop"

function new_fake_announcer {
	$obj = New-Object PSObject
	$obj | Add-Member -Type ScriptMethod Write { param(
		$message
	)
	}
	$obj | Add-Member -Type ScriptMethod Info { param(
		$message
	)
	}
	$obj | Add-Member -Type ScriptMethod Verbose { param(
		$message
	)
	}
	$obj | Add-Member -Type ScriptMethod Error { param(
		$message
	)
	}
	$obj | Add-Member -Type ScriptMethod Debug { param(
		$message
	)
	}
	$obj | Add-Member -Type ScriptMethod ApiTrace { param($actionName, $callParams)
	}
	$obj
}
