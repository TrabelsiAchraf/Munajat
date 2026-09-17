# Munajat — audit produit et croissance, 17 septembre 2026

## Conclusion

La priorité est de rendre l’offre existante facile à découvrir, à utiliser et à
recommander. Munajat possède déjà trois usages distinctifs : invocations selon
15 situations, séquence après la prière, mémorisation espacée. Ajouter une
super-app de prière ou retirer l’un de ces parcours n’est pas justifié par les
données disponibles. Le refus 4.3(a) de mai et le pivot accepté restent des
contraintes utiles : conserver la proposition contextuelle.

Les problèmes démontrables sont une navigation francophone incomplète, une
recherche qui ignore le contenu traduit, une demande d’avis absente de trois
parcours principaux, et des défauts techniques dans le partage et la séance de
mémorisation. Ils sont corrigés dans la préparation 1.3.0. Leur effet sur les
téléchargements et la rétention reste à mesurer.

## Sources et limites

Lecture de `CLAUDE.md`, `.claude`, README, specs et plans Superpowers de mai,
août et septembre, historique Git, code, JSON, supports et scripts marketing.
Base de départ : `6d9ff3a`, arbre de travail propre au début de l’audit.

Le dernier relevé **privé documenté** est celui du 1er septembre : 30 premiers
téléchargements cumulés, 8 sur 30 jours, 2 sur 7 jours ; Sénégal 11, France 6,
États-Unis 4. Ce ne sont pas les résultats du 17 septembre. Les chiffres récents
App Store Connect ont été demandés ; aucun export n’était disponible pendant
l’audit. Impossible de calculer un effet avant/après, un taux de conversion,
une rétention ou les canaux réels avec seulement ces nombres.

La [fiche française publique](https://apps.apple.com/fr/app/munajat-dhikr-douas/id6768824373)
indexée au moment de la recherche affiche **une note de 5/5**. C’est un instantané
public, pas une lecture du compte App Store Connect. « Aucune note visible »
dans un pays ne signifie pas zéro partout : Apple précise que la note globale
est [propre à chaque territoire](https://developer.apple.com/app-store/ratings-and-reviews/).
Ne pas réinitialiser les notes à la prochaine publication.

## Audit du parcours

| Étape | Constat vérifiable au départ | Conséquence possible | Action |
|---|---|---|---|
| Découverte | Positionnement contextuel déjà présent dans fiche et captures 1.2 | Un ajout de fonctions seul ne crée pas de trafic | Mesurer les sources et les impressions avant de modifier encore les mots-clés |
| Conversion | « Seule app », audio pour chaque dhikr, promesse d’apprentissage en cinq minutes | Attentes trop fortes, différenciation non démontrée | Fiche préparée sans ces affirmations |
| Premier usage | 133/133 titres de catégories uniquement en arabe | Un lecteur francophone ne peut pas identifier les catégories quotidiennes | 133 titres FR/EN ajoutés, arabe conservé |
| Recherche | Titres et texte arabe seulement | Les traductions/phonétiques de 1.2 sont impossibles à retrouver par leurs mots | Index local AR/FR/EN, accents et vocalisation ignorés |
| Pratique | PNG 3240×5760 rendu depuis `body` à chaque recalcul | Coût CPU/mémoire sur un écran avec compteur interactif | Export à la demande en 1080×1920 ; pas de benchmark de vitesse promis |
| Mémorisation | La modal reçoit `dueToday`, calculé à partir des dates que la séance modifie | Liste susceptible de rétrécir ou changer d’ordre pendant l’avancement | Photographie de la liste à l’ouverture ; compte widget rafraîchi |
| Avis | Demande native uniquement après fermeture d’une célébration de catégorie | Contextes ciblés, après-prière et Hifz ne peuvent pas déclencher de demande | Éligibilité commune aux quatre parcours |
| Recommandation | Carte image sans lien d’installation, pas de partage de l’app dans Réglages | Le destinataire doit chercher manuellement le nom | Lien Store dans le message de partage et partage de l’app |

Le Sénégal et la France représentent 17/30 téléchargements documentés (57 %),
mais le pays n’établit pas la langue de chaque utilisateur. C’est un motif
raisonnable de prioriser le français, pas une segmentation linguistique prouvée.

### Contenu : ce qui est réellement disponible

294 entrées dans 133 catégories ; traduction française et translittération
française sur 272 entrées ; traduction anglaise sur 276 ; URL audio sur 279.
Une URL présente ne garantit pas sa disponibilité réseau. Le fallback peut être
anglais ou arabe selon les champs disponibles ; ne pas annoncer une traduction
française ou anglaise universelle. Les textes, traductions, références, comptes
de répétition, associations de contextes et identifiants religieux sont inchangés.
Les nouvelles traductions concernent uniquement les libellés de navigation,
isolés dans `Resources/category-titles.json` et aussi embarqués dans le widget.

### Demande de note 1.3

L’API native SwiftUI `@Environment(\.requestReview)` existait déjà en 1.2.
Elle est maintenant partagée entre catégorie complète, dhikr ciblé terminé,
séquence après-prière terminée et séance de mémorisation terminée. Une séance
Hifz compte quel que soit le bouton d’auto-évaluation choisi : aucune sélection
des seuls utilisateurs satisfaits.

Au moins deux jours calendaires distincts avec une activité terminée ; un même
événement compte une seule fois par jour. Demande après deux secondes de calme,
après fermeture de la célébration pour une catégorie, annulée si l’écran quitte
la hiérarchie, et seulement en scène active. Une tentative par version et au
moins 60 jours entre deux tentatives, y compris lors de la migration 1.2.
Les anciens compteurs et la date de dernière tentative sont conservés ; les
jours d’activité distincts commencent à être observés avec 1.3.

Ce sont des **tentatives**, pas des fenêtres ou des notes confirmées. Apple
décide de l’affichage, applique ses propres limites et ne révèle pas si
l’utilisateur a noté. Une note n’est jamais obligatoire. Le lien permanent dans
Réglages utilise `action=write-review`, pour une initiative explicite de
l’utilisateur. Pas d’écran personnalisé « Aimes-tu l’app ? », ni récompense.
Références : [StoreKit](https://developer.apple.com/documentation/storekit/requestreviewaction),
[recommandations Apple](https://developer.apple.com/app-store/ratings-and-reviews/).

## Priorités suivantes, sans les confondre avec des causes mesurées

1. **Acquisition organique francophone.** Préparer de courtes démonstrations
   des parcours Anxieux, Après la prière et Mémoriser. À diffuser par le
   propriétaire dans des communautés où il a l’autorisation, avec liens de
   campagne App Store Connect distincts. Aucun message envoyé ni campagne
   payante lancée pendant cet audit. Ne pas présenter l’app comme un traitement
   médical de l’anxiété ou de l’insomnie.
2. **Captures.** Les captures 1.2 ont déjà été retravaillées en storytelling.
   Rafraîchir celles où les titres ont changé ; garder l’histoire contextuelle
   en premier. Pour une expérience ultérieure : « Une invocation pour ce que tu
   vis », puis texte FR/phonétique, puis après-prière. Les premiers visuels
   doivent montrer la valeur, les réglages peuvent venir en dernier.
3. **Retour quotidien.** Les rappels sont enfouis dans Réglages et leurs taps
   n’ont pas de routage dédié dans le code. Prochaine amélioration à envisager :
   lien vers les réglages de rappel après une séance et ouverture du bon
   parcours depuis la notification. Demander la permission à la suite du choix
   de l’utilisateur ; pas au premier lancement.
4. **Mémorisation.** L’état vide ne propose pas d’action directe ; les lignes
   de cartes ne sont pas navigables ; « Encore » rend la carte immédiatement
   due mais ne la réinsère pas dans la même séance. Ces écarts au design initial
   méritent une itération dédiée, avec une vraie décision sur la répétition
   intra-séance et les compteurs de progression. Pas de bibliothèque de nouvelles
   invocations inventée pour remplir l’état vide.
5. **Audio et partage long.** L’audio ne montre pas ses erreurs réseau ni la
   fin du chargement ; les cartes de partage très longues peuvent dépasser le
   format fixe. Prioriser selon les retours observés. Un téléchargement audio
   hors ligne doit d’abord vérifier les droits, la taille et la fiabilité du
   serveur ; ce n’est pas ajouté implicitement.

Pas de nouvel onboarding obligatoire, pas de compte, pas de réseau social, pas
de SDK analytique tiers. Le seuil iOS 17 est déjà abaissé depuis 1.1 ; aller plus
bas implique de remplacer SwiftData/Observation et ne se justifie pas sans
données sur les appareils exclus.

## Plan de mesure sur 30 jours après publication

Exporter avant publication les 30 jours précédents, puis relever chaque
semaine les mêmes périodes et filtres. Séparer Sénégal, France, États-Unis,
autres, ainsi que Search, Browse et referrals. Noter version et date de sortie.

| Mesure | Décision qu’elle permet |
|---|---|
| Impressions uniques par territoire/source | Savoir si l’app est découverte |
| Vues uniques de fiche et conversion Apple | Vérifier si fiche et promesse attirent les bons utilisateurs |
| Premiers téléchargements, séparés des retéléchargements | Mesurer les nouveaux utilisateurs, pas les mises à jour |
| Appareils actifs, sessions et rétention J1/J7 par cohorte | Vérifier l’usage au-delà de l’installation |
| Crashes, suppressions si disponibles | Détecter une régression de qualité |
| Nouvelles notes et avis par pays | Suivre la contribution de la nouvelle couverture de demande |
| Téléchargements par lien de campagne | Comparer des canaux externes concrets |

La conversion App Store Connect a une définition propre ; ne pas la remplacer
par téléchargements ÷ vues de fiche : un téléchargement peut venir directement
de la recherche. Les mesures d’usage dépendent du consentement et de seuils de
confidentialité. Zéro affiché ou métrique absente ne prouve pas zéro usage.
Sources : [définitions](https://developer.apple.com/help/app-store-connect-analytics/reference/metrics-definitions),
[Analytics](https://developer.apple.com/app-store-connect/analytics/).

Interprétation : peu d’impressions → travailler distribution/métadonnées ;
impressions présentes mais conversion faible → vérifier promesse, visuels et
territoire ; installations mais faible rétention → traiter premier usage,
rappels, fiabilité et mémorisation. Plusieurs problèmes peuvent coexister.

L’ancien objectif de 8 téléchargements/mois est un repère historique, pas un
objectif actuel. Recaler le point de départ avec les chiffres récents demandés.
À ce volume, quelques personnes font varier fortement les pourcentages :
reporter les nombres absolus, éviter les verdicts statistiques après une semaine
et ne pas lancer plusieurs variantes simultanées. Si le trafic reste faible à
J30, prolonger la mesure plutôt que proclamer un gagnant.

Ne pas encore changer nom, sous-titre et mots-clés en même temps que cette
correction produit. Apple indique que le texte promotionnel n’influence pas le
classement de recherche : il sert la compréhension, pas le bourrage de mots-clés.
[Recherche App Store](https://developer.apple.com/app-store/search/).

## Validation et livraison

- 61 tests Swift Testing passent sur simulateur iOS, dont localisation,
  recherche FR/EN/AR, diacritiques, classement, anti-répétition des avis,
  limite par version, frontière des 60 jours, migration de 1.2 et export PNG
  valide de dimensions 1080×1920.
- Compilation iOS et macOS réussie. Compilation visionOS tentée mais bloquée
  dans `actool` par l’absence de runtime xrsimulator installé ; compatibilité
  complète de cette plateforme non certifiée dans cet environnement.
- Vérification RocketSim en français : catégories lisibles, recherche
  « Apres priere » classant « Après la prière » en premier, liens de notation
  et de partage présents dans Réglages. Séance de trois cartes terminée
  (1/3 → 2/3 → 3/3 → « 3 cartes revues »), malgré les dates d’échéance
  modifiées. Fenêtre native Apple de notation observée visuellement au-dessus
  du récapitulatif en build de développement, avec l’éligibilité simulée par
  arguments de lancement. Aucune note envoyée. Ces arguments ne sont pas
  nécessaires en production ; les vraies activités alimentent l’éligibilité.
  Relance sans arguments d’éligibilité et contrôle de l’accueil arabe effectués.
- Limites des 15 champs de fiche validées par `scripts/check_store_listing.py`.
- Notes de version FR/EN/AR et instructions App Review préparées dans
  `marketing/release-notes/1.3.0/`. Aucune soumission ou publication effectuée.
- Les captures marketing existantes restent celles de 1.2.0 ; leur régénération
  et le test de l’archive signée sur appareil font partie de la préparation Store.
