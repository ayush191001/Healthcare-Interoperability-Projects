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


/// Atomically claim a message identity. The unique index arbitrates concurrent deliveries.
ClassMethod ClaimMessage(pSendingApplication As %String, pSendingFacility As %String, pMessageControlID As %String, pMessageType As %String, Output pRegistryID As %String, Output pIsDuplicate As %Boolean, Output pExistingStatus As %String) As %Status
{
    Set pRegistryID = ""
    Set pIsDuplicate = 0
    Set pExistingStatus = ""
    If (pSendingApplication = "") || (pSendingFacility = "") || (pMessageControlID = "") {
        Quit $$$ERROR($$$GeneralError, "Sending application, sending facility and message control ID are required")
    }

    Set tNow = $REPLACE($ZDATETIME($HOROLOG,3,1)," ","T")
    Set tRegistry = ..%New()
    Set tRegistry.SendingApplication = pSendingApplication
    Set tRegistry.SendingFacility = pSendingFacility
    Set tRegistry.MessageControlID = pMessageControlID
    Set tRegistry.MessageType = pMessageType
    Set tRegistry.ProcessingStatus = "PROCESSING"
    Set tRegistry.ReceivedAt = tNow
    Set tRegistry.StartedAt = tNow
    Set tRegistry.LastUpdatedAt = tNow
    Set tRegistry.AttemptCount = 1
    Set tSC = tRegistry.%Save()
    If $$$ISOK(tSC) {
        Set pRegistryID = tRegistry.%Id()
        Quit $$$OK
    }

    // A failed insert may be a duplicate-key race. Confirm by the full identity.
    Set tStatement = ##class(%SQL.Statement).%New()
    Set tSC = tStatement.%Prepare("SELECT ID, ProcessingStatus FROM HOSPITAL_NewProduction.MessageRegistry WHERE SendingApplication = ? AND SendingFacility = ? AND MessageControlID = ?")
    Quit:$$$ISERR(tSC) tSC
    Set tResult = tStatement.%Execute(pSendingApplication,pSendingFacility,pMessageControlID)
    If tResult.%Next() {
        Set pRegistryID = tResult.%Get("ID")
        Set pExistingStatus = tResult.%Get("ProcessingStatus")
        Set pIsDuplicate = 1
        Quit $$$OK
    }
    Quit tSC
}

/// Mark a claimed message complete only after all downstream work succeeds.
ClassMethod CompleteMessage(pRegistryID As %String) As %Status
{
    Set tRegistry = ..%OpenId(pRegistryID)
    If '$IsObject(tRegistry) {
        Quit $$$ERROR($$$GeneralError, "Message registry record not found")
    }
    Set tNow = $REPLACE($ZDATETIME($HOROLOG,3,1)," ","T")
    Set tRegistry.ProcessingStatus = "COMPLETED"
    Set tRegistry.CompletedAt = tNow
    Set tRegistry.LastUpdatedAt = tNow
    Quit tRegistry.%Save()
}

/// Record a failed processing attempt for operational review.
ClassMethod FailMessage(pRegistryID As %String, pErrorDetails As %String) As %Status
{
    If pRegistryID = "" Quit $$$OK
    Set tRegistry = ..%OpenId(pRegistryID)
    If '$IsObject(tRegistry) {
        Quit $$$ERROR($$$GeneralError, "Message registry record not found while recording failure")
    }
    Set tRegistry.ProcessingStatus = "FAILED"
    Set tRegistry.ErrorDetails = $EXTRACT(pErrorDetails,1,4000)
    Set tRegistry.LastUpdatedAt = $REPLACE($ZDATETIME($HOROLOG,3,1)," ","T")
    Quit tRegistry.%Save()
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
