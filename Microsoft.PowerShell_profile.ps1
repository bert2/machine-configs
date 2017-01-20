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
	Write-Host "Local PS profile loaded."
}

Set-Alias Open Invoke-Item
Set-Alias :? Get-Help
Set-Alias ?? If-Null
Set-Alias Col Colorize-MatchInfo
Set-Alias Tree Print-DirectoryTree

Function Desktop { Set-Location ~\Desktop }

Function Con { ping.exe -t web.de }

Function MkLink { cmd.exe /c mklink $args }

Function cl($Path) { Get-ChildItem $Path; Set-Location $Path }

Function Max { $args | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum }

Function Min { $args | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum }

Function Expl($Path) { explorer.exe ($Path | ?? .) }

Function Profile { $profile | Split-Path -Parent | Set-Location }

Function SvnAddAll { 
	svn.exe status `
	| ?{ $_ -match "^\?" } `
	| %{ $_ -replace "^\?\s+", ""} `
	| %{ svn.exe add $_ }
}

Function Search($Pattern, $Context = 0) { 
	Get-ChildItem -Recurse | Select-String -Context $Context -AllMatches $Pattern | Colorize-MatchInfo
}

Function HardClean { 
	Get-ChildItem -Recurse -Directory -Include bin,obj,packages | %{ Remove-Item -Recurse -Force $_.FullName } 
}

Function Prompt {
    $prompt = "PS " + $(Split-Path $(Get-Location) -Leaf) + ">"
    Write-Host $prompt -NoNewline -ForegroundColor Cyan
    " "
}

Filter Colorize-MatchInfo([Parameter(ValueFromPipeline = $true)][Microsoft.PowerShell.Commands.MatchInfo] $Item) {
	If (Test-Path $Item.Path) {
		Write-Host -NoNewLine -ForegroundColor Magenta ($Item.Path | Resolve-Path -Relative)
		Write-Host -NoNewLine -ForegroundColor Cyan ":"
	}
	
	Write-Host -NoNewLine -ForegroundColor Green $Item.LineNumber
	Write-Host -NoNewLine -ForegroundColor Cyan ":"
	
	If ($Item.Context -ne $null) {
		Write-Host
	}
	
	If ($Item.Context.PreContext -ne $null) {
		Write-Host -ForegroundColor DarkGray ($Item.Context.PreContext -join "`n")
	}
	
	$matchLine = $Item.Line;
	ForEach ($match in $Item.Matches) {
		$lineParts = $matchLine -Split $match,2
		Write-Host -NoNewLine $lineParts[0]
		Write-Host -NoNewLine -ForegroundColor Red $match
		$matchLine = $lineParts[1]
	}
	
	Write-Host $matchLine
	
	If ($Item.Context.PostContext -ne $null) {
		Write-Host -ForegroundColor DarkGray ($Item.Context.PostContext -join "`n")
	}
}

Function New-Credential($UserName, $Password) {
	New-Object `
		-TypeName System.Management.Automation.PSCredential `
		-ArgumentList $UserName, (ConvertTo-SecureString $Password -AsPlainText -Force)
}

<#
test
 |- sub
 |   |- file
 |	 +- file
 |-	sub
 |	 +- file
 +-	file
#>
Function Print-DirectoryTree([IO.DirectoryInfo] $Dir = $null, $Limit = [int]::MaxValue, $Depth = 0) {	
	$indent = "   "
	Write-Host -NoNewLine ($indent * $Depth)
	Write-Host ($Dir.Name | ?? (Resolve-Path . | Split-Path -Leaf))

	If ($Depth -gt $Limit) {
		Return
	}
	
	Get-ChildItem $Dir.FullName `
	| ForEach-Object { 
		If ($_ -is [IO.DirectoryInfo]) { 
			Print-DirectoryTree $_ $Limit ($Depth + 1)
		} Else {
			Write-Host -NoNewLine ($indent * ($Depth + 1))			
			Write-Host $_.Name
		}
	}
}

Filter Get-AssemblyName([Parameter(ValueFromPipeline = $true)] $File, [switch] $SuppressAssemblyLoadErrors) {
	$path = $File.File | ?? $File.Path | ?? $File.FullName | ?? $File.FullPath | ?? $File
	$absolutePath = Resolve-Path $path
	
	Try {
		[System.Reflection.AssemblyName]::GetAssemblyName($absolutePath)
	} Catch [BadImageFormatException] {
		If (-not $SuppressAssemblyLoadErrors) {
			throw
		}
	}
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

Function ss($Size) {
	Switch ($Size) {
		1 { Set-Screen -Full }
		2 { Set-Screen -Half }
		4 { Set-Screen -Quarter }
	}
}

Function Set-Screen([switch] $Full, [switch] $Half, [switch] $Quarter) {
	Function Main {	
		If ($Full) { Set-PowerShellSize ((Get-DisplaySize).Width - 5) ((Get-DisplaySize).Height - 1) }
		If ($Half) { Set-PowerShellSize ((Get-DisplaySize).Width / 2) ((Get-DisplaySize).Height - 1) }
		If ($Quarter) { Set-PowerShellSize ((Get-DisplaySize).Width / 2) ((Get-DisplaySize).Height / 2) }
		
		Write-Host "Current size: $((Get-PSWindow).WindowSize)"
	}

	Function Set-PowerShellSize($Width, $Height) {
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
	
	Function Get-DisplaySize {
		$oldBufferSize = (Get-PSWindow).BufferSize
		# Window size is restricted by the current buffer size. Increase buffer before querying the maximum window size.
		Set-BufferSize 500 500
		$maxSize = (Get-PSWindow).MaxWindowSize 
		Set-BufferSize $oldBufferSize.Width $oldBufferSize.Height
		$maxSize
	}
	
	Function Get-PSWindow { (Get-Host).UI.RawUI }
	
	Main
}

Function If-Null([Parameter(ValueFromPipeline = $true)]$value, [Parameter(Position = 0)]$default) {
	Begin { $processedSomething = $false }

	Process { 
		$processedSomething = $true
		If ($value) { $value } Else { $default } 
	}
	
	# This makes sure the $default is returned even when the input was an empty array or of type
	# [System.Management.Automation.Internal.AutomationNull]::Value (which prevents execution of the Process block).
	End { If (-not $processedSomething) { $default } }
}
