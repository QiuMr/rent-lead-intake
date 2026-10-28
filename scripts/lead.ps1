param(
    [Parameter(Position = 0)]
    [ValidateSet("whoami", "submit", "update")]
    [string]$Command = "whoami",
    [string]$Set = "",
    [string]$Text = "",
    [string]$Fields = "",
    [int]$CandidateId = 0,
    [string]$ClientId = "",
    [string]$Ts = ""
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$Api = if ($env:RENT_LEAD_API) { $env:RENT_LEAD_API.TrimEnd("/") } else { "http://182.92.214.51:8789" }
$HomeDir = if ($env:RENT_LEAD_HOME) { $env:RENT_LEAD_HOME } else { Join-Path $HOME ".rent-lead" }
$Config = Join-Path $HomeDir "whoami.json"

function Get-Name {
    if (-not (Test-Path $Config)) { return "" }
    try {
        return [string]((Get-Content $Config -Raw -Encoding UTF8 | ConvertFrom-Json).name)
    } catch {
        return ""
    }
}

function Set-Name([string]$Name) {
    $Name = ($Name -replace "\s+", " ").Trim()
    if (-not $Name) { throw "名字不能为空" }
    New-Item -ItemType Directory -Force -Path $HomeDir | Out-Null
    @{
        name = $Name
        saved_at = (Get-Date).ToString("s")
    } | ConvertTo-Json | Set-Content -Path $Config -Encoding UTF8
    return $Name
}

function Invoke-Post([string]$Path, [byte[]]$Bytes, $Proxy, [int]$TimeoutMs) {
    try {
        $req = [System.Net.HttpWebRequest]::Create($Api + $Path)
    } catch {
        return @{ ok = $false; error = $_.Exception.Message }
    }
    $req.Method = "POST"
    $req.ContentType = "application/json; charset=utf-8"
    $req.Timeout = $TimeoutMs
    $req.ReadWriteTimeout = $TimeoutMs
    $req.Proxy = $Proxy
    $req.ContentLength = $Bytes.Length
    try {
        $stream = $req.GetRequestStream()
        $stream.Write($Bytes, 0, $Bytes.Length)
        $stream.Close()
        $resp = $req.GetResponse()
    } catch [System.Net.WebException] {
        $errResp = $_.Exception.Response
        if ($errResp) {
            try {
                $reader = New-Object System.IO.StreamReader($errResp.GetResponseStream(), [System.Text.Encoding]::UTF8)
                $text = $reader.ReadToEnd()
                $reader.Close()
                $errResp.Close()
                return @{ ok = $true; text = $text }
            } catch {
                return @{ ok = $false; error = $_.Exception.Message }
            }
        }
        return @{ ok = $false; error = $_.Exception.Message }
    } catch {
        return @{ ok = $false; error = $_.Exception.Message }
    }
    $reader = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
    $text = $reader.ReadToEnd()
    $reader.Close()
    $resp.Close()
    return @{ ok = $true; text = $text }
}

function Post-Json([string]$Path, [hashtable]$Payload) {
    $json = $Payload | ConvertTo-Json -Depth 10 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    # 直连优先：云端沙盒的系统代理常拦截非 443 出网，还会回 502
    $direct = Invoke-Post $Path $bytes $null 10000
    if ($direct.ok) { return $direct.text }
    $systemProxy = [System.Net.WebRequest]::GetSystemWebProxy()
    $viaProxy = Invoke-Post $Path $bytes $systemProxy 20000
    if ($viaProxy.ok) { return $viaProxy.text }
    return (@{
        ok = $false
        code = "network_error"
        message = "连不上后台（直连：$($direct.error)；系统代理：$($viaProxy.error)）。若在云端沙盒中，可设置 NO_PROXY=182.92.214.51 后重试，或让宿主直连。"
        data = @{}
    } | ConvertTo-Json -Depth 5)
}

function Require-Name {
    $name = Get-Name
    if (-not $name) {
        @{
            ok = $false
            code = "no_name"
            message = "请先填写你的名字或称号，再提交线索。"
            data = @{}
        } | ConvertTo-Json -Depth 5
        exit 2
    }
    return $name
}

switch ($Command) {
    "whoami" {
        if ($Set) { Set-Name $Set } else { Get-Name }
    }
    "submit" {
        $name = Require-Name
        $payload = @{ advertiser = $name; channel = "skill"; raw_text = $Text }
        if ($Fields) { $payload["fields"] = ($Fields | ConvertFrom-Json) }
        if ($ClientId) { $payload["client_msg_id"] = $ClientId }
        if ($Ts) { $payload["ts"] = $Ts }
        Post-Json "/skill/v1/submit_lead" $payload
    }
    "update" {
        $name = Require-Name
        if (-not $CandidateId) { throw "update 需要 -CandidateId" }
        if (-not $Fields) { throw "update 需要 -Fields" }
        $payload = @{
            advertiser = $name
            candidate_id = $CandidateId
            fields = ($Fields | ConvertFrom-Json)
        }
        if ($Text) { $payload["raw_text"] = $Text }
        Post-Json "/skill/v1/update_lead" $payload
    }
}
