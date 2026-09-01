# ASO & Growth — Phase 1 (spec)

Date : 2026-09-01. Baseline : 30 first-time downloads all-time, 8/30 jours,
top pays Sénégal 11 / France 6 / US 4. Version en ligne : 1.1.0.

Source : plan ASO externe (ChatGPT) fourni par Achraf + audit du repo fait en
session. Ce spec retient ce qui est validé, corrige ce qui était factuellement
faux, et fixe le périmètre de la phase 1.

## Hypothèse produit (inchangée)

Munajat gagne en aidant à trouver le bon dhikr pour ce que l'on vit
(15 contextes), pas en devenant une super-app. Le test : meilleure fiche →
plus de découverte → plus de téléchargements. Fenêtre d'observation 30 jours,
baseline 8 downloads/30 j. Pas de pub avant signal organique.

## Audit — écarts entre le plan externe et le code réel

1. **« Works offline » est faux pour l'audio** : `AudioPlayer` est
   streaming-only (hisnmuslim.com). Les textes/compteur/mémorisation sont
   offline. Toute formulation doit dire « textes disponibles hors ligne ».
2. **Les contextes cités par le plan ne sont pas les vrais** : pas de
   « guidance » ni « hardship ». Les 15 réels (contexts.json) : Anxious,
   Grateful, Sad, Angry, Fearful, Happy, Regretful, Hopeful (émotions) ;
   Sick, Mourning, In debt, Before an important moment, In conflict,
   Insomnia, Doubting (épreuves). Toute copy utilise ces libellés.
3. **Sources : déjà 294/294 dans les données et déjà affichées dans l'UI**
   (AdhkarDetailsView, ContextDhikrRow, ReviewSessionView). Mais en arabe
   uniquement, la moitié en chaînes de takhrij longues. « Authentic » nu est
   remplacé par l'attribution vérifiable « Hisn al-Muslim ».
4. **Traductions FR des dhikr : 0/294** (UI 100 % trilingue, mais
   `translation.fr` vide partout). Le marché organique actuel est
   francophone (17/30 downloads). La fiche 1.0 promettait déjà
   « arabe/français/anglais » — c'est l'écart produit n° 1.
5. **Translittérations : 0/294** alors que le modèle `Adhkar` a déjà un champ
   `transliteration` rendu par une DisclosureSection existante.
6. **Aucune demande d'avis in-app** (pas de `requestReview` dans le code).

## Périmètre phase 1 (ce plan)

1. **Traductions FR + translittérations** injectées dans
   `Adhkar/Resources/adhkar.json` depuis le dataset
   `AleaToir3/hisnul-muslim-api-json` (commit
   `57e451b34d5f98a9b75e1858ffd4ad8cad64bdd4`) — la traduction française
   standard publiée de la Citadelle du Musulman (ar + fr + translittération +
   réf par item, 133 chapitres, ~283 items exploitables). Matching arabe →
   arabe (containment de tokens normalisés ≥ 0.6, fallback sous-chaîne pour
   les textes courts) ; dry-run mesuré en session : ≥ 270/294 items, et les
   56 items référencés par les contextes tous rattrapables. Script
   d'enrichissement **in place** : n'écrit que `translation.fr` et
   `transliteration.fr`, ne touche jamais id/arabic/source/count/audio/en.
   Jamais de traduction inventée : uniquement le texte du dataset, verbatim.
   Les items non matchés restent sans fr (fallback en existant dans
   `LocalizedText`).
2. **Demande d'avis** : `ReviewPromptGate` (logique pure testée) — à partir de
   la 2e célébration de complétion, au plus une fois tous les 60 jours —
   déclenchée à la fermeture du `CompletionOverlay` via
   `@Environment(\.requestReview)` (iOS 16+/macOS 13+/visionOS 1+ : OK pour
   les trois plateformes).
3. **Label de source lisible** : « Source : Hisn al-Muslim » (localisé
   ar/fr/en) au-dessus de la référence arabe dans AdhkarDetailsView.
4. **Fiche App Store 1.2.0** (`marketing/config/store_listing.md`) : hook
   d'ouverture situationnel, contextes réels, attribution Hisn al-Muslim,
   clarification offline, keywords retravaillés sans répéter les mots du
   nom/sous-titre. Notes de version 1.2.0 (fr/en/ar).
5. **Bump 1.2.0** + CHANGELOG.

## Hors périmètre (phases suivantes)

- Screenshots storytelling (Phase B du plan externe) — après merge du code,
  avec `scripts/make_screenshots.py` / `capture_marketing.sh` existants.
- Titres de catégories en/fr (aujourd'hui arabe partout — amélioration
  possible, source en dispo côté wafa, mais scope creep ici).
- Custom Product Pages, contenu organique, Apple Ads — après signal 30 jours.
- Aucun analytics tiers, aucune nouvelle dépendance, aucune fonctionnalité.

## Points à valider par Achraf

- La source FR retenue est l'édition standard librement diffusée de la
  Citadelle (repo sans licence déclarée, contenu = traduction publiée en
  distribution gratuite, cohérent avec le sourcing en existant). Relire un
  échantillon avant release — règle absolue : ne jamais modifier le contenu
  religieux sans validation.
- Choix de sous-titre EN « Adhkar for how you feel » (alternatives en NOTES).
