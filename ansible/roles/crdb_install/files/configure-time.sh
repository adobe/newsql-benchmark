cd ~
curl -O https://raw.githubusercontent.com/torvalds/linux/master/tools/hv/lsvmbus
python lsvmbus -vv | grep -w "Time Synchronization" -A 3
echo 2dd1ce17-079e-403c-b352-a1921ee207ee | sudo tee /sys/bus/vmbus/drivers/hv_util/unbind
sudo service ntp stop
sudo ntpd -b time.google.com
sudo service ntp start
sudo ntpq -p