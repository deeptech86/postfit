# MomCare Backend API

A comprehensive, HIPAA-compliant backend API for the MomCare postpartum health and wellness iOS application.

## Features

- **User Authentication**: JWT-based auth with OAuth support (Apple, Google, Facebook)
- **Food Tracking**: AI-powered food recognition, nutrition logging, calorie tracking
- **Hydration Monitoring**: Breastfeeding-adjusted water intake goals
- **Exercise Management**: Postpartum-safe exercise library with recovery stage filtering
- **Real-Time Features**: Socket.io for chat, notifications, and live updates
- **HIPAA Compliance**: AES-256 encryption, audit logging, data retention policies

## Tech Stack

- **Runtime**: Node.js 18+
- **Framework**: Express.js
- **Database**: PostgreSQL 14+
- **Cache/Sessions**: Redis
- **Real-Time**: Socket.io
- **Authentication**: JWT, Passport.js
- **Storage**: AWS S3
- **Payments**: Stripe

## Prerequisites

- Node.js 18 or higher
- PostgreSQL 14 or higher
- Redis 6 or higher
- AWS account (for S3 storage)
- Stripe account (for payments)

## Installation

### 1. Clone the Repository

```bash
cd /path/to/PostFit/backend
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Configure Environment

Copy the example environment file and configure:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```bash
# Required for development
DB_HOST=localhost
DB_PORT=5432
DB_NAME=momcare_db
DB_USER=momcare_admin
DB_PASSWORD=your_password

REDIS_HOST=localhost
REDIS_PORT=6379

JWT_SECRET=your_64_character_secret_key
JWT_REFRESH_SECRET=your_refresh_token_secret

ENCRYPTION_KEY=your_256_bit_hex_key
```

### 4. Set Up Database

Create the PostgreSQL database:

```bash
createdb momcare_db
```

Run migrations:

```bash
npm run migrate
```

Seed initial data (optional):

```bash
npm run seed
```

### 5. Start the Server

Development mode (with hot reload):

```bash
npm run dev
```

Production mode:

```bash
npm start
```

## Project Structure

```
backend/
├── src/
│   ├── config/          # Configuration files
│   │   ├── index.js     # Main config (env variables)
│   │   ├── database.js  # PostgreSQL connection
│   │   └── redis.js     # Redis connection
│   │
│   ├── controllers/     # Route handlers
│   │   ├── authController.js
│   │   ├── foodController.js
│   │   ├── hydrationController.js
│   │   └── exerciseController.js
│   │
│   ├── middleware/      # Express middleware
│   │   ├── auth.js      # JWT authentication
│   │   ├── validation.js
│   │   ├── rateLimit.js
│   │   └── errorHandler.js
│   │
│   ├── models/          # Database models
│   │   ├── User.js
│   │   ├── HealthProfile.js
│   │   ├── FoodEntry.js
│   │   ├── HydrationEntry.js
│   │   └── Exercise.js
│   │
│   ├── routes/          # API routes
│   │   ├── auth.js
│   │   ├── food.js
│   │   ├── hydration.js
│   │   ├── exercises.js
│   │   └── workouts.js
│   │
│   ├── services/        # Business logic
│   │   └── socketService.js
│   │
│   ├── utils/           # Utility functions
│   │   ├── logger.js
│   │   ├── encryption.js
│   │   ├── validators.js
│   │   └── apiResponse.js
│   │
│   └── server.js        # Main entry point
│
├── migrations/          # Database migrations
├── tests/               # Test files
├── docs/                # API documentation
└── scripts/             # Utility scripts
```

## API Documentation

Full API documentation is available at `/docs/API.md` or when running the server at `/api/v1/docs`.

### Quick Reference

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/auth/register` | POST | Register new user |
| `/api/v1/auth/login` | POST | User login |
| `/api/v1/auth/refresh` | POST | Refresh access token |
| `/api/v1/auth/me` | GET | Get current user |
| `/api/v1/food` | POST | Log food entry |
| `/api/v1/food/date/:date` | GET | Get food by date |
| `/api/v1/food/targets` | GET | Get nutrition targets |
| `/api/v1/hydration` | POST | Log hydration |
| `/api/v1/hydration/today` | GET | Today's progress |
| `/api/v1/exercises` | GET | List exercises |
| `/api/v1/workouts` | POST | Start workout |

## Database Migrations

Create a new migration:

```bash
npm run migrate:create -- my_migration_name
```

Run migrations:

```bash
npm run migrate
```

Rollback last migration:

```bash
npm run migrate:down
```

## Testing

Run all tests:

```bash
npm test
```

Run tests with coverage:

```bash
npm run test:coverage
```

Run integration tests:

```bash
npm run test:integration
```

## Environment Variables

### Required

| Variable | Description |
|----------|-------------|
| `DB_HOST` | PostgreSQL host |
| `DB_PORT` | PostgreSQL port |
| `DB_NAME` | Database name |
| `DB_USER` | Database user |
| `DB_PASSWORD` | Database password |
| `REDIS_HOST` | Redis host |
| `REDIS_PORT` | Redis port |
| `JWT_SECRET` | JWT signing secret (min 64 chars) |
| `JWT_REFRESH_SECRET` | Refresh token secret |
| `ENCRYPTION_KEY` | AES-256 key (hex format) |

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Server port | 3000 |
| `NODE_ENV` | Environment | development |
| `DB_POOL_MAX` | Max DB connections | 10 |
| `REDIS_PASSWORD` | Redis password | - |
| `AWS_REGION` | AWS region | us-east-1 |
| `STRIPE_SECRET_KEY` | Stripe secret | - |
| `OPENAI_API_KEY` | OpenAI API key | - |

## Security

### HIPAA Compliance

- All PHI encrypted with AES-256
- Audit logging enabled by default
- Secure session management
- Data retention policies enforced

### Authentication

- JWT tokens with refresh rotation
- Rate limiting on auth endpoints
- Account lockout after failed attempts
- OAuth 2.0 with major providers

### Data Protection

- HTTPS required in production
- CORS configured for allowed origins
- Helmet.js security headers
- Input validation on all endpoints

## Deployment

### Docker

```dockerfile
FROM node:18-alpine

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .

EXPOSE 3000
CMD ["node", "src/server.js"]
```

### Docker Compose

```yaml
version: '3.8'
services:
  api:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    depends_on:
      - postgres
      - redis

  postgres:
    image: postgres:14
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:6-alpine
```

### Production Checklist

- [ ] Set `NODE_ENV=production`
- [ ] Configure all required environment variables
- [ ] Enable HTTPS with valid SSL certificate
- [ ] Set up database backups
- [ ] Configure log aggregation
- [ ] Set up monitoring and alerting
- [ ] Review rate limiting settings
- [ ] Test disaster recovery procedures

## Monitoring

### Health Checks

- `GET /health` - Basic health check
- `GET /ready` - Readiness check (includes DB and Redis)

### Logging

Logs are written to:
- Console (all environments)
- `logs/combined.log` (production)
- `logs/error.log` (production, errors only)
- `logs/hipaa-audit.log` (HIPAA audit trail)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `npm test`
5. Run linting: `npm run lint`
6. Submit a pull request

## License

Proprietary - All rights reserved

## Support

- API Support: api-support@momcare.app
- Security Issues: security@momcare.app
