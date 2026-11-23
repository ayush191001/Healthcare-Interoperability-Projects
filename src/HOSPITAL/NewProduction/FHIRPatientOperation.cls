/// 
Class HOSPITAL.NewProduction.FHIRPatientOperation Extends Ens.BusinessOperation
{

Parameter ADAPTER = "EnsLib.HTTP.OutboundAdapter";

Method SendPatient(pRequest As HOSPITAL.NewProduction.FHIRPatientRequest, Output pResponse As HOSPITAL.NewProduction.FHIRPatientResponse) As %Status
{
    Set pResponse = ##class(HOSPITAL.NewProduction.FHIRPatientResponse).%New()
    Set tSC = $$$OK

    Try {
        Set tPatient = ##class(%DynamicObject).%FromJSON(pRequest.PatientJSON)
    } Catch ex {
        Set tSC = $$$ERROR($$$GeneralError, "Invalid FHIR Patient JSON")
    }
    Quit:$$$ISERR(tSC) tSC

    If '$IsObject(tPatient) || (tPatient.%Get("resourceType") '= "Patient") {
        Quit $$$ERROR($$$GeneralError, "Request must contain a FHIR Patient resource")
    }
    If '$IsObject(tPatient.%Get("identifier")) || (tPatient.identifier.%Size() = 0) {
        Quit $$$ERROR($$$GeneralError, "FHIR Patient has no identifier")
    }

    Set tIdentifier = tPatient.identifier.%Get(0)
    If '$IsObject(tIdentifier) {
        Quit $$$ERROR($$$GeneralError, "FHIR Patient identifier is missing")
    }
    Set tSystem = tIdentifier.%Get("system")
    Set tValue = tIdentifier.%Get("value")
    If (tSystem = "") || (tValue = "") {
        Quit $$$ERROR($$$GeneralError, "Patient identifier system and value are required")
    }

    Set tConditionalSearch = "identifier="_tSystem_"|"_tValue
    Set tHttpRequest = ##class(%Net.HttpRequest).%New()
    Set tBody = ##class(%GlobalBinaryStream).%New()
    Do tBody.Write(pRequest.PatientJSON)
    Do tBody.Rewind()
    Set tHttpRequest.EntityBody = tBody
    Set tHttpRequest.ContentType = "application/fhir+json"

    Set tSC = tHttpRequest.SetHeader("Accept", "application/fhir+json")
    Quit:$$$ISERR(tSC) tSC
    Set tSC = tHttpRequest.SetHeader("If-None-Exist", tConditionalSearch)
    Quit:$$$ISERR(tSC) tSC

    Set tData = ""
    Set tSC = ..Adapter.SendFormDataArray(.tHttpResponse, "POST", tHttpRequest, "", .tData, ..Adapter.URL)
    Quit:$$$ISERR(tSC) tSC
    If '$IsObject(tHttpResponse) {
        Quit $$$ERROR($$$GeneralError, "FHIR Patient create returned no HTTP response")
    }

    Set pResponse.FHIRStatusCode = tHttpResponse.StatusCode
    Set pResponse.FHIRStatusLine = tHttpResponse.StatusLine
    Set pResponse.ResourceLocation = tHttpResponse.GetHeader("Location")
    Set pResponse.FHIRResponseBody = ""
    If $IsObject(tHttpResponse.Data) {
        Do tHttpResponse.Data.Rewind()
        Set pResponse.FHIRResponseBody = tHttpResponse.Data.Read(32000)
    }

    If (pResponse.FHIRStatusCode < 200) || (pResponse.FHIRStatusCode > 299) {
        Quit $$$ERROR($$$GeneralError, "FHIR Patient POST failed: HTTP "_pResponse.FHIRStatusCode_" "_pResponse.FHIRStatusLine_" "_$EXTRACT(pResponse.FHIRResponseBody,1,1000))
    }
    Quit $$$OK
}

/// Update an existing Patient using the MRN; only fields present in PatientJSON are changed.
Method UpdatePatient(pRequest As HOSPITAL.NewProduction.FHIRPatientUpdateRequest, Output pResponse As HOSPITAL.NewProduction.FHIRPatientResponse) As %Status
{
    Set pResponse = ##class(HOSPITAL.NewProduction.FHIRPatientResponse).%New()
    Set tSC = $$$OK

    Try {
        Set tUpdate = ##class(%DynamicObject).%FromJSON(pRequest.PatientJSON)
    } Catch ex {
        Set tSC = $$$ERROR($$$GeneralError, "Invalid A08 Patient update JSON")
    }
    Quit:$$$ISERR(tSC) tSC

    If '$IsObject(tUpdate) || (tUpdate.%Get("resourceType") '= "Patient") {
        Quit $$$ERROR($$$GeneralError, "A08 update payload must be a FHIR Patient resource")
    }
    If '$IsObject(tUpdate.%Get("identifier")) || (tUpdate.identifier.%Size() '= 1) {
        Quit $$$ERROR($$$GeneralError, "A08 update must contain exactly one MRN identifier")
    }

    Set tIdentifier = tUpdate.identifier.%Get(0)
    If '$IsObject(tIdentifier) {
        Quit $$$ERROR($$$GeneralError, "A08 MRN identifier is missing")
    }
    Set tSystem = tIdentifier.%Get("system")
    Set tValue = tIdentifier.%Get("value")
    If (tSystem '= "https://hospital.example/mrn") || (tValue = "") {
        Quit $$$ERROR($$$GeneralError, "A08 requires the configured hospital MRN system and a non-empty MRN")
    }

    // Search directly over HTTPS; this is the same request pattern verified from IRIS.
    Set tSearchRequest = ##class(%Net.HttpRequest).%New()
    Set tSearchRequest.Server = ..Adapter.HTTPServer
    Set tSearchRequest.Port = ..Adapter.HTTPPort
    Set tSearchRequest.Https = 1
    Set tSearchRequest.SSLConfiguration = ..Adapter.SSLConfig
    Set tSC = tSearchRequest.SetHeader("Accept", "application/fhir+json")
    Quit:$$$ISERR(tSC) tSC

    Set tSearchURL = ..Adapter.URL_"?identifier="_tSystem_"|"_tValue_"&_count=2"
    Set tSC = tSearchRequest.Get(tSearchURL)
    Quit:$$$ISERR(tSC) tSC
    Set tSearchResponse = tSearchRequest.HttpResponse
    If '$IsObject(tSearchResponse) {
        Quit $$$ERROR($$$GeneralError, "FHIR Patient search returned no HTTP response")
    }

    Set pResponse.FHIRStatusCode = tSearchResponse.StatusCode
    Set pResponse.FHIRStatusLine = tSearchResponse.StatusLine
    Set pResponse.ResourceLocation = ""
    Set pResponse.FHIRResponseBody = ""
    If $IsObject(tSearchResponse.Data) {
        Do tSearchResponse.Data.Rewind()
        Set pResponse.FHIRResponseBody = tSearchResponse.Data.Read(32000)
    }
    If (pResponse.FHIRStatusCode < 200) || (pResponse.FHIRStatusCode > 299) {
        Quit $$$ERROR($$$GeneralError, "FHIR Patient search failed: HTTP "_pResponse.FHIRStatusCode_" "_pResponse.FHIRStatusLine_" "_$EXTRACT(pResponse.FHIRResponseBody,1,1000))
    }

    Set tSC = $$$OK
    Try {
        Set tBundle = ##class(%DynamicObject).%FromJSON(pResponse.FHIRResponseBody)
    } Catch ex {
        Set tSC = $$$ERROR($$$GeneralError, "FHIR Patient search returned invalid JSON")
    }
    Quit:$$$ISERR(tSC) tSC
    If '$IsObject(tBundle) || (tBundle.%Get("resourceType") '= "Bundle") {
        Quit $$$ERROR($$$GeneralError, "FHIR Patient search did not return a Bundle")
    }

    Set tEntryCount = 0
    If $IsObject(tBundle.%Get("entry")) {
        Set tEntryCount = tBundle.entry.%Size()
    }
    Set tTotal = tBundle.%Get("total", tEntryCount)
    If (tTotal > 1) || (tEntryCount > 1) {
        Quit $$$ERROR($$$GeneralError, "Multiple FHIR Patients match this MRN; no update was made")
    }
    If (tTotal = 0) || (tEntryCount = 0) {
        Quit $$$ERROR($$$GeneralError, "No FHIR Patient matches this MRN; no Patient was created")
    }

    Set tEntry = tBundle.entry.%Get(0)
    If '$IsObject(tEntry) || '$IsObject(tEntry.%Get("resource")) {
        Quit $$$ERROR($$$GeneralError, "FHIR Patient search result has no resource")
    }
    Set tPatient = tEntry.resource
    If (tPatient.%Get("resourceType") '= "Patient") || (tPatient.%Get("id") = "") {
        Quit $$$ERROR($$$GeneralError, "FHIR search result is not a valid Patient resource")
    }

    // Confirm the returned resource carries the exact MRN before modifying it.
    Set tMRNFound = 0
    If $IsObject(tPatient.%Get("identifier")) {
        For i = 0:1:tPatient.identifier.%Size()-1 {
            Set tExistingIdentifier = tPatient.identifier.%Get(i)
            If $IsObject(tExistingIdentifier) {
                If (tExistingIdentifier.%Get("system") = tSystem) && (tExistingIdentifier.%Get("value") = tValue) {
                    Set tMRNFound = 1
                }
            }
        }
    }
    If 'tMRNFound {
        Quit $$$ERROR($$$GeneralError, "FHIR Patient returned by search does not contain the exact MRN")
    }

    // Merge only fields supplied by A08; retain all other Patient data.
    Set tChanged = 0
    If $IsObject(tUpdate.%Get("name")) {
        If (tUpdate.name.%Size() > 0) {
            Set tPatient.name = tUpdate.name
            Set tChanged = 1
        }
    }
    If tUpdate.%Get("birthDate") '= "" {
        Set tPatient.birthDate = tUpdate.birthDate
        Set tChanged = 1
    }
    If tUpdate.%Get("gender") '= "" {
        Set tPatient.gender = tUpdate.gender
        Set tChanged = 1
    }
    If 'tChanged {
        Quit $$$ERROR($$$GeneralError, "A08 contains no supported demographic fields to update")
    }

    // PUT to the existing logical Patient endpoint; preserve the existing FHIR id.
    Set tPatientURL = ..Adapter.URL
    If $EXTRACT(tPatientURL,*) = "/" {
        Set tPatientURL = $EXTRACT(tPatientURL,1,$LENGTH(tPatientURL)-1)
    }
    Set tPatientURL = tPatientURL_"/"_tPatient.%Get("id")

    Set tPutRequest = ##class(%Net.HttpRequest).%New()
    Set tBody = ##class(%GlobalBinaryStream).%New()
    Do tBody.Write(tPatient.%ToJSON())
    Do tBody.Rewind()
    Set tPutRequest.EntityBody = tBody
    Set tPutRequest.ContentType = "application/fhir+json"
    Set tSC = tPutRequest.SetHeader("Accept", "application/fhir+json")
    Quit:$$$ISERR(tSC) tSC

    Set tMeta = tPatient.%Get("meta")
    If $IsObject(tMeta) {
        Set tVersion = tMeta.%Get("versionId")
        If tVersion '= "" {
            Set tSC = tPutRequest.SetHeader("If-Match", "W/"""_tVersion_"""")
            Quit:$$$ISERR(tSC) tSC
        }
    }

    Set tData = ""
    Set tSC = ..Adapter.SendFormDataArray(.tPutResponse, "PUT", tPutRequest, "", .tData, tPatientURL)
    Quit:$$$ISERR(tSC) tSC
    If '$IsObject(tPutResponse) {
        Quit $$$ERROR($$$GeneralError, "FHIR Patient update returned no HTTP response")
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
        Quit $$$ERROR($$$GeneralError, "FHIR Patient PUT failed: HTTP "_pResponse.FHIRStatusCode_" "_pResponse.FHIRStatusLine_" "_$EXTRACT(pResponse.FHIRResponseBody,1,1000))
    }

    Quit $$$OK
}

XData MessageMap
{
<MapItems>
    <MapItem MessageType="HOSPITAL.NewProduction.FHIRPatientRequest">
        <Method>SendPatient</Method>
    </MapItem>
    <MapItem MessageType="HOSPITAL.NewProduction.FHIRPatientUpdateRequest">
        <Method>UpdatePatient</Method>
    </MapItem>
</MapItems>
}

}
