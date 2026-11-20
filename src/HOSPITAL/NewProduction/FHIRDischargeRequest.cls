Class HOSPITAL.NewProduction.FHIRDischargeRequest Extends Ens.Request
{

Property PatientIdentifier As %String(MAXLEN = 256);

Property VisitNumber As %String(MAXLEN = 128);

Property DischargeDateTime As %String(MAXLEN = 32);

Property MessageControlID As %String(MAXLEN = 128);

Storage Default
{
<Data name="FHIRDischargeRequestDefaultData">
<Subscript>"FHIRDischargeRequest"</Subscript>
<Value name="1">
<Value>PatientIdentifier</Value>
</Value>
<Value name="2">
<Value>VisitNumber</Value>
</Value>
<Value name="3">
<Value>DischargeDateTime</Value>
</Value>
<Value name="4">
<Value>MessageControlID</Value>
</Value>
</Data>
<DefaultData>FHIRDischargeRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
