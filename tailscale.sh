curl -fsSL https://tailscale.com/install.sh | sh
sudo snap stop amazon-ssm-agent
sudo snap remove amazon-ssm-agent
sudo rm -rf /var/snap/amazon-ssm-agent
