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

# Nom du groupe à traiter (non sensible à la case)
$nomGroup = "unix"

# Nom de la base de donnée Keepass
$nomBaseDeDonnee = "database"

# Chemin vers la base de données Keepass
$cheminBaseDeDonnees = "C:\Users\user\Downloads\$nomBaseDeDonnee.kdbx"

function BackupKeepass {
    # Chemin de destination pour la copie du fichier Keepass avec la date du jour
    $cheminDestination = "C:\Users\user\Downloads\keepass_backup_$(Get-Date -Format 'yyyyMMdd').kdbx"

    # Copier le fichier Keepass vers le chemin de destination
    Copy-Item -Path $cheminBaseDeDonnees -Destination $cheminDestination -Force

    # Renommer le fichier avec la date du jour
    Rename-Item -Path $cheminDestination -NewName ("keepass_backup_$(Get-Date -Format 'yyyyMMdd').kdbx") -Force
}

function ImporterNouveauxServeursDansKeepass {
    # Demander à l'utilisateur s'il veut importer de nouveaux serveurs
    $reponse = Read-Host "Voulez-vous importer de nouveaux serveurs dans Keepass ? (O/N)"
    if ($reponse -eq "O" -or $reponse -eq "o") {
        try {
            # Chemin du fichier CSV contenant les informations des serveurs
            $cheminFichierCSV = "C:\Users\user\Downloads\cmdb.csv"
            
            # Récupérer les serveurs existants dans le Keepass
            $serveursExistants = Get-KeePassEntry -AsPlainText -DatabaseProfileName "Default" | Where-Object { $_.ParentGroup -eq $nomGroup -and $_.URL -ne $null }
            
            # Importer les nouveaux serveurs depuis le fichier CSV
            $nouveauxServeurs = Import-Csv $cheminFichierCSV
            foreach ($serveur in $nouveauxServeurs) {
                $adresseIP = $serveur.hostname
                $title = $serveur.os
                
                # Vérifier si le serveur est déjà dans la liste
                $serveurExiste = $serveursExistants | Where-Object { $_.URL -eq $adresseIP }
                
                # Ajouter le serveur au Keepass s'il n'existe pas déjà
                if (-not $serveurExiste) {
                    New-KeePassEntry -DatabaseProfileName "Default" -KeePassEntryGroupPath "$nomBaseDeDonnee/$nomGroup" -Title $title -URL $adresseIP -Notes "Nouveau serveur ajouté automatiquement le $(Get-Date -Format 'yyyy-MM-dd')"
                    Write-Host "Le serveur $adresseIP a été ajouté à Keepass."
                }
            }
            Write-Host "Fin de l'importation dans le Keepass."
        }
        catch {
            Write-Host "Une erreur s'est produite lors de l'importation des nouveaux serveurs dans Keepass : $_"
        }
    }
    else {
        Write-Host "L'importation a été annulée par l'utilisateur."
    }
}

# Créer un backup de la base de donnée de Keepass
BackupKeepass

# Importation des serveurs d'une CMDB dans le Keepass
ImporterNouveauxServeursDansKeepass

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
    $caracteresSpeciaux = '!@#$%&*-_=+'
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
    $motDePasseEncrypted = ConvertTo-SecureString -String $motDePasseUtilisateur -AsPlainText -Force

    # Générer un nouveau mot de passe
    $nouveauMotDePasse = GenererMotDePasse
    
    # Tenter de se connecter au serveur via SSH
    try {
        # Exécuter le script Expect avec les arguments appropriés
        $expectScriptPath = "C:\Users\user\Downloads\passwd.exp"
        Start-Process -FilePath "expect" -ArgumentList "$expectScriptPath", $motDePasseEncrypted, $adresseIP, $utilisateurSSH, $nouveauMotDePasse -NoNewWindow -Wait
    }
    catch {
        Write-Host "Une erreur s'est produite lors du changement de mot de passe sur $adresseIP : $_"
    }
}

# Vérifier si la variable existe avant de la supprimer
if (Test-Path variable:motDePasseKeepassTexte) {
    Remove-Variable -Name motDePasseKeepassTexte -Force
}
