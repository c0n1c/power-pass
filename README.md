```markdown
# Gestion des mots de passe pour les serveurs Unix

Ce script PowerShell permet de gérer les mots de passe des comptes utilisateurs sur plusieurs serveurs Unix en utilisant SSH, en générant des mots de passe sécurisés et en les stockant dans une base de données Keepass.

## Prérequis

- PowerShell 5.1 ou version ultérieure
- Les modules PowerShell suivants doivent être installés :
  - Posh-SSH
  - PoShKeePass

## Installation

1. Installez les modules Posh-SSH et PoShKeePass en exécutant les commandes suivantes dans PowerShell :
   ```
   Install-Module Posh-SSH -Scope CurrentUser
   Install-Module PoShKeePass -Scope CurrentUser
   ```

2. Assurez-vous que les modules sont importés dans votre script :
   ```powershell
   Import-Module Posh-SSH
   Import-Module PoShKeePass
   ```

3. Assurez-vous que votre base de données Keepass est configurée correctement dans le script en spécifiant le chemin d'accès à la base de données et en créant un profil de base de données.

## Utilisation

1. Assurez-vous que votre base de données Keepass est configurée correctement avec les informations des serveurs Unix dans le groupe spécifié.

2. Exécutez le script `change_password_unix.ps1` pour changer les mots de passe des comptes utilisateurs sur les serveurs Unix.

## Fonctionnalités

- Génère des mots de passe sécurisés pour les comptes utilisateurs.
- Utilise SSH pour se connecter aux serveurs Unix.
- Stocke les mots de passe générés dans une base de données Keepass.
- Gère les erreurs et affiche des messages d'information pendant l'exécution du script.

## Licence

Ce script est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

---

Pour toute question ou suggestion, n'hésitez pas à me contacter.
```
