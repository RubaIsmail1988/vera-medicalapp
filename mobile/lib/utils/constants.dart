const String baseUrl = "http://127.0.0.1:8000";
//const String baseUrl = "https://rubaismail.pythonanywhere.com";
//const String baseUrl = "http://10.0.2.2:8000";
//const String baseUrl = "http://192.168.49.101:8000";
// API domains
const String accountsBaseUrl = "$baseUrl/api/accounts";
const String clinicalBaseUrl = "$baseUrl/api/clinical";
const String appointmentsBaseUrl = "$baseUrl/api/appointments";

// Clinical endpoints
const String clinicalOrdersEndpoint = "$clinicalBaseUrl/orders/";
const String clinicalPrescriptionsEndpoint = "$clinicalBaseUrl/prescriptions/";
const String clinicalAdherenceEndpoint = "$clinicalBaseUrl/adherence/";
const String clinicalOutboxEndpoint = "$clinicalBaseUrl/outbox/";

// Appointments endpoints
const String appointmentsCreateEndpoint = "$appointmentsBaseUrl/";
const String appointmentsDoctorSearchEndpoint =
    "$appointmentsBaseUrl/doctors/search/";
