# Downloads the MODNet portrait-matting model (Apache-2.0) that "add me" uses for the edge of the
# person. Without it the feature still works, with a coarser edge.
#   powershell -File android/tools/fetch_modnet.ps1
$ErrorActionPreference = 'Stop'
$url = 'https://huggingface.co/onnx-community/modnet-webnn/resolve/main/onnx/model.onnx'
$sha = '07c308cf0fc7e6e8b2065a12ed7fc07e1de8febb7dc7839d7b7f15dd66584df9'
$target = Join-Path $PSScriptRoot '..\app\src\main\assets\modnet.onnx'
New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
$tmp = "$target.download"
Invoke-WebRequest -Uri $url -OutFile $tmp
$got = (Get-FileHash $tmp -Algorithm SHA256).Hash.ToLower()
if ($got -ne $sha) { Remove-Item $tmp; throw "Checksum differs ($got); the file was not kept." }
Move-Item -Force $tmp $target
Write-Host "Saved $target"
