# Builds the Windows release and packs it exactly like the other platforms.
#
# Run this ON WINDOWS, from anywhere:
#     powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1
#
# Needs: Flutter (stable) + Visual Studio 2022 with the
# "Desktop development with C++" workload. Users need the WebView2 Runtime,
# which is already part of Windows 10/11.
#
# Output:
#     dist\windows\pchat_app-<version>-windows-x64\       <- run pchat_app.exe here
#     dist\windows\pchat_app-<version>-windows-x64.zip    <- what you hand out

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$match = Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9][^+]*).*$' | Select-Object -First 1
$version = if ($match) { $match.Matches[0].Groups[1].Value } else { "1.0.0" }
$name = "pchat_app-$version"

Write-Host "== Building Windows release ($version) =="
flutter build windows --release

$release = "build\windows\x64\runner\Release"
if (-not (Test-Path $release)) { throw "build output not found: $release" }

$dist = "dist\windows"
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$folder = "$dist\$name-windows-x64"
if (Test-Path $folder) { Remove-Item -Recurse -Force $folder }
Copy-Item -Recurse -Force $release $folder

# The .exe alone does not run — data\ and the .dll files have to travel with it.
Compress-Archive -Force -Path "$folder\*" -DestinationPath "$dist\$name-windows-x64.zip"

Write-Host ""
Write-Host "Ready: $dist\$name-windows-x64.zip"
Get-ChildItem $dist -File | Format-Table Name, @{Name = "Size (MB)"; Expression = { [math]::Round($_.Length / 1MB, 1) } }
Write-Host "Ship the whole folder, not just pchat_app.exe."
