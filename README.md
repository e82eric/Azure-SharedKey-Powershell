Azure-SharedKey-Powershell
==========================
Load library
. .\Steps.Azure.Storage.ps1 $storageAccountKey

Load Small Files
Get-ChildItem $directory -Recurse | ? { ! $_.PSIsContainer } | % {
  $resource = $_.FullName.Replace($parentDirectory, "").Replace("\", "/")
  $url = "http://$storageAccount.blob.core.windows.net/$container$resource"
  $toUpload = [IO.File]::ReadAllBytes($_.FullName)
  $request = Request PUT $url $toUpload
  $request.WebRequest.Close()
}

