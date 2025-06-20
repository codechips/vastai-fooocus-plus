#!/usr/bin/env bash
# Model provisioning service

function run_provisioning() {
    # Check if provisioning is enabled
    if [[ -z "${PROVISION_URL}" ]]; then
        echo "provisioning: PROVISION_URL not set, skipping model provisioning"
        return
    fi

    echo "provisioning: starting model provisioning"
    echo "provisioning: config URL: ${PROVISION_URL}"

    # Run provisioning script (uv will handle dependencies automatically)
    echo "provisioning: downloading models..."
    if /opt/provision/provision.py "${PROVISION_URL}"; then
        echo "provisioning: completed successfully"
    else
        echo "provisioning: failed, but continuing startup"
        echo "provisioning: check /workspace/logs/provision.log for details"
    fi
}

# Main execution if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_provisioning
fi