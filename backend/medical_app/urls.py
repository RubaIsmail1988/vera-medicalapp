from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path("admin/", admin.site.urls),

    # Accounts API (All authentication + users + details + hospitals + labs)
    path("api/accounts/", include("accounts.urls")),
]
