from __future__ import annotations

from django.utils import timezone
from clinical.models import OutboxEvent


def display_name(u):
    if not u:
        return None

    full_name = getattr(u, "get_full_name", None)
    if callable(full_name):
        try:
            v = full_name()
            if v:
                return v
        except Exception:
            pass

    return getattr(u, "username", None) or getattr(u, "email", None) or f"User #{u.id}"


def _normalize_entity_id(value):
    """
    Normalize entity_id/object_id to avoid 'None'/'null' strings leaking to API.
    Returns int/str or None.
    """
    if value is None:
        return None

    # If already an int-like string, keep it as int string (object_id stored as str anyway).
    s = str(value).strip()
    if not s:
        return None

    low = s.lower()
    if low in ("none", "null", "nil"):
        return None

    return value


def create_outbox_event(
    *,
    event_type: str,
    actor,
    recipient=None,
    obj=None,
    payload=None,
    entity_type: str | None = None,
    entity_id=None,
    route: str | None = None,
    title: str | None = None,
    message: str | None = None,
) -> None:
    """
    Create Outbox event safely (fail-safe, does not break main flow).

    Notes:
    - OutboxEvent.patient is used as RECIPIENT (may be patient OR doctor).
    - payload is enriched with ready-to-display fields for Flutter:
      actor_name/recipient_name/title/message/route/entity_type/entity_id/timestamp.
    """
    try:
        actor_user = actor if getattr(actor, "is_authenticated", False) else None
        recipient_user = recipient

        base = dict(payload) if isinstance(payload, dict) else {}

        # ---- unified identity ----
        base.setdefault("type", event_type)

        base.setdefault("actor_id", getattr(actor_user, "id", None))
        base.setdefault("actor_name", display_name(actor_user))
        base.setdefault("actor_role", getattr(actor_user, "role", None) if actor_user else None)

        base.setdefault("recipient_id", getattr(recipient_user, "id", None))
        base.setdefault("recipient_name", display_name(recipient_user))
        base.setdefault("recipient_role", getattr(recipient_user, "role", None) if recipient_user else None)

        # ---- entity + routing ----
        resolved_entity_id = _normalize_entity_id(entity_id)
        if resolved_entity_id is None and obj is not None:
            resolved_entity_id = _normalize_entity_id(getattr(obj, "id", None))

        resolved_entity_type = entity_type or base.get("entity_type")

        if resolved_entity_type:
            base.setdefault("entity_type", resolved_entity_type)
        if resolved_entity_id is not None:
            base.setdefault("entity_id", resolved_entity_id)

        if route:
            base.setdefault("route", route)

        # ---- timestamp ----
        base.setdefault("timestamp", timezone.now().isoformat())

        # ---- ready-to-show defaults ----
        # Allow explicit title/message params to override, else fallback to payload, else defaults
        if title and str(title).strip():
            base["title"] = title
        elif not str(base.get("title") or "").strip():
            base["title"] = event_type

        if message and str(message).strip():
            base["message"] = message
        elif not str(base.get("message") or "").strip():
            base["message"] = "تفاصيل غير متوفرة."

        # OutboxEvent.object_id is stored as string.
        object_id_str = ""
        if resolved_entity_id is not None:
            object_id_str = str(resolved_entity_id)

        OutboxEvent.objects.create(
            event_type=event_type,
            actor=actor_user,
            patient=recipient_user,  # recipient (legacy DB field)
            object_id=object_id_str,
            payload=base,
            status=OutboxEvent.Status.PENDING,
        )

    except Exception:
        # fail-safe: do not break main operation
        pass
