# Préparation 1.3.0

Pas encore soumise. Fiche : `marketing/config/store_listing.md`.
Audit et protocole de mesure : `docs/growth-audit-2026-09-17.md`.

Les notes publiques ne présentent pas la demande d’avis comme une fonctionnalité.
Le lien ajouté au message de partage dépend des champs que l’application
destinataire accepte ; il n’est pas garanti avec une image seule.

## App Review Information — Notes (à copier)

```text
Munajat 1.3.0 improves navigation and search in the existing contextual dhikr app.
No account, payment, advertising, tracking SDK or new permission.

WHAT CHANGED
• All 133 category navigation labels are available in French and English, alongside the existing Arabic labels. No religious texts, translations, references, repetition counts or IDs were changed.
• Offline search now includes the existing translations and transliterations, and ignores accents and Arabic vocalization marks. Search "morning", "matin", or "اذكار الصباح".
• Memorization sessions retain their initial card list as due dates change; the widget's due count is refreshed after a session.
• Shared images are rendered on export, instead of on every counter update. The share message includes the public App Store link.
• Settings includes a direct App Store "Rate the app" link and a Share Munajat action.

NATIVE REVIEW REQUEST
Uses StoreKit's SwiftUI requestReview environment action. Eligible after completed activities on at least two distinct calendar days. The activities can be a whole category, a focused dhikr opened from a context, a post-prayer session, or a memorization session (regardless of recall rating). The attempt is delayed by two seconds after completion (after dismissal of the category celebration), cancelled if the view disappears, and requires an active scene. At most once per app version, with a minimum 60-day interval across versions. Existing 1.2.0 request history is retained. Apple's display policy still applies; there is no custom pre-prompt, incentive or positive-rating filter.

The contextual home (15 life contexts), guided post-prayer sequence and spaced memorization remain the central features. All existing progress is retained; no database migration.
```

## Avant soumission

- Reprendre les captures FR/EN concernées par les nouveaux titres (accueil,
  détail, mémorisation, réglages) avec les scripts marketing existants ; les
  PNG de `marketing/out*` datent encore de 1.2.0.
- Tester l’archive signée sur iPhone physique, notamment le partage vers les
  applications réellement utilisées. TestFlight ne présente pas la fenêtre
  native d’avis : le test de cette fenêtre se fait en build de développement.
- Ne pas réinitialiser la note du Store lors de la création de la version.
- Noter la date effective de publication dans l’audit et exporter les mesures
  de référence avant toute nouvelle expérience sur le titre ou les captures.
