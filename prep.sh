#!/bin/bash
read -r -p "Is this a Master or Slave node? (slave) " node_choice
case "$node_choice" in
  master|Master ) node_type=master;;
  slave|Slave ) node_type=slave;;
  * ) node_type=slave;;
esac

echo "Installing Docker"
curl -sSL get.docker.com | sh

if uname -a | grep hypriot; then
os_type=hypriot
elif uname -a | grep raspbian; then
os_type=raspbian
elif id pi > /dev/null; then
os_type=raspbian
fi

if [[ "$os_type" == "raspbian" ]]; then
sudo usermod pi -aG docker
elif [[ "$os_type" == "hypriot" ]]; then
sudo usermod pirate -aG docker
else
echo "OS type not known"
exit 1
fi

installed_docker_version=$(apt-cache policy docker-ce | grep "Installed" | cut -d ":" -f 2)
echo 
echo "$installed_docker_version is currently installed."
read -r -p "Do you need to install a different version? (no) " docker_choice
echo
case "$docker_choice" in
  y|Y ) apt-cache madison docker-ce | cut -d "|" -f 2 && \
  echo 
  read -r -p "Which Docker version do you want to install (e.g. 18.05.0~ce~3-0~ubuntu)? " docker_version && \
  sudo apt-get install -qy docker-ce="$docker_version";;
  n|N );;
  * );;
esac

echo

echo "Disabling Swap"
sudo dphys-swapfile swapoff && \
sudo dphys-swapfile uninstall && \
sudo update-rc.d dphys-swapfile remove

echo 

echo "Installing Kubernetes"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - && \
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list && \
sudo apt-get update -q

echo 

installed_kuber_version=$(apt-cache policy kubeadm | grep "Installed" | cut -d ":" -f 2)
echo "$installed_kuber_version is currently installed."
read -r -p " Use latest Kubeadm version? (yes) " kuber_choice
case "$kuber_choice" in
  n|N ) read -r -p "Which version of Kubernetes do you want to install (e.g. 1.10.2-00)? " kuber_version
  sudo apt-get install -qy kubeadm="$kuber_version" kubectl="$kuber_version" kubelet="$kuber_version";;
  y|Y ) sudo apt-get install -qy kubeadm kubectl kubelet;;
esac

echo 

echo "Docker $(apt-cache policy docker-ce | grep "Installed" | cut -d ":" -f 2) is installed"
read -r -p "Do you want to prevent docker-ce from being upgraded? (no) " upgrade_docker
case $upgrade_docker in
  y|Y ) echo "docker-ce hold" | sudo dpkg --set-selections; echo "done";;
  n|N );;
  * );;
esac

echo 

echo "Kubeadm $(apt-cache policy kubeadm | grep "Installed" | cut -d ":" -f 2) is installed"
read -r -p "Do you want to prevent kubeadm from being upgraded? (no) " upgrade_kuber
case "$upgrade_kuber" in
  y|Y ) echo "kubeadm hold" | sudo dpkg --set-selections; echo "done";;
  n|N );;
  * );;
esac

echo 

echo "Backing up cmdline.txt to /boot/cmdline_backup.txt"
sudo cp /boot/cmdline.txt /boot/cmdline_backup.txt

echo 

echo Adding " cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory " to /boot/cmdline.txt
orig="$(head -n1 /boot/cmdline.txt) cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory"
echo "$orig" | sudo tee /boot/cmdline.txt

if [[ "$node_type" == "master" ]]; then
    echo "Removing \"KUBELET_NETWORK_ARGS\" from 10-kubeadm.conf"
    sudo sed -i '/KUBELET_NETWORK_ARGS=/d' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    echo "Please reboot"
    exit 0
elif [[ "$node_type" == "slave" ]]; then
echo "Please reboot"
exit 0
fi
