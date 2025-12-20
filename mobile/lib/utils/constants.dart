const String baseUrl = "http://127.0.0.1:8000";

// API domains
const String accountsBaseUrl = "$baseUrl/api/accounts";

//
const String clinicalBaseUrl = "$baseUrl/api/clinical";

// ثوابت endpoints
const String clinicalOrdersEndpoint = "$clinicalBaseUrl/orders/";
const String clinicalPrescriptionsEndpoint = "$clinicalBaseUrl/prescriptions/";
const String clinicalAdherenceEndpoint = "$clinicalBaseUrl/adherence/";
const String clinicalOutboxEndpoint = "$clinicalBaseUrl/outbox/";
