param (
    [Parameter(Mandatory)]
    [string] $IPAddress
)

$IPs = $IPAddress -split ',' | 
    ForEach-Object -Process {
        $_.Trim()
    }

foreach ($ip in $IPs) {
    "`t$ip`tAPPLICATION_SERVER_VIP" |
        Out-File -FilePath C:\Windows\System32\drivers\etc\hosts -Append -Encoding utf8
}
