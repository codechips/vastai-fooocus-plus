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

Main entry point script for model provisioning.
"""

if __name__ == "__main__":
    import sys
    from pathlib import Path
    
    # When running as a script, we need to handle imports differently
    script_dir = Path(__file__).parent
    
    # Add the parent of the provision package to sys.path
    sys.path.insert(0, str(script_dir.parent))
    
    # Now we can import from the provision package using absolute imports
    from provision.cli import main
    main()