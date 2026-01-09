from django.db import migrations


def forwards(apps, schema_editor):
    Appointment = apps.get_model("accounts", "Appointment")

    mapping = {
        "Pending": "pending",
        "Confirmed": "confirmed",
        "Cancelled": "cancelled",
        "pending": "pending",
        "confirmed": "confirmed",
        "cancelled": "cancelled",
    }

    # Update only rows that match known values
    for old, new in mapping.items():
        Appointment.objects.filter(status=old).update(status=new)


def backwards(apps, schema_editor):
    Appointment = apps.get_model("accounts", "Appointment")

    mapping = {
        "pending": "Pending",
        "confirmed": "Confirmed",
        "cancelled": "Cancelled",
        "no_show": "no_show",  # keep as-is on rollback
    }

    for old, new in mapping.items():
        Appointment.objects.filter(status=old).update(status=new)


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0014_appointmenttype_default_duration_minutes_and_more"),
    ]

    operations = [
        migrations.RunPython(forwards, backwards),
    ]
