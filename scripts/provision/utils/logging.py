"""
Logging utilities for the provisioning system.
"""

import logging
import sys
from pathlib import Path
from typing import Optional


def setup_logging(log_file: Optional[Path] = None, level: int = logging.INFO) -> None:
    """
    Set up logging for the provisioning system.
    
    Args:
        log_file: Optional path to log file
        level: Logging level
    """
    # Create formatter
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # Create console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(level)
    console_handler.setFormatter(formatter)
    
    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(level)
    root_logger.addHandler(console_handler)
    
    # Add file handler if specified
    if log_file:
        log_file.parent.mkdir(parents=True, exist_ok=True)
        file_handler = logging.FileHandler(log_file, encoding='utf-8')
        file_handler.setLevel(level)
        file_handler.setFormatter(formatter)
        root_logger.addHandler(file_handler)
    
    # Reduce noise from some libraries
    logging.getLogger('aiohttp').setLevel(logging.WARNING)
    logging.getLogger('urllib3').setLevel(logging.WARNING)


class ProvisioningLogger:
    """Custom logger for provisioning operations."""
    
    def __init__(self, name: str):
        self.logger = logging.getLogger(name)
    
    def log_download_start(self, model_name: str, source: str, target: str) -> None:
        """Log start of download."""
        self.logger.info(f"📥 Starting download: {model_name}")
        self.logger.info(f"    Source: {source}")
        self.logger.info(f"    Target: {target}")
    
    def log_download_success(self, model_name: str) -> None:
        """Log successful download."""
        self.logger.info(f"✅ Successfully downloaded: {model_name}")
    
    def log_download_failure(self, model_name: str, error: str) -> None:
        """Log failed download."""
        self.logger.error(f"❌ Failed to download: {model_name}")
        self.logger.error(f"    Error: {error}")
    
    def log_download_skipped(self, model_name: str, reason: str) -> None:
        """Log skipped download."""
        self.logger.info(f"⏭️  Skipped: {model_name}")
        self.logger.info(f"    Reason: {reason}")
    
    def log_progress(self, model_name: str, progress: int, size_info: str = "") -> None:
        """Log download progress."""
        if size_info:
            self.logger.info(f"    {model_name}: {progress}% complete ({size_info})")
        else:
            self.logger.info(f"    {model_name}: {progress}% complete")
    
    def log_gated_model_error(self, model_name: str, platform: str, repo_url: str = "") -> None:
        """Log gated model access error."""
        self.logger.error("🔒 GATED MODEL ACCESS DENIED")
        self.logger.error(f"Model: {model_name}")
        self.logger.error(f"Platform: {platform}")
        self.logger.error("Reason: Terms of Service not accepted or invalid token")
        
        if repo_url:
            self.logger.error(f"Action: Visit {repo_url} and accept Terms of Service")
        
        self.logger.error("Status: SKIPPED")
        self.logger.error("")  # Empty line for readability
    
    def log_summary(self, total: int, succeeded: int, failed: int, skipped: int) -> None:
        """Log provisioning summary."""
        self.logger.info("")
        self.logger.info("=" * 50)
        self.logger.info("PROVISIONING SUMMARY")
        self.logger.info("=" * 50)
        self.logger.info(f"Total models: {total}")
        self.logger.info(f"✅ Succeeded: {succeeded}")
        self.logger.info(f"❌ Failed: {failed}")
        self.logger.info(f"⏭️  Skipped: {skipped}")
        
        if failed == 0 and skipped == 0:
            self.logger.info("🎉 All models provisioned successfully!")
        elif failed == 0:
            self.logger.info("✨ All attempted downloads succeeded!")
        else:
            self.logger.warning("⚠️  Some downloads failed. Check logs above for details.")
        
        self.logger.info("=" * 50)