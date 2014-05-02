$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".tests.", ".")
. "$here\$sut"

Describe "split parameters" {
	$parser = new_uri_parser
	Context "one parameter" {
		$expected = @{ name = "value 1"; value = "value1" }
		$parser | Add-Member -Type ScriptMethod _splitParameter { param($parameterString) if($parameterString -ne "name=value") { throw } return $expected } -Force
		$result = $parser._splitParameters("name=value")
		It "returns the query string" {
			$result.length | should equal 1
			$result[0] | should equal $expected 
		}
	}
	Context "two parameters" {
		$expected1 = @{ name = "value 1"; value = "value1" }
		$expected2 = @{ name = "value 2"; value = "value2" }
		$parser | Add-Member -Type ScriptMethod _splitParameter { param($parameterString) 
			if ($parameterString -eq "name1=value1") { 
				return $expected1
			} if ($parameterString -eq "name2=value2") {
				return $expected2
			}
		} -Force
		$result = $parser._splitParameters("name1=value1&name2=value2")
		It "should split the parameters using &" {
			$result.length | should equal 2
			$result[0] | should equal $expected1
			$result[1] | should equal $expected2
		}
	}
}

Describe "split parameter" {
	$parser = new_uri_parser
	Context "one equal sign" {
		$result = $parser._splitParameter("name1=value1")
		It "split the name and value using the equal sign" {
			$result.Name | should equal "name1"
			$result.Value | should equal "value1"
		}
	}
	Context "the value contains a equal sign" {
		$result = $parser._splitParameter("name1=value1=")
		It "should include the equal sign in the value" {
			$result.Name | should equal "name1"
			$result.Value | should equal "value1="
		}
	}
}

Describe "parse uri" {
	$clientType = "type1"
	$parser = new_uri_parser $clientType
	Context "when there are no operations and the resource is a container" {
		$params = @{ Options = @{Url = "http://AccountName1.$clientType.core.windows.net/resource" } }
		$parser.execute($params)
		It "parses the account name out of the start of the uri" {
			$params.Account | should equal "AccountName1"
		}
		It "parses the name from the end of the uri" {
			$params.Resource | should equal "resource"
		}
		It "returns null for operation" {
			$params.Operations | should equal $null 
		}
	}
	Context "when there are no operations and the resource is a blob" {
		$params = @{ Options = @{ Url = "http://AccountName1.$clientType.core.windows.net/container/blob" } }
		$parser.execute($params)
		It "parses the account name out of the start of the uri" {
			$params.Account | should equal "AccountName1"
		}	
		It "uses the end the url for the resource" {
			$params.Resource | should equal "container/blob"
		}	
		It "returns null for operation" {
			$params.Operations | should equal $null 
		}
	}
	Context "when there is one operation and the resource is a blob" {
		$params = @{ Options = @{ Url = "http://AccountName1.$clientType.core.windows.net/container/blob?comp=list" } }
		$expectedOperations = "operations1"
		$parser | Add-member -Type ScriptMethod _splitParameters { param($queryString) if($queryString -ne "comp=list") { throw } return $expectedOperations } -Force
		$parser.execute($params)
		It "parses the account name out of the start of the uri" {
			$params.Account | should equal "AccountName1"
		}	
		It "uses the end the url before the ? for the resource" {
			$params.Resource | should equal "container/blob"
		}	
		It "parses the name and value of the operation between the =" {
			$params.Operations | should equal $expectedOperations
		}
	}
	Context "when there is two operations and the resource is a blob" {
		$params = @{ Options = @{ Url = "http://AccountName1.$clientType.core.windows.net/container/blob?restype=container&comp=list" } }
		$expectedOperations = "operations2"
		$parser | Add-member -Type ScriptMethod _splitParameters { param($queryString) if($queryString -ne "restype=container&comp=list") { throw } return $expectedOperations } -Force
		$parser.execute($params)
		It "parses the name and value of the operation between the =" {
			$params.Operations | should equal $expectedOperations 
		}
	}
	Context "when the scheme is https" {
		$params = @{ Options = @{ Url = "http://AccountName1.$clientType.core.windows.net/resource" } }
		$parser.execute($params)
		It "parses the account name out of the start of the uri" {
			$params.Account | should equal "AccountName1"
		}
		It "parses the name from the end of the uri" {
			$params.Resource | should equal "resource"
		}
		It "returns null for operation" {
			$params.Operations | should equal $null 
		}
	}
}
