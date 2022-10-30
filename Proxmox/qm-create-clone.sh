#!/bin/bash

image_dir="/root/images"
cd $image_dir

# VM Configurations
VM_IMAGE="debian-11-generic-amd64.qcow2"
VM_NAME="${VM_IMAGE:0:17}"
VM_BRIDGE="vmbr0"
VM_NET="virtio"
VM_DISK="Royale"
VM_DOMAIN="typhon.tech"
VM_DNS="8.8.8.8"

resources_vm () {
  read -p "What type of VM: 'good, better, super' " vm_type

  case $vm_type in

    good)

     VM_CPU="1"
     VM_MEM="1024"
     ;;

    better)

     VM_CPU="2"
     VM_MEM="2048"
     ;;

    super)

     VM_CPU="4"
     VM_MEM="4096"
     ;;

    *)
     echo "Unknown option for VM type."
    ;;

  esac

}

cloud_init_conf () {

  read -p 'User name for CI User: ' cloud_user
  echo "ciuser: $cloud_user" | tee -a /etc/pve/qemu-server/${VM_ID}.conf
  echo "ipconfig0: ip=dhcp" | tee -a /etc/pve/qemu-server/${VM_ID}.conf

}

set_dns () {
  read -p 'Do you want to change DNS settings? [Y,N]: ' dns_ans

  if [[ $dns_ans == 'Y' || $dns_ans == 'y' ]]
  then
    read -p 'Domain Name: ' VM_DOMAIN
    read -p 'DNS: ' VM_DNS
  elif [[ $dns_ans == 'N' || $dns_ans == 'n' ]]
  then
    echo "Using host settings!"
  else
    echo "Invalid option!"
  fi
}


check_vmid () {

  # Enter the directory
  cd /etc/pve/qemu-server

  # List all files and store in array
  for file in *.conf; do arrFiles=(${arrFiles[@]} "$file"); done

  # Get user input for VMID
  read -p 'Set ID for the VM: ' VM_ID

  # Remove .conf from
  while [[ " ${arrFiles[@]/.conf} " =~ " ${VM_ID} " ]]
  do
    read -p "VM ID is in use, enter a new one: " VM_ID
  done

}


create_vm () {
  # Get the VMs resources
  resources_vm

  # Ask for DNS
  set_dns

  # Check for the VMID
  check_vmid
  echo $VM_ID

  qm create $VM_ID --memory $VM_MEM --core $VM_CPU --name $VM_NAME --net0 $VM_NET,bridge=$VM_BRIDGE
  qm importdisk $VM_ID $VM_IMAGE $VM_DISK
  qm set $VM_ID --scsihw virtio-scsi-pci --scsi0 $VM_DISK:vm-$VM_ID-disk-0
  qm set $VM_ID --ide2 $VM_DISK:cloudinit
  qm set $VM_ID --boot c --bootdisk scsi0
  qm set $VM_ID --serial0 socket --vga serial0

}

read -p 'Create a template or clone: ' qm_type

case $qm_type in

  template | temp)

    # Create the VM
    create_vm

    # Call the function
    cloud_init_conf

    # Set the DNS
    set_dns

    ;;

  clone)

    read -p 'Enter the VMID to clone: ' clone_id
    read -p 'Enter the VMID for the clone machine: ' clone_machine
    read -p 'Full or linked: ' clone_type
    read -p 'Clone Name: '

    if [[ clone_type == 'full' ]]
    then
      qm clone $clone_id $clone_machine --full
    else
      qm clone $clone_id $clone_machine
    fi
    ;;

  *)
    echo "Unknown option for VM type."
    ;;

esac
