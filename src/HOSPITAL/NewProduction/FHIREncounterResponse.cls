Class HOSPITAL.NewProduction.FHIREncounterResponse Extends Ens.Response
{

Property FHIRStatusCode As %Integer;

Property FHIRStatusLine As %String(MAXLEN = 256);

Property ResourceLocation As %String(MAXLEN = 2048);

Property FHIRResponseBody As %String(MAXLEN = 32000);

Storage Default
{
<Data name="FHIREncounterResponseDefaultData">
<Subscript>"FHIREncounterResponse"</Subscript>
<Value name="1">
<Value>FHIRStatusCode</Value>
</Value>
<Value name="2">
<Value>FHIRStatusLine</Value>
</Value>
<Value name="3">
<Value>ResourceLocation</Value>
</Value>
<Value name="4">
<Value>FHIRResponseBody</Value>
</Value>
</Data>
<DefaultData>FHIREncounterResponseDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
