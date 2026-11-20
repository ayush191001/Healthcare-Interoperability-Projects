# IHIP — Intelligent Healthcare Interoperability Platform

## Purpose

Extend the existing InterSystems IRIS healthcare integration project into an intelligent, auditable interoperability platform. The first vertical slice is ADT A03 discharge processing with deterministic FHIR lookup/update and a structured exception record that can later be investigated by AI agents.

## Existing repository foundation

- IRIS production: `HOSPITAL.NewProduction`
- HL7 ingress: `ADT_TCP_Service` (MLLP, TCP 2575)
- Routing: `MsgRouter` and `HOSPITAL.NewProduction.RoutingRule`
- Existing ADT process: `HOSPITAL.NewProduction.AD01`
- Existing FHIR Patient operation: `FHIRPatientOperation`
- Existing FHIR Encounter create operation: `FHIREncounterOperation`
- Existing Patient and Encounter request/response messages under `src/HOSPITAL/NewProduction`

The existing Encounter operation performs POST/conditional-create and must remain the creation path for admission workflows. ADT A03 must use a separate search-and-update path; it must not create a duplicate Encounter.

## Target A03 workflow

1. Receive the ADT A03 HL7 message through the existing production.
2. Parse MSH, PID and PV1, retaining the message control ID and original-message reference.
3. Normalize the patient and visit identifiers according to configured identifier systems.
4. Search FHIR Encounter by the hospital visit identifier.
5. Verify the returned Encounter is linked to the expected Patient.
6. Handle outcomes deterministically:
   - Exactly one verified match: update that Encounter.
   - No match: create a structured exception with reason `ENCOUNTER_NOT_FOUND`.
   - More than one match: create a structured exception with reason `MULTIPLE_ENCOUNTERS_FOUND`.
   - Patient mismatch: create a structured exception with reason `PATIENT_ENCOUNTER_MISMATCH`.
   - Remote FHIR/API failure: create an integration failure record with the HTTP status and correlation information.
7. For a verified unique match, preserve existing Encounter fields and update status to `finished` and `period.end` to the normalized discharge time. Use the resource logical ID and version-aware update where supported.
8. Record outcome and correlation data for monitoring and future investigation.

## Future intelligent workflow

- Exception Agent: retrieve structured exception and relevant integration context.
- FHIR Agent: use narrowly scoped, authorized MCP tools for read/search operations.
- AI recommendation service: produce evidence-linked recommendations with confidence and uncertainty.
- Human approval: authorized engineer approves or rejects any proposed correction.
- IRIS execution: revalidate the resource and execute only an approved, authorized action.
- Dashboard: show original failure, investigation evidence, recommendation, approval, execution and audit trail.

AI agents must not directly commit clinical-resource mutations. Deterministic validation, authorization, approval and IRIS-controlled execution remain mandatory.

## Implementation principles

- Reuse the current production and message patterns where appropriate.
- Keep ADT A01 creation and ADT A03 discharge/update behavior separate.
- Do not update a resource until exactly one Encounter has been identified and its Patient association verified.
- Preserve existing Encounter properties when updating.
- Treat identifiers as FHIR token search values; URL-encode query values correctly.
- Do not assume a FHIR server always returns a `Location` header for every successful response. Parse response bodies and handle HTTP 200/201/204 and version metadata as applicable.
- Store only the minimum necessary PHI in exception/audit records; apply access control and retention rules.
- Never place credentials, tokens or private keys in source control.

## Delivery sequence

1. Confirm current repository/production state and FHIR server behavior.
2. Implement and test A03 parsing and identifier normalization.
3. Implement FHIR Encounter search and exact-match/patient-association checks.
4. Implement safe Encounter update and idempotency.
5. Implement structured exception persistence and correlation.
6. Add Python AI service, agents and MCP tools as separate, secured components.
7. Add human approval, controlled execution and dashboard.
8. Add automated tests, deployment notes and operational documentation.

## Current known environment from repository configuration

- FHIR endpoint host: `hapi.fhir.org`
- FHIR R4 base path: `/baseR4`
- Existing TLS configuration name: `FHIRClientTLS`
- Existing Patient endpoint: `/baseR4/Patient`
- Existing Encounter endpoint: `/baseR4/Encounter`

The public HAPI test server is suitable for development/testing only. Do not use real patient data or treat it as a production clinical endpoint.
