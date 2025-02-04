Challenge link: https://roadmap.sh/projects/configuration-management

# Configuration management roadmap.sh challenge

The goal of this project is to practice and become more familiar with using Ansible. In this challenge, the Ansible playbook will be used to configure a static website.

To acheive that, 4 roles were created:

- base - handles the initial server setup, installs fail2ban
- nginx - installs and configures Nginx, including setting up the domain and securing it with an SSL certificate using Certbot
- app - this role deploys the website files
- ssh - this role adds additional ssh keys to the server making it easier to grant access to team members

# Stretch goal

Additionally to the main goals, Terraform is used to provision the infrastructure and configure DNS automatically. The HCP Terraform backend is utilized, allowing collaboration across local environments and GitHub Actions runners. This ensures consistency and state management across deployments.

The entire process is integrated into a GitHub Actions pipeline, ensuring a seamless deployment experience.

To enable Ansible to work with dynamically created resources, the [dynamic inventory plugin](https://docs.ansible.com/ansible/latest/collections/community/digitalocean/digitalocean_inventory.html) is utilized. This allows Ansible to automatically discover and manage resources created by Terraform.

Certbot is used to configure SSL. By using the `--nginx` flag, it not only sets up the certificate but also configures a systemd timer to automatically check and renew the certificate when needed.

# Prerequisites

Before deploying the website, ensure you have the following:

1. [HCP Terraform account](https://app.terraform.io/) - create an organization (e.g., "roadmap-sh") and generate an [API token](https://app.terraform.io/app/settings/tokens)
2. [Digital Ocean API token](https://cloud.digitalocean.com/account/api/tokens) required for managing cloud resources on DigitalOcean
3. [CloudFlare User API token](https://dash.cloudflare.com/profile/api-tokens) with "Zone.Zone, Zone.Page Rules, Zone.DNS" permissions
4. SSH key pair - used by ansible and you to connect to the server
5. GitHub repo configured with secrets and variables, these can be set up quickly using the [`gh` cli tool](https://cli.github.com/)

   ```sh
   gh variable set ACME_EMAIL -b <email>
   gh variable set APEX_DOMAIN -b <domain>
   gh variable set SUBDOMAIN -b <subdomain>
   gh variable set DO_KEY_NAME -b <digitalocean keyname> # https://cloud.digitalocean.com/account/security

   gh secret set DIGITALOCEAN_API_TOKEN -b <digital ocean api token>
   gh secret set CLOUDFLARE_API_TOKEN -b <cloudflare api token>
   gh secret set SSH_PRIV_KEY -b "$(cat <private key file path>)"
   gh secret set HCP_TERRAFORM_TOKEN -b <hcp terraform token>
   ```

# Deploying the website

1. **Fork this repository** - if all prerequisites are met, the pipeline will automatically start and deploy the website.
2. **Clean up resources** - once you're done, you can manually destroy the Terraform-managed infrastructure to avoid unnecessary costs.

# Using tags to run specific role

```console
ansible-playbook -i inventory_digitalocean.yaml setup.yaml --tags ssh
```
In this example, only the `ssh` role was executed. This means that if we only need to add new SSH keys to the authorized keys, we can save time by using tags.
```console
PLAY [Deploy static website] *********************************************************************************************************************************************************************************************************************************************

TASK [Gathering Facts] ***************************************************************************************************************************************************************************************************************************************************
[WARNING]: Platform linux on host web is using the discovered Python interpreter at /usr/bin/python3.13, but future installation of another Python interpreter could change the meaning of that path. See https://docs.ansible.com/ansible-
core/2.18/reference_appendices/interpreter_discovery.html for more information.
ok: [web]

TASK [ssh : Add public keys from the file to the servers] ****************************************************************************************************************************************************************************************************************
ok: [web]

PLAY RECAP ***************************************************************************************************************************************************************************************************************************************************************
web                        : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

# Fail2ban example:

Fail2ban was installed with the role `base`, it was configured to block failed attempts to ssh and failed requests to the hosted website

### Example:

In the following test, repeated failed attempts to access the website result in the IP being blocked:

```console
root@ubuntu-s-1vcpu-512mb-10gb-fra1-01:~# for i in {1..10}; do curl -k https://ans.kzwolenik.com/e; done
<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx/1.26.2</center>
</body>
</html>
(...x10...)

root@ubuntu-s-1vcpu-512mb-10gb-fra1-01:~# for i in {1..10}; do curl -k https://ans.kzwolenik.com/e; done
curl: (7) Failed to connect to ans.kzwolenik.com port 443 after 8 ms: Could not connect to server
(...x10...)
```

Similarly, after multiple failed SSH login attempts, the IP is also blocked:

```console
root@ubuntu-s-1vcpu-512mb-10gb-fra1-01:~# for i in {1..10}; do ssh rsoot@104.248.249.184; done
rsoot@104.248.249.184: Permission denied (publickey,gssapi-keyex,gssapi-with-mic).
(...x10...)

root@ubuntu-s-1vcpu-512mb-10gb-fra1-01:~# for i in {1..10}; do ssh rsoot@104.248.249.184; done
ssh: connect to host 104.248.249.184 port 22: Connection refused
(...x10...)
```

As seen above, the IP can no longer access the website or attempt to SSH into the server.

### Verifying the Ban

Using the fail2ban-client command, we confirm that the IP has been banned:

FAIL2BAN

```console
[root@web ~]# fail2ban-client status nginx-errors
Status for the jail: nginx-errors
|- Filter
|  |- Currently failed:	0
|  |- Total failed:	10
|  `- File list:	/var/log/nginx/error.log
`- Actions
   |- Currently banned:	1
   |- Total banned:	1
   `- Banned IP list:	167.71.35.164

[root@web ~]# fail2ban-client status sshd
Status for the jail: sshd
|- Filter
|  |- Currently failed:	0
|  |- Total failed:	10
|  `- Journal matches:	_SYSTEMD_UNIT=sshd.service + _COMM=sshd
`- Actions
   |- Currently banned:	1
   |- Total banned:	1
   `- Banned IP list:	167.71.35.164
```

Additionally, the new entries in iptables confirm the IP has been blocked for both SSH and HTTP/HTTPS access:

```console
[root@web ~]# iptables -L -n --line-numbers
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination
1    f2b-SSH    6    --  0.0.0.0/0            0.0.0.0/0            multiport dports 22
2    f2b-HTTP_HTTPS  6    --  0.0.0.0/0            0.0.0.0/0            multiport dports 80,443

Chain FORWARD (policy ACCEPT)
num  target     prot opt source               destination

Chain OUTPUT (policy ACCEPT)
num  target     prot opt source               destination

Chain f2b-HTTP_HTTPS (1 references)
num  target     prot opt source               destination
1    REJECT     0    --  167.71.35.164        0.0.0.0/0            reject-with icmp-port-unreachable
2    RETURN     0    --  0.0.0.0/0            0.0.0.0/0

Chain f2b-SSH (1 references)
num  target     prot opt source               destination
1    REJECT     0    --  167.71.35.164        0.0.0.0/0            reject-with icmp-port-unreachable
2    RETURN     0    --  0.0.0.0/0            0.0.0.0/0

Chain f2b-http-auth (0 references)
num  target     prot opt source               destination
1    RETURN     0    --  0.0.0.0/0            0.0.0.0/0
```

This confirms that Fail2Ban is actively blocking repeated unauthorized access attempts.
