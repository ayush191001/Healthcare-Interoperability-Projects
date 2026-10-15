Class HOSPITAL.NewProduction.FHIRPatientResponse Extends Ens.Response
{
    Property FHIRStatusCode As %Integer;
    Property FHIRStatusLine As %String(MAXLEN = 256);
    Property ResourceLocation As %String(MAXLEN = 2048);
    Property FHIRResponseBody As %String(MAXLEN = 32000);
}