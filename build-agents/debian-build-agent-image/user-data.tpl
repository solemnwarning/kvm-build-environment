#cloud-config

users:
  - name: root
    ssh_authorized_keys:
      - ${ ssh_public_key }
