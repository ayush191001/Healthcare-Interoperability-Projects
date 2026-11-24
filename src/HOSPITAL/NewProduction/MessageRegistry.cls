/// Persistent registry for inbound HL7 message processing and duplicate detection.
Class HOSPITAL.NewProduction.MessageRegistry Extends %Persistent
{

/// HL7 MSH-3: sending application.
Property SendingApplication As %String(MAXLEN = 256) [ Required ];

/// HL7 MSH-4: sending facility.
Property SendingFacility As %String(MAXLEN = 256) [ Required ];

/// HL7 MSH-10: message control ID.
Property MessageControlID As %String(MAXLEN = 128) [ Required ];

/// HL7 MSH-9 message type, for example ADT^A01.
Property MessageType As %String(MAXLEN = 32) [ Required ];

/// Processing lifecycle: RECEIVED, PROCESSING, COMPLETED, FAILED.
Property ProcessingStatus As %String(MAXLEN = 20) [ InitialExpression = "RECEIVED", Required ];

/// ISO 8601 timestamp recorded when the message is first registered.
Property ReceivedAt As %String(MAXLEN = 32);

/// ISO 8601 timestamp recorded when processing starts.
Property StartedAt As %String(MAXLEN = 32);

/// ISO 8601 timestamp recorded after successful processing.
Property CompletedAt As %String(MAXLEN = 32);

/// ISO 8601 timestamp of the most recent registry update.
Property LastUpdatedAt As %String(MAXLEN = 32);

/// Number of processing attempts, including the initial attempt.
Property AttemptCount As %Integer [ InitialExpression = 0 ];

/// Most recent processing error; populated only when processing fails.
Property ErrorDetails As %String(MAXLEN = 4000);

/// One inbound message is uniquely identified by sender application, sender facility and MSH-10.
Index MessageIdentity On (SendingApplication, SendingFacility, MessageControlID) [ Unique ];

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
