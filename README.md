<p align="center">
  <img src="Resources/mole-logo.png" alt="Mole Logo" width="128" height="128" />
</p>

<h1 align="center">Mole</h1>

<p align="center">
  <strong>L'application native macOS de nettoyage, d'optimisation et d'analyse système — 100% gratuite, open-source et sans abonnement.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0%2B-blue?logo=apple" alt="macOS" />
  <img src="https://img.shields.io/badge/Architecture-Apple%20Silicon%20(ARM64)-indigo" alt="Apple Silicon" />
  <img src="https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift" alt="Swift" />
  <img src="https://img.shields.io/badge/UI-SwiftUI%20Native-purple" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License" />
</p>

---

## ✨ Présentation

**Mole** est un utilitaire système moderne conçu spécifiquement pour macOS et l'architecture Apple Silicon (M1/M2/M3/M4). 

Contrairement aux solutions propriétaires lourdes, payantes ou truffées de processus résidents en arrière-plan, **Mole** est :
* 💎 **100% Gratuit & Open-Source** : Aucun achat in-app, aucun abonnement, aucune clé de licence requise.
* ⚡️ **Ultra-léger & Rapide** : Binaire autonome compilé en natif Swift/SwiftUI (< 1 Mo), temps de lancement quasi instantané (< 50 ms).
* 🛡 **Zéro Espionnage** : Aucune télémétrie, aucun tracking réseau, aucune permission superflue.
* 🎨 **Design Apple HIG & Liquid Glass** : Interface translucide avec flous d'arrière-plan `NSVisualEffectView`, animations physiques réactives et typographie système soignée.

---

## 🚀 Fonctionnalités Clés

### 1. 📊 Tableau de Bord Temps Réel
* **4 jauges circulaires interactives** :
  * **CPU** : Charge globale du processeur et répartition système/utilisateur.
  * **Mémoire Unifiée (RAM)** : Suivi en direct de la mémoire active, liée et disponible.
  * **Stockage SSD** : Espace libre, utilisé et pourcentage d'occupation.
  * **Batterie & Santé** : Niveau de charge, état d'alimentation et cycles.
* **Inspecteur de Processus** : Visualisation en direct des 5 processus les plus gourmands avec possibilité de les interrompre instantanément (`Kill`).

### 2. 🧹 Nettoyeur Approfondi (System Cleaner)
* Analyse et purge ciblée :
  * Caches système et utilisateur (`~/Library/Caches`).
  * Fichiers journaux obsolètes (`~/Library/Logs`).
  * Données dérivées Xcode & caches développeur (`DerivedData`, caches outils).
  * Fichiers temporaires et corbeille.
* Récupération d'espace disque en 1 clic sans risque pour les fichiers personnels.

### 3. ⚡️ Optimiseur de Performances
* **Purge RAM intelligente** : Libération immédiate de la mémoire inactive.
* **Maintenance macOS** : Réinitialisation des services DNS, flush des caches du Finder et du Dock.
* **Détection des processus zombies** et des applications énergivores.

### 4. 🗑 Désinstallateur d'Applications Propre
* Analyse complète des paquets d'applications.
* Détection automatique de tous les fichiers résiduels associés :
  * `~/Library/Application Support`
  * `~/Library/Preferences`
  * `~/Library/Caches`
  * `~/Library/Saved Application State`
* Désinstallation complète et propre en un clic.

### 5. 💻 Console & Journal d'Audit
* Affichage en direct de toutes les actions de nettoyage et d'optimisation effectuées avec horodatage précis.

---

## 🛠 Compilation et Installation

### Prérequis
* Un Mac sous **macOS 14 (Sonoma)** ou **macOS 27 (Golden Gate / Sequoia)**.
* **Command Line Tools** d'Apple (`xcode-select --install`) ou Xcode.

### Installation en une seule commande

Clonez le dépôt et lancez le script de build avec le flag `--install` :

```bash
git clone https://github.com/nexos20lv/mole.git
cd mole
./scripts/build.sh --install
```

Le script va :
1. Compiler le binaire Swift optimisé pour ARM64.
2. Assembler le paquet d'application macOS (`Mole.app`).
3. Intégrer l'icône haute résolution (`mole.icns`) et le fichier de configuration `Info.plist`.
4. Signer le binaire et installer l'application directement dans votre dossier `/Applications`.

---

## 🖥 Utilisation

Vous pouvez lancer **Mole** directement depuis :
* **Spotlight** : `Cmd + Espace` puis tapez `Mole`.
* **Le Finder** : Ouvrez `/Applications/Mole.app`.
* **Le Terminal** : `open /Applications/Mole.app`.

---

## 🏗 Architecture du Projet

```text
mole/
├── Sources/
│   └── App.swift           # Code source complet SwiftUI / AppKit
├── Resources/
│   ├── Info.plist          # Métadonnées du bundle macOS
│   ├── mole.icns           # Icône officielle haute résolution
│   └── mole-logo.png       # Logo officiel
├── scripts/
│   └── build.sh            # Script d'assemblage et de packaging
├── .github/
│   └── workflows/ci.yml    # Intégration continue (CI)
├── Package.swift           # Manifeste Swift Package Manager
└── README.md
```

---

## 📜 Licence

Ce projet est distribué sous la licence **MIT**. Voir le fichier [LICENSE](LICENSE) pour plus de détails.
