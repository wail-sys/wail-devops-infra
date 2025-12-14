# Infrastructure DevOps Self-Hosted

Infrastructure de production automatisée : VPS Digital Ocean, monitoring complet, sécurité multi-couches.

🌐 **Site** : [wail-sys.com](https://wail-sys.com)
📊 **Status** : [status.wail-sys.com](https://status.wail-sys.com)

## Stack

- **VPS** : Digital Ocean (2 vCPU / 4GB RAM / 80GB SSD)
- **Containers** : 7 services Docker (Nginx, Hugo, Prometheus, Grafana, Node Exporter, cAdvisor, Uptime Kuma)
- **Database** : PostgreSQL managée (Digital Ocean)
- **IaC** : Terraform + Ansible
- **Monitoring** : Prometheus + Grafana (rétention 30j)
- **Sécurité** : Cloudflare CDN/DDoS, UFW, Fail2ban, Tailscale VPN, SSL Let's Encrypt

## Déploiement

### Prérequis

```bash
# Outils nécessaires
terraform >= 1.5
ansible >= 2.15
hugo >= 0.121
```

### Variables

```bash
# Terraform
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Éditer terraform.tfvars avec vos tokens

# Ansible Vault
ansible-vault create ansible/group_vars/all/vault.yml
# Ajouter : vault_db_password, vault_grafana_password, etc.
```

### Déploiement complet (< 15 min)

```bash
# 1. Provisionner VPS
cd terraform && terraform apply

# 2. Configurer infrastructure
cd ../ansible
ansible-playbook playbooks/01-security.yml
ansible-playbook playbooks/02-ssh-vpn.yml
ansible-playbook playbooks/03-docker.yml
ansible-playbook playbooks/04-deploy-stack.yml
ansible-playbook playbooks/05-ssl.yml

# 3. Déployer site
ansible-playbook playbooks/06-deploy-site.yml
```

## Structure

```
.
├── terraform/          # Provisioning VPS
├── ansible/            # Configuration et déploiement
│   ├── inventory/      # Hosts
│   ├── group_vars/     # Variables (vault chiffré)
│   └── playbooks/      # Playbooks numérotés
├── monitoring/         # Docker Compose + configs
│   ├── prometheus/     # Métriques
│   ├── grafana/        # Dashboards
│   └── nginx/          # Reverse proxy
└── portfolio/          # Site Hugo
```

## Playbooks

1. **01-security.yml** - Sécurisation système (UFW, Fail2ban, updates)
2. **02-ssh-vpn.yml** - SSH via Tailscale uniquement
3. **03-docker.yml** - Installation Docker + Docker Compose
4. **04-deploy-stack.yml** - Déploiement conteneurs (Nginx, monitoring, Uptime Kuma)
5. **05-ssl.yml** - Certificats Let's Encrypt
6. **06-deploy-site.yml** - Build et déploiement Hugo

## Sécurité

- **Layer 1** : Cloudflare (DDoS, CDN), UFW (ports 22/80/443), Fail2ban
- **Layer 2** : SSH via VPN Tailscale uniquement, clé ED25519
- **Layer 3** : Conteneurs isolés (réseaux Docker séparés)
- **Layer 4** : Grafana/Prometheus accessibles uniquement via VPN
- **Layer 5** : Updates automatiques (unattended-upgrades)

## Monitoring

- **Métriques système** : Node Exporter
- **Métriques conteneurs** : cAdvisor
- **Collecte** : Prometheus (scraping 15s, rétention 30j)
- **Visualisation** : Grafana (VPN only)
- **Status public** : Uptime Kuma

## Maintenance

```bash
# Update site
ansible-playbook playbooks/06-deploy-site.yml

# Rebuild stack
ansible-playbook playbooks/04-deploy-stack.yml

# Check services
ssh -J tailscale vps
docker ps
docker-compose -f /opt/docker/docker-compose.yml logs
```

## License

MIT
