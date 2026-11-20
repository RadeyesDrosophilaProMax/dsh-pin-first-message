# dsh-pin-first-message install script
# Usage: irm https://raw.githubusercontent.com/RadeyesDrosophilaProMax/dsh-pin-first-message/main/install.ps1 | iex
#        or: .\install.ps1 -Profile "D:\DSshuju\profiles\desktop"

param(
  [string]$Profile = '',
  [string]$InstallDir = "$env:USERPROFILE\DSHAI\dsh-pin"
)

$ErrorActionPreference = 'Stop'
$repo = 'https://github.com/RadeyesDrosophilaProMax/dsh-pin-first-message.git'

function Find-Profile {
  if ($Profile -ne '') { return $Profile }
  if ($env:DSH_PROFILE -and (Test-Path "$env:DSH_PROFILE\cordis.patch.yml")) { return $env:DSH_PROFILE }
  $roots = @("$env:USERPROFILE\DSHAI", "$env:APPDATA\dsh", "$env:LOCALAPPDATA\dsh", 'D:\DSshuju\profiles')
  $hits = @()
  foreach ($root in $roots) {
    if (-not (Test-Path $root)) { continue }
    $hits += Get-ChildItem $root -Recurse -Depth 3 -Filter 'cordis.patch.yml' -ErrorAction SilentlyContinue |
      Where-Object { $_.DirectoryName -notmatch 'node_modules' }
  }
  if ($hits.Count -eq 0) { throw 'No DSH profile found. Pass -Profile <dir>.' }
  if ($hits.Count -eq 1) { return $hits[0].DirectoryName }
  $sorted = $hits | Sort-Object LastWriteTime -Descending
  Write-Host 'Found several DSH profiles:'
  foreach ($hit in $sorted) { Write-Host "  - $($hit.DirectoryName)" }
  Write-Host "Using the most recently used one: $($sorted[0].DirectoryName)"
  Write-Host 'Pass -Profile <dir> to choose another.'
  return $sorted[0].DirectoryName
}

$profileDir = Find-Profile
Write-Host "profile : $profileDir"

if (Test-Path "$InstallDir\.git") {
  Write-Host "update  : $InstallDir"
  git -C $InstallDir pull -q --ff-only 2>$null | Out-Null
} else {
  Write-Host "clone   : $InstallDir"
  New-Item -ItemType Directory -Force -Path (Split-Path $InstallDir) | Out-Null
  git clone -q --depth 1 $repo $InstallDir 2>$null | Out-Null
}

$link = Join-Path $profileDir 'node_modules\@local\dsh-pin'
if (-not (Test-Path $link)) {
  New-Item -ItemType Directory -Force -Path (Split-Path $link) | Out-Null
  try {
    New-Item -ItemType Junction -Path $link -Target $InstallDir -ErrorAction Stop | Out-Null
    Write-Host "link    : junction $link"
  } catch {
    Write-Host "link    : junction not allowed here, copying files instead"
    Copy-Item -Recurse -Force (Join-Path $InstallDir '*') $link
  }
} else {
  Write-Host "link    : exists"
}

$node = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $node) { throw 'node.exe not found on PATH' }

$script = @'
const fs = require('fs');
const [profileDir, installDir] = process.argv.slice(2);
const pkgPath = profileDir + '/package.json';
const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
pkg.dependencies = pkg.dependencies || {};
pkg.dependencies['@local/dsh-pin'] = 'link:' + installDir.replace(/\\\\/g, '/');
fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n', 'utf8');
const patchPath = profileDir + '/cordis.patch.yml';
let text = fs.readFileSync(patchPath, 'utf8');
if (!text.includes("name: '@local/dsh-pin'")) {
  text += "\n\n# 固定记忆：把会话里对方说的第一句话挂进系统提示，压缩拿不走。\n- insert:\n    - id: pin-first-message\n      name: '@local/dsh-pin'\n";
  fs.writeFileSync(patchPath, text, 'utf8');
  console.log('patch   : added');
} else {
  console.log('patch   : exists');
}
console.log('dep     : ok');
'@

$tmp = Join-Path $env:TEMP 'dsh-pin-install.cjs'
Set-Content -Path $tmp -Value $script -Encoding UTF8
& $node $tmp $profileDir $InstallDir
Remove-Item $tmp -Force -ErrorAction SilentlyContinue

Write-Host ''
Write-Host 'Done. Restart DSH, then open a NEW session - its first user message gets pinned.'
