param(
    [string]$Path,
    [string]$HostName = "127.0.0.1",
    [int]$Port = 2575,
    [int]$RepeatCount = 1,
    [int]$DelaySeconds = 1,
    [switch]$Continuous,
    [switch]$NoAck,
    [int]$TimeoutSeconds = 10
)
$ErrorActionPreference = "Stop"

function Read-HL7File {
    param([string]$FilePath)
    $content = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $FilePath))
    $cr = [string][char]13
    $content = $content -replace "\r\n|\n|\r", $cr
    $content = $content.TrimEnd([char]13)
    if ([string]::IsNullOrWhiteSpace($content)) { throw "The HL7 file is empty: $FilePath" }
    if (-not $content.StartsWith("MSH|")) { throw "The file does not start with an MSH segment: $FilePath" }
    return $content + $cr
}

function Send-HL7Mllp {
    param([string]$Message,[string]$Destination,[int]$DestinationPort,[bool]$WaitForAck,[int]$Timeout)
    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $connectTask = $client.ConnectAsync($Destination, $DestinationPort)
        if (-not $connectTask.Wait($Timeout * 1000)) {
            throw ("Connection timed out connecting to " + $Destination + ":" + $DestinationPort)
        }
        $connectTask.GetAwaiter().GetResult()
        $stream = $client.GetStream()
        $stream.ReadTimeout = $Timeout * 1000
        $stream.WriteTimeout = $Timeout * 1000

        # MLLP frame: VT + HL7 payload + FS + CR.
        $payload = [System.Text.Encoding]::UTF8.GetBytes($Message)
        $frame = [byte[]]::new($payload.Length + 3)
        $frame[0] = 0x0B
        [Array]::Copy($payload, 0, $frame, 1, $payload.Length)
        $frame[$frame.Length - 2] = 0x1C
        $frame[$frame.Length - 1] = 0x0D
        $stream.Write($frame, 0, $frame.Length)
        $stream.Flush()

        if (-not $WaitForAck) {
            Write-Host "Sent successfully (ACK not requested)." -ForegroundColor Green
            return
        }

        $ackBytes = [System.Collections.Generic.List[byte]]::new()
        $seenStart = $false
        $seenFS = $false
        $deadline = [DateTime]::UtcNow.AddSeconds($Timeout)
        while ([DateTime]::UtcNow -lt $deadline) {
            if (-not $stream.DataAvailable) {
                Start-Sleep -Milliseconds 50
                continue
            }
            $value = $stream.ReadByte()
            if ($value -lt 0) { break }
            if (-not $seenStart) {
                if ($value -eq 0x0B) { $seenStart = $true }
                continue
            }
            $ackBytes.Add([byte]$value)
            if ($seenFS -and $value -eq 0x0D) { break }
            $seenFS = ($value -eq 0x1C)
        }
        if ($ackBytes.Count -eq 0 -or -not $seenFS) {
            throw ("No complete MLLP ACK received within " + $Timeout + " seconds. Check the IRIS service ACK mode.")
        }
        $ackText = [System.Text.Encoding]::UTF8.GetString($ackBytes.ToArray()).TrimEnd([char]13)
        $ackText = $ackText -replace ([char]28), ""
        Write-Host "ACK received:" -ForegroundColor Cyan
        Write-Host $ackText
        if ($ackText -match "(?m)^MSA\|([AR]E|CR|CE)\|") {
            Write-Warning "The receiver returned a negative/error ACK. Review MSA-1 and MSA-3."
        }
    }
    finally { $client.Dispose() }
}

if ([string]::IsNullOrWhiteSpace($Path)) {
    Write-Host ""
    Write-Host "=== IHIP HL7 MLLP Test Sender ===" -ForegroundColor Cyan
    $Path = Read-Host "Enter path to an .hl7 file or folder containing .hl7 files"
    if ([string]::IsNullOrWhiteSpace($Path)) { throw "A file or folder path is required." }
    $inputMode = Read-Host "Send mode: 1 = once, 2 = repeat, 3 = continuous (Ctrl+C to stop)"
    switch ($inputMode) {
        "1" { $RepeatCount = 1; $Continuous = $false }
        "2" {
            $countText = Read-Host "How many times?"
            $RepeatCount = [Math]::Max(1, [int]$countText)
            $Continuous = $false
        }
        "3" { $Continuous = $true }
        default { throw "Invalid send mode." }
    }
    $hostInput = Read-Host ("IRIS host (Enter for " + $HostName + ")")
    if (-not [string]::IsNullOrWhiteSpace($hostInput)) { $HostName = $hostInput }
    $portInput = Read-Host ("IRIS port (Enter for " + $Port + ")")
    if (-not [string]::IsNullOrWhiteSpace($portInput)) { $Port = [int]$portInput }
}
if (Test-Path -LiteralPath $Path -PathType Container) {
    $files = @(Get-ChildItem -LiteralPath $Path -Filter "*.hl7" -File | Sort-Object Name)
} else {
    $files = @(Get-Item -LiteralPath $Path)
}
if ($files.Count -eq 0) { throw ("No .hl7 files found at: " + $Path) }

Write-Host ""
Write-Host ("Target: " + $HostName + ":" + $Port + " | Files: " + $files.Count + " | MLLP") -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop continuous sending." -ForegroundColor Yellow
$sent = 0
$iteration = 0
do {
    $iteration++
    foreach ($file in $files) {
        $sent++
        Write-Host ""
        Write-Host ("[" + $sent + "] Sending " + $file.Name + " ...") -ForegroundColor Yellow
        try {
            $message = Read-HL7File -FilePath $file.FullName
            Send-HL7Mllp -Message $message -Destination $HostName -DestinationPort $Port -WaitForAck (-not $NoAck) -Timeout $TimeoutSeconds
        } catch {
            Write-Host ("FAILED: " + $_.Exception.Message) -ForegroundColor Red
        }
        if ($Continuous -or $iteration -lt $RepeatCount -or $file.FullName -ne $files[-1].FullName) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }
} while ($Continuous -or $iteration -lt $RepeatCount)
Write-Host ""
Write-Host ("Finished. Messages attempted: " + $sent) -ForegroundColor Green
