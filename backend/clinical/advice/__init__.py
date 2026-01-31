# backend/clinical/advice/__init__.py
from .contracts import AdviceCard
from .factory import get_advice_engine
from .rules_engine import RuleBasedAdviceEngine
from .ml_engine import MLAdviceEngine
