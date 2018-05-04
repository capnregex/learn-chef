#!/bin/bash

# from https://learn.chef.io/modules/manage-a-node-chef-server/ubuntu/bring-your-own-system/set-up-your-chef-server#step1.4
# creates the chefadmin user who's password is insecurepassword.
# creates an organization named 4thcoffee. An organization provides scope for authorization rules.
# copies an RSA private key to /drop/chefadmin.pem.

apt-get update
apt-get -y install curl

# create staging directories
if [ ! -d /drop ]; then
  mkdir /drop
fi
if [ ! -d /downloads ]; then
  mkdir /downloads
fi

# download the Chef server package
if [ ! -f /downloads/chef-server-core_12.17.33_amd64.deb ]; then
  echo "Downloading the Chef server package..."
  wget -nv -P /downloads https://packages.chef.io/files/stable/chef-server/12.17.33/ubuntu/16.04/chef-server-core_12.17.33-1_amd64.deb
fi

# install Chef server
if [ ! $(which chef-server-ctl) ]; then
  echo "Installing Chef server..."
  dpkg -i /downloads/chef-server-core_12.17.33-1_amd64.deb
  chef-server-ctl reconfigure

  echo "Waiting for services..."
  until (curl -D - http://localhost:8000/_status) | grep "200 OK"; do sleep 15s; done
  while (curl http://localhost:8000/_status) | grep "fail"; do sleep 15s; done

  echo "Creating initial user and organization..."
  chef-server-ctl user-create chefadmin Chef Admin admin@4thcoffee.com insecurepassword --filename /drop/chefadmin.pem
  chef-server-ctl org-create 4thcoffee "Fourth Coffee, Inc." --association_user chefadmin --filename 4thcoffee-validator.pem
fi

echo "Your Chef server is ready!"

## copy pem to workstation
# scp -i ~/.ssh/private_key ubuntu@ec2-54-235-228-159.compute-1.amazonaws.com:/drop/chefadmin.pem ~/learn-chef/.chef/chefadmin.pem

## knife.rb
knife_config=<<-KNIFE_CONFIG
current_dir = File.dirname(__FILE__)
log_level                 :info
log_location              STDOUT
node_name                 "chefadmin"
client_key                "#{current_dir}/chefadmin.pem"
chef_server_url           "https://ec2-54-86-187-76.compute-1.amazonaws.com/organizations/4thcoffee"
cookbook_path             ["#{current_dir}/../cookbooks"]
KNIFE_CONFIG

echo "$knife_config" > knife.rb
mv knife.rb .chef/knife.rb

knife ssl fetch
knife ssl check

