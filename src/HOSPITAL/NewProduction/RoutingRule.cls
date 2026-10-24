/// 
Class HOSPITAL.NewProduction.RoutingRule Extends Ens.Rule.Definition
{

Parameter RuleAssistClass = "EnsLib.HL7.MsgRouter.RuleAssist";

XData RuleDefinition [ XMLNamespace = "http://www.intersystems.com/rule" ]
{
<ruleDefinition alias="" context="EnsLib.HL7.MsgRouter.RoutingEngine" production="HOSPITAL.NewProduction">
<ruleSet name="" effectiveBegin="" effectiveEnd="">
<rule name="">
<constraint name="source" value="ADT_TCP_Service"></constraint>
<when condition="1" comment="">
<send transform="" target="HL7FileOperation"></send>
<send transform="" target="HOSPITAL.NewProduction.AD01"></send>
</when>
</rule>
</ruleSet>
</ruleDefinition>
}

}
