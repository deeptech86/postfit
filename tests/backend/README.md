# MomCare Backend API Tests

Comprehensive test suite for the MomCare postpartum health & wellness backend API.

## Overview

This test suite covers all API endpoints with a focus on:
- ✅ Functional correctness
- ✅ Input validation
- ✅ Authentication & authorization
- ✅ Postpartum-specific features
- ✅ Medical safety requirements
- ✅ Error handling
- ✅ HIPAA compliance features

## Test Structure

```
tests/backend/
├── package.json          # Test dependencies
├── setup.js             # Global test configuration
├── auth.test.js         # Authentication endpoints (33 tests)
├── food.test.js         # Food tracking endpoints (22 tests)
├── hydration.test.js    # Hydration tracking endpoints (18 tests)
├── exercises.test.js    # Exercise library endpoints (15 tests)
├── workouts.test.js     # Workout sessions endpoints (16 tests)
└── README.md           # This file
```

**Total: 104+ API tests**

## Prerequisites

1. **Backend server must be running**:
   ```bash
   cd ../backend
   npm start
   ```

2. **PostgreSQL database must be set up**:
   - Database: `momcare_db`
   - Schema migrated: `001_initial_schema.sql`

3. **Environment variables configured** in `backend/.env`

## Installation

```bash
cd tests/backend
npm install
```

## Running Tests

### Run All Tests
```bash
npm test
```

### Run Specific Test Suite
```bash
npm run test:auth        # Authentication tests
npm run test:food        # Food tracking tests
npm run test:hydration   # Hydration tests
npm run test:exercises   # Exercise library tests
npm run test:workouts    # Workout sessions tests
```

### Run with Coverage
```bash
npm run test:coverage
```

### Watch Mode (for development)
```bash
npm run test:watch
```

## Test Coverage

### Authentication API (`auth.test.js`)
- ✅ User registration with postpartum profile
- ✅ Email/password validation
- ✅ Login/logout functionality
- ✅ JWT token generation & validation
- ✅ Token refresh mechanism
- ✅ Password reset flow
- ✅ Get current user profile
- ✅ Medical disclaimers
- ✅ Duplicate email handling

### Food Tracking API (`food.test.js`)
- ✅ Manual food logging
- ✅ AI recognition metadata
- ✅ Meal type validation
- ✅ Nutrition data (calories, macros, iron, calcium)
- ✅ Breastfeeding calorie adjustments
- ✅ Daily nutrition summary
- ✅ Nutrition targets (minimum 1800 cal)
- ✅ Food entry CRUD operations
- ✅ Date filtering
- ✅ Medical safety validations

### Hydration Tracking API (`hydration.test.js`)
- ✅ Water intake logging
- ✅ Different drink types
- ✅ Quick-add presets
- ✅ Amount validation (no negatives, max limits)
- ✅ Breastfeeding adjustments (30-50% increase)
- ✅ Daily progress tracking
- ✅ Personalized hydration goals
- ✅ Weekly statistics
- ✅ Goal customization
- ✅ Entry management

### Exercise Library API (`exercises.test.js`)
- ✅ Browse all exercises
- ✅ Filter by recovery stage (early, progressive, building, full)
- ✅ Filter by category (pelvic_floor, core, cardio, etc.)
- ✅ Filter by difficulty (beginner, intermediate, advanced)
- ✅ Search by name
- ✅ Personalized recommendations
- ✅ Exercise details (instructions, videos)
- ✅ Favorite exercises
- ✅ Safety warnings for recovery stages
- ✅ Exercise categories with counts

### Workout Sessions API (`workouts.test.js`)
- ✅ Start workout session
- ✅ Track active session
- ✅ Add exercises to session
- ✅ Record sets, reps, duration
- ✅ Complete workout with notes
- ✅ Workout history
- ✅ Filter by date range and status
- ✅ Workout statistics (streak, calories, minutes)
- ✅ Weekly progress tracking
- ✅ Recovery stage compliance
- ✅ Session deletion
- ✅ Medical disclaimers

## Test Users

The test suite uses two predefined test users:

**Test User 1** (Primary):
```javascript
{
  email: 'test@momcare.com',
  password: 'TestPassword123!',
  fullName: 'Test Mother',
  deliveryDate: '2024-06-15',
  deliveryType: 'vaginal',
  isBreastfeeding: true
}
```

**Test User 2** (Secondary):
```javascript
{
  email: 'test2@momcare.com',
  password: 'TestPassword456!',
  fullName: 'Test Mother 2',
  deliveryDate: '2024-07-20',
  deliveryType: 'cesarean',
  isBreastfeeding: false
}
```

## Postpartum-Specific Tests

### Breastfeeding Features
- Calorie targets increased by 300-500 cal/day
- Hydration goals increased by 30-50%
- Minimum 1800 calories enforced
- Nutritional adjustments validated

### Recovery Stage Safety
- Exercise filtering by postpartum stage
- Early recovery (weeks 1-6): Safe exercises only
- Progressive (weeks 6-12): Moderate intensity
- Building (months 3-6): Increased strength work
- Full recovery (months 6-12): Advanced training

### Medical Disclaimers
- All health-related responses include disclaimers
- Reminders to consult healthcare providers
- Safety warnings for concerning symptoms

## Expected Test Results

All tests should pass when:
1. Backend server is running on `http://localhost:3000`
2. Database is properly migrated
3. Environment variables are configured
4. No other users with test emails exist in database

### Sample Output
```
PASS tests/backend/auth.test.js (5.2s)
  Authentication API
    ✓ should register a new user (142ms)
    ✓ should reject invalid email (48ms)
    ✓ should login with valid credentials (95ms)
    ...

PASS tests/backend/food.test.js (3.8s)
  Food Tracking API
    ✓ should log food entry (87ms)
    ✓ should calculate breastfeeding adjustment (62ms)
    ...

Test Suites: 5 passed, 5 total
Tests:       104 passed, 104 total
Time:        18.3s
```

## Troubleshooting

### Tests Failing: "ECONNREFUSED"
**Problem**: Cannot connect to backend server
**Solution**: Make sure backend is running: `cd backend && npm start`

### Tests Failing: "Authentication required"
**Problem**: auth.test.js didn't run first
**Solution**: Run `npm test` to run all tests in order

### Tests Failing: "Email already exists"
**Problem**: Test users already in database from previous run
**Solution**: Clean up test users:
```sql
DELETE FROM users WHERE email IN ('test@momcare.com', 'test2@momcare.com');
```

### Tests Failing: "Database connection failed"
**Problem**: PostgreSQL not running or database doesn't exist
**Solution**:
```bash
pg_isready                    # Check if PostgreSQL is running
createdb momcare_db           # Create database if needed
psql -d momcare_db -f ../backend/migrations/001_initial_schema.sql
```

### Tests Failing: Validation errors
**Problem**: API validation rules changed
**Solution**: Update test data in `setup.js` to match new requirements

## CI/CD Integration

### GitHub Actions Example
```yaml
name: API Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_DB: momcare_db
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-node@v2
        with:
          node-version: '18'

      - name: Install backend dependencies
        run: cd backend && npm install

      - name: Run database migration
        run: psql -d momcare_db -f backend/migrations/001_initial_schema.sql

      - name: Start backend server
        run: cd backend && npm start &

      - name: Install test dependencies
        run: cd tests/backend && npm install

      - name: Run API tests
        run: cd tests/backend && npm test
```

## Adding New Tests

1. **Create new test file**: `feature.test.js`
2. **Import required modules**:
   ```javascript
   const request = require('supertest');
   const BASE_URL = global.API_BASE_URL;
   const API = global.API_VERSION;
   ```
3. **Use authentication token**:
   ```javascript
   let authToken = global.authTokens.user1;
   ```
4. **Write test cases**:
   ```javascript
   describe('Feature API', () => {
     it('should do something', async () => {
       const response = await request(BASE_URL)
         .get(`${API}/feature`)
         .set('Authorization', `Bearer ${authToken}`)
         .expect(200);

       expect(response.body.success).toBe(true);
     });
   });
   ```
5. **Add test script** to `package.json`:
   ```json
   "test:feature": "jest feature.test.js --verbose"
   ```

## Best Practices

1. **Test Order**: Tests run sequentially - auth tests must run first
2. **Isolation**: Each test should be independent
3. **Cleanup**: Delete created resources in tests
4. **Assertions**: Use specific assertions, not just status codes
5. **Error Cases**: Test both success and failure scenarios
6. **Security**: Never commit real credentials or tokens
7. **Medical Safety**: Always verify medical disclaimers are present

## References

- **API Documentation**: `/backend/docs/API.md`
- **Database Schema**: `/backend/migrations/001_initial_schema.sql`
- **Environment Config**: `/backend/.env.example`
- **Jest Documentation**: https://jestjs.io/
- **Supertest Documentation**: https://github.com/visionmedia/supertest

---

**Last Updated**: 2025-12-30
**Total Tests**: 104+
**Test Framework**: Jest 29.7.0
**HTTP Client**: Supertest 6.3.3
