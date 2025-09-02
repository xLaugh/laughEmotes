# laughEmotes

Un menu d’emotes pour FiveM avec favoris persistants, aperçu en direct et commande rapide.

## Fonctionnalités

- **Menu RageUI**: Catégories ordonnées (Animations, Animations de danses, Props animations, Humeurs, Démarches)
- **Aperçu en direct**: un clone semi-transparent joue l’emote lors du survol dans le menu
- **Favoris persistants**: ajout/suppression, stockage via KVP côté client
- **Commande rapide**: `/e <id>` pour jouer une emote par son identifiant généré
- **Réinitialisations**: options pour annuler l’animation, réinitialiser humeur et démarche, supprimer les props

## Installation

1. Placez le dossier dans `resources/`
2. Dans `server.cfg`, ajoutez:
   ```
   ensure pemotes
   ```

## Utilisation

- **Ouvrir le menu**: F1
- **Lancer une emote**: sélectionnez-la dans le menu
- **Commande rapide**:
  ```
  /e <id>
  ```
  Exemple: `/e salut`
- **Annuler l’animation**: X
- **Supprimer tous les props**: bouton dans le menu

## Notes

- Favoris stockés via `SetResourceKvp` sous la clé `pemotes_favorites`
- Script purement client; aucune dépendance ESX/ox requise
