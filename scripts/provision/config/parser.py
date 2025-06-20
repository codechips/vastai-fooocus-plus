"""
Configuration parser for TOML provisioning files.
"""

import logging
import sys
from pathlib import Path
from typing import Any, Dict

import aiohttp

# Add URL processing utilities
from ..utils.urls import URLProcessor

# Handle tomllib import for different Python versions
if sys.version_info >= (3, 11):
    import tomllib
else:
    try:
        import tomli as tomllib
    except ImportError:
        raise ImportError(
            "tomli package required for Python < 3.11. Install with: pip install tomli"
        )


class ConfigParser:
    """Parses TOML configuration files for provisioning."""

    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.url_processor = URLProcessor()

    async def fetch_and_parse(self, config_url: str) -> Dict[str, Any]:
        """
        Fetch configuration from URL and parse as TOML.

        Args:
            config_url: URL to fetch configuration from

        Returns:
            Parsed configuration dictionary
        """
        try:
            self.logger.info(f"Fetching configuration from: {config_url}")
            
            # Process URL (convert Google Drive sharing links to direct download)
            processed_url = self.url_processor.process_url(config_url)
            if processed_url != config_url:
                self.logger.info(f"Processed URL for direct access: {processed_url}")

            async with aiohttp.ClientSession() as session:
                async with session.get(processed_url) as response:
                    if response.status != 200:
                        raise Exception(
                            f"Failed to fetch config: HTTP {response.status}"
                        )

                    content = await response.text()
                    
                    # Handle Google Drive virus scan warning
                    if 'drive.google.com' in processed_url and 'Google Drive - Virus scan warning' in content:
                        import re
                        # Extract the confirm download URL
                        confirm_match = re.search(r'href="(/uc\?export=download[^"]*)"', content)
                        if confirm_match:
                            new_url = 'https://drive.google.com' + confirm_match.group(1).replace('&amp;', '&')
                            self.logger.info("Handling Google Drive virus scan warning for config")
                            return await self.fetch_and_parse(new_url)
                        else:
                            raise Exception("Google Drive virus scan warning detected but couldn't find bypass URL")

            # Parse TOML content
            config = tomllib.loads(content)
            self.logger.info("Configuration parsed successfully")

            # Validate configuration
            self._validate_config(config)

            return config

        except Exception as e:
            self.logger.error(f"Failed to fetch and parse config: {e}")
            raise

    async def parse_file(self, config_path: str) -> Dict[str, Any]:
        """
        Parse local TOML configuration file.

        Args:
            config_path: Path to local configuration file

        Returns:
            Parsed configuration dictionary
        """
        try:
            self.logger.info(f"Parsing configuration file: {config_path}")

            config_file = Path(config_path)
            if not config_file.exists():
                raise Exception(f"Configuration file not found: {config_path}")

            content = config_file.read_text(encoding="utf-8")
            config = tomllib.loads(content)

            self.logger.info("Configuration parsed successfully")

            # Validate configuration
            self._validate_config(config)

            return config

        except Exception as e:
            self.logger.error(f"Failed to parse config file: {e}")
            raise

    def _validate_config(self, config: Dict[str, Any]) -> None:
        """
        Validate configuration structure.

        Args:
            config: Configuration dictionary to validate
        """
        # Check for required sections
        if "models" not in config:
            raise Exception("Configuration missing required 'models' section")

        models = config["models"]
        if not isinstance(models, dict):
            raise Exception("'models' section must be a dictionary")

        # Validate each model category
        for category, model_list in models.items():
            if not isinstance(model_list, dict):
                raise Exception(f"Model category '{category}' must be a dictionary")

            # Validate each model in the category
            for model_name, model_config in model_list.items():
                self._validate_model_config(model_name, model_config, category)

        self.logger.info("Configuration validation passed")

    def _validate_model_config(
        self, model_name: str, model_config: Any, category: str
    ) -> None:
        """
        Validate individual model configuration.

        Args:
            model_name: Name of the model
            model_config: Model configuration (can be string or dict)
            category: Model category
        """
        if isinstance(model_config, str):
            # Simple URL string - validate it looks like a URL
            if not (
                model_config.startswith("http://")
                or model_config.startswith("https://")
            ):
                raise Exception(
                    f"Model '{model_name}' URL must start with http:// or https://"
                )
            return

        if not isinstance(model_config, dict):
            raise Exception(f"Model '{model_name}' config must be string or dictionary")

        # Validate based on source type
        source = model_config.get("source", self._detect_source(model_config))

        if source == "huggingface":
            self._validate_hf_config(model_name, model_config)
        elif source == "civitai":
            self._validate_civitai_config(model_name, model_config)
        elif source == "url":
            self._validate_url_config(model_name, model_config)
        else:
            raise Exception(f"Model '{model_name}' has unknown or missing source type")

    def _detect_source(self, model_config: Dict[str, Any]) -> str:
        """Auto-detect source type from configuration."""
        if "repo" in model_config:
            return "huggingface"
        elif "model_id" in model_config:
            return "civitai"
        elif "url" in model_config:
            return "url"
        else:
            return "unknown"

    def _validate_hf_config(self, model_name: str, config: Dict[str, Any]) -> None:
        """Validate HuggingFace model configuration."""
        if "repo" not in config:
            raise Exception(
                f"HuggingFace model '{model_name}' missing required 'repo' field"
            )

        repo = config["repo"]
        if not isinstance(repo, str) or "/" not in repo:
            raise Exception(
                f"HuggingFace model '{model_name}' 'repo' must be in format 'user/repo'"
            )

        # File is optional for HF models (can download entire repo)
        if "file" in config and not isinstance(config["file"], str):
            raise Exception(f"HuggingFace model '{model_name}' 'file' must be a string")

    def _validate_civitai_config(self, model_name: str, config: Dict[str, Any]) -> None:
        """Validate CivitAI model configuration."""
        if "model_id" not in config:
            raise Exception(
                f"CivitAI model '{model_name}' missing required 'model_id' field"
            )

        model_id = config["model_id"]
        if not isinstance(model_id, (str, int)):
            raise Exception(
                f"CivitAI model '{model_name}' 'model_id' must be string or integer"
            )

        # Convert to string for consistency
        config["model_id"] = str(model_id)

    def _validate_url_config(self, model_name: str, config: Dict[str, Any]) -> None:
        """Validate direct URL model configuration."""
        if "url" not in config:
            raise Exception(f"URL model '{model_name}' missing required 'url' field")

        url = config["url"]
        if not isinstance(url, str):
            raise Exception(f"URL model '{model_name}' 'url' must be a string")

        if not (url.startswith("http://") or url.startswith("https://")):
            raise Exception(
                f"URL model '{model_name}' 'url' must start with http:// or https://"
            )

    def get_model_count(self, config: Dict[str, Any]) -> Dict[str, int]:
        """
        Get count of models by category.

        Args:
            config: Configuration dictionary

        Returns:
            Dictionary with model counts by category
        """
        counts = {}
        total = 0

        for category, models in config.get("models", {}).items():
            count = len(models) if isinstance(models, dict) else 0
            counts[category] = count
            total += count

        counts["total"] = total
        return counts

    def get_gated_models(self, config: Dict[str, Any]) -> list:
        """
        Get list of gated models from configuration.

        Args:
            config: Configuration dictionary

        Returns:
            List of gated model configurations
        """
        gated_models = []

        for category, models in config.get("models", {}).items():
            for model_name, model_config in models.items():
                if isinstance(model_config, dict) and model_config.get("gated", False):
                    gated_models.append(
                        {
                            "name": model_name,
                            "category": category,
                            "config": model_config,
                        }
                    )

        return gated_models
