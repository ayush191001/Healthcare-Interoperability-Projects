Class HOSPITAL.NewProduction.FHIRPatientRequest Extends Ens.Request
{

Property PatientJSON As %String(MAXLEN = 32000);

Storage Default
{
<Data name="FHIRPatientRequestDefaultData">
<Subscript>"FHIRPatientRequest"</Subscript>
<Value name="1">
<Value>PatientJSON</Value>
</Value>
</Data>
<DefaultData>FHIRPatientRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
