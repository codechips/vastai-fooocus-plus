"""
CivitAI model downloader with API support.
"""

import asyncio
import aiohttp
import logging
import os
from pathlib import Path
from typing import Optional, Dict, Any
from urllib.parse import urlparse


class CivitAIDownloader:
    """Downloads models from CivitAI using their API."""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.base_url = "https://civitai.com/api"
        self.token = os.environ.get("CIVITAI_TOKEN")
        
        if self.token:
            self.logger.info("CivitAI authentication token found")
        else:
            self.logger.warning("No CIVITAI_TOKEN provided, downloads may be limited")
    
    async def download(
        self, 
        model_name: str, 
        model_id: str, 
        target_dir: Path,
        filename: str = ""
    ) -> bool:
        """
        Download a model from CivitAI.
        
        Args:
            model_name: Human-readable model name for logging
            model_id: CivitAI model version ID
            target_dir: Directory to save the model
            filename: Optional custom filename (uses CivitAI filename if not provided)
            
        Returns:
            True if download succeeded, False otherwise
        """
        try:
            self.logger.info(f"📥 Downloading {model_name} from CivitAI")
            self.logger.info(f"    Model ID: {model_id}")
            self.logger.info(f"    Target: {target_dir}")
            
            # Get model info to determine filename
            model_info = await self._get_model_info(model_id)
            if not model_info:
                self.logger.error(f"❌ Failed to get model info for {model_name}")
                return False
            
            # Determine target filename
            if not filename:
                filename = model_info.get('filename', f"{model_name}.safetensors")
            
            # Check if model already exists
            target_file = target_dir / filename
            if target_file.exists():
                self.logger.info(f"✅ {model_name} already exists, skipping download")
                return True
            
            # Download the model
            download_url = f"{self.base_url}/download/models/{model_id}"
            success = await self._download_file(download_url, target_file, model_name)
            
            if success:
                self.logger.info(f"✅ Successfully downloaded {model_name}")
                return True
            else:
                self.logger.error(f"❌ Failed to download {model_name}")
                return False
                
        except Exception as e:
            self.logger.error(f"❌ CivitAI download failed for {model_name}: {e}")
            return False
    
    async def _get_model_info(self, model_id: str) -> Optional[Dict[str, Any]]:
        """Get model information from CivitAI API."""
        try:
            url = f"{self.base_url}/v1/model-versions/{model_id}"
            headers = {}
            
            if self.token:
                headers["Authorization"] = f"Bearer {self.token}"
            
            async with aiohttp.ClientSession() as session:
                async with session.get(url, headers=headers) as response:
                    if response.status == 200:
                        data = await response.json()
                        return {
                            'filename': data.get('files', [{}])[0].get('name', ''),
                            'size': data.get('files', [{}])[0].get('sizeKB', 0),
                            'downloadUrl': data.get('downloadUrl', '')
                        }
                    elif response.status == 401:
                        self.logger.error("CivitAI authentication failed - invalid token")
                        return None
                    elif response.status == 404:
                        self.logger.error(f"Model version {model_id} not found")
                        return None
                    else:
                        self.logger.error(f"CivitAI API error: {response.status}")
                        return None
                        
        except Exception as e:
            self.logger.error(f"Failed to get model info: {e}")
            return None
    
    async def _download_file(self, url: str, target_file: Path, model_name: str) -> bool:
        """Download file from URL with progress tracking."""
        try:
            headers = {}
            
            # Add authentication token if available
            if self.token:
                headers["Authorization"] = f"Bearer {self.token}"
            
            async with aiohttp.ClientSession() as session:
                async with session.get(url, headers=headers) as response:
                    if response.status != 200:
                        self.logger.error(f"Download failed with status {response.status}")
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
                                    self.logger.info(f"    {model_name}: {progress}% complete")
                                    last_progress = progress
                    
                    return True
                    
        except Exception as e:
            self.logger.error(f"Download error: {e}")
            # Clean up partial file
            if target_file.exists():
                target_file.unlink()
            return False
    
    async def search_models(self, query: str, limit: int = 10) -> list:
        """Search for models on CivitAI."""
        try:
            url = f"{self.base_url}/v1/models"
            params = {
                'query': query,
                'limit': limit
            }
            headers = {}
            
            if self.token:
                headers["Authorization"] = f"Bearer {self.token}"
            
            async with aiohttp.ClientSession() as session:
                async with session.get(url, params=params, headers=headers) as response:
                    if response.status == 200:
                        data = await response.json()
                        return data.get('items', [])
                    else:
                        self.logger.error(f"Search failed with status {response.status}")
                        return []
                        
        except Exception as e:
            self.logger.error(f"Search error: {e}")
            return []