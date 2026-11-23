/// Routes incoming HL7 ADT messages to the appropriate processing workflow.
Class HOSPITAL.NewProduction.RoutingRule Extends Ens.Rule.Definition
{

Parameter RuleAssistClass = "EnsLib.HL7.MsgRouter.RuleAssist";

XData RuleDefinition [ XMLNamespace = "http://www.intersystems.com/rule" ]
{
<ruleDefinition alias="" context="EnsLib.HL7.MsgRouter.RoutingEngine" production="HOSPITAL.NewProduction">
<ruleSet name="" effectiveBegin="" effectiveEnd="">

<!-- Preserve a copy of every inbound HL7 message for audit/debugging. -->
<rule name="LogAllInboundMessages">
<constraint name="source" value="ADT_TCP_Service"></constraint>
<when condition="1" comment="Log every inbound HL7 message">
<send transform="" target="HL7FileOperation"></send>
</when>
</rule>

<!-- Route ADT A01 admission messages to the existing A01 workflow. -->
<rule name="RouteADT_A01">
<constraint name="source" value="ADT_TCP_Service"></constraint>
<constraint name="docName" value="ADT_A01"></constraint>
<when condition="1" comment="Process ADT A01 admission messages">
<send transform="" target="HOSPITAL.NewProduction.AD01"></send>
</when>
</rule>

<!-- Route ADT A03 discharge messages only to the A03 workflow. -->
<rule name="RouteADT_A03">
<constraint name="source" value="ADT_TCP_Service"></constraint>
<constraint name="docName" value="ADT_A03"></constraint>
<when condition="1" comment="Process ADT A03 discharge messages">
<send transform="" target="HOSPITAL.NewProduction.AD03"></send>
</when>
</rule>

<!-- Route ADT A08 patient demographic updates to the A08 workflow. -->
<rule name="RouteADT_A08">
<constraint name="source" value="ADT_TCP_Service"></constraint>
<constraint name="docName" value="ADT_A08"></constraint>
<when condition="1" comment="Process ADT A08 patient updates">
<send transform="" target="HOSPITAL.NewProduction.AD08"></send>
</when>
</rule>

</ruleSet>
</ruleDefinition>
}

}