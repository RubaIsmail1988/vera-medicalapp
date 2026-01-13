from django.utils import timezone

from clinical.models import OutboxEvent
from .push_sender import send_push_to_user


def try_send_event(event: OutboxEvent) -> None:
    """
    يحاول إرسال حدث واحد.
    - يحدّث attempts
    - يحدّث status (sent / failed)
    """
    event.attempts += 1

    try:
        ok = send_push_to_user(
            user_id=event.patient_id or event.actor_id,
            title=event.event_type,
            body="You have a new notification.",
            data=event.payload or {},
        )

        if ok:
            event.mark_sent()
        else:
            event.mark_failed("push_sender returned False")

    except Exception as exc:
        event.mark_failed(str(exc))

    event.save(update_fields=["attempts", "status", "last_error", "sent_at"])


def process_pending_events(limit: int = 50) -> int:
    """
    يعالج مجموعة من أحداث PENDING.
    """
    qs = (
        OutboxEvent.objects
        .filter(status=OutboxEvent.Status.PENDING)
        .order_by("created_at")[:limit]
    )

    count = 0
    for ev in qs:
        try_send_event(ev)
        count += 1

    return count
