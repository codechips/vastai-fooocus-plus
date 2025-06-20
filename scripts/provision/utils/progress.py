"""
Progress tracking utilities for downloads.
"""

import time
from typing import Dict, Optional


class ProgressTracker:
    """Tracks download progress for multiple concurrent downloads."""

    def __init__(self):
        self.downloads: Dict[str, Dict] = {}
        self.start_time = time.time()

    def start_download(self, model_name: str, total_size: Optional[int] = None) -> None:
        """Start tracking a download."""
        self.downloads[model_name] = {
            "start_time": time.time(),
            "total_size": total_size,
            "downloaded": 0,
            "last_update": time.time(),
            "status": "downloading",
        }

    def update_progress(self, model_name: str, downloaded: int) -> None:
        """Update download progress."""
        if model_name in self.downloads:
            self.downloads[model_name]["downloaded"] = downloaded
            self.downloads[model_name]["last_update"] = time.time()

    def complete_download(self, model_name: str, success: bool = True) -> None:
        """Mark download as completed."""
        if model_name in self.downloads:
            self.downloads[model_name]["status"] = "completed" if success else "failed"
            self.downloads[model_name]["end_time"] = time.time()

    def get_progress(self, model_name: str) -> Optional[Dict]:
        """Get progress information for a specific download."""
        return self.downloads.get(model_name)

    def get_progress_percentage(self, model_name: str) -> Optional[int]:
        """Get progress percentage for a specific download."""
        download = self.downloads.get(model_name)
        if not download or not download.get("total_size"):
            return None

        return int((download["downloaded"] * 100) / download["total_size"])

    def get_download_speed(self, model_name: str) -> Optional[float]:
        """Get download speed in MB/s."""
        download = self.downloads.get(model_name)
        if not download:
            return None

        elapsed = time.time() - download["start_time"]
        if elapsed <= 0:
            return None

        mb_downloaded = download["downloaded"] / (1024 * 1024)
        return mb_downloaded / elapsed

    def get_eta(self, model_name: str) -> Optional[int]:
        """Get estimated time to completion in seconds."""
        download = self.downloads.get(model_name)
        if not download or not download.get("total_size"):
            return None

        speed = self.get_download_speed(model_name)
        if not speed or speed <= 0:
            return None

        remaining_bytes = download["total_size"] - download["downloaded"]
        remaining_mb = remaining_bytes / (1024 * 1024)

        return int(remaining_mb / speed)

    def get_overall_progress(self) -> Dict:
        """Get overall progress across all downloads."""
        total_downloads = len(self.downloads)
        completed = sum(
            1 for d in self.downloads.values() if d["status"] in ["completed", "failed"]
        )
        succeeded = sum(
            1 for d in self.downloads.values() if d["status"] == "completed"
        )
        failed = sum(1 for d in self.downloads.values() if d["status"] == "failed")
        active = total_downloads - completed

        # Calculate total progress by size if available
        total_size = sum(
            d.get("total_size", 0)
            for d in self.downloads.values()
            if d.get("total_size")
        )
        total_downloaded = sum(d.get("downloaded", 0) for d in self.downloads.values())

        overall_percentage = 0
        if total_size > 0:
            overall_percentage = int((total_downloaded * 100) / total_size)
        elif total_downloads > 0:
            overall_percentage = int((completed * 100) / total_downloads)

        elapsed_time = time.time() - self.start_time

        return {
            "total": total_downloads,
            "completed": completed,
            "succeeded": succeeded,
            "failed": failed,
            "active": active,
            "percentage": overall_percentage,
            "elapsed_time": elapsed_time,
            "total_size_mb": total_size / (1024 * 1024) if total_size > 0 else 0,
            "downloaded_mb": total_downloaded / (1024 * 1024),
        }

    def format_size(self, bytes_size: int) -> str:
        """Format bytes into human-readable size."""
        for unit in ["B", "KB", "MB", "GB"]:
            if bytes_size < 1024:
                return f"{bytes_size:.1f}{unit}"
            bytes_size /= 1024
        return f"{bytes_size:.1f}TB"

    def format_time(self, seconds: int) -> str:
        """Format seconds into human-readable time."""
        if seconds < 60:
            return f"{seconds}s"
        elif seconds < 3600:
            return f"{seconds // 60}m {seconds % 60}s"
        else:
            hours = seconds // 3600
            minutes = (seconds % 3600) // 60
            return f"{hours}h {minutes}m"

    def get_status_summary(self) -> str:
        """Get a formatted status summary."""
        progress = self.get_overall_progress()

        lines = []
        lines.append(f"Progress: {progress['completed']}/{progress['total']} downloads")
        lines.append(
            f"Success: {progress['succeeded']}, Failed: {progress['failed']}, Active: {progress['active']}"
        )

        if progress["total_size_mb"] > 0:
            lines.append(
                f"Downloaded: {progress['downloaded_mb']:.1f}MB / {progress['total_size_mb']:.1f}MB ({progress['percentage']}%)"
            )

        lines.append(f"Elapsed: {self.format_time(int(progress['elapsed_time']))}")

        return "\n".join(lines)
