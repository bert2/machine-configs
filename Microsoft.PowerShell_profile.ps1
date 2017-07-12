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
Set-Alias Col Colorize-MatchInfo
Set-Alias Tree Print-DirectoryTree

function Desktop { Set-Location ~\Desktop }

function MkLink { cmd.exe /c mklink $args }

function cl($Path) { Get-ChildItem $Path; Set-Location $Path }

function Max { $args | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum }

function Min { $args | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum }

function Expl($Path) { explorer.exe ($Path | If-Null .) }

function Explr($Path) { Expl $Path }

function Profile { $profile | Split-Path -Parent | Set-Location }

function Prompt {
	$originalLastExitCode = $LASTEXITCODE
    
	Write-Host -NoNewline -ForegroundColor Cyan $ExecutionContext.SessionState.Path.CurrentLocation
	if (Get-Command svn -ErrorAction Ignore) { Write-SvnStatus }
	if ((Get-Command git -ErrorAction Ignore) -and (Get-Module -ListAvailable -Name posh-git)) { 
		if (Test-Path .git) { git.exe fetch -q }
		Write-VcsStatus 
	}
	Write-Host
	
	$LASTEXITCODE = $originalLastExitCode
	"$('>' * ($NestedPromptLevel + 1)) "
}

function Locate($Filter, [switch]$MatchWholeWord) {
	$Filter = if ($MatchWholeWord) {$Filter} else {"*$Filter*"}
	Get-ChildItem -Recurse -Filter $Filter `
	| ForEach-Object {
		Write-Host -ForegroundColor DarkGray -NoNewLine "$($_.FullName | Split-Path -Parent | Resolve-Path -Relative)\"
		Write-Host -ForegroundColor Green  $_.Name
	}
}

function Search(
	$Pattern, 
	$Context = 0, 
	$Include = @(), 
	$Exclude = @('*.exe', '*.dll', '*.pdb', '*ResolveAssemblyReference.cache'),
	[ScriptBlock]$FilterPredicate = {$_ -notlike '*\bin\*' -and $_ -notlike '*\obj\*'},
	[switch]$PassThru) { 
	Get-ChildItem .\* -Recurse -Include $Include -Exclude $Exclude `
	| Where-Object { -not $FilterPredicate -or (& $FilterPredicate $_) } `
	| Select-String -Context $Context -AllMatches $Pattern `
	| % {if ($PassThru) {$_} else {Colorize-MatchInfo $_}}
}

function HardClean { 
	Get-ChildItem -Recurse -Directory -Include bin,obj,packages | %{ Remove-Item -Recurse -Force $_.FullName } 
}

function SvnForAll([Parameter(Mandatory=$true)][ValidateSet('?', 'A', 'M', 'D', 'R', '*')]$Status, $SvnCommand, $ExternalCommand) {
	$statusPattern = switch ($Status) {
			'?' {'\?'}
			'*' {'.'}
			default {$Status}
		}
	$command = if ($SvnCommand) {"svn.exe $SvnCommand"} else {$ExternalCommand}
	
	svn.exe status `
	| ?{ $_ -match "^$statusPattern" } `
	| %{ $_ -replace "^$statusPattern\s+", '' } `
	| %{ Invoke-Expression "$command '$_'" }
}

function Write-SvnStatus {
	function Write-Status($status, $color) {
		Write-Host -NoNewline -ForegroundColor Yellow ' ['
		Write-Host -NoNewline -ForegroundColor $color $status		
		Write-Host -NoNewline -ForegroundColor Yellow ']'
	}

	$svnLocalRev = svn.exe info --show-item last-changed-revision 2>&1
	
	# Current directory is not part of an SVN working copy.
	if ($svnLocalRev -like 'svn: E155007*') {
		return
	}
	
	# Current directory has not been added to SVN.
	if ($svnLocalRev -like 'svn: warning: W155010*') {
		Write-Status "not VC'ed" Red
		return
	}
	
	# Current directory is part of an SVN working copy, but SVN can still not find it.
	# Probably a letter case issue, since the case of the paths passed to filesystem cmdlets (e.g. CD) is preserved.
	if ($svnLocalRev -like 'svn: E200009*') {
		# Fix case of current working directory and try svn info again.
		Get-Location | Resolve-PathCase | Set-Location
		$svnLocalRev = svn.exe info --show-item last-changed-revision 2>&1
	}
	
	if ($svnLocalRev -match '^svn: E\d+') {
		Write-Status $svnLocalRev Red
		return
	}
	
	$svnHeadRev = svn.exe info -r HEAD --show-item last-changed-revision 2>&1
	
	if ($svnHeadRev -match '^svn: E\d+') {
		Write-Status $svnHeadRev Red
		return
	}
	
	$color = if ($svnLocalRev -eq $svnHeadRev) {'Cyan'} else {'Red'}
	$svnStatus = $svnLocalRev.Trim()
	$svnStatus += if ($svnLocalRev -ne $svnHeadRev) {"/$($svnLocalRev - $svnHeadRev)"}
	Write-Status $svnStatus.Trim() $color
}

filter Colorize-MatchInfo([Parameter(ValueFromPipeline = $true)][Microsoft.PowerShell.Commands.MatchInfo] $Item) {
	if (Test-Path $Item.Path) {
		Write-Host -NoNewLine -ForegroundColor Magenta ($Item.Path | Resolve-Path -Relative)
		Write-Host -NoNewLine -ForegroundColor Cyan ":"
	}
	
	Write-Host -NoNewLine -ForegroundColor Red $Item.LineNumber
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
		Write-Host -NoNewLine -ForegroundColor Green $match
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
	Write-Host "$($Dir.Name | If-Null (Resolve-Path . | Split-Path -Leaf))\"

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

function WinMerge($Left, $Right) { 
	$leftName = Split-Path -Leaf $Left
	$rightName = Split-Path -Leaf $Right
	WinMergeU.exe /e /s /u /wr /dl $leftName /dr $rightName $Left $Right 
}

filter Get-AssemblyName([Parameter(ValueFromPipeline = $true)] $File, [switch] $SuppressAssemblyLoadErrors) {
	$path = $File.File | If-Null $File.Path | If-Null $File.FullName | If-Null $File.FullPath | If-Null $File
	$absolutePath = Resolve-Path $path
	
	try {
		[System.Reflection.AssemblyName]::GetAssemblyName($absolutePath)
	} catch [BadImageFormatException] {
		if (-not $SuppressAssemblyLoadErrors) {
			throw
		}
	}
}

filter Test-Xml(
	[Parameter(ValueFromPipeline = $true)]$XmlFile, 
	$XsdFile, 
	[scriptblock]$ValidationEventHandler = { 
		Write-Host "Error in ${XmlFile}:`n`t$($args[1].Exception)" -ForegroundColor Red 
	}) {
	$xml = New-Object System.Xml.XmlDocument
	$schemaReader = New-Object System.Xml.XmlTextReader (Resolve-Path $XsdFile).Path
	$schema = [System.Xml.Schema.XmlSchema]::Read($schemaReader, $null)
	$xml.Schemas.Add($schema) | Out-Null
	$xml.Load((Resolve-Path $XmlFile).Path)
	$xml.Validate($ValidationEventHandler)
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

filter Resolve-PathCase(
	[Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)] $Path) {

	$Path = if ($Path -is [IO.DirectoryInfo]) {$Path} else {Get-Item $Path}
	$parent = $Path.Parent

	if (-not $parent) {
		# Resolve-Path corrects case of filesystem roots (e.g. c:\ becomes C:\).
		Resolve-Path $Path.Name
		return
	}

	$parent `
	| Resolve-PathCase `
	| Join-Path -ChildPath $parent.GetDirectories($Path.Name).Name `
	| Resolve-Path
}

function ss($Size) {
	switch ($Size) {
		1 { Set-Screen -Full }
		2 { Set-Screen -Half }
		3 { Set-Screen -TwoThirds }
		4 { Set-Screen -Quarter }
	}
}

function Set-Screen(
	[switch]$Full, [switch]$Half, [switch]$Quarter, [switch]$TwoThirds, $Width, $Height) {
	function Main {	
		if ($Width -and $Height) { Set-PowerShellSize $Width $Height }
		if ($Full) { Set-PowerShellSize ((Get-DisplaySize).Width - 5) ((Get-DisplaySize).Height - 1) }
		if ($TwoThirds) { Set-PowerShellSize ((Get-DisplaySize).Width / 3 * 2) ((Get-DisplaySize).Height - 1) }
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

function ConvertFrom-Gzip(
	[Parameter(ValueFromPipeline=$True)][byte[]]$Bytes,
	[ValidateSet('ASCII', 'Unicode', 'BigEndianUnicode', 'Default', 'UTF32', 'UTF7', 'UTF8')][String]$Encoding = 'ASCII') {
	$input = New-Object -TypeName System.IO.MemoryStream -ArgumentList @(,$Bytes)
	$gzipStream = New-Object -TypeName System.IO.Compression.GZipStream -ArgumentList @($input, [System.IO.Compression.CompressionMode]::Decompress)
	$output = New-Object -TypeName System.IO.MemoryStream
	
	$gzipStream.CopyTo($output)	
	$data = $output.ToArray()
	
	$output.Close()
	$gzipStream.Close()
	$input.Close()
	
	([System.Text.Encoding]::$Encoding).GetString($data).Split("`n")
}