$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".tests.", ".")
. "$here\..\lib\$sut"

Describe "create operations string" {
	$parser = new_blob_canonicalized_resources_parser
	Context "when the operations are null" {
		It "returns an empty string" {
			$result = $parser._createOperationsString()
			$result | should equal ""
		}
	}
	Context "when there are no operations" {
		It "returns an empty string" {
			$result = $parser._createOperationsString(@())
			$result | should equal ""
		}
	}
	Context "when there is one operation" {
		It "converts the name to lower case" {
			$operation = @{ name = "OpNaMe"; value = "opvalue" }
			$result = $parser._createOperationsString($operation)
			$result | should equal "opname:opvalue"
		}
		It "does not convert the value to lower case" {
			$operation = @{ name = "opname"; value = "OpVAlUe" }
			$result = $parser._createOperationsString($operation)
			$result | should equal "opname:OpVAlUe"
		}
		It "concatenates the name and value with a :" {
			$operation = @{ name = "opname"; value = "opvalue" }
			$result = $parser._createOperationsString($operation)
			$result | should be "opname:opvalue"
		}
	}
	Context "when there are two operations" {
		It "concatenates the operations with a new line" {
			$operation1 = @{ name = "op1name"; value = "op1value" }
			$operation2 = @{ name = "op2name"; value = "op2value" }
			$result = $parser._createOperationsString(@($operation1,$operation2))
			$result | should be "op1name:op1value`nop2name:op2value"
		}
		It "sorts the operations alphabetically by name" {
			$operation1 = @{ name = "bop1name"; value = "op1value" }
			$operation2 = @{ name = "aop2name"; value = "op2value" }
			$result = $parser._createOperationsString(@($operation1,$operation2))
			$result | should be "aop2name:op2value`nbop1name:op1value"
		}
	}
	Context "when there are three operations" {
		It "concatenates the operations with a new line" {
			$operation1 = @{ name = "op1name"; value = "op1value" }
			$operation2 = @{ name = "op2name"; value = "op2value" }
			$operation3 = @{ name = "op3name"; value = "op3value" }
			$result = $parser._createOperationsString(@($operation1,$operation2,$operation3))
			$result | should be "op1name:op1value`nop2name:op2value`nop3name:op3value"
		}
		It "sorts the operations alphabetically by name" {
			$operation1 = @{ name = "bopname"; value = "opbvalue" }
			$operation2 = @{ name = "aopname"; value = "opavalue" }
			$operation3 = @{ name = "copname"; value = "opcvalue" }
			$result = $parser._createOperationsString(@($operation1,$operation2,$operation3))
			$result | should be "aopname:opavalue`nbopname:opbvalue`ncopname:opcvalue"
		}
	}
}

Describe "parse the canonicalized resources" {
	$accountName = "account1"
	$parser = new_blob_canonicalized_resources_parser $accountName
	Context "when there are operations" {
		It "concatenates the account, uri with a / and the operations string with new line" {
			$resource = "resource1"
			$operations = "operations1"
			$parser | Add-Member -Type ScriptMethod _createOperationsString { param($passedOperations) if($passedOperations -ne $operations) { throw "Expected $(operations)" } return "operations string 1" } -Force
			$result = $parser.execute($operations, $resource)
			$result | should equal "/account1/resource1`noperations string 1"
		}
	}
	Context "when there are not operations" {
		It "concatenates the account and uri with a /" {
			$resource = "resource1"
			$operations = "operations1"
			$parser | Add-Member -Type ScriptMethod _createOperationsString { param($passedOperations) if($passedOperations -ne $operations) { throw "Expected $($operations)" } return [string]::empty } -Force
			$result = $parser.execute($operations, $resource)
			$result | should equal "/account1/resource1"
		}
	}
}
