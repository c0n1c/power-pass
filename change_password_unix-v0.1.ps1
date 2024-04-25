<#
.SYNOPSIS
    Script de gestion des mots de passe pour les serveurs Unix.

.DESCRIPTION
    Ce script permet de changer les mots de passe des comptes utilisateurs sur plusieurs serveurs Unix
    en utilisant SSH, en générant des mots de passe sécurisés et en les stockant dans une base de données Keepass.

.PREREQUIS
    - Assurez-vous d'avoir installé les modules Posh-SSH et PoShKeePass.
        Install-Module Posh-SSH -Scope CurrentUser
        Install-Module PoShKeePass -Scope CurrentUser
    - Adapter les variables $cheminBaseDeDonnees et $nomGroup selon vos préférences.
    - Mettez le nom du serveur (ou IP) dans le champ URL de chaque entrée dans le bon groupe de la base de données Keepass.

.PARAMETERS
    Aucun.

.EXAMPLE
    .\change_password_unix.ps1

.NOTES
    Version: 0.1    Initialisation
    TROUBLESHOOTING : Si vous avez l'erreur : Could not load type 'System.Security.Cryptography.ProtectedMemory' from assembly 'System.Security, Version=4.0.0.0, Culture=neutral,
PublicKeyToken=b03f5f7f11d50a3a', désinstaller Powershell 7.
#>

# Importer les modules nécessaires
Import-Module Posh-SSH
Import-Module PoShKeePass

# Chemin vers la base de données Keepass
$cheminBaseDeDonnees = "C:\Users\user\Downloads\database.kdbx"

# Créer un backup de la base de donnée de Keepass
# Chemin de destination pour la copie du fichier Keepass avec la date du jour
$cheminDestination = "C:\Users\user\Downloads\keepass_backup_$(Get-Date -Format 'yyyyMMdd').kdbx"

# Copier le fichier Keepass vers le chemin de destination
Copy-Item -Path $cheminBaseDeDonnees -Destination $cheminDestination -Force

# Renommer le fichier avec la date du jour
Rename-Item -Path $cheminDestination -NewName ("keepass_backup_$(Get-Date -Format 'yyyyMMdd').kdbx") -Force

# Chemin du groupe à traiter (non sensible à la case)
$nomGroup = "unix"

# Mise en place d'un profile dans la configuration Keepass
try {
    New-KeePassDatabaseConfiguration -DatabaseProfileName "Default" -DatabasePath $cheminBaseDeDonnees -UseMasterKey
}
catch {
    # Le message d'alerte est déjà afficher dans la console
    Write-Host ""
}

# Récupérer les informations sur les serveurs Unix à partir de la base de données Keepass
try {
    $serveursUnix = Get-KeePassEntry -AsPlainText -DatabaseProfileName "Default" | Where-Object { $_.ParentGroup -eq $nomGroup -and $_.URL -ne $null }
}
catch {
    Write-Host "Erreur lors de la récupération des informations sur les serveurs Unix : $_"
    exit
}

# Génération du mot de passe
function GenererMotDePasse {
    $longueurMinimale = 15
    $caracteresSpeciaux = '!@#$%&*()-_=+'
    $caracteresMajuscules = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    $caracteresMinuscules = 'abcdefghijklmnopqrstuvwxyz'
    $chiffres = '0123456789'
    
    # Générer une liste de caractères autorisés
    $caracteresPermis = $caracteresSpeciaux + $caracteresMajuscules + $caracteresMinuscules + $chiffres
    
    # Mélanger les caractères
    $caracteresMelanges = $caracteresPermis.ToCharArray() | Get-Random -Count $caracteresPermis.Length
    
    # Initialiser le mot de passe
    $motDePasse = ""

    # Générer un mot de passe aléatoire
    for ($i = 0; $i -lt $longueurMinimale; $i++) {
        # Sélectionner un caractère aléatoire parmi ceux autorisés
        $caractereAleatoire = $caracteresMelanges[$i % $caracteresMelanges.Length]
        $motDePasse += $caractereAleatoire
    }
    
    return $motDePasse
}

# Parcourir chaque serveur Unix
foreach ($serveur in $serveursUnix) {
    # Récupérer les informations du serveur
    $adresseIP = $serveur.URL
    $utilisateurSSH = $serveur.UserName
    $motDePasseUtilisateur = ConvertTo-SecureString $serveur.Password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($utilisateurSSH, $motDePasseUtilisateur)

    # Tenter de se connecter au serveur via SSH
    try {
        $sessionSSH = New-SSHSession -ComputerName $adresseIP -Credential $credential
        
        # Si la connexion est réussie, afficher un message
        Write-Host "Connexion réussie à $adresseIP"
        
        # Générer un nouveau mot de passe
        $nouveauMotDePasse = GenererMotDePasse

        # Répondre à la demande de changement de mot de passe en envoyant le nouveau mot de passe
        # Invoke-SSHCommand -SSHSession $sessionSSH -Command "echo '$motDePasseUtilisateur`n$nouveauMotDePasse`n$nouveauMotDePasse' | passwd"
        Invoke-SSHCommand -SSHSession $sessionSSH -Command "printf '%s\n' $motDePasseUtilisateur $nouveauMotDePasse $nouveauMotDePasse | passwd"
    
        # Afficher un message indiquant que le mot de passe a été changé avec succès
        Write-Host "Mot de passe changé avec succès pour $utilisateurSSH sur $adresseIP. Nouveau mot de passe : $nouveauMotDePasse"
    }
    catch {
        # Si une erreur se produit, vérifier si c'est une demande de changement de mot de passe
        if ($_ -match "change your password"  -or $_ -match "changer votre mot de passe") {
            # Générer un nouveau mot de passe
            $nouveauMotDePasse = GenererMotDePasse

            # Répondre à la demande de changement de mot de passe en envoyant le nouveau mot de passe
            Invoke-SSHCommand -SSHSession $sessionSSH -Command "echo '$motDePasseUtilisateur`n$nouveauMotDePasse`n$nouveauMotDePasse' | passwd"

            # Afficher un message indiquant que le mot de passe a été changé avec succès
            Write-Host "Mot de passe changé avec succès pour $utilisateurSSH sur $adresseIP. Nouveau mot de passe : $nouveauMotDePasse"
        }
        else {
            # Si c'est une autre erreur, afficher le message d'erreur
            Write-Host "Une erreur s'est produite lors de la connexion de $adresseIP : $_"
        }
    }
    finally {
        # Enregistrer la modification du mot de passe dans le Keepass
        # Récupérer l'entrée KeePass correspondante à l'adresse IP ou au nom du serveur Unix
        $entry = Get-KeePassEntry -DatabaseProfileName "Default" | Where-Object { $_.ParentGroup -eq $nomGroup -and $_.URL -eq $adresseIP }
        
        # Vérifier si une entrée correspondante a été trouvée
        if ($entry -ne $null) {
            # Mettre à jour le champ de mot de passe de l'entrée avec le nouveau mot de passe
            Set-KeePassEntry -Entry $entry -Password $nouveauMotDePasse
            Write-Host "Le nouveau mot de passe a été enregistré dans KeePass pour $adresseIP."
        } else {
            Write-Host "Aucune entrée correspondante trouvée dans KeePass pour $adresseIP."
        }

        # Fermer la session SSH
        if ($sessionSSH) {
            Remove-SSHSession -SSHSession $sessionSSH
        }
    }
}

# Vérifier si la variable existe avant de la supprimer
if (Test-Path variable:motDePasseKeepassTexte) {
    Remove-Variable -Name motDePasseKeepassTexte -Force
}
