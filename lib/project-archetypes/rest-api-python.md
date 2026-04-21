---
name: rest-api-python
category: api
public: false
database: optional
hosting_hints:
  - vps
  - docker
  - k8s
  - render
  - railway
  - fly
  - heroku
audit_stack:
  - analyze
  - code-clean
  - cso
  - perf
  - doc
plugins:
  context7: optional
  ui-ux-pro-max: no
  gstack: no
---

# REST API (Python)

API backend Python (FastAPI / Flask / Django REST / Starlette / Litestar), sans frontend inclus.

## Detection signals

### Strong signals (×3)
- FILE: `pyproject.toml` OR `requirements.txt` OR `Pipfile` OR `setup.py`
- DEP: l'un de : "fastapi", "flask", "django", "djangorestframework", "starlette", "litestar"
- STRING_IN_FILE: tout .py du projet contient "FastAPI(" OR "Flask(__name__)" OR "app = Starlette(" OR "from django"

### Medium signals (×2)
- FILE: `src/main.py` OR `app/main.py` OR `app.py` OR `manage.py`
- DEP: ORM — "sqlalchemy", "tortoise-orm", "peewee", "django" (Django ORM), "pydantic"
- DEP: Validation — "pydantic" (implicite avec FastAPI), "marshmallow"

### Weak signals (×1)
- DEP: "uvicorn", "gunicorn", "hypercorn"
- DEP: "alembic" (migrations)
- DEP: "python-jose", "passlib", "bcrypt"
- FILE: `Dockerfile`
- DIR: `tests/`
- FILE: `alembic.ini`

### Counter-signals (exclusion)
- DEP: "streamlit", "gradio", "dash" → data app UI (archétype à créer)
- DEP: "jupyter" comme main focus → notebook project

## Implications
- **Hébergement** : VPS, Docker (Render, Railway, Fly), K8s, AWS Lambda, Heroku
- **Base de données** : FORTEMENT PROBABLE — PostgreSQL dominant
- **SEO/GEO** : N/A
- **Surface sécurité** : GRANDE — mêmes risques que Node, plus Django admin exposé si mal config
- **UI/UX** : N/A (sauf Django admin, rarement customisé)

## Typical pain points
- Pas de versioning API (/api/v1/)
- Pydantic mal utilisé (types trop permissifs, `Any` partout)
- SQLAlchemy : N+1 queries (pas de `selectinload`/`joinedload`)
- Django : `SECRET_KEY` committé, DEBUG=True en prod
- Secrets dans le repo
- Requirements non pinned (`fastapi` sans version) → builds instables
- CORS `*` en production
- Pas de rate limiting
- Tests : pytest fixtures non isolées (DB pollution entre tests)
- Alembic migrations conflictuelles (branches non résolues)
- Async mal maîtrisé (bloque event loop avec `requests` sync en FastAPI)
- Dependencies audit absent (`pip-audit` non exécuté)
- Couverture de types mypy / pyright absente

## Interview questions (adaptive)
En plus du set minimum business :
- Framework : FastAPI / Flask / Django REST / Starlette / Litestar ?
- Mode : sync / async ?
- Base de données : PostgreSQL / MySQL / SQLite / MongoDB / autre / aucune ?
- ORM : SQLAlchemy / Django ORM / Tortoise / Peewee / raw SQL ?
- Migrations : Alembic / Django migrate / autre / aucune ?
- Auth : JWT / OAuth / session / API key / aucun ?
- Validation : Pydantic (v1 ou v2 ?) / Marshmallow / autre ?
- Typing : mypy / pyright / aucun ?
- Tests : pytest + fixtures ? couverture cible ?
- Linting / formatter : Ruff / Black / Flake8 / Mypy ?
- Déploiement : VPS / Docker / Lambda / Heroku / autre ?
- Package manager : pip / poetry / pdm / uv / Pipenv ?
- Documentation : OpenAPI auto (FastAPI) / Swagger manuel / aucune ?

## Plugin recommendations
- **context7** : OPTIONAL — ON pour FastAPI récent, Pydantic v2, SQLAlchemy 2.0
- **ui-ux-pro-max** : OFF
- **gstack** : OFF

## Example project layout
```
pyproject.toml
src/
  main.py
  api/
    v1/
      users.py
      orders.py
  models/
  schemas/
  services/
  db/
alembic/
  versions/
tests/
Dockerfile
```
