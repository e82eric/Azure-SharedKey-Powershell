$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".tests.", ".")
. "$here\$sut"

Describe "create signature" {
	$parser = new_table_signature_parser
	It "capitalizes the verb" {
		$params = @{ Options = @{ Verb = "verb1"; Content = @{ Length = 5 } }; CanonicalizedResources = "resource 1"; MsHeaders = @{ name = "x-ms-date"; value = "date1"; } }
		$parser.execute($params)
		$params.Signature | should be "VERB1`n`n`ndate1`nresource 1"
	}
	#Context "when there is no content" {
	#	It "returns the verb concatenated with twelve new lines, the canonicalized header and resource seperated by a new line" {
	#		$params = @{ Options = @{ Verb = "VERB 1"; }; CanonicalizedHeaders = "headers 1"; CanonicalizedResources = "resource 1"; }
	#		$parser.execute($params)
	#		$params.Signature | should be "VERB 1`n`n`n`n`n`n`n`n`n`n`n`nheaders 1`nresource 1"
	#	}
	#}
	#Context "when there is content" {
	#	It "adds the content length at the fourth line" {
	#		$params = @{ Options = @{ Verb = "VERB 1"; Content = @{ Length = 5 } }; CanonicalizedHeaders = "headers 1"; CanonicalizedResources = "resource 1"; }
	#		$parser.execute($params)
	#		$params.Signature | should be "VERB 1`n`n`n5`n`n`n`n`n`n`n`n`nheaders 1`nresource 1"
	#	}
	#}
	#Context "when there is no content type" {
	#	$params = @{ Options = @{ Verb = "VERB 1"; Content = @{ Length = 12 } }; CanonicalizedHeaders = "headers 1"; CanonicalizedResources = "resource 1"; }
	#	$parser.execute($params)
	#	It "leaves the sixth line blank" {
	#		$params.Signature | should be "VERB 1`n`n`n12`n`n`n`n`n`n`n`n`nheaders 1`nresource 1"
	#	}
	#}
	#Context "when there is a content type" {
	#	$params = @{ Options = @{ Verb = "VERB 1"; Content = @{ Length = 12 }; ContentType = "text/plain; charset=UTF-8" }; CanonicalizedHeaders = "headers 1"; CanonicalizedResources = "resource 1"; }
	#	$parser.execute($params)
	#	It "sets the 6th line to the hash" {
	#		$params.Signature | should be "VERB 1`n`n`n12`n`ntext/plain; charset=UTF-8`n`n`n`n`n`n`nheaders 1`nresource 1"
	#	}
	#}
	#Context "when there is no md5 hash" {
	#	$params = @{ Options = @{ Verb = "VERB 1"; Content = @{ Length = 12 }; ContentType = "text/plain; charset=UTF-8" }; CanonicalizedHeaders = "headers 1"; CanonicalizedResources = "resource 1"; }
	#	$parser.execute($params)
	#	It "leaves the fifth line blank" {
	#		$params.Signature | should be "VERB 1`n`n`n12`n`ntext/plain; charset=UTF-8`n`n`n`n`n`n`nheaders 1`nresource 1"
	#	}
	#}
	#Context "when there is a md5 hash" {
	#	$params = @{ Options = @{ Verb = "VERB 1"; Content = @{ Length = 12 }; ContentType = "text/plain; charset=UTF-8"; ContentHash = "contenthash1" }; CanonicalizedHeaders = "headers 1"; CanonicalizedResources = "resource 1"; }
	#	$parser.execute($params)
	#	It "sets the 5th line to the hash" {
	#		$params.Signature | should be "VERB 1`n`n`n12`ncontenthash1`ntext/plain; charset=UTF-8`n`n`n`n`n`n`nheaders 1`nresource 1"
	#	}
	#}
}
