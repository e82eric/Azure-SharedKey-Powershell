$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".tests.", ".")
. "$here\$sut"

$handler = new_retry_handler { }

Describe "retry handler" {
	Context "When a timeout exception is thrown" {
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
		It "passes the exceptions response to the exception response handler when the exception has a response" {
			$script:numberOfResponseHandlerCalls = 0;
			$expected = New-Object Net.HttpWebResponse
			$responseHandler = { param($response)
				$response | should be $expected
				$script:numberOfResponseHandlerCalls++
			}
			$handler = new_retry_handler $responseHandler
			$script:numberOfTries = 0;
			{
				$handler.execute(3, { 
					if($script:numberOfTries -lt 4) {
						$script:numberOfTries++ 
						throw New-Object Net.WebException("Timeout", (New-Object Exception), [Net.WebExceptionStatus]::Timeout, $expected)
					}
					$script:numberOfTries++ 
				}) 
			} | should throw

			$script:numberOfResponseHandlerCalls | should be 4
		}
		It "does not call the exception response handler when the exception does not have a response" {
			$script:numberOfResponseHandlerCalls = 0;
			$expected = New-Object Net.HttpWebResponse
			$responseHandler = { param($response)
				$response | should be $expected
				$script:numberOfResponseHandlerCalls++
			}
			$handler = new_retry_handler $responseHandler
			$script:numberOfTries = 0;
			{
				$handler.execute(3, { 
					if($script:numberOfTries -lt 4) {
						$script:numberOfTries++ 
						throw New-Object Net.WebException("Timeout", (New-Object Exception), [Net.WebExceptionStatus]::Timeout, $expected)
					}
					$script:numberOfTries++ 
				}) 
			} | should throw

			$script:numberOfResponseHandlerCalls | should be 4
		}
	}
	Context "when a non timeout exception is thrown" {
		It "throws" {
			$script:numberOfTries = 0
			{
				$handler.execute(3, { 
					if($script:numberOfTries -eq 0) {
						$script:numberOfTries++ 
						throw New-Object Net.WebException("ConnectFailure", [Net.WebExceptionStatus]::ConnectFailure)
					}
					$script:numberOfTries++ 
				})
			} | Should throw
		}
		It "passes the exceptions response to the response handler when the exception has a response" {
			$script:numberOfResponseHandlerCalls = 0;
			$expected = New-Object Net.HttpWebResponse
			$responseHandler = { param($response)
				$response | should be $expected
				$script:numberOfResponseHandlerCalls++
			}
			$handler = new_retry_handler $responseHandler
			$script:numberOfTries = 0;
			{
				$handler.execute(3, {
					if($script:numberOfTries -eq 0) {
						$script:numberOfTries++ 
						throw New-Object Net.WebException("ConnectFailure", (New-Object Exception), [Net.WebExceptionStatus]::ConnectFailure, $expected)
					}
				})
			} | should throw

			$script:numberOfResponseHandlerCalls | should be 1
		}
		It "does not call the response handler when the exception has no response" {
			$script:numberOfResponseHandlerCalls = 0;
			$responseHandler = { param($response)
				$script:numberOfResponseHandlerCalls++
			}
			$handler = new_retry_handler $responseHandler
			$script:numberOfTries = 0;
			{
				$handler.execute(3, {
					if($script:numberOfTries -eq 0) {
						$script:numberOfTries++ 
						throw New-Object Net.WebException("ConnectFailure", [Net.WebExceptionStatus]::ConnectFailure)
					}
				})
			} | should throw

			$script:numberOfResponseHandlerCalls | should be 0
		}
	}
}
