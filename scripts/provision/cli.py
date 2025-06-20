"""
Command-line interface for the provisioning system.
"""

import argparse
import asyncio
import sys

from .core import ProvisioningSystem


def main() -> None:
    """Main entry point for provisioning."""
    parser = argparse.ArgumentParser(
        description="VastAI Fooocus Plus Provisioning System - Download models from various sources",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s config.toml                    # Provision from local config file
  %(prog)s http://example.com/config.toml # Provision from remote config
  %(prog)s config.toml --dry-run          # Validate config without downloading

Environment Variables:
  WORKSPACE      - Target directory for models (default: /workspace)
  HF_TOKEN       - HuggingFace API token for gated models
  CIVITAI_TOKEN  - CivitAI API token for some models
        """,
    )

    parser.add_argument("config", help="Path to TOML config file or URL")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate configuration and tokens without downloading models",
    )
    parser.add_argument(
        "--workspace",
        help="Override workspace directory (default: $WORKSPACE or /workspace)",
    )

    args = parser.parse_args()

    # Run the async main function
    asyncio.run(async_main(args))


async def async_main(args: argparse.Namespace) -> None:
    """Async main function."""
    # Create provisioner with custom workspace if specified
    provisioner = ProvisioningSystem(args.workspace)

    # For dry run, we'll add a dry_run parameter to the provisioning methods
    if args.dry_run:
        provisioner.dry_run = True
        print("🔍 Dry run mode - validating configuration without downloading")

    # Determine if source is URL or file path
    if args.config.startswith(("http://", "https://")):
        success = await provisioner.provision_from_url(args.config)
    else:
        success = await provisioner.provision_from_file(args.config)

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()