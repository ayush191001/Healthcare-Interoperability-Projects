Class HOSPITAL.NewProduction.AD03 Extends Ens.BusinessProcessBPL
{

ClassMethod ParseA03Message(
    message As EnsLib.HL7.Message,
    Output dischargeRequest As HOSPITAL.NewProduction.FHIRDischargeRequest
) As %Status
{
    Set tSC = $$$OK

    // Convert HL7 message object to raw HL7 text
    Set hl7Text = message.OutputToString("", "", .tSC, "")
    Quit:$$$ISERR(tSC) tSC

    // Normalize line endings
    Set hl7Text = $REPLACE(hl7Text, $CHAR(13,10), $CHAR(13))

    // Find the required segments
    Set msh = ""
    Set pid = ""
    Set pv1 = ""

    For i = 1:1:$LENGTH(hl7Text, $CHAR(13)) {
        Set segment = $PIECE(hl7Text, $CHAR(13), i)
        Set segmentName = $PIECE(segment, "|", 1)

        If segmentName = "MSH" {
            Set msh = segment
        }
        ElseIf segmentName = "PID" {
            Set pid = segment
        }
        ElseIf segmentName = "PV1" {
            Set pv1 = segment
        }
    }

    // Validate required segments
    If msh = "" {
        Quit $$$ERROR($$$GeneralError, "MSH segment is missing")
    }

    If pid = "" {
        Quit $$$ERROR($$$GeneralError, "PID segment is missing")
    }

    If pv1 = "" {
        Quit $$$ERROR($$$GeneralError, "PV1 segment is missing")
    }

    // Extract MSH fields
    Set messageType = $PIECE(msh, "|", 9)
    Set messageControlID = $PIECE(msh, "|", 10)

    If ($PIECE(messageType, "^", 1) '= "ADT") ||
       ($PIECE(messageType, "^", 2) '= "A03") {
        Quit $$$ERROR($$$GeneralError, "Expected ADT A03 message")
    }

    If messageControlID = "" {
        Quit $$$ERROR($$$GeneralError, "MSH-10 Message Control ID is missing")
    }

    // Extract PID-3 Patient Identifier
    Set patientIdentifier = $PIECE(pid, "|", 4)

    If patientIdentifier = "" {
        Quit $$$ERROR($$$GeneralError, "PID-3 Patient Identifier is missing")
    }

    // Extract PV1-19 Visit Number
    Set visitNumber = $PIECE(pv1, "|", 20)

    If visitNumber = "" {
        Quit $$$ERROR($$$GeneralError, "PV1-19 Visit Number is missing")
    }

    // Extract PV1-45 Discharge Date/Time
    Set dischargeDateTime = $PIECE(pv1, "|", 46)

    If dischargeDateTime = "" {
        Quit $$$ERROR($$$GeneralError, "PV1-45 Discharge Date/Time is missing")
    }

    If $LENGTH(dischargeDateTime) < 8 {
        Quit $$$ERROR($$$GeneralError, "Invalid PV1-45 Discharge Date/Time")
    }

    // Build discharge request
    Set dischargeRequest = ##class(HOSPITAL.NewProduction.FHIRDischargeRequest).%New()

    Set dischargeRequest.PatientIdentifier = patientIdentifier
    Set dischargeRequest.VisitNumber = visitNumber
    Set dischargeRequest.DischargeDateTime = dischargeDateTime
    Set dischargeRequest.MessageControlID = messageControlID

    Quit $$$OK
}


// BPL Definition
XData BPL [ XMLNamespace = "http://www.intersystems.com/bpl" ]
{
<process language='objectscript'
         request='EnsLib.HL7.Message'
         response='Ens.Response'
         height='1000'
         width='1600'>

    <context>

        <property name="PatientIdentifier" type="%String"/>

        <property name="VisitNumber" type="%String"/>

        <property name="DischargeDateTime" type="%String"/>

        <property name="MessageControlID" type="%String"/>

    </context>

    <sequence xend='300' yend='300'>

        <code name="ParseAndValidateA03">
            <![CDATA[
                SET tSC = ##class(HOSPITAL.NewProduction.AD03).ParseA03Message(
                    request,
                    .dischargeRequest
                )

                IF $$$ISERR(tSC) {
                    SET status = tSC
                    QUIT
                }

                SET context.PatientIdentifier = dischargeRequest.PatientIdentifier
                SET context.VisitNumber = dischargeRequest.VisitNumber
                SET context.DischargeDateTime = dischargeRequest.DischargeDateTime
                SET context.MessageControlID = dischargeRequest.MessageControlID
            ]]>
        </code>

        <trace value='"ADT A03 validated; ControlID="_context.MessageControlID'/>

        <trace value='"Patient Identifier="_context.PatientIdentifier'/>

        <trace value='"Visit Number="_context.VisitNumber'/>

        <trace value='"Discharge DateTime="_context.DischargeDateTime'/>

    </sequence>

</process>
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
