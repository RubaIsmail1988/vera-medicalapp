import logging

logger = logging.getLogger(__name__)


def send_push_to_user(*, user_id: int, title: str, body: str, data: dict | None = None) -> bool:
    """
    Mock push sender.
    - لا يرسل أي شيء فعليًا
    - فقط يسجل log
    - يرجع True وكأن الإرسال نجح
    """
    logger.info(
        "[PUSH:MOCK] user_id=%s | title=%s | body=%s | data=%s",
        user_id,
        title,
        body,
        data or {},
    )
    return True
