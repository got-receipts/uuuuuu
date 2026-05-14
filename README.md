# GigOS

GigOS is a production-ready MVP for independent gig-worker shift tracking. It does **not** connect to Uber, DoorDash, Grubhub, Instacart, Amazon Flex, or any third-party gig platform API.

> GigOS is an independent shift, mileage, break, and earnings tracker for gig workers. Not affiliated with Uber, DoorDash, Grubhub, Instacart, Amazon Flex, or any delivery platform.

## Stack

- Flutter Web mobile-first PWA frontend
- FastAPI backend
- PostgreSQL
- SQLAlchemy + Alembic
- JWT authentication with bcrypt password hashing
- Docker Compose for local development
- Railway-compatible root Dockerfile

## Repository Layout

```text
.
├── backend
│   ├── alembic
│   ├── app
│   │   ├── routers
│   │   ├── calculations.py
│   │   ├── config.py
│   │   ├── database.py
│   │   ├── main.py
│   │   ├── models.py
│   │   ├── schemas.py
│   │   └── security.py
│   ├── tests
│   ├── Dockerfile
│   └── requirements.txt
├── frontend
│   ├── lib
│   ├── web
│   └── Dockerfile
├── docker-compose.yml
├── Dockerfile
├── railway.json
└── .env.example
```

## Local Development

Copy the example environment file if you want local overrides:

```bash
cp .env.example .env
```

Run the full stack:

```bash
docker compose up --build
```

Services:

- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- API docs: http://localhost:8000/docs
- PostgreSQL: localhost:5432
- Health: http://localhost:8000/health

The backend service runs `alembic upgrade head` automatically before starting.

## Railway Deployment

1. Create a Railway project.
2. Add a Railway PostgreSQL service.
3. Deploy this repository as a Dockerfile service. Railway detects the root `Dockerfile`.
4. Set these variables on the app service:

```text
DATABASE_URL=${{Postgres.DATABASE_URL}}
JWT_SECRET=<strong random secret>
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=10080
CORS_ORIGINS=https://your-railway-domain.up.railway.app
```

The root Dockerfile builds Flutter Web to `build/web`, copies it into the FastAPI image, runs migrations, and serves the PWA and API from the same Railway service. The healthcheck path is `/health`.

If you deploy frontend and backend as separate services later, build `frontend/Dockerfile` with:

```text
API_BASE_URL=https://your-backend-domain
```

## API Routes

- `POST /auth/register`
- `POST /auth/login`
- `GET /me`
- `POST /shifts/start`
- `POST /shifts`
- `PATCH /shifts/{id}/end`
- `PATCH /shifts/{id}`
- `GET /shifts`
- `GET /shifts/{id}`
- `DELETE /shifts/{id}`
- `POST /shifts/{id}/breaks/start`
- `PATCH /breaks/{id}/end`
- `GET /reports/weekly`
- `GET /export/csv`
- `GET /health`

## Calculation Rules

- `total_minutes = ended_at - started_at`
- `gross_hourly = gross_earnings / hours`
- `tax_set_aside = gross_earnings * 0.20`
- `maintenance_reserve = miles * 0.15`
- `net_profit = gross_earnings - gas_cost - other_expenses - tax_set_aside - maintenance_reserve`
- `net_hourly = net_profit / hours`
- `earnings_per_mile = gross_earnings / miles`

Break companion thresholds:

- 4 hours: suggest a 15 minute break
- 6 hours: suggest a 30 minute break
- 8 hours: fatigue warning

## Security Notes

- Passwords are hashed with bcrypt.
- Access tokens are signed JWTs with expiration.
- GigOS never stores delivery platform passwords.
- GigOS performs no scraping.
- GigOS does not use third-party gig platform APIs.

## Tests

Run backend tests locally:

```bash
cd backend
pip install -r requirements-dev.txt
pytest
```

Flutter checks:

```bash
cd frontend
flutter pub get
flutter analyze
flutter build web --release --dart-define=API_BASE_URL=http://localhost:8000
```

