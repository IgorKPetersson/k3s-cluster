[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$ScreenshotDirectory = Join-Path $RepositoryRoot 'screenshots'
$ArtifactDirectory = Join-Path $RepositoryRoot 'artifacts\evidence-pages'
$GitBash = 'C:\Program Files\Git\bin\bash.exe'
$BrowserCandidates = @(
    'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
    'C:\Program Files\Google\Chrome\Application\chrome.exe',
    'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
)

if (-not (Test-Path -LiteralPath $GitBash)) {
    throw "Git Bash was not found at $GitBash."
}

$Browser = $BrowserCandidates | Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1
if (-not $Browser) {
    throw 'Microsoft Edge or Google Chrome is required to capture evidence.'
}

New-Item -ItemType Directory -Force -Path $ScreenshotDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $ArtifactDirectory | Out-Null

function Invoke-GitBash {
    param([Parameter(Mandatory)][string]$Command)

    $output = & $GitBash -lc $Command 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "Evidence command failed with exit code ${LASTEXITCODE}: $Command`n$output"
    }
    return $output -replace "`e\[[0-9;]*[A-Za-z]", ''
}

function Save-BrowserScreenshot {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$OutputPath,
        [string]$WindowSize = '1600,1000'
    )

    $arguments = @(
        '--headless=new',
        '--disable-gpu',
        '--hide-scrollbars',
        "--window-size=$WindowSize",
        "--screenshot=$OutputPath",
        $Url
    )
    $process = Start-Process -FilePath $Browser -ArgumentList $arguments -Wait `
        -PassThru -WindowStyle Hidden
    if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $OutputPath)) {
        throw "Browser screenshot failed for $Url."
    }
}

function New-EvidencePage {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][string]$Output
    )

    $htmlPath = Join-Path $ArtifactDirectory "$Name.html"
    $screenshotPath = Join-Path $ScreenshotDirectory "$Name.png"
    $encodedOutput = [System.Net.WebUtility]::HtmlEncode($Output.TrimEnd())
    $encodedTitle = [System.Net.WebUtility]::HtmlEncode($Title)
    $encodedDescription = [System.Net.WebUtility]::HtmlEncode($Description)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'
    $html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>$encodedTitle</title>
  <style>
    body { margin: 0; padding: 44px; background: #0b1020; color: #ecf2ff;
      font-family: "Segoe UI", sans-serif; }
    h1 { margin: 0 0 8px; font-size: 30px; color: #7dd3fc; }
    p { margin: 0 0 24px; color: #b7c5df; font-size: 17px; }
    pre { margin: 0; padding: 26px; border: 1px solid #33466d; border-radius: 12px;
      background: #080c17; color: #d8e5ff; font: 15px/1.5 Consolas, monospace;
      white-space: pre-wrap; }
    footer { margin-top: 18px; color: #7f91b2; font-size: 13px; }
  </style>
</head>
<body>
  <h1>$encodedTitle</h1>
  <p>$encodedDescription</p>
  <pre>$encodedOutput</pre>
  <footer>Homework 08 final evidence - captured $timestamp</footer>
</body>
</html>
"@
    Set-Content -LiteralPath $htmlPath -Value $html -Encoding utf8
    $url = ([System.Uri]$htmlPath).AbsoluteUri
    Save-BrowserScreenshot -Url $url -OutputPath $screenshotPath
}

$cleanState = Invoke-GitBash @'
source scripts/common.sh
printf 'Cluster inventory after clean recreation:\n'
k3d cluster list
printf '\nDocker network created for this run:\n'
docker network inspect k3d-homework08 --format 'Name={{.Name}} Created={{.Created}} Containers={{len .Containers}} Labels={{json .Labels}}'
printf '\nFinal verification result:\n'
./scripts/verify.sh | tail -n 1
'@
New-EvidencePage -Name '01-clean-recreation' -Title 'Clean recreation succeeded' `
    -Description 'Fresh k3d network, six-node cluster, and successful final verification.' `
    -Output $cleanState

$runtime = Invoke-GitBash @'
source scripts/common.sh
k3d cluster list
printf '\nNamed k3d containers:\n'
docker ps --filter name=k3d-homework08 --format 'table {{.Names}}\t{{.Status}}'
'@
New-EvidencePage -Name '02-six-node-runtime' -Title 'Six-node k3s runtime' `
    -Description 'Three server containers and three agent containers are running.' `
    -Output $runtime

$nodes = Invoke-GitBash @'
source scripts/common.sh
kubectl get nodes -o wide
'@
New-EvidencePage -Name '03-role-separation' -Title 'Kubernetes role separation' `
    -Description 'Three Ready control-plane/etcd nodes and three Ready worker nodes.' `
    -Output $nodes

$webScreenshot = Join-Path $ScreenshotDirectory '04-hello-world-browser.png'
Save-BrowserScreenshot -Url 'http://localhost:8080' -OutputPath $webScreenshot `
    -WindowSize '1440,900'

$pod = Invoke-GitBash @'
source scripts/common.sh
kubectl -n homework08 get pods -o wide
'@
New-EvidencePage -Name '05-running-pod' -Title 'Hello World pod placement' `
    -Description 'The application pod is Running and Ready on a dedicated worker.' `
    -Output $pod

$safety = Invoke-GitBash @'
python -B .codex/hooks/demo_policy.py
'@
New-EvidencePage -Name '06-safety-hook' -Title 'Full-cluster safety policy' `
    -Description 'Representative commands are classified without executing them.' `
    -Output $safety

Write-Output "Captured six evidence screenshots in $ScreenshotDirectory."
