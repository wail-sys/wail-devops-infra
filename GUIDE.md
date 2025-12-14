# Guide Pédagogique - Infrastructure DevOps

Guide complet pour débutant : comprendre, maintenir et reproduire cette infrastructure.

---

## 📚 Table des matières

1. [Concepts fondamentaux](#1-concepts-fondamentaux)
2. [Architecture globale](#2-architecture-globale)
3. [Infrastructure as Code](#3-infrastructure-as-code)
4. [Sécurité en couches](#4-sécurité-en-couches)
5. [Monitoring](#5-monitoring)
6. [Commandes essentielles](#6-commandes-essentielles)
7. [Troubleshooting](#7-troubleshooting)
8. [Scénarios de maintenance](#8-scénarios-de-maintenance)

---

## 1. Concepts fondamentaux

### Qu'est-ce que l'Infrastructure as Code (IaC) ?

**Problème sans IaC** :
- Tu configures ton serveur manuellement (SSH, commandes une par une)
- 6 mois plus tard, le serveur plante
- Tu ne te souviens plus de ce que tu as fait
- Impossible de reproduire l'infra

**Solution avec IaC** :
- Toute la config est dans des fichiers (Terraform, Ansible)
- Tu peux recréer l'infra en 15 min avec quelques commandes
- Versioning Git : tu vois qui a changé quoi et quand
- Reproductible à l'infini (dev, staging, prod)

### Terraform vs Ansible : Qui fait quoi ?

**Terraform** = Création infrastructure cloud
- Crée le VPS sur Digital Ocean
- Crée la base de données PostgreSQL
- Configure le réseau

**Ansible** = Configuration serveurs
- Installe les logiciels (Docker, Nginx, etc.)
- Configure la sécurité (firewall, SSH)
- Déploie les applications

**Analogie** :
- Terraform = Construire une maison (fondations, murs)
- Ansible = Aménager la maison (meubles, décoration)

### Docker : Pourquoi des conteneurs ?

**Sans Docker** :
- Tu installes directement Nginx, Prometheus, Grafana sur le serveur
- Conflit de dépendances (version Python différente entre apps)
- Si une app plante, elle peut crasher tout le serveur

**Avec Docker** :
- Chaque app tourne dans sa "boîte" isolée (conteneur)
- Si Grafana plante, Nginx continue de fonctionner
- Rollback facile : retour version précédente en 30s

**Docker Compose** :
- Fichier YAML qui dit "lance 7 conteneurs ensemble"
- Une commande : `docker compose up -d`
- Tout démarre automatiquement

---

## 2. Architecture globale

### Flux complet d'une requête utilisateur

```
1. Utilisateur tape wail-sys.com dans son navigateur
   ↓
2. DNS Cloudflare renvoie l'IP du VPS
   ↓
3. Requête passe par Cloudflare (proxy, DDoS protection, cache)
   ↓
4. Cloudflare envoie au VPS
   ↓
5. Firewall UFW vérifie (ports 80/443 autorisés)
   ↓
6. Nginx (conteneur Docker) reçoit la requête
   ↓
7. Nginx sert le fichier HTML statique (Hugo)
   ↓
8. Réponse renvoyée à l'utilisateur
```

### Les 7 conteneurs Docker

1. **Nginx** : Reverse proxy (reçoit toutes les requêtes HTTPS)
2. **Hugo** : Site statique (juste des fichiers HTML)
3. **Prometheus** : Collecte métriques (CPU, RAM, disque)
4. **Grafana** : Affiche métriques sous forme de graphiques
5. **Node Exporter** : Donne métriques système à Prometheus
6. **cAdvisor** : Donne métriques Docker à Prometheus
7. **Uptime Kuma** : Page status publique (status.wail-sys.com)

### Réseaux Docker

**Réseau "web"** :
- Nginx
- Uptime Kuma
- Exposés sur Internet

**Réseau "monitoring"** :
- Prometheus
- Grafana
- Node Exporter
- cAdvisor
- Accessible uniquement via VPN Tailscale

**Isolation** : Si Nginx est hacké, l'attaquant ne peut pas atteindre Grafana (réseaux séparés).

---

## 3. Infrastructure as Code

### Déploiement complet depuis zéro

#### Étape 1 : Terraform (Provisioning)

```bash
cd terraform
terraform init      # Télécharge provider Digital Ocean
terraform plan      # Montre ce qui va être créé
terraform apply     # Crée VPS + Base PostgreSQL
```

**Ce que fait Terraform** :
- Crée VPS 2 vCPU / 4GB RAM à Frankfurt
- Upload ta clé SSH publique
- Crée base PostgreSQL managée
- Autorise VPS à se connecter à la base

**Outputs** :
- IP du serveur
- Info connexion base de données

#### Étape 2 : Ansible (Configuration)

```bash
cd ../ansible

# 1. Sécurisation
ansible-playbook playbooks/01-security.yml
# Crée user wail, hardening SSH, firewall UFW, Fail2ban

# 2. SSH via VPN uniquement
ansible-playbook playbooks/02-ssh-vpn.yml
# Installe Tailscale, SSH écoute uniquement sur VPN

# 3. Docker
ansible-playbook playbooks/03-docker.yml
# Installe Docker + Docker Compose

# 4. Stack monitoring
ansible-playbook playbooks/04-deploy-stack.yml
# Déploie les 7 conteneurs

# 5. SSL Let's Encrypt
ansible-playbook playbooks/05-ssl.yml
# Certificats HTTPS gratuits (renouvellement auto)

# 6. Site Hugo
ansible-playbook playbooks/06-deploy-site.yml
# Build Hugo + déploiement via rsync
```

### Comment fonctionnent les playbooks

**Exemple : 01-security.yml**

```yaml
- name: Sécurisation initiale VPS
  hosts: vps          # Cible : serveur défini dans inventory/hosts.yml
  become: yes         # Exécute en sudo

  tasks:
    - name: Création utilisateur wail
      user:
        name: wail
        groups: sudo
```

**Ansible** :
1. Lit `inventory/hosts.yml` pour trouver IP du serveur
2. Se connecte en SSH
3. Exécute chaque tâche une par une
4. Idempotent : si déjà fait, ne refait pas

### Variables et secrets

**Fichiers** :
- `group_vars/all/all.yml` : Variables non-sensibles
- `group_vars/all/vault.yml` : Secrets chiffrés (Ansible Vault)

**Ansible Vault** :
```bash
# Éditer secrets
ansible-vault edit group_vars/all/vault.yml

# Playbook va demander mot de passe vault automatiquement
```

---

## 4. Sécurité en couches

### Layer 1 : Protection réseau

**Cloudflare** :
- Absorbe attaques DDoS avant qu'elles atteignent le VPS
- Cache fichiers statiques (moins de charge serveur)
- Masque IP réelle du serveur

**UFW (Firewall)** :
```bash
# Voir règles actuelles
sudo ufw status

# Seuls 3 ports ouverts : 22 (SSH), 80 (HTTP), 443 (HTTPS)
```

**Fail2ban** :
```bash
# Voir IPs bannies
sudo fail2ban-client status sshd

# Débannir une IP
sudo fail2ban-client set sshd unbanip 1.2.3.4
```

### Layer 2 : SSH via VPN uniquement

**Problème** : SSH accessible depuis Internet = cible brute force

**Solution** :
- SSH écoute seulement sur interface Tailscale (100.x.x.x)
- Depuis Internet : port 22 fermé (invisible)
- Pour se connecter : d'abord VPN, puis SSH

**Connexion** :
```bash
# 1. Connecter au VPN Tailscale (depuis WSL)
tailscale up

# 2. SSH via IP Tailscale du VPS
ssh wail@100.x.x.x
```

### Layer 3 : Isolation conteneurs

**Réseaux Docker séparés** :
- `web` : Nginx, Uptime Kuma (public)
- `monitoring` : Grafana, Prometheus (VPN only)

**Si compromission Nginx** :
- Attaquant enfermé dans conteneur Nginx
- Ne peut pas accéder à Grafana (réseau différent)
- Ne peut pas accéder au système hôte (user non-root)

### Layer 4 : Mises à jour automatiques

**unattended-upgrades** :
- Installe patchs de sécurité Ubuntu chaque nuit
- Pas besoin d'intervention manuelle

**Conteneurs Docker** :
- À mettre à jour manuellement (contrôle total)
- Modifier version image dans `docker-compose.yml`
- Relancer : `docker compose up -d`

---

## 5. Monitoring

### Prometheus : Collecte métriques

**Ce qu'il fait** :
- Scrape (récupère) métriques toutes les 15 secondes
- Stocke dans base de données temps réel (TSDB)
- Garde données 30 jours

**Sources** :
- **Node Exporter** : CPU, RAM, disque, réseau du VPS
- **cAdvisor** : Métriques par conteneur Docker

**Requêtes PromQL** (exemples) :
```promql
# CPU utilisé par le serveur
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# RAM utilisée
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100

# Espace disque restant
node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100
```

### Grafana : Visualisation

**Accès** :
1. Connecter au VPN Tailscale
2. Navigateur : `http://100.x.x.x:3000`
3. Login : admin / (mot de passe dans vault.yml)

**Dashboards recommandés** :
- Node Exporter Full (ID: 1860)
- Docker monitoring (ID: 193)

**Import dashboard** :
1. Grafana → + → Import
2. Entrer l'ID (ex: 1860)
3. Sélectionner datasource : Prometheus
4. Import

### Uptime Kuma : Status public

**Pourquoi** :
- Grafana = admin only (VPN)
- Uptime Kuma = status public pour utilisateurs

**Accès** : https://status.wail-sys.com

**Monitors configurés** :
- wail-sys.com (HTTP)
- Certificat SSL (expiration)

---

## 6. Commandes essentielles

### SSH et connexion

```bash
# Démarrer Tailscale (WSL)
tailscale up

# SSH via VPN
ssh wail@100.x.x.x

# Voir IP Tailscale du VPS
tailscale ip -4
```

### Docker

```bash
# Voir conteneurs actifs
docker ps

# Logs d'un conteneur
docker logs nginx
docker logs -f grafana  # Mode suivi temps réel

# Redémarrer un conteneur
docker restart nginx

# Redémarrer toute la stack
docker compose restart

# Arrêter la stack
docker compose down

# Démarrer la stack
docker compose up -d

# Voir utilisation ressources
docker stats
```

### Ansible

```bash
# Tester connexion
ansible vps -m ping

# Exécuter commande sur serveur
ansible vps -a "uptime"

# Relancer playbook (idempotent)
ansible-playbook playbooks/01-security.yml

# Playbook avec tags spécifiques
ansible-playbook playbooks/01-security.yml --tags firewall

# Mode check (dry-run, ne fait rien)
ansible-playbook playbooks/01-security.yml --check
```

### Terraform

```bash
# Voir état actuel
terraform show

# Détruire infrastructure
terraform destroy  # ⚠️ ATTENTION : supprime tout

# Voir outputs
terraform output
terraform output -raw database_password
```

### Système

```bash
# Utilisation disque
df -h

# Utilisation RAM
free -h

# Processus qui consomment
htop

# Logs système
journalctl -xe
journalctl -u nginx  # Logs service spécifique

# Firewall
sudo ufw status
sudo ufw allow 8080  # Ouvrir port
sudo ufw delete allow 8080  # Fermer port
```

---

## 7. Troubleshooting

### Site inaccessible

**1. Vérifier DNS** :
```bash
dig wail-sys.com
# Doit pointer vers IP Cloudflare (pas IP VPS directe)
```

**2. Vérifier conteneur Nginx** :
```bash
docker ps | grep nginx
docker logs nginx
```

**3. Vérifier certificat SSL** :
```bash
sudo certbot certificates
# Doit montrer certificat valide
```

**4. Tester depuis serveur** :
```bash
curl http://localhost
curl https://wail-sys.com
```

### Grafana inaccessible

**1. Vérifier VPN Tailscale** :
```bash
tailscale status
# Doit montrer serveur connecté
```

**2. Vérifier conteneur** :
```bash
docker logs grafana
```

**3. Vérifier port** :
```bash
netstat -tlnp | grep 3000
# Doit écouter sur 127.0.0.1:3000
```

### Prometheus ne collecte pas de métriques

**1. Vérifier exporters** :
```bash
docker ps | grep exporter
curl http://localhost:9100/metrics  # Node Exporter
curl http://localhost:8080/metrics  # cAdvisor
```

**2. Vérifier config Prometheus** :
```bash
docker exec prometheus cat /etc/prometheus/prometheus.yml
```

**3. Voir targets dans Prometheus** :
- http://100.x.x.x:9090/targets
- Tous doivent être "UP"

### Conteneur crash en boucle

```bash
# Voir pourquoi il crash
docker logs nom_conteneur

# Voir événements
docker events --since 1h

# Inspecter conteneur
docker inspect nom_conteneur

# Redémarrer proprement
docker compose down
docker compose up -d
```

---

## 8. Scénarios de maintenance

### Mettre à jour le site Hugo

```bash
# Local (WSL)
cd portfolio
# Modifier contenu dans content/

# Déployer
cd ../ansible
ansible-playbook playbooks/06-deploy-site.yml

# Vérifier
curl -I https://wail-sys.com
```

### Mettre à jour un conteneur Docker

```bash
# 1. Modifier version dans docker-compose.yml
# Exemple : grafana/grafana:latest → grafana/grafana:10.2.0

# 2. SSH sur serveur
cd /opt/docker

# 3. Pull nouvelle image
docker compose pull grafana

# 4. Recréer conteneur
docker compose up -d grafana

# 5. Vérifier
docker ps
docker logs grafana
```

### Ajouter un monitor Uptime Kuma

1. https://status.wail-sys.com
2. Login
3. Add New Monitor
4. Type : HTTP(s)
5. URL : https://ton-nouveau-site.com
6. Interval : 60s
7. Save

### Backup base de données PostgreSQL

**Digital Ocean fait backups auto** (7j rétention)

**Restore manuel** :
1. Console Digital Ocean
2. Databases → wail-portfolio-db
3. Backups
4. Choisir date → Restore

### Recréer infra complète

**Scénario** : VPS détruit, tout perdu

```bash
# 1. Terraform
cd terraform
terraform apply

# 2. Copier nouvelle IP dans inventory
nano ../ansible/inventory/hosts.yml

# 3. Ansible (ordre important)
cd ../ansible
ansible-playbook playbooks/01-security.yml
ansible-playbook playbooks/02-ssh-vpn.yml
ansible-playbook playbooks/03-docker.yml
ansible-playbook playbooks/04-deploy-stack.yml
ansible-playbook playbooks/05-ssl.yml
ansible-playbook playbooks/06-deploy-site.yml

# Total : ~15 min
```

### Voir les coûts Digital Ocean

```bash
# Via CLI
doctl account get

# Ou console web
# https://cloud.digitalocean.com/billing
```

**Coûts mensuels** :
- VPS s-2vcpu-4gb : 24$
- PostgreSQL db-s-1vcpu-1gb : 15$
- **Total : ~39$/mois**

---

## 🎓 Pour aller plus loin

### Concepts à approfondir

1. **Kubernetes** : Orchestration conteneurs (overkill pour 7 conteneurs, mais industrie standard)
2. **CI/CD** : Pipeline automatique (GitHub Actions → déploiement auto)
3. **Helm** : Package manager Kubernetes
4. **Terraform modules** : Réutiliser code Terraform
5. **Ansible roles** : Organiser playbooks complexes
6. **Vault** (HashiCorp) : Gestion secrets centralisée
7. **ELK Stack** : Logs centralisés (Elasticsearch, Logstash, Kibana)

### Livres recommandés

- "The DevOps Handbook" - Gene Kim
- "Site Reliability Engineering" - Google
- "Infrastructure as Code" - Kief Morris

### Certifications

- **Terraform Associate** (HashiCorp)
- **CKA** (Certified Kubernetes Administrator)
- **AWS Solutions Architect**
- **Red Hat Certified System Administrator**

---

## 📝 Résumé en 5 points

1. **Terraform** crée infra cloud → **Ansible** configure serveurs
2. **Docker** isole services → **Docker Compose** orchestre 7 conteneurs
3. **Prometheus** collecte métriques → **Grafana** affiche dashboards
4. **Sécurité 5 layers** : Cloudflare, UFW, Fail2ban, VPN, updates auto
5. **IaC** : Tout dans Git, rebuild complet en 15 min

---

**Questions ? Debugging ?** → Regarde les logs :
```bash
docker logs nom_conteneur
journalctl -xe
```

Bonne chance ! 🚀
