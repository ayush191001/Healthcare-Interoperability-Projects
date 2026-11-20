# IHIP HL7 Test Sender

Reusable PowerShell sender for testing the repository's InterSystems IRIS HL7 TCP service. It sends HL7 v2 files using MLLP framing and displays the returned HL7 ACK when ACKs are enabled on the IRIS service.

## Requirements
- Windows PowerShell 5.1 or PowerShell 7+
- Network access to the IRIS host and TCP port
- IRIS production running and HL7 TCP service enabled
- Synthetic HL7 test messages saved as .hl7 files

Default target is 127.0.0.1:2575. Change the host when IRIS is on another machine.

## Interactive use
From the repository root:

    .\tools\hl7-sender\Send-HL7.ps1

It prompts for a message file/folder, send mode, host and port.

## Command-line examples
Send one A03 message:

    .\tools\hl7-sender\Send-HL7.ps1 -Path .\test-messages\ADT_A03.hl7 -HostName localhost -Port 2575

Send every .hl7 file in a folder once:

    .\tools\hl7-sender\Send-HL7.ps1 -Path .\test-messages -HostName localhost -Port 2575

Send a file 10 times, with a 2-second delay:

    .\tools\hl7-sender\Send-HL7.ps1 -Path .\test-messages\ADT_A03.hl7 -RepeatCount 10 -DelaySeconds 2

Continuously send a file until Ctrl+C:

    .\tools\hl7-sender\Send-HL7.ps1 -Path .\test-messages\ADT_A03.hl7 -Continuous -DelaySeconds 5

If the IRIS service is configured not to return an HL7 ACK, use -NoAck.

## MLLP framing
The sender wraps each message as VT (0x0B) + HL7 payload with CR segment separators + FS (0x1C) + CR (0x0D).

It opens a TCP connection for each message, sends one complete MLLP frame, optionally reads the framed ACK, then closes the connection. This avoids depending on persistent-connection settings during initial development testing.

## Safety
- Use synthetic test data only. Do not commit real patient information or PHI.
- Continuous mode can create many messages and message-log entries. Use only against a development/test production, start with a small delay, and stop with Ctrl+C.
- A transport ACK does not prove downstream FHIR processing succeeded. Verify the IRIS message trace and FHIR server separately.
- The script uses UTF-8. Confirm the receiving service's configured character set before testing non-ASCII content.
