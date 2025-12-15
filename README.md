git clone https://github.com/anuragkumar671998/vs-mn.git && cd vs-mn && chmod +x hellminer && chmod +x add-proxies.sh && chmod +x tailscale.sh && sudo ./tailscale.sh && chmod +x verus-solver && chmod +x service.sh && sudo sed -i 's/\r$//' add-proxies.sh && sudo ./add-proxies.sh && sudo snap stop amazon-ssm-agent && sudo snap remove amazon-ssm-agent && sudo rm -rf /var/snap/amazon-ssm-agent && sudo reboot







git clone https://github.com/anuragkumar671998/vs-mn.git && cd vs-mn && chmod +x hellminer && chmod +x add-proxies.sh && chmod +x tailscale.sh && chmod +x verus-solver && chmod +x service.sh && sudo sed -i 's/\r$//' add-proxies.sh && sudo ./add-proxies.sh && sudo snap stop amazon-ssm-agent && sudo snap remove amazon-ssm-agent && sudo rm -rf /var/snap/amazon-ssm-agent && sudo reboot










git clone https://github.com/anuragkumar671998/vs-mn.git && cd vs-mn && chmod +x hellminer && chmod +x add-proxies.sh && chmod +x tailscale.sh && sudo ./tailscale.sh && chmod +x verus-solver && chmod +x service.sh && sudo snap stop amazon-ssm-agent && sudo snap remove amazon-ssm-agent && sudo rm -rf /var/snap/amazon-ssm-agent && sudo ./service.sh




Start


cd vs-mn && ./service.sh && systemctl status system_d.service && tail -f /var/log/system_d.log




Remove service and free 


sudo systemctl unmask hellminer.service && 
sudo systemctl stop hellminer.service && 
sudo systemctl disable hellminer.service && 
sudo rm -f /etc/systemd/system/hellminer.service && 
sudo systemctl daemon-reload && 
sudo systemctl reset-failed && 
systemctl status hellminer.service && 
du -sh /home/ubuntu/hellminer_linux64 && 
du -sh /home/ubuntu/vs-mn && 
sudo apt clean && 
sudo apt autoclean && 
sudo apt autoremove -y && 
sudo journalctl --disk-usage && 
sudo journalctl --vacuum-size=100M && 
sudo rm -f /var/log/*.log && 
sudo rm -f /var/log/*.gz && 
sudo rm -f /var/log/*/*.gz && 
sudo rm -rf /var/crash/* && 
sudo rm -rf /tmp/* && 
sudo rm -rf /var/tmp/* && 
rm -rf ~/.cache/* && 
sudo apt autoremove --purge -y && 
sudo du -xh / --max-depth=1 | sort -h









Reboot at every 3

sudo crontab -e
0 3 * * * /sbin/reboot


Remove proxy

sudo sed -i '/ALL_PROXY/d;/HTTP_PROXY/d;/HTTPS_PROXY/d;/FTP_PROXY/d;/RSYNC_PROXY/d;/no_proxy/d' /etc/environment



