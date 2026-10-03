# ImmoBudget — Document de passation (pour agent IA)

> Ce document permet de reprendre le développement d'ImmoBudget sans contexte préalable.
> Lisez-le en entier avant toute modification, puis lisez `index.html` (≈600 lignes).

---

## 1. Objectif du produit

ImmoBudget est un **simulateur personnel de trésorerie** pour un crédit immobilier en cours.

Question à laquelle il répond : *« Si j'utilise une épargne dédiée pour compléter chaque mensualité, combien dois-je réellement payer chaque mois depuis mes revenus ? »*

- Ce n'est **pas** un simulateur de remboursement anticipé : la banque prélève toujours la mensualité contractuelle. L'épargne sert seulement à « lisser » l'effort mensuel.
- Pas de calcul d'intérêts (ni ceux du crédit, ni ceux de l'épargne) : tout est en euros constants.
- Usage personnel, mono-utilisateur, interface **en français**.
- 100 % local : aucune requête réseau, aucune donnée envoyée.

### Données réelles de l'utilisateur (valeurs par défaut)

| Donnée | Valeur |
|---|---|
| Mensualité contractuelle | 1 713 € / mois |
| Début du crédit | **juin 2021** (constante dans le code) |
| Durée totale | 20 ans (240 mensualités) |
| Épargne disponible | 125 488 € |
| Mensualités restantes (oct. 2026) | 176 (calculé automatiquement) |

Avec ces valeurs, en octobre 2026 : 125 488 ÷ 176 = 713 €/mois de complément, soit **1 000 €/mois** payés depuis les revenus.

---

## 2. Architecture technique

- **Un seul fichier** : `index.html`, avec HTML, CSS (`<style>`) et JS (`<script>`) intégrés.
- Aucune dépendance, aucun framework, aucun build, aucun package manager.
- JavaScript **ES5** (`var`, `function`, IIFE en `"use strict"`). Gardez ce style : pas de `let`/`const`/arrow functions, sauf migration décidée explicitement.
- Lancement : ouvrir `index.html` dans un navigateur (ou `python3 -m http.server` puis http://localhost:8000).
- Le seul stockage est `localStorage['immobudget-theme']`, pour le thème clair/sombre (lecture et écriture entourées de `try/catch`).

### Arborescence

```
ImmoBudget/
├── index.html    # toute l'application
├── README.md     # minimal
└── HANDOFF.md    # ce document
```

---

## 3. Structure de `index.html`

### 3.1 CSS (lignes ~10–165)

- Les couleurs sont des variables CSS sur `:root` : `--bg`, `--card`, `--ink`, `--muted`, `--line`, `--brand`, `--brand-ink`, `--brand-soft`, `--accent`, `--accent-soft`, `--warn`, `--warn-soft`, `--danger`, `--danger-soft`, `--shadow`, `--radius`.
- Le mode sombre est défini deux fois :
  - `@media (prefers-color-scheme: dark)` avec `:root:not([data-theme="light"])` (thème automatique) ;
  - `:root[data-theme="dark"]` (forcé par le bouton 🌓).
  - **Toute nouvelle couleur doit être ajoutée aux trois endroits.**
- Responsive : `.grid2` passe à une colonne sous 420 px.
- Classes utiles : `.card`, `.hero`, `.field`, `.inp` + `.unit`, `.metrics` / `.metric` (`.k` = libellé, `.v` = valeur), `.banner` + `ok|warn|err`, `.chip`, `.quick`, `.synth`, `.note`, `.hint`, `tr.hl` (ligne surlignée).

### 3.2 Sections HTML (dans l'ordre d'affichage)

| # | Section | IDs principaux |
|---|---|---|
| 0 | En-tête + bouton thème | `themeBtn` |
| 1 | **Paramètres du crédit** (saisies) | `mens`, `rest`, `epargne` |
| 2 | **Résultat principal** (lissage) | `heroReal`, `heroComp`, `heroNeed`, `heroBanner`/`heroBannerTxt`, `mUsed`, `mIncome`, `mMonths`, `mLeft` |
| 3 | **Mode inverse** | `target`, `targetRange`, `rangeMax`, `quickBtns`, `invComp`, `invNeed`, `invBanner`/`invBannerTxt` |
| 4 | **Tableau des objectifs** | `goalsBody` |
| 5 | **Durée du crédit** | `total` (ans), `paid` (ans), `dPaid`, `dLeft`, `coverEp`, `coverEq` |
| 6 | **Synthèse** | `sTotal`, `sPaid`, `sLeft`, `sEp`, `sEq`, `sMens`, `sReal`, `sComp` |
| 7 | Avertissement en pied de page | — |

Champs de saisie (tous `type="number"`) : `mens`, `rest`, `epargne`, `target`, `total`, `paid`, ainsi que le curseur `targetRange`.

### 3.3 JavaScript

Tout le code est dans une IIFE. Fonctions, dans l'ordre du fichier :

| Fonction | Rôle |
|---|---|
| `money(x)` | Format `1 713 €` (arrondi à l'euro, `Intl` fr-FR). Renvoie `—` si non fini. |
| `money2(x)` | Format au centime. **Non utilisée actuellement.** |
| `monthsToText(m)` | `64` → `"5 ans 4 mois"`. |
| `yearsToText(y)` | Années décimales → texte, via `monthsToText`. |
| `$(id)`, `num(id)`, `set(id, txt)` | Helpers DOM. `num` remplace `,` par `.` et renvoie `NaN` si invalide. |
| `banner(id, txtId, cls, ic, txt)` | Met à jour une bannière (classe, icône, texte). |
| `GOALS` | `[1500,1400,1300,1200,1100,1000]` : objectifs du tableau et des boutons rapides. |
| `START_YEAR`, `START_MONTH` | `2021`, `5` (juin, mois **0-indexé**). |
| `monthsElapsed()` | Mois écoulés entre juin 2021 et le mois courant (`new Date()`). |
| `syncRest()` | `rest = round(total × 12) − monthsElapsed()` (minimum 0). |
| `recompute()` | **Point d'entrée unique du calcul.** Calcule la section 2, puis appelle les quatre fonctions ci-dessous. |
| `computeInverse(...)` | Section 3. |
| `buildGoals(...)` | Section 4 (reconstruit le `<tbody>`). |
| `computeDuration(...)` | Section 5. |
| `fillSynthesis(...)` | Section 6. |
| `buildQuick()`, `markQuick()` | Boutons d'objectifs rapides et état actif. |
| `syncRangeMax()` | Maximum du curseur = mensualité. |
| `themeInit()` | Bascule clair/sombre persistée. |

**Flux des événements**

- `input` sur `mens`, `rest`, `epargne`, `target`, `total` ou `paid` déclenche `recompute()`, avec des effets propres à certains champs :
  - `mens` → `syncRangeMax()` ;
  - `total` → `syncRest()` ;
  - `target` → synchronise le curseur et `markQuick()`.
- `input` sur `targetRange` → met à jour `target`, appelle `markQuick()` puis `recompute()`.
- Initialisation : `syncRest()`, `buildQuick()`, `syncRangeMax()`, `markQuick()`, `recompute()`.

---

## 4. Règles de calcul (référence)

Notations : `M` = mensualité contractuelle, `N` = mensualités restantes, `E` = épargne, `T` = objectif mensuel.

### 4.1 Lissage (section 2)

```
usable   = min(E, M × N)        // on ne peut pas utiliser plus que ce qui reste à payer
perMonth = usable / N           // complément pris dans l'épargne chaque mois
real     = M − perMonth         // payé depuis les revenus
leftEnd  = E − usable           // surplus d'épargne à la fin (0 sauf si E > M×N)
```

Bannières :
- `E ≤ 0` → info « vous payez la mensualité complète » ;
- `E ≥ M×N` → le crédit est entièrement couvert, avec le surplus ;
- sinon, l'épargne tombe à 0 € au terme du crédit.

### 4.2 Mode inverse (section 3)

```
si T ≥ M : complément = 0, épargne nécessaire = 0
sinon :
  comp = M − T
  need = comp × N
  E ≥ need → suffisant (surplus = E − need)
  E < need → épuisée après floor(E / comp) mois, puis mensualité complète
```

### 4.3 Tableau des objectifs (section 4)

Pour chaque `g` de `GOALS` :
- `need = (M − g) × N`, affiché 0 € si `g ≥ M` ;
- couverture : « toute la durée » si `E ≥ need`, sinon `floor(E / (M − g))` mois ;
- la ligne qui correspond à l'objectif `target` reçoit la classe `hl`.

### 4.4 Durée et synthèse (sections 5 et 6)

- Déjà payé = `paid` (ans) ; restant = `total − paid` (ans).
- Équivalent de l'épargne = `E / M` mois.
- La synthèse reprend ces valeurs ainsi que `real` et `perMonth` de la section 2.

### 4.5 Mensualités restantes automatiques

```
monthsElapsed = (année_courante − 2021) × 12 + (mois_courant_0idx − 5)
N = round(total_ans × 12) − monthsElapsed
```

Exemple : octobre 2026 → 60 + 4 = 64 mois écoulés → N = 240 − 64 = **176**.
Convention : le mois en cours est compté comme **restant**. L'utilisateur peut toujours modifier `rest` à la main ; la valeur est recalculée au rechargement de la page et à chaque changement de `total`.

---

## 5. État actuel (au 2026-10-03)

### Historique git

```
c5419d8 Merge PR #1 (simulateur initial, monofichier)
c81bfcd Add mortgage savings treasury simulator
1013a15 Initial commit
```

### Modification non commitée

Dans `index.html` : `rest` n'est plus fixé à `176`. Il est calculé par `syncRest()` à partir de la date du jour et de juin 2021. Les changements sont visibles avec `git diff`.

> Remarque : les fichiers appartenaient auparavant à `root`. Si une écriture échoue avec `EACCES`, demandez à l'utilisateur de lancer `sudo chown -R $USER:$USER <repo>`.

---

## 6. Backlog — problèmes connus (non corrigés)

À traiter en priorité, dans cet ordre :

1. **Incohérence entre `paid` et `rest` (priorité haute).** `paid` (« Années déjà payées ») est fixé à `5` dans le HTML, alors que `rest` est calculé depuis la date du jour (64 mois payés en oct. 2026, soit 5 ans 4 mois). Résultat : les sections Durée et Synthèse affichent « Restant 15 ans » (180 mois) alors que le simulateur utilise 176 mois.
   *Correction suggérée :* calculer aussi `paid = monthsElapsed() / 12` au chargement (et mettre à jour le texte `.hint`), ou dériver `paid` de `total − rest/12`.
2. **Valeurs périmées quand la mensualité est invalide.** Dans `recompute()`, la branche `!validMens` ne réinitialise que `heroReal` et la bannière : `heroComp`, `heroNeed`, `mUsed`, `mIncome`, `mMonths` et `mLeft` gardent leurs anciennes valeurs. `heroReal` perd aussi son `<small>/ mois</small>`.
3. **« Mois couverts par l'épargne » faux quand l'épargne vaut 0.** `mMonths` affiche toujours `N mois`, même quand `E = 0` ; il devrait afficher 0.
4. **Message trompeur quand `rest` est vide.** `NaN` déclenche « le crédit est déjà terminé » au lieu d'inviter à remplir le champ. Il faut distinguer `rest === 0` de `rest` invalide.
5. *(Optionnel)* Le libellé « Épargne nécessaire jusqu'à la fin » (`heroNeed`) affiche `usable`, ce qui fait doublon avec l'épargne saisie. À reformuler en « Épargne mobilisée », ou à remplacer par `M × N`.
6. *(Optionnel)* La date de début (juin 2021) est codée en dur. On pourrait ajouter un champ « Date de début » (`type="month"`), dont `syncRest()` et `paid` dépendraient.
7. *(Optionnel)* Supprimer `money2` (non utilisée) ou s'en servir.

Non-objectifs, sauf demande explicite : intérêts de l'épargne, tableau d'amortissement, remboursement anticipé, backend, framework, build.

---

## 7. Conventions et consignes pour l'agent

- **Langue** : toute l'interface et les commentaires de code sont en **français**. Communiquez avec l'utilisateur en français.
- **Ne pas découper le fichier** et ne pas ajouter de dépendances ou de CDN sans accord. Le fonctionnement hors ligne en monofichier est voulu.
- Imiter le style existant : ES5, petits helpers (`$`, `num`, `set`, `banner`), commentaires de section `// ---------- Titre ----------`.
- Toute nouvelle sortie doit passer par `recompute()` ; ne pas multiplier les écouteurs qui calculent chacun de leur côté.
- Toute valeur affichée doit tomber sur `—` si les entrées sont invalides (voir `money()`).
- Garder la mention que ceci n'est pas un remboursement anticipé (pied de page).
- Mobile d'abord : vérifier l'affichage à 360–420 px de large, en thème clair et sombre.
- Git : branche `main`. Ne committer ou pousser que sur demande de l'utilisateur.

---

## 8. Vérification manuelle (pas de tests automatisés)

Ouvrir `index.html` et vérifier avec les valeurs par défaut (en octobre 2026) :

| Contrôle | Attendu |
|---|---|
| `rest` au chargement | 176 (diminue de 1 chaque mois) |
| Résultat principal | **1 000 € / mois**, complément 713 € / mois, épargne restante à la fin 0 € |
| Mode inverse, objectif 1 000 € | complément 713 €, épargne nécessaire 125 488 €, bannière « suffit… juste ce qu'il faut » |
| Objectif 1 500 € | nécessaire 37 488 €, surplus 88 000 € |
| Objectif 0 € | nécessaire 301 488 € (1 713 × 176), épargne épuisée après 73 mois |
| `total` = 25 | `rest` devient 236 |
| Épargne = 0 | 1 713 € / mois depuis les revenus |
| Épargne = 400 000 | couverture totale, surplus 98 512 € |
| Bouton 🌓 | bascule le thème, conservé après rechargement |

Pour tester une autre date : les fonctions sont dans une IIFE, donc inaccessibles depuis la console. Modifiez temporairement `monthsElapsed()` (par exemple `var now = new Date(2027, 0, 15);`), rechargez la page, puis annulez la modification. Pour janvier 2027 : 67 mois écoulés, `rest` = 173.
