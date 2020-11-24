sudo pacman -S libvirt qemu-headless ebtables virt-manager 
sudo systemctl start libvirt
sudo systemctl enable libvirt
systemctl status libvirt