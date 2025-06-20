#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "aiohttp",
#     "tomli",
#     "huggingface_hub[hf_transfer]",
# ]
# ///
"""
VastAI Fooocus Plus Provisioning System

Wrapper script that uses the provision package.
This maintains compatibility with the uv script approach while using the new package structure.
"""

import sys
from pathlib import Path

# Add src directory to Python path so we can import the provision package
src_dir = Path(__file__).parent / "src"
sys.path.insert(0, str(src_dir))

# Import and run the CLI
from provision.cli import main

if __name__ == "__main__":
    main()