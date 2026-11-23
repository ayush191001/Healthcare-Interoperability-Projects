Class HOSPITAL.NewProduction.FHIRPatientUpdateRequest Extends Ens.Request
{

Property PatientIdentifier As %String(MAXLEN = 256);

Property MessageControlID As %String(MAXLEN = 128);

Property PatientJSON As %String(MAXLEN = 32000);

Storage Default
{
<Data name="FHIRPatientUpdateRequestDefaultData">
<Subscript>"FHIRPatientUpdateRequest"</Subscript>
<Value name="1">
<Value>PatientIdentifier</Value>
<Value>MessageControlID</Value>
<Value>PatientJSON</Value>
</Value>
</Data>
<DefaultData>FHIRPatientUpdateRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
