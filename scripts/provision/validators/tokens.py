"""
Token validation for HuggingFace and CivitAI APIs.
"""

import asyncio
import logging
import os
from typing import Dict, Optional

import aiohttp


class TokenValidator:
    """Validates authentication tokens for various platforms."""

    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.hf_token = os.environ.get("HF_TOKEN")
        self.civitai_token = os.environ.get("CIVITAI_TOKEN")

    async def validate_hf_token(self) -> bool:
        """
        Validate HuggingFace token.

        Returns:
            True if token is valid, False otherwise
        """
        if not self.hf_token:
            self.logger.warning("No HF_TOKEN environment variable found")
            return False

        try:
            url = "https://huggingface.co/api/whoami-v2"
            headers = {
                "Authorization": f"Bearer {self.hf_token}",
                "Content-Type": "application/json",
            }

            async with aiohttp.ClientSession() as session:
                async with session.get(url, headers=headers) as response:
                    if response.status == 200:
                        data = await response.json()
                        username = data.get("name", "unknown")
                        self.logger.info(
                            f"HuggingFace token valid for user: {username}"
                        )
                        return True
                    else:
                        self.logger.error(
                            f"HuggingFace token validation failed: HTTP {response.status}"
                        )
                        return False

        except Exception as e:
            self.logger.error(f"HuggingFace token validation error: {e}")
            return False

    async def validate_civitai_token(self) -> bool:
        """
        Validate CivitAI token.

        Returns:
            True if token is valid, False otherwise
        """
        if not self.civitai_token:
            self.logger.warning("No CIVITAI_TOKEN environment variable found")
            return False

        try:
            # Test with a simple API call that requires authentication
            url = "https://civitai.com/api/v1/models?hidden=1&limit=1"
            headers = {
                "Authorization": f"Bearer {self.civitai_token}",
                "Content-Type": "application/json",
            }

            async with aiohttp.ClientSession() as session:
                async with session.get(url, headers=headers) as response:
                    if response.status == 200:
                        self.logger.info("CivitAI token is valid")
                        return True
                    else:
                        self.logger.error(
                            f"CivitAI token validation failed: HTTP {response.status}"
                        )
                        return False

        except Exception as e:
            self.logger.error(f"CivitAI token validation error: {e}")
            return False

    async def validate_all_tokens(self) -> Dict[str, bool]:
        """
        Validate all available tokens.

        Returns:
            Dictionary with validation results for each platform
        """
        self.logger.info("Validating authentication tokens...")

        # Run validations in parallel
        hf_task = self.validate_hf_token()
        civitai_task = self.validate_civitai_token()

        hf_valid, civitai_valid = await asyncio.gather(hf_task, civitai_task)

        results = {"huggingface": hf_valid, "civitai": civitai_valid}

        # Log summary
        valid_count = sum(results.values())
        total_count = len(
            [token for token in [self.hf_token, self.civitai_token] if token]
        )

        if total_count == 0:
            self.logger.warning("No authentication tokens found")
        elif valid_count == total_count:
            self.logger.info(f"All {valid_count} tokens are valid")
        else:
            self.logger.warning(f"{valid_count}/{total_count} tokens are valid")

        return results

    async def check_repo_access(
        self, repo_id: str, platform: str = "huggingface"
    ) -> bool:
        """
        Check if we can access a specific repository.

        Args:
            repo_id: Repository ID to check
            platform: Platform ("huggingface" or "civitai")

        Returns:
            True if repository is accessible, False otherwise
        """
        if platform == "huggingface":
            return await self._check_hf_repo_access(repo_id)
        elif platform == "civitai":
            return await self._check_civitai_model_access(repo_id)
        else:
            self.logger.error(f"Unknown platform: {platform}")
            return False

    async def _check_hf_repo_access(self, repo_id: str) -> bool:
        """Check access to a HuggingFace repository."""
        if not self.hf_token:
            return False

        try:
            url = f"https://huggingface.co/api/models/{repo_id}"
            headers = {
                "Authorization": f"Bearer {self.hf_token}",
                "Content-Type": "application/json",
            }

            async with aiohttp.ClientSession() as session:
                async with session.get(url, headers=headers) as response:
                    if response.status == 200:
                        return True
                    elif response.status == 404:
                        self.logger.warning(f"Repository {repo_id} not found")
                        return False
                    elif response.status == 403:
                        self.logger.warning(f"Access denied to repository {repo_id}")
                        return False
                    else:
                        self.logger.warning(
                            f"Unexpected status {response.status} for {repo_id}"
                        )
                        return False

        except Exception as e:
            self.logger.error(f"Error checking HF repo access: {e}")
            return False

    async def _check_civitai_model_access(self, model_id: str) -> bool:
        """Check access to a CivitAI model."""
        if not self.civitai_token:
            return False

        try:
            url = f"https://civitai.com/api/v1/model-versions/{model_id}"
            headers = {
                "Authorization": f"Bearer {self.civitai_token}",
                "Content-Type": "application/json",
            }

            async with aiohttp.ClientSession() as session:
                async with session.get(url, headers=headers) as response:
                    if response.status == 200:
                        return True
                    elif response.status == 404:
                        self.logger.warning(f"Model {model_id} not found")
                        return False
                    elif response.status == 403:
                        self.logger.warning(f"Access denied to model {model_id}")
                        return False
                    else:
                        self.logger.warning(
                            f"Unexpected status {response.status} for model {model_id}"
                        )
                        return False

        except Exception as e:
            self.logger.error(f"Error checking CivitAI model access: {e}")
            return False

    def get_token_status(self) -> Dict[str, Optional[str]]:
        """
        Get status of all tokens.

        Returns:
            Dictionary with token presence status
        """
        return {
            "huggingface": "present" if self.hf_token else "missing",
            "civitai": "present" if self.civitai_token else "missing",
        }
