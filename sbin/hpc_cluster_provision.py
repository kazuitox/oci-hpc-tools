#!/usr/bin/python

import sys
import os
import time
import uuid
import json
import time
import random
import subprocess
import shutil
import socket
import ipaddress
# import re

USER = "opc"
PROG_NAME = sys.argv[0]
API_VERSION = "1.5"
# 4K addresses
DEFAULT_RDMA_SUBNET_IP = u'192.168.240.0/20'

def get_cluster_config(json_config_file):
	f = open(sys.argv[2], "r")
	json_s = f.read()
	cfg = json.loads(json_s)
	return cfg

def get_local_node(json_config_file):
	cfg = get_cluster_config(json_config_file)
	for node in cfg['nodes']:
		if socket.getfqdn() == node['hostname_fqdn']:
			if node['deleted'] != 0:
				return None
			else:
				return node
	return None

def get_local_node_provisioned():
	if len(sys.argv) < 3:
		print(PROG_NAME + ": usage: " + PROG_NAME + " " + sys.argv[1] + " cluster_config.json")
		exit(1)
	#print(PROG_NAME + ": get_local_node_provisioned " + sys.argv[2])
	node = get_local_node(sys.argv[2])
	if node is None:
		print "deleted"
		return
	print "provisioned"

def get_local_rdma_ip_address():
	if len(sys.argv) < 3:
		print(PROG_NAME + ": usage: " + PROG_NAME + " " + sys.argv[1] + " cluster_config.json")
		exit(1)
	#print(PROG_NAME + ": get_local_rdma_ip_adress " + sys.argv[2])
	node = get_local_node(sys.argv[2])
	if node is None:
		print "deleted"
		return
	print(node['rdma_ip'])

def get_local_rdma_ip_subnet_mask():
	if len(sys.argv) < 3:
		print(PROG_NAME + ": usage: " + PROG_NAME + " " + sys.argv[1] + " cluster_config.json")
		exit(1)
	#print(PROG_NAME + ": get_local_rdma_ip_subnet_mask " + sys.argv[2])
	node = get_local_node(sys.argv[2])
	if node is None:
		print "deleted"
		return
	print(node['rdma_ip_netmask'])

def get_ssh_key(key_name):
	if len(sys.argv) < 3:
		print(PROG_NAME + ": usage: " + PROG_NAME + " " + sys.argv[1] + " cluster_config.json")
		exit(1)
	cfg = get_cluster_config(sys.argv[2])
	print(cfg['ssh_intracluster'][key_name].rstrip('\n'))

def get_localvolume():
	if len(sys.argv) < 3:
		print(PROG_NAME + ": usage: " + PROG_NAME + " " + sys.argv[1] + " cluster_config.json")
		exit(1)
	cfg = get_cluster_config(sys.argv[2])
	print(cfg['localvolume_path'])

def get_nfs_server_config():
	if len(sys.argv) < 3:
		print(PROG_NAME + ": usage: " + PROG_NAME + " " + sys.argv[1] + " cluster_config.json")
		exit(1)
	cfg = get_cluster_config(sys.argv[2])
	if cfg['nfs_server']['nfs_setup'] == 0:
		print("none none.none /dev/null /dev/null")
		return
	#
	node = get_local_node(sys.argv[2])
	if node is None:
		print("deleted")
		return
	if node['is_nfs_server'] != 0:
		nfs_server_role = "server"
	else:
		nfs_server_role = "client"
	nfs_server = cfg['nfs_server']['nfs_server_vcn_hostname_fqdn']
	# if it doesn't have an absolute path, it's relative to cfg['localvolume'] path
	nfs_export = cfg['nfs_server']['export_path']
	nfs_mount = cfg['nfs_server']['mount_path']
	print(nfs_server_role + " " + nfs_server + " " + nfs_export + " " + nfs_mount)

def get_etchosts_nfs():
	if len(sys.argv) < 3:
		print(PROG_NAME + ": usage: " + PROG_NAME + " " + sys.argv[1] + " cluster_config.json")
		exit(1)
	print('# nfs host')
	cfg = get_cluster_config(sys.argv[2])
	nfs = cfg['nfs_server']
	if nfs['nfs_setup'] == 0:
		return
	print(nfs['nfs_server_vcn_ip'] + ' ' + nfs['nfs_server_vcn_hostname_fqdn'] + ' ' + nfs['nfs_server_vcn_hostname'])

def get_etchosts(comment, hostname_fqdn, hostname, host_ip):
	if len(sys.argv) < 3:
		print(PROG_NAME + ": usage: " + PROG_NAME + " " + sys.argv[1] + " cluster_config.json")
		exit(1)
	print(comment)
	cfg = get_cluster_config(sys.argv[2])
	for node in cfg['nodes']:
		#print(PROG_NAME + ": get_etchosts: " + socket.getfqdn() + ": " + node['hostname_fqdn'])
		if node['deleted'] != 0:
			#print(PROG_NAME + ": etchosts: node is deleted")
			continue
		print(node[host_ip] + ' ' + node[hostname_fqdn] + ' ' + node[hostname])


def main():
	if len(sys.argv) < 2:
		# every command has a minimum of one argument
		print(PROG_NAME + ": usage: " + PROG_NAME + " get-api-version")
		print(PROG_NAME + ": usage: " + PROG_NAME + " get-etchosts-vcn|get-etchosts-rdma|get-etchosts|get-etchosts-nfs cluster_config.json")
		print(PROG_NAME + ": usage: " + PROG_NAME + " get-local-rdma-ip-address|get-local-rdma-ip-subnet-mask cluster_config.json")
		print(PROG_NAME + ": usage: " + PROG_NAME + " get-ssh-private-key|get-ssh-public-key cluster_config.json")
		print(PROG_NAME + ": usage: " + PROG_NAME + " get-localvolume|get-nfs-server-config cluster_config.json")
		exit(1)
	if sys.argv[1] == "get-api-version":
		print(API_VERSION)
		exit(0)
	if sys.argv[1] == "get-local-node-provisioned":
		get_local_node_provisioned()
		exit(0)
	if sys.argv[1] == "get-etchosts-vcn":
		get_etchosts('# vcn hosts', 'vcn_hostname_fqdn', 'vcn_hostname', 'vcn_ip')
		exit(0)
	if sys.argv[1] == "get-etchosts-rdma":
		get_etchosts('# rdma hosts', 'rdma_hostname_fqdn', 'rdma_hostname', 'rdma_ip')
		exit(0)
	if sys.argv[1] == "get-etchosts":
		get_etchosts('# hosts', 'hostname_fqdn', 'hostname', 'vcn_ip')
		exit(0)
	if sys.argv[1] == "get-etchosts-nfs":
		get_etchosts_nfs()
		exit(0)
	if sys.argv[1] == "get-local-rdma-ip-address":
		get_local_rdma_ip_address()
		exit(0)
	if sys.argv[1] == "get-local-rdma-ip-subnet-mask":
		get_local_rdma_ip_subnet_mask()
		exit(0)
	if sys.argv[1] == "get-ssh-private-key":
		get_ssh_key('private_key')
		exit(0)
	if sys.argv[1] == "get-ssh-public-key":
		get_ssh_key('public_key')
		exit(0)
	if sys.argv[1] == "get-localvolume":
		get_localvolume()
		exit(0)
	if sys.argv[1] == "get-nfs-server-config":
		get_nfs_server_config()
		exit(0)
	print(PROG_NAME + ": unknown command " + sys.argv[1])
	exit(1)

main()
