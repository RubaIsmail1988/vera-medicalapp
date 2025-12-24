from django.urls import path

from .views import (
    ClinicalOrderListCreateView,
    ClinicalOrderRetrieveView,
    OrderFilesListView,
    OrderFileUploadView,
    approve_medical_record_file,
    reject_medical_record_file,
    PrescriptionListCreateView,
    PrescriptionRetrieveView,
    MedicationAdherenceListCreateView,
    OutboxEventListView,
    OrderFileDeleteView,
    ClinicalRecordAggregationView,
)

urlpatterns = [
    # Orders
    path("orders/", ClinicalOrderListCreateView.as_view(), name="clinical-order-list-create"),
    path("orders/<int:pk>/", ClinicalOrderRetrieveView.as_view(), name="clinical-order-retrieve"),

    # Files (by order)
    path("orders/<int:order_id>/files/", OrderFilesListView.as_view(), name="order-files-list"),
    path("orders/<int:order_id>/files/upload/", OrderFileUploadView.as_view(), name="order-file-upload"),

    # File review actions
    path("files/<int:file_id>/approve/", approve_medical_record_file, name="file-approve"),
    path("files/<int:file_id>/reject/", reject_medical_record_file, name="file-reject"),
    path("files/<int:file_id>/", OrderFileDeleteView.as_view(), name="clinical-file-delete"), 
    # Prescriptions
    path("prescriptions/", PrescriptionListCreateView.as_view(), name="prescription-list-create"),
    path("prescriptions/<int:pk>/", PrescriptionRetrieveView.as_view(), name="prescription-retrieve"),

    # Adherence
    path("adherence/", MedicationAdherenceListCreateView.as_view(), name="adherence-list-create"),

    #aggrigation
    path("record/", ClinicalRecordAggregationView.as_view(), name="clinical-record-aggregation"),


    # Outbox (optional)
    path("outbox/", OutboxEventListView.as_view(), name="outbox-list"),
    

]
