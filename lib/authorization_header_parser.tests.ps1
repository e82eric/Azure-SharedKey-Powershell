$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".tests.", ".")
. "$here\$sut"

Describe "add the authorization header to the params" {
	$storageName = "account1"
	$parser = new_authorization_header_parser $storageName
	Context "when signature hash is not null" {
		It "it conatenates SharedKey the storage name and the signature hash" {
			$result = $parser.execute("5566")
			$result | should equal "SharedKey account1:5566"
		}
	}
}
