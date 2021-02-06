<# 
    .SYNOPSIS
        Updates the doc/index.md table of contents
        Uses environment variables created inside the Azure DevOps environment
#>
[CmdletBinding()]
Param (
    [Parameter()]
    [System.String] $Path = [System.IO.Path]::Combine($env:SYSTEM_DEFAULTWORKINGDIRECTORY, "docs"),

    [Parameter()]
    [System.String] $Index = "index.md",

    [Parameter()]
    [System.String] $OutFile = [System.IO.Path]::Combine($env:SYSTEM_DEFAULTWORKINGDIRECTORY, "docs", $Index)
)

# Local testing
# $Path = [System.IO.Path]::Combine("/Users/aaron/Projects/packer", "docs")     
# $OutFile = [System.IO.Path]::Combine("/Users/aaron/Projects/packer", "docs", "index.md")

# Start with a blank markdown variable
Remove-Variable -Name markdown -ErrorAction "SilentlyContinue"
[System.String] $markdown

# Get a listing of files in the /docs folder
$params = @{
    Path      = $Path
    Directory = $true
    Recurse   = $false
}
$Level1Directories = Get-ChildItem @params

# There's a better way to do this, but this works for now
ForEach ($Level1Dir in $Level1Directories) {
    $markdown += New-MDHeader -Text $Level1Dir.BaseName -Level 1
    $markdown += "`n"

    $params = @{
        Path      = $Level1Dir
        Directory = $true
        Recurse   = $false
    }
    $Level2Directories = Get-ChildItem @params

    ForEach ($Level2Dir in $Level2Directories) {
        $markdown += New-MDHeader -Text $Level2Dir.BaseName -Level 2
        $markdown += "`n"

        $params = @{
            Path      = $Level2Dir
            Directory = $true
            Recurse   = $false
        }
        $Level3Directories = Get-ChildItem @params

        ForEach ($Level3Dir in $Level3Directories) {
            $markdown += New-MDHeader -Text $Level3Dir.BaseName -Level 3
            $markdown += "`n"
    
            $params = @{
                Path    = $Level3Dir
                Filter  = "*.md"
            }
            $Reports = Get-ChildItem @params

            ForEach ($report in $Reports) {

                # Create a link to the report, replacing \ if we're running on Windows
                $link = "* [$($report.BaseName)]($($report.FullName -replace $Path, """))`n"
                $markdown += $link -replace "\", "/"
            }
            $markdown += "`n"
        }
    }
}

# Write the markdown to a file
try {
    Write-Host "================ Writing markdown to: $OutFile."
    $markdown | Out-File -FilePath $OutFile -Encoding "Utf8" -Force
}
catch {
    Throw $_
    Break
}
