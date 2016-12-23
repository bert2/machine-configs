# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
If (Test-Path $ChocolateyProfile) {
	Import-Module "$ChocolateyProfile"
}

If (Get-Module PSReadline) {
	Import-Module PSReadline
	Set-PSReadlineKeyHandler -Key Tab -Function Complete
	Set-PSReadlineOption -BellStyle None
}

If (Test-Path ~\LocalPSProfile.ps1) {
	. ~\LocalPSProfile.ps1
	
	Set-Alias Bash $LocalBashPath
	Set-Alias NPP $LocalNppPath
	
	Write-Host "Local PS profile loaded."
}

Set-Alias :? Get-Help
Set-Alias Col Colorize

Function Desktop { Set-Location ~\Desktop }

Function Con { ping.exe -t web.de }

Function MkLink { cmd.exe /c mklink $args }

Function cl($Path) { Set-Location $Path; Get-ChildItem . }

Function FullScreen { Set-PowerShellSize ((Get-DisplaySize).Width - 3) ((Get-DisplaySize).Height - 1) }

Function HalfScreen { Set-PowerShellSize ((Get-DisplaySize).Width / 2) ((Get-DisplaySize).Height - 1) }

Function QuarterScreen { Set-PowerShellSize ((Get-DisplaySize).Width / 2) ((Get-DisplaySize).Height / 2) }

Function HardClean { Get-ChildItem -Recurse -Directory -Include bin,obj | %{ Remove-Item -Recurse -Force $_.FullName } }

Function Max { $args | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum }

Function Min { $args | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum }

Function Search($Pattern, $Context = 0) { 
	Get-ChildItem -Recurse | Select-String -Context $Context -AllMatches $Pattern | Colorize
}

Function Prompt {
    $prompt = "PS " + $(Split-Path $(Get-Location) -Leaf) + ">"
    Write-Host $prompt -NoNewline -ForegroundColor Cyan
    " "
}

Filter Colorize {
	if (Test-Path $_.Path) {
		Write-Host -NoNewLine -ForegroundColor Magenta ($_.Path | Resolve-Path -Relative)
		Write-Host -NoNewLine -ForegroundColor Cyan ":"
	}
	
	Write-Host -NoNewLine -ForegroundColor Green $_.LineNumber
	Write-Host -NoNewLine -ForegroundColor Cyan ":"
	
	if ($_.Context -ne $null) {
		Write-Host
	}
	
	if ($_.Context.PreContext -ne $null) {
		Write-Host -ForegroundColor DarkGray ($_.Context.PreContext -join "`n")
	}
	
	$matchLine = $_.Line;
	foreach ($match in $_.Matches) {
		$lineParts = $matchLine -Split $match,2
		Write-Host -NoNewLine $lineParts[0]
		Write-Host -NoNewLine -ForegroundColor Red $match
		$matchLine = $lineParts[1]
	}
	
	Write-Host $matchLine
	
	if ($_.Context.PostContext -ne $null) {
		Write-Host -ForegroundColor DarkGray ($_.Context.PostContext -join "`n")
	}
}

Function New-Credential($UserName, $Password) {
	New-Object `
		-TypeName System.Management.Automation.PSCredential `
		-ArgumentList $UserName, (ConvertTo-SecureString $Password -AsPlainText -Force)
}

Function Add-PathToEnvironment($Path, [switch] $Temp, [switch] $Force) {
	if (-not $Temp) {
		if (-not (Test-Path $Path) -and -not $Force) {
			Write-Warning "Use -Force switch to permanently add non-existing directory $Path to PATH environment variable."
			return
		}
	
		[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$Path", [System.EnvironmentVariableTarget]::User)
		Write-Host "Permanently added $path to PATH environment variable."
	}
	
	$env:Path += ";$Path"
}

Function Set-PowerShellSize($Width, $Height) {
	Write-Host "New size: $Width x $Height"
	$bufferSize = (Get-PSWindow).BufferSize

	If ($bufferSize.Width -lt $Width) {
		Set-BufferSize $Width 9999
		Set-WindowSize $Width $Height
	} Else {
		Set-WindowSize $Width $Height
		Set-BufferSize $Width 9999
	}
}

Function Set-BufferSize($Width, $Height) {
	$newSize = (Get-PSWindow).BufferSize
	$newSize.Width = $Width
	$newSize.Height = $Height
	(Get-PSWindow).BufferSize = $newSize
}

Function Set-WindowSize($Width, $Height) {
	$maxHeight = (Get-PSWindow).MaxWindowSize.Height
	$newSize = (Get-PSWindow).WindowSize
	$newSize.Width = $Width
	$newSize.Height = (Min $Height $maxHeight)
	(Get-PSWindow).WindowSize = $newSize
}

Function Get-PSWindow { (Get-Host).UI.RawUI }

Function Get-DisplaySize {
	$oldBufferSize = (Get-PSWindow).BufferSize
	# Window size is restricted by the current buffer size. Increase buffer before querying the maximum window size.
	Set-BufferSize 500 500
	$maxSize = (Get-PSWindow).MaxWindowSize 
	Set-BufferSize $oldBufferSize.Width $oldBufferSize.Height
	$maxSize
}