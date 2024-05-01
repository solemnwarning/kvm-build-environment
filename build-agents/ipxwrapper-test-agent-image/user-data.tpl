#cloud-config

growpart:
  mode: false

users:
  - name: root
    ssh_authorized_keys:
      - ${ ssh_public_key }
