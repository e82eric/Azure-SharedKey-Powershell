$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".tests.", ".")
. "$here\..\lib\$sut"

Describe "add the canonicalized resources to the params" {
	$accountName = "account1"
	$parser = new_table_canonicalized_resources_parser $accountName
	Context "when there are operations" {
		It "concatenates the account and the resource with a /" {
			$parser | Add-Member -Type ScriptMethod _createOperationsString { param($operations) if($operations -ne $params.Operations) { throw "Expected $(params.Operations)" } return "operations string 1" } -Force
			$result = $parser.execute("resource1")
			$result | should equal "/account1/resource1"
		}
	}
	Context "when there are not operations" {
		It "concatenates the account and resource with a /" {
			$parser | Add-Member -Type ScriptMethod _createOperationsString { param($operations) if($operations -ne $params.Operations) { throw "Expected $(params.Operations)" } return [string]::empty } -Force
			$result = $parser.execute("resource1")
			$result | should equal "/account1/resource1"
		}
	}
}
