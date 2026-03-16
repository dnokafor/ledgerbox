# LedgerBox

Self-hosted family finance tracker. Keep tabs on accounts, transactions, and budgets without giving your data to a third party.

## Features

- Multi-user support (family members with JWT auth)
- Manage checking, savings, credit, cash, and investment accounts
- Track income and expenses with categories
- Recurring transactions (monthly, weekly, etc.)
- Dashboard with balance overview and monthly summaries
- REST API + simple web UI
- Docker-ready (PostgreSQL) or local dev with SQLite

## Quick Start

```bash
# clone and install
git clone https://github.com/danokafor/ledgerbox.git
cd ledgerbox
npm install

# configure
cp .env.example .env
# edit .env with your settings

# run (uses SQLite by default)
npm run dev
```

Open http://localhost:3000

## Docker

```bash
docker-compose up -d
```

This starts the app on port 3000 with a PostgreSQL database.

## API

All endpoints (except auth) require a Bearer token in the `Authorization` header.

### Auth
| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/auth/register` | Create account |
| POST | `/api/auth/login` | Get token |
| GET | `/api/auth/me` | Current user info |

### Accounts
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/accounts` | List accounts |
| POST | `/api/accounts` | Create account |
| GET | `/api/accounts/:id` | Get account |
| PUT | `/api/accounts/:id` | Update account |
| DELETE | `/api/accounts/:id` | Delete account |

### Transactions
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/transactions` | List (with filtering) |
| POST | `/api/transactions` | Create |
| GET | `/api/transactions/:id` | Get |
| PUT | `/api/transactions/:id` | Update |
| DELETE | `/api/transactions/:id` | Delete |

Query params for filtering: `accountId`, `categoryId`, `type`, `startDate`, `endDate`, `recurring`, `page`, `limit`

### Categories
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/categories` | List |
| POST | `/api/categories` | Create |
| PUT | `/api/categories/:id` | Update |
| DELETE | `/api/categories/:id` | Delete |

### Dashboard
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/dashboard` | Balance summary + monthly totals |

## Tests

```bash
npm test
```

Uses SQLite in-memory for testing.

## Tech Stack

- Node.js + Express
- Sequelize ORM (PostgreSQL / SQLite)
- JWT authentication
- EJS templates
- Docker + docker-compose

## License

MIT

## Node Version

This project uses Node 18+. If you use nvm:
```bash
nvm use
```
