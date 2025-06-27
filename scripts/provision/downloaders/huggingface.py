"""
HuggingFace model downloader with hf_transfer support.
"""

import asyncio
import logging
import os
from pathlib import Path
from typing import Optional

try:
    from huggingface_hub import hf_hub_download, login, HfApi, snapshot_download
    HF_AVAILABLE = True
except ImportError:
    HF_AVAILABLE = False


class HuggingFaceDownloader:
    """Downloads models from HuggingFace Hub."""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.api = None
        
        if not HF_AVAILABLE:
            self.logger.warning("huggingface_hub not available, HF downloads will fail")
            return
        
        # Enable hf_transfer for faster downloads if available
        os.environ.setdefault("HF_HUB_ENABLE_HF_TRANSFER", "1")
        
        # Login with token if available
        hf_token = os.environ.get("HF_TOKEN")
        if hf_token:
            try:
                login(token=hf_token)
                self.api = HfApi(token=hf_token)
                self.logger.info("HuggingFace authentication successful")
            except Exception as e:
                self.logger.warning(f"HuggingFace authentication failed: {e}")
                self.api = HfApi()
        else:
            self.api = HfApi()
            self.logger.info("No HF_TOKEN provided, using anonymous access")
    
    async def download(
        self, 
        model_name: str, 
        repo_id: str, 
        filename: str, 
        target_dir: Path,
        gated: bool = False,
        download_all: bool = False
    ) -> bool:
        """
        Download a model from HuggingFace Hub.
        
        Args:
            model_name: Human-readable model name for logging
            repo_id: HuggingFace repository ID (e.g., "openai/clip-vit-large-patch14")
            filename: Specific file to download (e.g., "model.safetensors") or empty for full repo
            target_dir: Directory to save the model
            gated: Whether this is a gated model requiring authentication
            download_all: If True, download entire repository instead of single file
            
        Returns:
            True if download succeeded, False otherwise
        """
        if not HF_AVAILABLE:
            self.logger.error(f"Cannot download {model_name}: huggingface_hub not available")
            return False
        
        try:
            self.logger.info(f"📥 Downloading {model_name} from HuggingFace")
            self.logger.info(f"    Repository: {repo_id}")
            self.logger.info(f"    File: {filename}")
            self.logger.info(f"    Target: {target_dir}")
            
            # Check if model already exists
            if download_all or not filename:
                # For full repo downloads, check if target directory exists and has content
                if target_dir.exists() and any(target_dir.iterdir()):
                    self.logger.info(f"✅ {model_name} already exists, skipping download")
                    return True
            else:
                # For single file downloads, check specific file
                target_file = target_dir / filename
                if target_file.exists():
                    self.logger.info(f"✅ {model_name} already exists, skipping download")
                    return True
            
            # Pre-validate access for gated models
            if gated and not await self._can_access_repo(repo_id):
                self.logger.error(f"🔒 Cannot access gated repository: {repo_id}")
                self.logger.error(f"    Visit https://huggingface.co/{repo_id} to accept Terms of Service")
                return False
            
            # Download in thread pool to avoid blocking
            loop = asyncio.get_event_loop()
            if download_all or not filename:
                # Download entire repository
                downloaded_path = await loop.run_in_executor(
                    None,
                    self._download_repo_sync,
                    repo_id,
                    str(target_dir)
                )
            else:
                # Download single file
                downloaded_path = await loop.run_in_executor(
                    None,
                    self._download_sync,
                    repo_id,
                    filename,
                    str(target_dir)
                )
            
            if downloaded_path:
                self.logger.info(f"✅ Successfully downloaded {model_name}")
                return True
            else:
                self.logger.error(f"❌ Failed to download {model_name}")
                return False
                
        except Exception as e:
            self.logger.error(f"❌ HuggingFace download failed for {model_name}: {e}")
            return False
    
    def _download_sync(self, repo_id: str, filename: str, target_dir: str) -> Optional[str]:
        """Synchronous download wrapper for single file downloads."""
        try:
            return hf_hub_download(
                repo_id=repo_id,
                filename=filename,
                local_dir=target_dir,
                token=os.environ.get("HF_TOKEN"),
                resume_download=True
            )
        except Exception as e:
            self.logger.error(f"Download error: {e}")
            return None
    
    def _download_repo_sync(self, repo_id: str, target_dir: str) -> Optional[str]:
        """Synchronous download wrapper for full repository downloads."""
        try:
            return snapshot_download(
                repo_id=repo_id,
                local_dir=target_dir,
                token=os.environ.get("HF_TOKEN"),
                resume_download=True
            )
        except Exception as e:
            self.logger.error(f"Repository download error: {e}")
            return None
    
    async def _can_access_repo(self, repo_id: str) -> bool:
        """Check if we can access a repository (for gated models)."""
        if not self.api:
            return False
        
        try:
            # Try to get repo info - this will fail for gated repos without access
            loop = asyncio.get_event_loop()
            await loop.run_in_executor(
                None,
                self.api.repo_info,
                repo_id
            )
            return True
        except Exception:
            return False
    
    async def list_repo_files(self, repo_id: str) -> list:
        """List all files in a repository."""
        if not self.api:
            return []
        
        try:
            loop = asyncio.get_event_loop()
            repo_info = await loop.run_in_executor(
                None,
                self.api.repo_info,
                repo_id
            )
            return [f.rfilename for f in repo_info.siblings] if repo_info.siblings else []
        except Exception as e:
            self.logger.error(f"Failed to list files for {repo_id}: {e}")
            return []