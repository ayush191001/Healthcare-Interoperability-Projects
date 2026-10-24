/// 
Class HOSPITAL.NewProduction.FHIREncounterOperation Extends Ens.BusinessOperation
{

Parameter ADAPTER = "EnsLib.HTTP.OutboundAdapter";

/// <b>NOTE:</b> This is an example operation method.
/// You should replace it and its entry in the MessageMap with your custom operation methods.
/// See <a href="https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=EGDV_busop#EGDV_busop_message_handlers">the documentation</a>
/// for tips on how to implement operation methods.
Method SendEncounter(pRequest As HOSPITAL.NewProduction.FHIREncounterRequest, Output pResponse As HOSPITAL.NewProduction.FHIREncounterResponse) As %Status
{
    Set pResponse = ##class(HOSPITAL.NewProduction.FHIREncounterResponse).%New()

    // Parse the FHIR Patient JSON
   Set tSC = $$$OK

    Try 
    {
        Set tPatient = ##class(%DynamicObject).%FromJSON(pRequest.EncounterJSON)
    }
    Catch ex 
    {
        Set tSC = $$$ERROR($$$GeneralError,"Invalid FHIR Patient JSON")
    }

    // Get the first business identifier
    If '$IsObject(tPatient.identifier) {
        Quit $$$ERROR( $$$GeneralError, "FHIR Patient has no identifier array" )
    }

    Set tIdentifier = tPatient.identifier.%Get(0)

    If '$IsObject(tIdentifier) {
        Quit $$$ERROR($$$GeneralError, "FHIR Patient identifier is missing")
    }

    Set tSystem = tIdentifier.system
    Set tValue = tIdentifier.value

    If tSystem="" {
        Quit $$$ERROR($$$GeneralError, "Patient identifier system is missing" )
    }

    If tValue="" {
        Quit $$$ERROR( $$$GeneralError,"Patient identifier value is missing")
    }

    // Build the FHIR conditional-create search criteria
    Set tConditionalSearch = "identifier="_tSystem_"|"_tValue

    // Construct an HTTP request with per-message headers
    Set tHttpRequest = ##class(%Net.HttpRequest).%New()

    Set tBody = ##class(%GlobalBinaryStream).%New()
    Do tBody.Write(pRequest.EncounterJSON)
    Do tBody.Rewind()

    Set tHttpRequest.EntityBody = tBody
    Set tHttpRequest.ContentType = "application/fhir+json"

    Set tSC = tHttpRequest.SetHeader(
        "Accept",
        "application/fhir+json"
    )
    Quit:$$$ISERR(tSC) tSC

    Set tSC = tHttpRequest.SetHeader(
        "If-None-Exist",
        tConditionalSearch
    )
    Quit:$$$ISERR(tSC) tSC

    // Send through the configured production HTTP adapter
    Set tData = ""

    Set tSC = ..Adapter.SendFormDataArray(.tHttpResponse, "POST", tHttpRequest, "", .tData)

    Quit:$$$ISERR(tSC) tSC

    If '$IsObject(tHttpResponse) {
        Quit $$$ERROR( $$$GeneralError,"HTTP request returned no response object")
    }

    Set pResponse.FHIRStatusCode = tHttpResponse.StatusCode
    Set pResponse.FHIRStatusLine = tHttpResponse.StatusLine
    Set pResponse.ResourceLocation = tHttpResponse.GetHeader("Location")
    Set pResponse.FHIRResponseBody = ""

    If $IsObject(tHttpResponse.Data) {
        Do tHttpResponse.Data.Rewind()
        Set pResponse.FHIRResponseBody = tHttpResponse.Data.Read(32000)
    }

    // 200 = existing matching resource; 201 = newly created resource
    If (pResponse.FHIRStatusCode < 200) || (pResponse.FHIRStatusCode > 299) {
        Quit $$$ERROR($$$GeneralError,"FHIR POST failed: HTTP "_ pResponse.FHIRStatusCode_" "_pResponse.FHIRStatusLine_" "_ $EXTRACT(pResponse.FHIRResponseBody,1,1000))
    }

    Quit $$$OK
}

XData MessageMap
{
<MapItems>
        <MapItem MessageType="HOSPITAL.NewProduction.FHIREncounterRequest">
            <Method>SendEncounter</Method>
        </MapItem>
    </MapItems>
}

}
