/// 
Class HOSPITAL.NewProduction.FHIRPatientOperation Extends Ens.BusinessOperation
{

Parameter ADAPTER = "EnsLib.HTTP.OutboundAdapter";

/// <b>NOTE:</b> This is an example operation method.
/// You should replace it and its entry in the MessageMap with your custom operation methods.
/// See <a href="https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=EGDV_busop#EGDV_busop_message_handlers">the documentation</a>
/// for tips on how to implement operation methods.
Method SendPatient( pRequest As HOSPITAL.NewProduction.FHIRPatientRequest,Output pResponse As HOSPITAL.NewProduction.FHIRPatientResponse ) As %Status
    {
        Set pResponse = ##class(HOSPITAL.NewProduction.FHIRPatientResponse).%New()

        Set tSC = ..Adapter.Post(.tHttpResponse, "", pRequest.PatientJSON)

        Quit:$$$ISERR(tSC) tSC

        If '$ISOBJECT(tHttpResponse) {
            Quit $$$ERROR($$$GeneralError, "HTTP request returned no response object")
        }

        Set pResponse.FHIRStatusCode = tHttpResponse.StatusCode
        Set pResponse.FHIRStatusLine = tHttpResponse.StatusLine
        Set pResponse.ResourceLocation = tHttpResponse.GetHeader("Location")
        Set pResponse.FHIRResponseBody = ""

        If $ISOBJECT(tHttpResponse.Data) {
            Do tHttpResponse.Data.Rewind()
            Set pResponse.FHIRResponseBody =
                tHttpResponse.Data.Read(32000)
        } Else {
            Set pResponse.FHIRResponseBody = tHttpResponse.Data
        }

        If (pResponse.FHIRStatusCode < 200) ||
           (pResponse.FHIRStatusCode > 299) {
            Quit $$$ERROR($$$GeneralError,"FHIR POST failed: HTTP "_pResponse.FHIRStatusCode_" "_pResponse.FHIRStatusLine_" "_$EXTRACT(pResponse.FHIRResponseBody,1,1000))
        }

        Quit $$$OK
    }


XData MessageMap
{
    <MapItems>
        <MapItem MessageType="HOSPITAL.NewProduction.FHIRPatientRequest">
            <Method>SendPatient</Method>
        </MapItem>
    </MapItems>
}
}
