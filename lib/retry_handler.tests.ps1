$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".tests.", ".")
. "$here\$sut"

$handler = new_retry_handler

Describe "retry handler" {
	It "executes the action once when it does not throw an exception" {
		$script:numberOfTries = 0
		$handler.execute(3, { $script:numberOfTries++ })
		$script:numberOfTries | should equal 1
	}
	It "executes the action twice when it throws a web exception the first time" {
		$script:numberOfTries = 0
		$handler.execute(3, { 
			if($script:numberOfTries -eq 0) {
				$script:numberOfTries++ 
				throw New-Object Net.WebException("Timeout", [Net.WebExceptionStatus]::Timeout)
			}
			$script:numberOfTries++ 
		})
		$script:numberOfTries | should equal 2
	}
	It "executes the action three times when it throws a web exception the first and second times" {
		$script:numberOfTries = 0
		$handler.execute(3, { 
			if($script:numberOfTries -lt 2) {
				$script:numberOfTries++ 
				throw New-Object Net.WebException("Timeout", [Net.WebExceptionStatus]::Timeout)
			}
			$script:numberOfTries++ 
		})
		$script:numberOfTries | should equal 3
	}
	It "executes the action three times when it throws a web exception the first and second times" {
		$script:numberOfTries = 0
		$handler.execute(3, { 
			if($script:numberOfTries -lt 3) {
				$script:numberOfTries++ 
				throw New-Object Net.WebException("Timeout", [Net.WebExceptionStatus]::Timeout)
			}
			$script:numberOfTries++ 
		})
		$script:numberOfTries | should equal 4
	}
	It "throws the exception when the action throws more times that the retry count" {
		$script:numberOfTries = 0
		{ 
			$handler.execute(3, { 
				if($script:numberOfTries -lt 4) {
					$script:numberOfTries++ 
					throw New-Object Net.WebException("Timeout", [Net.WebExceptionStatus]::Timeout)
				}
				$script:numberOfTries++ 
			}) 
		} | Should throw
	}
}
