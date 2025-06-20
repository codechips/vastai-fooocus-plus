"""
Shared utilities for URL processing and conversion.
"""

import re
import logging
from typing import Dict


class URLProcessor:
    """Processes and converts URLs for different sources."""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
    
    def process_url(self, url: str) -> str:
        """
        Process special URLs (Google Drive, etc.) to get direct download links.
        
        Args:
            url: URL to process
            
        Returns:
            Processed URL (direct download if conversion was possible)
        """
        # Google Drive file ID extraction and conversion
        google_drive_patterns = [
            r'drive\.google\.com/file/d/([a-zA-Z0-9_-]+)',
            r'drive\.google\.com/uc\?id=([a-zA-Z0-9_-]+)',
            r'docs\.google\.com/uc\?id=([a-zA-Z0-9_-]+)'
        ]
        
        for pattern in google_drive_patterns:
            match = re.search(pattern, url)
            if match:
                file_id = match.group(1)
                direct_url = f"https://drive.google.com/uc?export=download&id={file_id}"
                self.logger.info(f"Converted Google Drive URL to direct download")
                return direct_url
        
        # Handle Google Drive URLs that are already in direct format
        if 'drive.google.com/uc' in url and 'export=download' in url:
            return url
        
        # For other URLs, return as-is
        return url
    
    def is_google_drive_url(self, url: str) -> bool:
        """Check if URL is a Google Drive URL."""
        return any(domain in url for domain in ['drive.google.com', 'docs.google.com'])
    
    def is_s3_url(self, url: str) -> bool:
        """Check if URL is an S3 URL."""
        return any(pattern in url for pattern in ['amazonaws.com', 's3.', '.s3-'])
    
    def get_url_info(self, url: str) -> Dict[str, str]:
        """
        Get information about the URL source.
        
        Args:
            url: URL to analyze
            
        Returns:
            Dictionary with URL information
        """
        info = {'type': 'generic', 'url': url}
        
        if self.is_google_drive_url(url):
            info['type'] = 'google_drive'
            info['needs_processing'] = str(not ('export=download' in url))
        elif self.is_s3_url(url):
            info['type'] = 's3'
        elif 'github.com' in url:
            info['type'] = 'github'
        elif 'gitlab.com' in url:
            info['type'] = 'gitlab'
        
        return info