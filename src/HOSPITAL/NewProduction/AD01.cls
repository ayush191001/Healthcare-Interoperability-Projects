/// 
Class HOSPITAL.NewProduction.AD01 Extends Ens.BusinessProcessBPL [ ClassType = persistent, ProcedureBlock ]
{

ClassMethod ValidateA01Message(message As EnsLib.HL7.Message, Output patientJSON As %String) As %Status
{
    ; Convert the parsed HL7 message object to text
    SET tSC = $$$OK
    SET hl7Text = message.OutputToString("", "", .tSC, "")

    QUIT:$$$ISERR(tSC) tSC

    ; Reuse the existing validation and FHIR mapping
    SET tSC = ..ValidateA01(hl7Text, .patientResource)

    QUIT:$$$ISERR(tSC) tSC

    ; Convert the FHIR Patient object to JSON
    SET patientJSON = patientResource.%ToJSON()

    QUIT $$$OK
}

ClassMethod ValidateA01(hl7 As %String, Output patientResource As %DynamicObject) As %Status
{
  
    SET msh = $PIECE(hl7,$CHAR(13),1)
    SET pid = $PIECE(hl7,$CHAR(13),3)
    SET pv1 = $PIECE(hl7,$CHAR(13),4)
    
    ; -----------------------------
    ; MSH validation
    ; -----------------------------
    
    SET messageType = $PIECE(msh,"|",9)
    SET messageControlID = $PIECE(msh,"|",10)
    
    IF messageType="" {
        WRITE !,"ERROR: Message Type is missing"
        QUIT $$$ERROR($$$GeneralError,"Message Type is missing")
    }
    
    IF messageControlID="" {
        WRITE !,"ERROR: Message Control ID is missing"
        QUIT $$$ERROR($$$GeneralError,"Message Control ID is missing")
    }
    
    ; -----------------------------
    ; PID validation
    ; -----------------------------
    
    SET patientID = $PIECE(pid,"|",4)
    SET patientName = $PIECE(pid,"|",6)
    SET dob = $PIECE(pid,"|",8)
    SET gender = $PIECE(pid,"|",9)
    
    IF patientID="" {
        WRITE !,"ERROR: Patient ID is missing"
        QUIT $$$ERROR($$$GeneralError,"Patient ID is missing")
    }
    
    IF patientName="" {
        WRITE !,"ERROR: Patient Name is missing"
        QUIT $$$ERROR($$$GeneralError,"Patient Name is missing")
    }
    
    IF dob="" {
        WRITE !,"ERROR: Date of Birth is missing"
        QUIT $$$ERROR($$$GeneralError,"Date of Birth is missing")
    }
    
    IF gender="" {
        WRITE !,"ERROR: Gender is missing"
        QUIT $$$ERROR($$$GeneralError,"Gender is missing")
    }
    
    ; -----------------------------
    ; PV1 validation
    ; -----------------------------
    
    SET patientClass = $PIECE(pv1,"|",3)
    SET location = $PIECE(pv1,"|",4)
    SET attendingDoctor = $PIECE(pv1,"|",8)
    
    IF patientClass="" {
        WRITE !,"ERROR: Patient Class is missing"
        QUIT $$$ERROR($$$GeneralError,"Patient Class is missing")
    }
    
    IF location="" {
        WRITE !,"ERROR: Patient Location is missing"
        QUIT $$$ERROR($$$GeneralError,"Patient Location is missing")
    }
    
    IF attendingDoctor="" {
        WRITE !,"ERROR: Attending Doctor is missing"
        QUIT $$$ERROR($$$GeneralError,"Attending Doctor is missing")
    }
    
    WRITE !,"ADT A01 validation successful"
    
    WRITE !,"Patient ID: ",patientID
    WRITE !,"Patient Name: ",patientName
    WRITE !,"DOB: ",dob
    WRITE !,"Gender: ",gender
    WRITE !,"Patient Class: ",patientClass
    WRITE !,"Location: ",location
    WRITE !,"Attending Doctor: ",attendingDoctor
    
    Set patientResource = ..BuildPatient(pid)
    QUIT $$$OK
}

ClassMethod BuildPatient(pid As %String) As %DynamicObject
{

    SET patient = ##class(%DynamicObject).%New()
    Set patient.name = ##class(%DynamicArray).%New()
    SET patient.resourceType = "Patient"

    ; 1. Extract PID-3
    SET patientID = $PIECE(pid,"|",4)

    ; 2. Extract PID-5
    SET patientName = $PIECE(pid,"|",6)

    ; 3. Extract PID-7
    SET dob = $PIECE(pid,"|",8)

    ; 4. Extract PID-8
    SET gender = $PIECE(pid,"|",9)

    ; Build FHIR identifier
    SET identifier = ##class(%DynamicObject).%New()
    SET identifier.system = "https://hospital.example/mrn"
    SET identifier.value = patientID

    ; Build FHIR name
    SET name = ##class(%DynamicObject).%New()
    SET given = ##class(%DynamicArray).%New()

    

    Set givenName = $Piece(patientName,"^",2)
    Set familyName = $Piece(patientName,"^",1)

    SET name.family = familyName
    Do given.%Push(givenName)
    SET name.given = given

    ; YOU write the family/given extraction here

    SET patient.identifier = ##class(%DynamicArray).%New()
    DO patient.identifier.%Push(identifier)

    SET patient.name = ##class(%DynamicArray).%New()
    DO patient.name.%Push(name)

    SET year = $EXTRACT(dob,1,4)
    SET month = $EXTRACT(dob,5,6)
    SET day = $EXTRACT(dob,7,8)
    
    SET patient.birthDate = year_"-"_month_"-"_day      
    IF gender = "M" 
    {
        SET patient.gender = "male"
    }
    ELSEIF gender = "F" 
    {
        SET patient.gender = "female"
    }
    ELSEIF gender = "O" 
    {
        SET patient.gender = "other"
    }
    ELSE 
    {
    SET patient.gender = "unknown"
    }
    
    QUIT patient
}

/// BPL Definition
XData BPL [ XMLNamespace = "http://www.intersystems.com/bpl" ]
{
<process language='objectscript' request='EnsLib.HL7.Message' response='Ens.Response' height='2000' width='2000' >
     <context>
        <property name="FHIRPatientJSON" type="%String">
            <parameters>
                <parameter name="MAXLEN" value="32000"/>
            </parameters>
        </property>

        <property name="FHIRStatusCode" type="%Integer"/>

        <property name="FHIRResourceLocation" type="%String">
            <parameters>
                <parameter name="MAXLEN" value="2048"/>
            </parameters>
        </property>

        <property name="FHIRResponseBody" type="%String">
            <parameters>
                <parameter name="MAXLEN" value="32000"/>
            </parameters>
        </property>
    </context>
<sequence xend='300' yend='450'>
<code name='ValidateAndBuildFHIRPatient'>
 <![CDATA[
     SET tSC = ##class(HOSPITAL.NewProduction.AD01).ValidateA01Message(request, .patientJSON)
         IF $$$ISERR(tSC) {
             SET status = tSC
                 QUIT
             }
        SET context.FHIRPatientJSON = patientJSON
 ]]>
 </code>

    <trace value='"FHIR Patient JSON generated; length="_$LENGTH(context.FHIRPatientJSON)'/>
    <call name="PostFHIRPatient" target="FHIRPatientOperation" async="0">
    <request type="HOSPITAL.NewProduction.FHIRPatientRequest">
        <assign property="callrequest.PatientJSON" value="context.FHIRPatientJSON"/>
    </request>
    <response type="HOSPITAL.NewProduction.FHIRPatientResponse">
        <assign property="context.FHIRStatusCode"  value="callresponse.FHIRStatusCode"/>
        <assign property="context.FHIRResourceLocation"  value="callresponse.ResourceLocation"/>
        <assign property="context.FHIRResponseBody"   value="callresponse.FHIRResponseBody"/>
    </response>
</call>

<trace value='"FHIR POST returned HTTP "_context.FHIRStatusCode'/>
</sequence>
</process>
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
