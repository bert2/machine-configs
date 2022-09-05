function Write-ElapsedMilliseconds($PreText, [ScriptBlock]$Operation, [Switch]$ExportToOuterScope) {
    Write-Host -NoNewline "$PreText..."
    $sw = [System.Diagnostics.StopWatch]::StartNew()
    if ($ExportToOuterScope) { . $Operation } else { & $Operation }
    Write-Host "done (took $($sw.ElapsedMilliseconds)ms)."
}

$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path $ChocolateyProfile) {
    Write-ElapsedMilliseconds 'Loading chocolatey profile' {
        Import-Module $ChocolateyProfile
    }
}

if (Get-Module -ListAvailable -Name PSReadline) {
    Write-ElapsedMilliseconds 'Loading PSReadLine' {
        Import-Module PSReadline
        Set-PSReadlineKeyHandler -Key Tab -Function Complete
        Set-PSReadlineOption -BellStyle None
    }
}

if (Get-Module -ListAvailable -Name posh-git) {
    Write-ElapsedMilliseconds 'Loading posh-git' {
        Import-Module posh-git
    }
}

if (Get-Module -ListAvailable -Name oh-my-posh) {
    Write-ElapsedMilliseconds 'Loading oh-my-posh' {
        Import-Module oh-my-posh
        Set-Theme Paradox
    }
    $DefaultUser = 'bert'
}

if (Test-Path ~\LocalPSProfile.ps1) {
    . Write-ElapsedMilliseconds 'Loading local PowerShell profile' {
        . ~\LocalPSProfile.ps1
    } -ExportToOuterScope
}

Set-Alias Open Invoke-Item
Set-Alias :? Get-Help
Set-Alias Col Colorize-MatchInfo
Set-Alias Tree Print-DirectoryTree
Set-Alias g git

function rmrf { Remove-Item -Recurse -Force $args }

function la { Get-ChildItem -Force $args }

function Desktop { Set-Location ~\Desktop }

function MkLink { cmd.exe /c mklink $args }

function cl($Path) { Get-ChildItem $Path; Set-Location $Path }

function Max { $args | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum }

function Min { $args | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum }

function Expl($Path) { explorer.exe ($Path | If-Null .) }

function Explr($Path) { Expl $Path }

function Profile { $profile | Split-Path -Parent | Set-Location }

function Which { Get-Command $args | Select-Object -ExpandProperty Definition }

function Locate($Filter, [switch]$MatchWholeWord, [switch]$PassThru) {
    $Filter = if ($MatchWholeWord) { $Filter } else { "*$Filter*" }
    Get-ChildItem -Recurse -Force -Filter $Filter `
    | ForEach-Object {
        if ($PassThru) {
            $_.FullName | Resolve-Path -Relative
        }
        else {
            Write-Host -ForegroundColor Gray -NoNewLine "$($_.FullName | Split-Path -Parent | Resolve-Path -Relative)\"
            Write-Host -ForegroundColor Green  $_.Name
        }
    }
}

function Search(
    $Pattern,
    $Context = 0,
    $Include = @(),
    $Exclude = @('*.exe', '*.dll', '*.pdb', '*ResolveAssemblyReference.cache', '*.dbmdl', '*.jfm', '*.bak'),
    [ScriptBlock]$FilterPredicate = {
        $_ -notlike '*\bin\*' -and $_ -notlike '*\obj\*' -and $_ -notlike '*\.git\*' -and $_ -notlike '*\.vs\*' -and $_ -notlike '*\node_modules\*' -and $_ -notlike '*\dist\*'
    },
    [switch]$PassThru) {
    Get-ChildItem .\* -Recurse -Force -Include $Include -Exclude $Exclude `
    | Where-Object { -not $FilterPredicate -or (& $FilterPredicate $_) } `
    | Select-String -Context $Context -AllMatches $Pattern `
    | ForEach-Object { if ($PassThru) { $_.Path } else { Colorize-MatchInfo $_ } }
}

function Replace(
    $Old,
    $New,
    $Include = @(),
    $Exclude = @('*.exe', '*.dll', '*.pdb', '*ResolveAssemblyReference.cache'),
    [ScriptBlock]$FilterPredicate = {
        $_ -notlike '*\bin\*' -and $_ -notlike '*\obj\*' -and $_ -notlike '*\.git\*' -and $_ -notlike '*\.vs\*'
    }) {
    Get-ChildItem .\* -Recurse -Force -Include $Include -Exclude $Exclude `
    | Where-Object { -not $FilterPredicate -or (& $FilterPredicate $_) } `
    | Select-String $Old `
    | Select-Object -Unique -ExpandProperty Path `
    | Where-Object { $_ -ne "InputStream" } `
    | ForEach-Object {
        $enc = Get-Encoding $_
        (Get-Content $_) `
        | % { $_ -replace $Old, $New } `
        | Set-Content $_ -Encoding $enc
    }
}

function Get-Encoding($File) {
    [byte[]]$byte = Get-Content -Encoding byte -ReadCount 4 -TotalCount 4 -Path $File

    if ($byte[0] -eq 0xef -and $byte[1] -eq 0xbb -and $byte[2] -eq 0xbf ) {
        'UTF8'
    }
    elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff) {
        'BigEndianUnicode'
    }
    elseif ($byte[0] -eq 0xff -and $byte[1] -eq 0xfe) {
        'Unicode'
    }
    elseif ($byte[0] -eq 0 -and $byte[1] -eq 0 -and $byte[2] -eq 0xfe -and $byte[3] -eq 0xff) {
        'UTF32'
    }
    elseif ($byte[0] -eq 0x2b -and $byte[1] -eq 0x2f -and $byte[2] -eq 0x76) {
        'UTF7'
    }
    else {
        'ASCII'
    }
}

function HardClean {
    Get-ChildItem -Recurse -Directory -Include bin, obj, packages | % { Remove-Item -Recurse -Force $_.FullName }
}

filter Colorize-MatchInfo([Parameter(ValueFromPipeline = $true)][Microsoft.PowerShell.Commands.MatchInfo] $Item) {
    if (Test-Path $Item.Path) {
        Write-Host -NoNewLine -ForegroundColor DarkYellow ($Item.Path | Resolve-Path -Relative)
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
        $lineParts = $matchLine -Split $match, 2, 'SimpleMatch,IgnoreCase'
        Write-Host -NoNewLine $lineParts[0]
        Write-Host -NoNewLine -BackgroundColor DarkGreen $match
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
        }
        else {
            Write-Host -NoNewLine ($indent * ($Depth + 1))
            Write-Host $_.Name
        }
    }
}

function WinMerge($Left, $Right) {
    $leftName = Split-Path -Leaf $Left
    $rightName = Split-Path -Leaf $Right
    WinMergeU.exe /e /s /u /wr /dl $leftName /dr $rightName (ls $Left).FullName (ls $Right).FullName
}

filter Get-AssemblyName([Parameter(ValueFromPipeline = $true)] $File, [switch] $SuppressAssemblyLoadErrors) {
    $path = $File.File | If-Null $File.Path | If-Null $File.FullName | If-Null $File.FullPath | If-Null $File
    $absolutePath = Resolve-Path $path

    try {
        [System.Reflection.AssemblyName]::GetAssemblyName($absolutePath)
    }
    catch [BadImageFormatException] {
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

function Set-EnvVar() {
    [CmdletBinding()]
    param($Var, $Value, [switch]$Append, [switch]$Temp)

    if ($Append) {
        $oldValue = Invoke-Expression "`$env:$Var"
        $Value = $oldValue + $Value
    }

    if (-not $Temp) {
        Write-Verbose "Update to $Var will be permanent."
        [Environment]::SetEnvironmentVariable($Var, $Value, [System.EnvironmentVariableTarget]::User)
    }

    Invoke-Expression "`$env:$Var = '$Value'"
    Write-Verbose "$Var set to new value '$Value'."
}

function Add-PathToEnvironment() {
    [CmdletBinding()]
    param($Path, [switch]$Temp, [switch]$Force)

    if (-not $Temp) {
        Write-Host 'Updating PATH environment variable permanently...'

        if (-not (Test-Path $Path) -and -not $Force) {
            Write-Warning "Directory $Path does not exist, stopping."
            Write-Warning 'Use -Force switch to permanently add non-existing directories to PATH environment variable.'
            return
        }
    }

    Set-EnvVar 'Path' -Append -Value ";$Path" -Temp:$Temp
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

# ConvertFrom-Compressed -Type DeflateStream -Encoding UTF8 -Bytes $(cat <file> -Encoding Byte)
function ConvertFrom-Compressed(
    [Parameter(ValueFromPipeline = $True)][byte[]]$Bytes,
    [ValidateSet('ASCII', 'Bytes', 'Unicode', 'BigEndianUnicode', 'Default', 'UTF32', 'UTF7', 'UTF8')][String]$Encoding = 'ASCII',
    [ValidateSet('DeflateStream', 'GZipStream')][String]$Type = 'GZipStream') {
    if ($Type -eq 'DeflateStream') { $Bytes = $Bytes | select -Skip 2 }
    $input = New-Object -TypeName System.IO.MemoryStream -ArgumentList @(, $Bytes)
    $comprStream = New-Object -TypeName System.IO.Compression.$Type -ArgumentList @($input, [System.IO.Compression.CompressionMode]::Decompress)
    $output = New-Object -TypeName System.IO.MemoryStream

    $comprStream.CopyTo($output)
    $data = $output.ToArray()

    $output.Close()
    $comprStream.Close()
    $input.Close()

    if ($Encoding -eq 'Bytes') {
        $data
    }
    else {
        ([System.Text.Encoding]::$Encoding).GetString($data).Split("`n")
    }
}

filter Escape-Uri([Parameter(ValueFromPipeline = $true)]$uri) {
    $uri | % { [uri]::EscapeDataString($_) }
}

filter Unescape-Uri([Parameter(ValueFromPipeline = $true)]$uri) {
    $uri | % { [uri]::UnescapeDataString($_) }
}

function google([Parameter(ValueFromRemainingArguments = $true)]$searchTerms) {

    function Main {
        if ($searchTerms.Count -eq 0) { return }

        $query = ($searchTerms | Escape-Uri) -join '+'
        $url = "https://www.google.com/search?safe=off&q=$query"

        Invoke-WebRequest $url `
        | Parse-GoogleResponse `
        | Print-SearchResult
    }

    function Parse-GoogleResponse([Parameter(ValueFromPipeline = $true)]$htmlDocument) {
        filter Parse-GoogleLink {
            if ($_ -match '^about:/url\?q=([^&]+)&.*') {
                # Google wraps regular links with /url?q=https://www.result.com/the-site/&sa=U&...
                $Matches[1]
            }
            elseif ($_ -match '^about:(/search\?q=.+)') {
                # Links to similar searches start with /search?q=...
                "https://www.google.com$($Matches[1])"
            }
            else {
                $_
            }
        }

        # Search results are wrapped with <div class="ZINbbc xpd O9g5cc uUPGi">...</div>. Except the first and the last
        # one, which are both some tables we are not interested in.
        $htmlDocument.ParsedHtml.GetElementsByTagName("div") `
        | ? { $_.Attributes["class"].NodeValue -eq 'ZINbbc xpd O9g5cc uUPGi' } `
        | select -Skip 1 `
        | select -Last 100 -Skip 1 `
        | % {
            # Search result structure:
            #
            # <div class="kCrYT">
            #   <a href=" { LINK } ">
            #     <div class="BNeawe vvjwJb AP7Wnd"> { TITLE } </div>
            #     <div class="BNeawe UPmit AP7Wnd"> { BREAD CRUMBS } </div>
            #   </a>
            # </div>
            # <div class="x54gtf"></div>
            # <div class="kCrYT">
            #   <div>
            #     <div class="BNeawe s3v9rd AP7Wnd">
            #       <div>
            #         <div>
            #           <div class="BNeawe s3v9rd AP7Wnd"> { SNIPPET } </div>
            #         </div>
            #       </div>
            #     </div>
            #   </div>
            # </div>
            $containers = $_.GetElementsByTagName("div") | ? { $_.Attributes["class"].NodeValue -eq 'kCrYT' }
            $link = $containers `
            | select -First 1 `
            | % { $_.GetElementsByTagName("a") }
            $title = $link.GetElementsByTagName("div") | ? { $_.Attributes["class"].NodeValue -eq 'BNeawe vvjwJb AP7Wnd' }
            $snippet = $containers `
            | select -Last 1 `
            | % { $_.GetElementsByTagName("div") | ? { $_.Attributes["class"].NodeValue -eq 'BNeawe s3v9rd AP7Wnd' } } `
            | % { $_.GetElementsByTagName("div") | ? { $_.Attributes["class"].NodeValue -eq 'BNeawe s3v9rd AP7Wnd' } }

            @{
                Title   = $title.InnerText
                Link    = $link.Href | Parse-GoogleLink | Unescape-Uri
                Snippet = $snippet.InnerText
            }
        }
    }

    filter Print-SearchResult {
        Write-Host $_.Title
        Write-Host -ForegroundColor Yellow $_.Link
        if ($_.Snippet) { Write-Host $_.Snippet -ForegroundColor Gray }
        Write-Host
    }

    Main
}
