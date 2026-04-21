---
name: data-notebook
category: meta
public: false
database: optional
hosting_hints:
  - local
  - jupyterhub
  - colab
  - kaggle
  - databricks
  - sagemaker
audit_stack:
  - analyze
  - code-clean
  - cso
  - doc
plugins:
  context7: optional
  ui-ux-pro-max: no
  gstack: no
---

# Data / Jupyter Notebook

Projet data science / ML axé sur notebooks Jupyter. Exploration, analyse, modèles. Pas d'application déployée au sens applicatif.

## Detection signals

### Strong signals (×3)
- EXT: 5+ fichiers `.ipynb`
- DEP: `requirements.txt` OR `pyproject.toml` OR `environment.yml` contient "jupyter" OR "jupyterlab" OR "notebook"
- FILE: `environment.yml` (Conda)

### Medium signals (×2)
- DIR: `notebooks/` OR `nb/` avec `.ipynb`
- DIR: `data/` OR `datasets/` (souvent gitignored)
- DEP: "pandas", "numpy", "matplotlib", "seaborn", "scikit-learn", "torch", "tensorflow", "jax"
- FILE: `Makefile` avec cibles data (download-data/, preprocess/, train/)
- FILE: `dvc.yaml` (DVC pipeline)

### Weak signals (×1)
- DIR: `models/` (trained artifacts)
- FILE: `.gitattributes` avec LFS rules
- DEP: "mlflow", "wandb", "tensorboard"
- DIR: `figures/` OR `plots/` (outputs)

### Counter-signals (exclusion)
- DEP: "streamlit" OR "gradio" OR "dash" + main entry point → data app UI (archétype à créer)
- DEP: "fastapi" / "flask" / "django" comme dep principale → API, pas notebook
- FILE: `setup.py` OR `pyproject.toml` AVEC `[project.scripts]` → package, pas notebook

## Implications
- **Exécution** : local / Google Colab / Kaggle / JupyterHub / Databricks / SageMaker
- **Base de données** : variable (souvent CSV/Parquet/DuckDB locaux, parfois DB externe)
- **SEO/GEO** : N/A
- **Surface sécurité** : SOUS-ESTIMÉE — notebooks souvent commités avec credentials, outputs, PII
- **UI/UX** : N/A (sauf si app Streamlit/Dash ajoutée)

## Typical pain points
- `.ipynb` committés avec **outputs** = fuite potentielle (données clients affichées)
- Credentials en dur dans cellules (API keys AWS, tokens Kaggle, mots de passe DB)
- PII dans outputs cellules (noms clients, emails, numéros carte)
- Datasets volumineux committés (pas de LFS / DVC / gitignore)
- `requirements.txt` non pinned → résultats non reproductibles
- Pas de seed random → runs non déterministes
- Notebooks monolithiques (10000+ lignes, cells non documentées)
- Logique dupliquée entre notebooks (pas de `src/lib.py`)
- Variables d'état entre cells (exécution non idempotente)
- Modèles trainés commités dans git (bloat repo)
- Pas de versioning data (DVC / lakeFS / Pachyderm absents)
- Expériences non trackées (MLflow / W&B absent)
- Pas de tests (pytest sur fonctions extraites)
- Conversion prod : notebook → script Python sans refactor (code non modulaire)
- GPU / environnement non documenté (CUDA version, cuDNN)
- Shared secrets dans environment.yml / requirements.txt

## Interview questions (adaptive)
En plus du set minimum business :
- Plateforme d'exécution : local / Colab / Kaggle / JupyterHub / Databricks / autre ?
- Python + libs stack principale ?
- Package manager : pip / poetry / uv / conda / mamba / pdm ?
- Datasets : taille moyenne ? où sont-ils stockés ? versionnés ?
- DVC / lakeFS / Git LFS pour data ?
- Tracking expériences : MLflow / W&B / TensorBoard / aucun ?
- Tests automatiques sur fonctions extraites ?
- Convention commit notebooks : nbstripout (outputs strippés) ou outputs inclus ?
- GPU requis ? CUDA version ?
- But final : exploration ponctuelle / modèle en prod / rapport reproductible / papier / autre ?
- Si prod : comment le modèle sort du notebook (export pickle/ONNX/API) ?
- RGPD / données sensibles dans les datasets ?

## Plugin recommendations
- **context7** : OPTIONAL — ON pour libs modernes (Pytorch, JAX, Transformers qui évoluent)
- **ui-ux-pro-max** : OFF
- **gstack** : OFF

## Example project layout
```
environment.yml            OR  requirements.txt    OR  pyproject.toml
notebooks/
  01-exploration.ipynb
  02-preprocessing.ipynb
  03-modeling.ipynb
  04-evaluation.ipynb
src/
  features.py              (fonctions extraites, testables)
  models.py
  utils.py
data/                       (GITIGNORED ou DVC-tracked)
  raw/
  interim/
  processed/
models/                     (artifacts — GITIGNORED ou LFS)
figures/
tests/
  test_features.py
dvc.yaml                    (optional)
.pre-commit-config.yaml     (nbstripout idéal)
Makefile
```
