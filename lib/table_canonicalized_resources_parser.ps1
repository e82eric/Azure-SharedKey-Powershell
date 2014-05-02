function new_table_canonicalized_resources_parser {
	$obj = New-Object PSObject
	$obj | Add-Member -Type ScriptMethod execute -Value { param ($params)
		$params.CanonicalizedResources = "/$($params.Account)/$($params.Resource)"
	}
	$obj
}
