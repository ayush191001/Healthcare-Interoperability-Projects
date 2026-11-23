Class HOSPITAL.NewProduction.AD08 Extends Ens.BusinessProcessBPL [ ClassType = persistent, ProcedureBlock ]
{

/// Parse ADT A08 and build a partial FHIR Patient payload.
/// Only demographics present in PID are included; the operation preserves other Patient fields.
ClassMethod ParseA08Message(
    message As EnsLib.HL7.Message,
    Output updateRequest As HOSPITAL.NewProduction.FHIRPatientUpdateRequest
) As %Status
{
    Set tSC = $$$OK
    Set hl7Text = message.OutputToString("", "", .tSC, "")
    Quit:$$$ISERR(tSC) tSC

    Set hl7Text = $REPLACE(hl7Text, $CHAR(13,10), $CHAR(13))
    Set msh = ""
    Set pid = ""

    For i = 1:1:$LENGTH(hl7Text, $CHAR(13)) {
        Set segment = $PIECE(hl7Text, $CHAR(13), i)
        Set segmentName = $PIECE(segment, "|", 1)
        If segmentName = "MSH" Set msh = segment
        If segmentName = "PID" Set pid = segment
    }

    If msh = "" {
        Quit $$$ERROR($$$GeneralError, "MSH segment is missing")
    }
    If pid = "" {
        Quit $$$ERROR($$$GeneralError, "PID segment is missing")
    }

    Set messageType = $PIECE(msh, "|", 9)
    Set messageControlID = $PIECE(msh, "|", 10)
    If ($PIECE(messageType, "^", 1) '= "ADT") || ($PIECE(messageType, "^", 2) '= "A08") {
        Quit $$$ERROR($$$GeneralError, "Expected ADT A08 message")
    }
    If messageControlID = "" {
        Quit $$$ERROR($$$GeneralError, "MSH-10 Message Control ID is missing")
    }

    // PID-3.1 is the MRN; do not send the complete HL7 assigning-authority composite.
    Set patientIdentifier = $PIECE($PIECE(pid, "|", 4), "^", 1)
    If patientIdentifier = "" {
        Quit $$$ERROR($$$GeneralError, "PID-3 Patient MRN is missing")
    }

    // PID-5, PID-7 and PID-8 are optional in this update.
    Set patientName = $PIECE(pid, "|", 6)
    Set dob = $PIECE(pid, "|", 8)
    Set gender = $PIECE(pid, "|", 9)

    If (patientName = "") && (dob = "") && (gender = "") {
        Quit $$$ERROR($$$GeneralError, "A08 contains no supported demographic fields to update")
    }

    If dob '= "" {
        If ($LENGTH(dob) '= 8) || ($TRANSLATE(dob, "0123456789", "") '= "") {
            Quit $$$ERROR($$$GeneralError, "PID-7 Date of Birth must use YYYYMMDD")
        }
        Set month = $EXTRACT(dob,5,6)
        Set day = $EXTRACT(dob,7,8)
        If (month < 1) || (month > 12) || (day < 1) || (day > 31) {
            Quit $$$ERROR($$$GeneralError, "PID-7 Date of Birth contains an invalid month or day")
        }
    }

    If gender '= "" {
        If (gender '= "M") && (gender '= "F") && (gender '= "O") && (gender '= "U") {
            Quit $$$ERROR($$$GeneralError, "PID-8 Administrative Sex must be M, F, O or U")
        }
    }

    Set patient = ##class(%DynamicObject).%New()
    Set patient.resourceType = "Patient"

    Set identifier = ##class(%DynamicObject).%New()
    Set identifier.system = "https://hospital.example/mrn"
    Set identifier.value = patientIdentifier
    Set identifiers = ##class(%DynamicArray).%New()
    Do identifiers.%Push(identifier)
    Set patient.identifier = identifiers

    If patientName '= "" {
        Set name = ##class(%DynamicObject).%New()
        Set given = ##class(%DynamicArray).%New()
        Set familyName = $PIECE(patientName, "^", 1)
        Set givenName = $PIECE(patientName, "^", 2)
        If familyName '= "" Set name.family = familyName
        If givenName '= "" Do given.%Push(givenName)
        If given.%Size() > 0 Set name.given = given
        Set names = ##class(%DynamicArray).%New()
        Do names.%Push(name)
        Set patient.name = names
    }

    If dob '= "" {
        Set patient.birthDate = $EXTRACT(dob,1,4)_"-"_$EXTRACT(dob,5,6)_"-"_$EXTRACT(dob,7,8)
    }

    If gender = "M" Set patient.gender = "male"
    If gender = "F" Set patient.gender = "female"
    If gender = "O" Set patient.gender = "other"
    If gender = "U" Set patient.gender = "unknown"

    Set updateRequest = ##class(HOSPITAL.NewProduction.FHIRPatientUpdateRequest).%New()
    Set updateRequest.PatientIdentifier = patientIdentifier
    Set updateRequest.MessageControlID = messageControlID
    Set updateRequest.PatientJSON = patient.%ToJSON()

    Quit $$$OK
}

XData BPL [ XMLNamespace = "http://www.intersystems.com/bpl" ]
{
<process language='objectscript'
         request='EnsLib.HL7.Message'
         response='Ens.Response'
         height='1000'
         width='1600'>
    <context>
        <property name="PatientIdentifier" type="%String"/>
        <property name="MessageControlID" type="%String"/>
        <property name="FHIRStatusCode" type="%Integer"/>
        <property name="FHIRStatusLine" type="%String"/>
        <property name="PatientJSON" type="%String">
            <parameters>
                <parameter name="MAXLEN" value="32000"/>
            </parameters>
        </property>
        <property name="FHIRResourceLocation" type="%String">
            <parameters>
                <parameter name="MAXLEN" value="2048"/>
            </parameters>
        </property>
    </context>

    <sequence xend='300' yend='300'>
        <code name="ParseAndValidateA08">
            <![CDATA[
                SET tSC = ##class(HOSPITAL.NewProduction.AD08).ParseA08Message(
                    request,
                    .updateRequest
                )
                IF $$$ISERR(tSC) {
                    SET status = tSC
                    QUIT
                }
                SET context.PatientIdentifier = updateRequest.PatientIdentifier
                SET context.MessageControlID = updateRequest.MessageControlID
                SET context.PatientJSON = updateRequest.PatientJSON
            ]]>
        </code>

        <trace value='"ADT A08 validated; Patient MRN="_context.PatientIdentifier'/>

        <call name="UpdateFHIRPatient" target="FHIRPatientOperation" async="0">
            <request type="HOSPITAL.NewProduction.FHIRPatientUpdateRequest">
                <assign property="callrequest.PatientJSON" value="context.PatientJSON"/>
            </request>
            <response type="HOSPITAL.NewProduction.FHIRPatientResponse">
                <assign property="context.FHIRStatusCode" value="callresponse.FHIRStatusCode"/>
                <assign property="context.FHIRStatusLine" value="callresponse.FHIRStatusLine"/>
                <assign property="context.FHIRResourceLocation" value="callresponse.ResourceLocation"/>
            </response>
        </call>

        <trace value='"A08 FHIR Patient update completed; HTTP "_context.FHIRStatusCode_" "_context.FHIRStatusLine_" Location="_context.FHIRResourceLocation'/>
    </sequence>
</process>
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
