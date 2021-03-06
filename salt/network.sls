# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "map.jinja" import network with context %}
{% set role = salt['environ.get']('RISE_ROLE', 'secondary') %}
{% set hostname = grains['host'] %}
{% set domain = salt['environ.get']('RISE_DOMAIN') %}
{% set public_ip = salt['environ.get']('RISE_PUBLIC_IP') %}
{% set main_interface = salt['environ.get']('RISE_MAIN_INTERFACE', 'network.main_interface') %}
{% set cluster_interface = salt['environ.get']('RISE_CLUSTER_INTERFACE', 'network.cluster_interface') %}

Configure system:
  network.system:
    - enabled: True
    - hostname: {{ hostname }}
    - nisdomain: {{ domain }}
    - apply_hostname: True
    - retain_settings: True

Configure main network:
  network.managed:
    - name: {{ main_interface }}
    - type: eth
    - proto: dhcp
    - require:
      - network: Configure system

Configure primary host alias:
  host.present:
    - ip: {{ network.primary_address }}
    - names:
      - primary.{{ domain }}
      - primary

Configure secondary host alias:
  host.present:
    - ip: {{ network.secondary_address }}
    - names:
      - secondary.{{ domain }}
      - secondary

{% if role == 'primary' %}
Configure cluster network:
  network.managed:
    - name: {{ cluster_interface }}
    - type: eth
    - proto: static
    - ipaddr: {{ network.primary_address }}
    - netmask: {{ network.cluster_netmask }}
    - require:
      - network: Configure system

Add public IP to cluster:
  pcs.resource_present:
    - name: ip__resource_present_public
    - resource_id: PublicIp
    - resource_type: ocf:heartbeat:IPaddr2
    - resource_options:
      - 'ip={{ public_ip }}'
      - 'cidr_netmask=32'
      - 'nic={{ network.main_interface }}'
      - 'op'
      - 'monitor'
      - 'interval=30s'
    - require:
      - pcs: Setup cluster

Public IP colocation:
  pcs.constraint_present:
    - name: network__constraint_present_publicip_colocation
    - constraint_id: colocation-publicip-fs_r0
    - constraint_type: colocation
    - constraint_options:
      - 'add'
      - 'PublicIp'
      - 'with'
      - 'fs_r0'
    - require:
      - pcs: Add public IP to cluster
      - pcs: Add filesystem to cluster

{% else %}
Configure cluster network:
  network.managed:
    - name: {{ cluster_interface }}
    - type: eth
    - proto: static
    - ipaddr: {{ network.secondary_address }}
    - netmask: {{ network.cluster_netmask }}
    - require:
      - network: Configure system

{% endif %}
