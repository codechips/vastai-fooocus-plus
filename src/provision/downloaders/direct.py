"""
Direct URL downloader for Google Drive, S3, and other HTTP endpoints.
"""

import asyncio
import aiohttp
import logging
import os
import re
from pathlib import Path
from typing import Dict, Optional
from urllib.parse import urlparse, parse_qs

from ..utils.urls import URLProcessor


class DirectURLDownloader:
    """Downloads models from direct URLs (Google Drive, S3, etc.)."""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.url_processor = URLProcessor()
    
    async def download(
        self, 
        model_name: str, 
        url: str, 
        target_dir: Path,
        filename: str = "",
        headers: Dict[str, str] = None
    ) -> bool:
        """
        Download a model from a direct URL.
        
        Args:
            model_name: Human-readable model name for logging
            url: Direct download URL
            target_dir: Directory to save the model
            filename: Optional custom filename (auto-detected if not provided)
            headers: Optional custom headers for the request
            
        Returns:
            True if download succeeded, False otherwise
        """
        try:
            self.logger.info(f"📥 Downloading {model_name} from URL")
            self.logger.info(f"    URL: {url}")
            self.logger.info(f"    Target: {target_dir}")
            
            # Process special URLs (Google Drive, etc.)
            processed_url = self.url_processor.process_url(url)
            
            # Determine filename if not provided
            if not filename:
                filename = await self._get_filename(processed_url, headers or {})
                if not filename:
                    filename = f"{model_name}.safetensors"
            
            # Check if model already exists
            target_file = target_dir / filename
            if target_file.exists():
                self.logger.info(f"✅ {model_name} already exists, skipping download")
                return True
            
            # Download the file
            success = await self._download_file(processed_url, target_file, model_name, headers or {})
            
            if success:
                self.logger.info(f"✅ Successfully downloaded {model_name}")
                return True
            else:
                self.logger.error(f"❌ Failed to download {model_name}")
                return False
                
        except Exception as e:
            self.logger.error(f"❌ Direct URL download failed for {model_name}: {e}")
            return False
    
    
    async def _get_filename(self, url: str, headers: Dict[str, str]) -> Optional[str]:
        """Attempt to get filename from URL or headers."""
        try:
            # First try to extract from URL
            parsed_url = urlparse(url)
            path = parsed_url.path
            if path and '.' in path:
                filename = Path(path).name
                if filename and len(filename) < 255:  # Reasonable filename length
                    return filename
            
            # Try to get filename from HEAD request
            async with aiohttp.ClientSession() as session:
                async with session.head(url, headers=headers, allow_redirects=True) as response:
                    if response.status == 200:
                        content_disposition = response.headers.get('content-disposition')
                        if content_disposition:
                            filename_match = re.search(r'filename[*]?=["\']?([^"\';\r\n]+)', content_disposition)
                            if filename_match:
                                return filename_match.group(1).strip('"\'')
            
            return None
            
        except Exception:
            return None
    
    async def _download_file(self, url: str, target_file: Path, model_name: str, headers: Dict[str, str]) -> bool:
        """Download file from URL with progress tracking and Google Drive handling."""
        try:
            # Set up default headers
            default_headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            }
            default_headers.update(headers)
            
            # Handle authentication headers from environment variables
            auth_header = headers.get('auth_header')
            if auth_header:
                # Support format like "Bearer ${TOKEN_VAR}"
                if '${' in auth_header and '}' in auth_header:
                    var_name = auth_header.split('${')[1].split('}')[0]
                    token_value = os.environ.get(var_name)
                    if token_value:
                        auth_header = auth_header.replace('${' + var_name + '}', token_value)
                        default_headers['Authorization'] = auth_header
            
            timeout = aiohttp.ClientTimeout(total=3600)  # 1 hour timeout
            
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url, headers=default_headers) as response:
                    # Handle Google Drive virus scan warning
                    if 'drive.google.com' in url and response.status == 200:
                        content = await response.text()
                        if 'Google Drive - Virus scan warning' in content:
                            # Extract the confirm download URL
                            confirm_match = re.search(r'href="(/uc\?export=download[^"]*)"', content)
                            if confirm_match:
                                new_url = 'https://drive.google.com' + confirm_match.group(1).replace('&amp;', '&')
                                self.logger.info("Handling Google Drive virus scan warning")
                                return await self._download_file(new_url, target_file, model_name, headers)
                    
                    if response.status != 200:
                        self.logger.error(f"Download failed with status {response.status}")
                        if response.status == 403:
                            self.logger.error("Access forbidden - check authentication or permissions")
                        elif response.status == 404:
                            self.logger.error("File not found")
                        return False
                    
                    # Get content length for progress tracking
                    total_size = int(response.headers.get('content-length', 0))
                    
                    # Create target directory if it doesn't exist
                    target_file.parent.mkdir(parents=True, exist_ok=True)
                    
                    # Download with progress tracking
                    downloaded = 0
                    last_progress = 0
                    
                    with open(target_file, 'wb') as f:
                        async for chunk in response.content.iter_chunked(8192):
                            f.write(chunk)
                            downloaded += len(chunk)
                            
                            # Log progress every 10%
                            if total_size > 0:
                                progress = (downloaded * 100) // total_size
                                if progress >= last_progress + 10:
                                    size_mb = downloaded / (1024 * 1024)
                                    total_mb = total_size / (1024 * 1024) if total_size > 0 else 0
                                    self.logger.info(f"    {model_name}: {progress}% complete ({size_mb:.1f}MB/{total_mb:.1f}MB)")
                                    last_progress = progress
                            elif downloaded > 0:
                                # Show progress even without content-length
                                size_mb = downloaded / (1024 * 1024)
                                if size_mb >= last_progress + 10:
                                    self.logger.info(f"    {model_name}: {size_mb:.1f}MB downloaded")
                                    last_progress = size_mb
                    
                    return True
                    
        except asyncio.TimeoutError:
            self.logger.error(f"Download timeout for {model_name}")
            # Clean up partial file
            if target_file.exists():
                target_file.unlink()
            return False
        except Exception as e:
            self.logger.error(f"Download error: {e}")
            # Clean up partial file
            if target_file.exists():
                target_file.unlink()
            return False
    
    def is_google_drive_url(self, url: str) -> bool:
        """Check if URL is a Google Drive URL."""
        return self.url_processor.is_google_drive_url(url)
    
    def is_s3_url(self, url: str) -> bool:
        """Check if URL is an S3 URL."""
        return self.url_processor.is_s3_url(url)
    
    def get_url_info(self, url: str) -> Dict[str, str]:
        """Get information about the URL source."""
        return self.url_processor.get_url_info(url)