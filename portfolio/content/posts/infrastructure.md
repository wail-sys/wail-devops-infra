---
title: "Infrastructure DevOps Self-Hosted"
date: 2025-12-12
summary: "Environnement de production automatisé : architecture, sécurité, monitoring et Infrastructure as Code"
tags: ["Terraform", "Ansible", "Docker", "Prometheus", "Grafana", "Hugo", "Nginx", "Sécurité"]
---

# Infrastructure DevOps Self-Hosted

Environnement de production self-hosted géré selon les principes DevOps : automatisation complète, monitoring en temps réel, sécurité multi-couches.

## Vue d'Ensemble

- **VPS Digital Ocean** : 2 vCPU / 4 GB RAM / 80 GB SSD
- **7 conteneurs Docker** : Nginx, Hugo, Prometheus, Grafana, Node Exporter, cAdvisor, Uptime Kuma
- **Base PostgreSQL managée** (Digital Ocean)
- **DNS Cloudflare** : protection DDoS, CDN global
- **SSL/TLS Let's Encrypt** : renouvellement automatique
- **VPN Tailscale** : accès admin sécurisé
- **Monitoring** : Prometheus + Grafana (rétention 30j)
- **Status public** : [status.wail-sys.com](https://status.wail-sys.com)
- **Infrastructure as Code** : rebuild complet < 15 min

## Architecture Technique

### DNS et Protection DDoS

Domaine OVH avec DNS Cloudflare. En cas d'attaque DDoS, Cloudflare filtre le trafic malveillant avant qu'il n'atteigne le VPS (2 vCPU seraient saturés instantanément).

**Bénéfices** :
- Protection DDoS automatique
- CDN global (cache distribué)
- Masquage IP du serveur
- SSL/TLS gratuit

### Infrastructure as Code

Tout le code est versionné dans Git. Recovery complet possible en 15 minutes sans intervention manuelle.

**Terraform** : Provisionne le VPS et les ressources réseau sur Digital Ocean.

**Ansible** : Configure le serveur (Docker, firewall UFW, Fail2ban), déploie les applications. Les secrets sont chiffrés avec Ansible Vault. Les playbooks sont idempotents : exécutables plusieurs fois sans risque.

### Stack Applicative

**Docker Compose** : Orchestre 7 conteneurs isolés. Chaque service tourne avec un utilisateur non-root. Les mises à jour se font par changement de version d'image.

**Nginx** : Reverse proxy pour toutes les requêtes HTTPS. Gère le SSL/TLS avec Let's Encrypt (renouvellement automatique).

**Hugo** : Site statique généré depuis Markdown. Pas de backend dynamique = surface d'attaque minimale et performances maximales.

### Monitoring

**Prometheus** : Collecte métriques système (Node Exporter) et conteneurs (cAdvisor) toutes les 15s. Rétention 30 jours.

**Grafana** : Dashboards de visualisation. Accès uniquement via VPN Tailscale.

**Uptime Kuma** : Status public ([status.wail-sys.com](https://status.wail-sys.com)) sans exposer d'infos sensibles.

### Sécurité : Défense en Profondeur

**Layer 1 - Protection Réseau** :
- Cloudflare : absorption DDoS, blacklist IPs malveillantes
- UFW : deny-by-default, 3 ports ouverts (22, 80, 443)
- Fail2ban : ban automatique après 5 échecs SSH

**Layer 2 - SSH via VPN** :
- SSH écoute uniquement sur interface Tailscale (invisible depuis Internet)
- Double auth : VPN + clé ED25519
- Root login désactivé

**Layer 3 - Isolation Conteneurs** :
- Réseaux Docker séparés (public/monitoring)
- Services sensibles en localhost uniquement
- Tous les conteneurs en utilisateur non-root

**Layer 4 - Administration VPN** :
- Grafana/Prometheus accessibles uniquement via Tailscale
- Déploiements Ansible depuis WSL via VPN

**Layer 5 - Mises à Jour** :
- unattended-upgrades : patchs de sécurité automatiques
- Images Docker rebuild réguliers

## Choix Techniques

### VPS Digital Ocean

VPS simple plutôt que cloud managé (AWS/Azure) : maîtrise système complète, coût fixe 24$/mois, adapté au besoin (site statique + monitoring). Kubernetes serait surdimensionné pour 7 conteneurs.

### Terraform + Ansible

Séparation provisioning (Terraform) / configuration (Ansible).

**Terraform** : Crée/détruit ressources cloud (VPS, réseau). Recovery complet en 12 min.

**Ansible** : Configure serveur (packages, apps). Changement config sans détruire le VPS. Idempotence = rejouable sans risque.

### Docker Compose

**Avantages** :
- Isolation : une panne ne se propage pas
- Reproductibilité : dev/staging/prod identiques
- Rollback : retour version précédente en 30s

Docker Compose vs Kubernetes : fichier YAML 100 lignes vs 500+. Pour 7 conteneurs, Kubernetes serait surdimensionné.

### Prometheus + Grafana

Détection proactive des anomalies avant impact utilisateur.

**Stack** : Prometheus (collecte), Grafana (visualisation), Node Exporter (métriques système), cAdvisor (métriques conteneurs). Rétention 30j, scraping 15s.

### PostgreSQL Managée

Base de données Uptime Kuma hébergée chez Digital Ocean (15$/mois).

**Avantages** :
- Backups automatiques (7j rétention)
- Mises à jour sécurité auto
- VPS reste stateless (destroy/rebuild sans perte données)
- Connexion via réseau privé DO

Architecture "stateless compute + stateful managed services" (pratique courante AWS RDS, Azure SQL).

### Hugo

Générateur de site statique : fichiers HTML servis directement par Nginx.

**vs WordPress** : Pas de PHP, pas de MySQL, pas de plugins = surface d'attaque minimale. Performance 500x supérieure (50k req/s vs 100 req/s).

**Maintenance** : Zéro updates de sécurité post-déploiement.

## Reproductibilité

Rebuild complet en 15 min via 4 commandes :

```bash
terraform apply                             # VPS
ansible-playbook 00-bootstrap-security.yml  # Sécurité
ansible-playbook 02-docker-install.yml      # Docker
ansible-playbook 03-deploy-apps.yml         # Apps
```

Pas de dérive de configuration : tout est dans Git.

---

**Status en temps réel** : [status.wail-sys.com](https://status.wail-sys.com)

**Stack** : Docker 24.x • Nginx 1.24 • Prometheus 2.x • Grafana 10.x • Hugo 0.121+
