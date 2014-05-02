function new_composite_parser { param($parsers)
	$obj = New-Object PSObject -Property @{ Parsers = $parsers }
	$obj | Add-Member -Type ScriptMethod execute { param($params)
		$this.Parsers | % {
			$_.execute($params)
		}
	}
	$obj
}
