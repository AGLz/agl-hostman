"""
Backup Restoration Testing Module

Tests automated backup restoration with SLA compliance verification.
AGL-22: Automated Backup and Disaster Recovery
"""

from .verify_restoration import RestorationVerifier

__all__ = ['RestorationVerifier']
__version__ = '1.0.0'
