/// 
Class HOSPITAL.NewProduction.FHIREncounterOperation Extends Ens.BusinessOperation
{

Parameter ADAPTER = "EnsLib.HTTP.OutboundAdapter";

/// <b>NOTE:</b> This is an example operation method.
/// You should replace it and its entry in the MessageMap with your custom operation methods.
/// See <a href="https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=EGDV_busop#EGDV_busop_message_handlers">the documentation</a>
/// for tips on how to implement operation methods.
Method SendEncounter(pRequest As HOSPITAL.NewProduction.FHIREncounterRequest,Output pResponse As HOSPITAL.NewProduction.FHIREncounterResponse) As %Status
{
    Set pResponse = ##class(HOSPITAL.NewProduction.FHIREncounterResponse).%New()
    Set tSC = $$$OK

    // Parse and validate Encounter JSON
    Try {
        Set tEncounter = ##class(%DynamicObject).%FromJSON(pRequest.EncounterJSON)
    } Catch ex {
        Set tSC = $$$ERROR($$$GeneralError, "Invalid FHIR Encounter JSON")
    }

    Quit:$$$ISERR(tSC) tSC

    If '$IsObject(tEncounter) {
        Quit $$$ERROR($$$GeneralError, "FHIR Encounter JSON did not produce an object")
    }

    If tEncounter.resourceType '= "Encounter" {
        Quit $$$ERROR($$$GeneralError, "Resource type must be Encounter")
    }

    // Read the Encounter business identifier
    If '$IsObject(tEncounter.identifier) {
        Quit $$$ERROR($$$GeneralError, "FHIR Encounter has no identifier array")
    }

    Set tIdentifier = tEncounter.identifier.%Get(0)

    If '$IsObject(tIdentifier) {
        Quit $$$ERROR($$$GeneralError, "FHIR Encounter identifier is missing")
    }

    Set tSystem = tIdentifier.system
    Set tValue = tIdentifier.value

    If tSystem = "" {
        Quit $$$ERROR($$$GeneralError, "Encounter identifier system is missing")
    }

    If tValue = "" {
        Quit $$$ERROR($$$GeneralError, "Encounter identifier value is missing")
    }

    // Use conditional create to help prevent duplicate Encounters
    Set tConditionalSearch = "identifier="_tSystem_"|"_tValue

    // Prepare the HTTP request
    Set tHttpRequest = ##class(%Net.HttpRequest).%New()

    Set tBody = ##class(%GlobalBinaryStream).%New()
    Do tBody.Write(pRequest.EncounterJSON)
    Do tBody.Rewind()

    Set tHttpRequest.EntityBody = tBody
    Set tHttpRequest.ContentType = "application/fhir+json"

    Set tSC = tHttpRequest.SetHeader("Accept", "application/fhir+json")
    Quit:$$$ISERR(tSC) tSC

    Set tSC = tHttpRequest.SetHeader("If-None-Exist", tConditionalSearch)
    Quit:$$$ISERR(tSC) tSC

    // POST to the URL configured on FHIREncounterOperation
    Set tData = ""

    Set tSC = ..Adapter.SendFormDataArray(
        .tHttpResponse,
        "POST",
        tHttpRequest,
        "",
        .tData,
        ..Adapter.URL
    )

    Quit:$$$ISERR(tSC) tSC

    If '$IsObject(tHttpResponse) {
        Quit $$$ERROR($$$GeneralError, "HTTP request returned no response object")
    }

    // Capture the FHIR response
    Set pResponse.FHIRStatusCode = tHttpResponse.StatusCode
    Set pResponse.FHIRStatusLine = tHttpResponse.StatusLine
    Set pResponse.ResourceLocation = tHttpResponse.GetHeader("Location")
    Set pResponse.FHIRResponseBody = ""

    If $IsObject(tHttpResponse.Data) {
        Do tHttpResponse.Data.Rewind()
        Set pResponse.FHIRResponseBody = tHttpResponse.Data.Read(32000)
    }

    // Accept successful 2xx responses
    If (pResponse.FHIRStatusCode < 200) ||
       (pResponse.FHIRStatusCode > 299) {
        Quit $$$ERROR( $$$GeneralError,"FHIR Encounter POST failed: HTTP "_pResponse.FHIRStatusCode_" "_ pResponse.FHIRStatusLine_" "_$EXTRACT(pResponse.FHIRResponseBody, 1, 1000) )
    }

    Quit $$$OK
}


/// Update an existing FHIR Encounter when an ADT A03 discharge is received.
Method DischargeEncounter(pRequest As HOSPITAL.NewProduction.FHIRDischargeRequest, Output pResponse As HOSPITAL.NewProduction.FHIREncounterResponse) As %Status
{
    Set pResponse = ##class(HOSPITAL.NewProduction.FHIREncounterResponse).%New()

    If pRequest.PatientIdentifier = "" {
        Quit $$ERROR($$GeneralError, "A03 Patient Identifier is missing")
    }
    If pRequest.VisitNumber = "" {
        Quit $$ERROR($$GeneralError, "A03 Visit Number is missing")
    }
    If pRequest.DischargeDateTime = "" {
        Quit $$ERROR($$GeneralError, "A03 Discharge Date/Time is missing")
    }

    // Convert the HL7 TS value to a FHIR dateTime. An absent timezone means IST.
    Set tHL7Time = pRequest.DischargeDateTime
    Set tDigits = $TRANSLATE(tHL7Time, "+-.", "")
    If $LENGTH(tDigits) < 8 {
        Quit $$ERROR($$GeneralError, "A03 Discharge Date/Time is invalid")
    }
    Set tYear = $EXTRACT(tDigits,1,4)
    Set tMonth = $EXTRACT(tDigits,5,6)
    Set tDay = $EXTRACT(tDigits,7,8)
    Set tFHIRTime = tYear_"-"_tMonth_"-"_tDay

    If $LENGTH(tDigits) >= 10 {
        Set tHour = $EXTRACT(tDigits,9,10)
        Set tMinute = $EXTRACT(tDigits,11,12)
        If tHour = "" Set tHour = "00"
        If tMinute = "" Set tMinute = "00"
        Set tSecond = "00"
        If $LENGTH(tDigits) >= 14 Set tSecond = $EXTRACT(tDigits,13,14)
        Set tFHIRTime = tFHIRTime_"T"_tHour_":"_tMinute_":"_tSecond

        // Preserve an explicit HL7 timezone; otherwise use India Standard Time.
        Set tZone = ""
        If $LENGTH(tHL7Time) >= 5 {
            Set tTail = $EXTRACT(tHL7Time,*-4,*)
            If ($EXTRACT(tTail,1) = "+") || ($EXTRACT(tTail,1) = "-") {
                Set tZone = $EXTRACT(tTail,1,3)_":"_$EXTRACT(tTail,4,5)
            }
        }
        If tZone = "" Set tZone = "+05:30"
        Set tFHIRTime = tFHIRTime_tZone
    }

    // Search by both the hospital visit identifier and the Patient identifier.
    Set tHttpRequest = ##class(%Net.HttpRequest).%New()
    Set tSC = tHttpRequest.SetHeader("Accept", "application/fhir+json")
    Quit:$$ISERR(tSC) tSC

    Set tData(1) = "https://hospital.example/visit-number|"_pRequest.VisitNumber
    Set tData(2) = "https://hospital.example/mrn|"_pRequest.PatientIdentifier
    Set tData(3) = "2"

    Set tSC = ..Adapter.SendFormDataArray(
        .tHttpResponse,
        "GET",
        tHttpRequest,
        "identifier,patient.identifier,_count",
        .tData,
        ..Adapter.URL
    )
    Quit:$$ISERR(tSC) tSC

    If '$IsObject(tHttpResponse) {
        Quit $$ERROR($$GeneralError, "FHIR Encounter search returned no HTTP response")
    }

    Set pResponse.FHIRStatusCode = tHttpResponse.StatusCode
    Set pResponse.FHIRStatusLine = tHttpResponse.StatusLine
    Set pResponse.ResourceLocation = ""
    Set pResponse.FHIRResponseBody = ""
    If $IsObject(tHttpResponse.Data) {
        Do tHttpResponse.Data.Rewind()
        Set pResponse.FHIRResponseBody = tHttpResponse.Data.Read(32000)
    }

    If (pResponse.FHIRStatusCode < 200) || (pResponse.FHIRStatusCode > 299) {
        Quit $$ERROR($$GeneralError, "FHIR Encounter search failed: HTTP "_pResponse.FHIRStatusCode_" "_pResponse.FHIRStatusLine_" "_$EXTRACT(pResponse.FHIRResponseBody,1,1000))
    }

    Try {
        Set tBundle = ##class(%DynamicObject).%FromJSON(pResponse.FHIRResponseBody)
    } Catch ex {
        Quit $$ERROR($$GeneralError, "FHIR Encounter search returned invalid JSON")
    }

    If '$IsObject(tBundle) || (tBundle.resourceType '= "Bundle") {
        Quit $$ERROR($$GeneralError, "FHIR Encounter search did not return a Bundle")
    }

    If '$IsObject(tBundle.entry) {
        Quit $$ERROR($$GeneralError, "FHIR Encounter search Bundle has no entry array")
    }

    Set tEntryCount = tBundle.entry.%Size()
    Set tTotal = tBundle.%Get("total", tEntryCount)

    If (tTotal > 1) || (tEntryCount > 1) {
        Quit $$ERROR($$GeneralError, "Multiple FHIR Encounters match this Patient and Visit Number; no update was made")
    }
    If (tTotal = 0) || (tEntryCount = 0) {
        Quit $$ERROR($$GeneralError, "No existing FHIR Encounter matches this Patient and Visit Number; no Encounter was created")
    }

    Set tEntry = tBundle.entry.%Get(0)
    If '$IsObject(tEntry) || '$IsObject(tEntry.resource) {
        Quit $$ERROR($$GeneralError, "FHIR Encounter search result has no resource")
    }
    Set tEncounter = tEntry.resource

    // Verify that the returned Encounter contains the exact visit identifier.
    Set tIdentifierFound = 0
    If $IsObject(tEncounter.identifier) {
        For i = 0:1:tEncounter.identifier.%Size()-1 {
            Set tIdentifier = tEncounter.identifier.%Get(i)
            If $IsObject(tIdentifier) {
                If (tIdentifier.%Get("system") = "https://hospital.example/visit-number") &&
                   (tIdentifier.%Get("value") = pRequest.VisitNumber) {
                    Set tIdentifierFound = 1
                }
            }
        }
    }
    If 'tIdentifierFound {
        Quit $$ERROR($$GeneralError, "Returned Encounter does not contain the expected visit identifier")
    }

    Set tSubject = tEncounter.%Get("subject")
    If '$IsObject(tSubject) {
        Quit $$ERROR($$GeneralError, "Returned Encounter has no Patient subject reference")
    }
    Set tSubjectReference = tSubject.%Get("reference")
    If $EXTRACT(tSubjectReference,1,8) '= "Patient/" {
        Quit $$ERROR($$GeneralError, "Returned Encounter has an invalid Patient subject reference")
    }

    // A repeated A03 is accepted only when the stored discharge time is identical.
    If tEncounter.%Get("status") = "finished" {
        Set tPeriod = tEncounter.%Get("period")
        If $IsObject(tPeriod) && (tPeriod.%Get("end") = tFHIRTime) {
            Set pResponse.FHIRStatusCode = 200
            Set pResponse.FHIRStatusLine = "200 OK - discharge already applied"
            Set pResponse.FHIRResponseBody = tEncounter.%ToJSON()
            Quit $$OK
        }
        Quit $$ERROR($$GeneralError, "Encounter is already finished with different discharge details")
    }

    If tEncounter.%Get("status") '= "in-progress" {
        Quit $$ERROR($$GeneralError, "Only an in-progress Encounter can be discharged")
    }

    // Preserve all other Encounter content and update only status and period.end.
    Set tEncounter.status = "finished"
    Set tPeriod = tEncounter.%Get("period")
    If '$IsObject(tPeriod) {
        Set tPeriod = ##class(%DynamicObject).%New()
        Set tEncounter.period = tPeriod
    }
    Set tPeriod.end = tFHIRTime

    // PUT the updated resource to its logical FHIR endpoint.
    Set tID = tEncounter.%Get("id")
    If tID = "" {
        Quit $$ERROR($$GeneralError, "FHIR Encounter logical id is missing")
    }

    Set tURL = ..Adapter.URL
    If $EXTRACT(tURL,*) = "/" Set tURL = $EXTRACT(tURL,1,$LENGTH(tURL)-1)
    Set tURL = tURL_"/"_tID

    Set tPutRequest = ##class(%Net.HttpRequest).%New()
    Set tBody = ##class(%GlobalBinaryStream).%New()
    Do tBody.Write(tEncounter.%ToJSON())
    Do tBody.Rewind()
    Set tPutRequest.EntityBody = tBody
    Set tPutRequest.ContentType = "application/fhir+json"
    Set tSC = tPutRequest.SetHeader("Accept", "application/fhir+json")
    Quit:$$ISERR(tSC) tSC

    // Use optimistic concurrency when the server supplied a version id.
    Set tMeta = tEncounter.%Get("meta")
    If $IsObject(tMeta) {
        Set tVersion = tMeta.%Get("versionId")
        If tVersion '= "" {
            Set tSC = tPutRequest.SetHeader("If-Match", "W/"""_tVersion_"""")
            Quit:$$ISERR(tSC) tSC
        }
    }

    Set tData = ""
    Set tSC = ..Adapter.SendFormDataArray(
        .tPutResponse,
        "PUT",
        tPutRequest,
        "",
        .tData,
        tURL
    )
    Quit:$$ISERR(tSC) tSC

    If '$IsObject(tPutResponse) {
        Quit $$ERROR($$GeneralError, "FHIR Encounter update returned no HTTP response")
    }

    Set pResponse.FHIRStatusCode = tPutResponse.StatusCode
    Set pResponse.FHIRStatusLine = tPutResponse.StatusLine
    Set pResponse.ResourceLocation = tPutResponse.GetHeader("Location")
    Set pResponse.FHIRResponseBody = ""
    If $IsObject(tPutResponse.Data) {
        Do tPutResponse.Data.Rewind()
        Set pResponse.FHIRResponseBody = tPutResponse.Data.Read(32000)
    }

    If (pResponse.FHIRStatusCode < 200) || (pResponse.FHIRStatusCode > 299) {
        Quit $$ERROR($$GeneralError, "FHIR Encounter PUT failed: HTTP "_pResponse.FHIRStatusCode_" "_pResponse.FHIRStatusLine_" "_$EXTRACT(pResponse.FHIRResponseBody,1,1000))
    }

    Quit $$OK
}

XData MessageMap
{
<MapItems>
        <MapItem MessageType="HOSPITAL.NewProduction.FHIREncounterRequest">
            <Method>SendEncounter</Method>
        </MapItem>
        <MapItem MessageType="HOSPITAL.NewProduction.FHIRDischargeRequest">
            <Method>DischargeEncounter</Method>
        </MapItem>
    </MapItems>
}

}
