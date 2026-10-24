Class HOSPITAL.NewProduction.FHIREncounterRequest Extends Ens.Request
{

Property EncounterJSON As %String(MAXLEN = 32000);

Storage Default
{
<Data name="FHIREncounterRequestDefaultData">
<Subscript>"FHIREncounterRequest"</Subscript>
<Value name="1">
<Value>EncounterJSON</Value>
</Value>
</Data>
<DefaultData>FHIREncounterRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
