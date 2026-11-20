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
        ..URL
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

XData MessageMap
{
<MapItems>
        <MapItem MessageType="HOSPITAL.NewProduction.FHIREncounterRequest">
            <Method>SendEncounter</Method>
        </MapItem>
    </MapItems>
}

}
