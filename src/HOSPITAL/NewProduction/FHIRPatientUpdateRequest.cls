Class HOSPITAL.NewProduction.FHIRPatientUpdateRequest Extends Ens.Request
{

Property PatientJSON As %String(MAXLEN = 32000);

Storage Default
{
<Data name="FHIRPatientUpdateRequestDefaultData">
<Subscript>"FHIRPatientUpdateRequest"</Subscript>
<Value name="1">
<Value>PatientJSON</Value>
</Value>
</Data>
<DefaultData>FHIRPatientUpdateRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
