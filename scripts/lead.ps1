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

function Post-Json([string]$Path, [hashtable]$Payload) {
    $json = $Payload | ConvertTo-Json -Depth 10 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    try {
        $resp = Invoke-WebRequest -Uri ($Api + $Path) -Method Post `
            -ContentType "application/json; charset=utf-8" -Body $bytes -UseBasicParsing
        if ($resp.RawContentStream) {
            return [System.Text.Encoding]::UTF8.GetString($resp.RawContentStream.ToArray())
        }
        return [string]$resp.Content
    } catch {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
            return $reader.ReadToEnd()
        }
        return (@{
            ok = $false
            code = "network_error"
            message = $_.Exception.Message
            data = @{}
        } | ConvertTo-Json -Depth 5)
    }
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
