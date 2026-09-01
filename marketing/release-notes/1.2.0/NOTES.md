# Notes de formulation — 1.2.0

Release ASO phase 1 (spec : docs/superpowers/specs/2026-09-01-aso-growth-phase1-design.md).

- On ne mentionne pas la demande d'avis (interne, pas une feature utilisateur).
- « quasi-totalité des invocations » (FR) / « nearly the entire dhikr
  library » (EN) / «معظم أدعية المكتبة» (AR) : couverture réelle finale
  272/294 avec fallback anglais pour le reste — formulation révisée après
  la correction de l'algorithme de correspondance (qui avait initialement
  produit de fausses correspondances sur ~35 items ; le nombre a baissé de
  294 à 272 en retirant les correspondances incorrectes plutôt que de les
  garder). Chaque invocation affiche toujours une traduction (fr ou en) ;
  ne pas durcir en « chaque invocation en français ».
- Sous-titre EN retenu : « Adhkar for how you feel ». Alternatives écartées :
  « Dhikr for Every Moment » (répète « Dhikr » déjà dans le nom — gaspille un
  mot-clé), « Adhkar for what you live » (calque non idiomatique).
- Keywords : ne répètent aucun mot du nom/sous-titre de la même locale ;
  aucun nom de concurrent ; « quran » écarté (l'app n'est pas une app Coran).
- Baseline du test 30 jours notée en tête de store_listing.md.
