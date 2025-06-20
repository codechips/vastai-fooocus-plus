"""
VastAI Fooocus Plus Provisioning System

Fast, parallel model provisioning for HuggingFace, CivitAI, and direct URLs.
Supports gated models with token pre-validation and graceful error handling.
"""

from .core import ProvisioningSystem

__version__ = "1.0.0"
__all__ = ["ProvisioningSystem"]