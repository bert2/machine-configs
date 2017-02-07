# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path $ChocolateyProfile) {
	Import-Module "$ChocolateyProfile"
}

if (Get-Module -ListAvailable -Name PSReadline) {
	Write-Host 'Loading module PSReadLine.'
	Import-Module PSReadline
	Set-PSReadlineKeyHandler -Key Tab -Function Complete
	Set-PSReadlineOption -BellStyle None
}

if (Get-Module -ListAvailable -Name posh-git) {
	Write-Host 'Loading module posh-git.'
	Import-Module posh-git
}

if (Test-Path ~\LocalPSProfile.ps1) {
	Write-Host 'Loading local PowerShell profile.'
	. ~\LocalPSProfile.ps1	
}

Set-Alias Open Invoke-Item
Set-Alias :? Get-Help
Set-Alias ?? If-Null
Set-Alias Col Colorize-MatchInfo
Set-Alias Tree Print-DirectoryTree

function Desktop { Set-Location ~\Desktop }

function Con { ping.exe -t www.google.com }

function MkLink { cmd.exe /c mklink $args }

function cl($Path) { Get-ChildItem $Path; Set-Location $Path }

function Max { $args | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum }

function Min { $args | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum }

function Expl($Path) { explorer.exe ($Path | ?? .) }

function Explr($Path) { Expl $Path }

function Profile { $profile | Split-Path -Parent | Set-Location }

function Prompt {
	$originalLastExitCode = $LASTEXITCODE
    
	Write-Host -NoNewline -ForegroundColor Cyan $ExecutionContext.SessionState.Path.CurrentLocation
	if (Get-Command svn -ErrorAction Ignore) { Write-SvnStatus }
	if (Get-Command git -ErrorAction Ignore) { Write-VcsStatus }
	Write-Host
	
	$LASTEXITCODE = $originalLastExitCode
	"$('>' * ($NestedPromptLevel + 1)) "
}

function Locate($Filter) { Get-ChildItem -Recurse -Filter $Filter }

function Search(
	$Pattern, 
	$Context = 0, 
	$Include = @(), 
	$Exclude = @('*.exe', '*.dll', '*.pdb', '*ResolveAssemblyReference.cache')) { 
	Get-ChildItem .\* -Recurse -Include $Include -Exclude $Exclude `
	| Select-String -Context $Context -AllMatches $Pattern `
	| Colorize-MatchInfo
}

function HardClean { 
	Get-ChildItem -Recurse -Directory -Include bin,obj,packages | %{ Remove-Item -Recurse -Force $_.FullName } 
}

function SvnForAll([ValidateSet('\?', 'A', 'M', 'D', 'R', '.')]$Status, $Command) { 
	svn.exe status `
	| ?{ $_ -match "^$Status" } `
	| %{ $_ -replace "^$Status\s+", ''} `
	| %{ & svn.exe $Command $_ }
}

function Write-SvnStatus {
	$svnLocalRev = svn.exe info --show-item last-changed-revision 2>&1
	
	# Current directory is not part of an SVN working copy.
	if ($svnLocalRev -like '*E155007*') {
		return
	}
	
	# Current directory is part of an SVN working copy, but SVN can still not find it.
	# Probably a letter case issue, since the case of the paths passed filesystem cmdlets (e.g. CD) is preserved.
	if ($svnLocalRev -like '*E200009*') {
		Write-Host -NoNewline -ForegroundColor Yellow ' ['
		Write-Host -NoNewline -BackgroundColor DarkRed 'Case mismatch'
		Write-Host -NoNewline -ForegroundColor Yellow ']'
		return
	}
	
	$svnHeadRev = svn.exe info -r HEAD --show-item last-changed-revision 2>&1
	$svnStatus = if ($svnLocalRev -eq $svnHeadRev) {'up to date'} else {'out of date'}
	$color = if ($svnLocalRev -eq $svnHeadRev) {'Cyan'} else {'Red'}
	
	Write-Host -NoNewline -ForegroundColor Yellow ' ['
	Write-Host -NoNewline -ForegroundColor $color $svnStatus		
	Write-Host -NoNewline -ForegroundColor Yellow ']'
}

filter Colorize-MatchInfo([Parameter(ValueFromPipeline = $true)][Microsoft.PowerShell.Commands.MatchInfo] $Item) {
	if (Test-Path $Item.Path) {
		Write-Host -NoNewLine -ForegroundColor Magenta ($Item.Path | Resolve-Path -Relative)
		Write-Host -NoNewLine -ForegroundColor Cyan ":"
	}
	
	Write-Host -NoNewLine -ForegroundColor Green $Item.LineNumber
	Write-Host -NoNewLine -ForegroundColor Cyan ":"
	
	if ($Item.Context -ne $null) {
		Write-Host
	}
	
	if ($Item.Context.PreContext -ne $null) {
		Write-Host -ForegroundColor DarkGray ($Item.Context.PreContext -join "`n")
	}
	
	$matchLine = $Item.Line;
	foreach ($match in $Item.Matches) {
		$lineParts = $matchLine -Split $match,2,'SimpleMatch,IgnoreCase'
		Write-Host -NoNewLine $lineParts[0]
		Write-Host -NoNewLine -ForegroundColor Red $match
		$matchLine = $lineParts[1]
	}
	
	Write-Host $matchLine
	
	if ($Item.Context.PostContext -ne $null) {
		Write-Host -ForegroundColor DarkGray ($Item.Context.PostContext -join "`n")
	}
}

function New-Credential($UserName, $Password) {
	New-Object `
		-TypeName System.Management.Automation.PSCredential `
		-ArgumentList $UserName, (ConvertTo-SecureString $Password -AsPlainText -Force)
}

function Print-DirectoryTree([IO.DirectoryInfo] $Dir = $null, $Limit = [int]::MaxValue, $Depth = 0) {	
	$indent = "   "
	Write-Host -NoNewLine ($indent * $Depth)
	Write-Host "$($Dir.Name | ?? (Resolve-Path . | Split-Path -Leaf))\"

	if ($Depth -gt $Limit) {
		return
	}
	
	Get-ChildItem $Dir.FullName `
	| ForEach-Object { 
		if ($_ -is [IO.DirectoryInfo]) { 
			Print-DirectoryTree $_ $Limit ($Depth + 1)
		} else {
			Write-Host -NoNewLine ($indent * ($Depth + 1))			
			Write-Host $_.Name
		}
	}
}

filter Get-AssemblyName([Parameter(ValueFromPipeline = $true)] $File, [switch] $SuppressAssemblyLoadErrors) {
	$path = $File.File | ?? $File.Path | ?? $File.FullName | ?? $File.FullPath | ?? $File
	$absolutePath = Resolve-Path $path
	
	try {
		[System.Reflection.AssemblyName]::GetAssemblyName($absolutePath)
	} catch [BadImageFormatException] {
		if (-not $SuppressAssemblyLoadErrors) {
			throw
		}
	}
}

function Add-PathToEnvironment($Path, [switch] $Temp, [switch] $Force) {
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

function ss($Size) {
	switch ($Size) {
		1 { Set-Screen -Full }
		2 { Set-Screen -Half }
		4 { Set-Screen -Quarter }
	}
}

function Set-Screen([switch] $Full, [switch] $Half, [switch] $Quarter) {
	function Main {	
		if ($Full) { Set-PowerShellSize ((Get-DisplaySize).Width - 5) ((Get-DisplaySize).Height - 1) }
		if ($Half) { Set-PowerShellSize ((Get-DisplaySize).Width / 2) ((Get-DisplaySize).Height - 1) }
		if ($Quarter) { Set-PowerShellSize ((Get-DisplaySize).Width / 2) ((Get-DisplaySize).Height / 2) }
		
		Write-Host "Current size: $((Get-PSWindow).WindowSize)"
	}

	function Set-PowerShellSize($Width, $Height) {
		$bufferSize = (Get-PSWindow).BufferSize

		if ($bufferSize.Width -lt $Width) {
			Set-BufferSize $Width 9999
			Set-WindowSize $Width $Height
		} else {
			Set-WindowSize $Width $Height
			Set-BufferSize $Width 9999
		}
	}
	
	function Set-BufferSize($Width, $Height) {
		$newSize = (Get-PSWindow).BufferSize
		$newSize.Width = $Width
		$newSize.Height = $Height
		(Get-PSWindow).BufferSize = $newSize
	}

	function Set-WindowSize($Width, $Height) {
		$maxHeight = (Get-PSWindow).MaxWindowSize.Height
		$newSize = (Get-PSWindow).WindowSize
		$newSize.Width = $Width
		$newSize.Height = (Min $Height $maxHeight)
		(Get-PSWindow).WindowSize = $newSize
	}
	
	function Get-DisplaySize {
		$oldBufferSize = (Get-PSWindow).BufferSize
		# Window size is restricted by the current buffer size. Increase buffer before querying the maximum window size.
		Set-BufferSize 500 500
		$maxSize = (Get-PSWindow).MaxWindowSize 
		Set-BufferSize $oldBufferSize.Width $oldBufferSize.Height
		$maxSize
	}
	
	function Get-PSWindow { (Get-Host).UI.RawUI }
	
	Main
}

function If-Null([Parameter(ValueFromPipeline = $true)]$value, [Parameter(Position = 0)]$default) {
	Begin { $processedSomething = $false }

	Process { 
		$processedSomething = $true
		if ($value) { $value } else { $default } 
	}
	
	# This makes sure the $default is returned even when the input was an empty array or of type
	# [System.Management.Automation.Internal.AutomationNull]::Value (which prevents execution of the Process block).
	End { if (-not $processedSomething) { $default } }
}
