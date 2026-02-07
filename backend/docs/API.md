# MomCare API Documentation

## Overview

MomCare is a HIPAA-compliant postpartum health and wellness API supporting a comprehensive iOS application for new mothers. This API provides endpoints for nutrition tracking, exercise management, hydration monitoring, and community features.

**Base URL:** `https://api.momcare.app/api/v1`

**Content-Type:** `application/json`

## Authentication

The API uses JWT (JSON Web Tokens) for authentication. Include the access token in the Authorization header:

```
Authorization: Bearer <access_token>
```

### Token Lifecycle

- **Access Token:** Valid for 7 days
- **Refresh Token:** Valid for 30 days

### OAuth Providers

- Apple Sign-In
- Google OAuth 2.0
- Facebook Login

---

## API Endpoints

### Authentication

#### Register a New User

```http
POST /auth/register
```

**Request Body:**
```json
{
  "email": "sarah@example.com",
  "password": "SecureP@ss123",
  "name": "Sarah Johnson",
  "acceptTerms": true,
  "marketingConsent": false
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Account created successfully",
  "data": {
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "email": "sarah@example.com",
      "name": "Sarah Johnson",
      "emailVerified": false,
      "subscriptionStatus": "free"
    },
    "tokens": {
      "accessToken": "eyJhbGciOiJIUzI1NiIs...",
      "refreshToken": "eyJhbGciOiJIUzI1NiIs...",
      "accessTokenExpiresAt": "2024-01-15T12:00:00.000Z",
      "refreshTokenExpiresAt": "2024-02-07T12:00:00.000Z",
      "tokenType": "Bearer"
    },
    "needsHealthProfile": true
  }
}
```

#### Login

```http
POST /auth/login
```

**Request Body:**
```json
{
  "email": "sarah@example.com",
  "password": "SecureP@ss123",
  "deviceId": "iPhone-12-ABC123",
  "deviceType": "ios"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "email": "sarah@example.com",
      "name": "Sarah Johnson",
      "profileImageUrl": "https://s3.amazonaws.com/momcare/profiles/...",
      "emailVerified": true,
      "subscriptionStatus": "premium"
    },
    "tokens": {
      "accessToken": "eyJhbGciOiJIUzI1NiIs...",
      "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
    },
    "hasHealthProfile": true
  }
}
```

#### Refresh Token

```http
POST /auth/refresh
```

**Request Body:**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
}
```

#### Get Current User

```http
GET /auth/me
Authorization: Bearer <token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "email": "sarah@example.com",
      "name": "Sarah Johnson",
      "deliveryDate": "2023-11-15",
      "deliveryType": "vaginal",
      "isBreastfeeding": true,
      "breastfeedingIntensity": "exclusive",
      "currentWeightKg": 68.5,
      "targetWeightKg": 62,
      "postpartumWeeks": 8,
      "subscriptionStatus": "premium",
      "notificationsEnabled": true,
      "measurementUnit": "metric"
    }
  }
}
```

---

### Food Tracking

#### Log a Food Entry

```http
POST /food
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "name": "Oatmeal with Berries",
  "mealType": "breakfast",
  "calories": 350,
  "protein": 12,
  "carbohydrates": 55,
  "fat": 8,
  "fiber": 6,
  "iron": 3.5,
  "calcium": 200,
  "servingSize": "1 bowl",
  "servingCount": 1,
  "notes": "Added honey and almonds"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Food entry logged successfully",
  "data": {
    "entry": {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "name": "Oatmeal with Berries",
      "mealType": "breakfast",
      "calories": 350,
      "protein": 12,
      "carbohydrates": 55,
      "fat": 8,
      "fiber": 6,
      "iron": 3.5,
      "calcium": 200,
      "servingSize": "1 bowl",
      "servingCount": 1,
      "loggedAt": "2024-01-08T08:30:00.000Z"
    }
  }
}
```

#### Get Food Entries by Date

```http
GET /food/date/2024-01-08
Authorization: Bearer <token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "date": "2024-01-08",
    "entries": [
      {
        "id": "660e8400-e29b-41d4-a716-446655440001",
        "name": "Oatmeal with Berries",
        "mealType": "breakfast",
        "calories": 350,
        "protein": 12,
        "carbohydrates": 55,
        "fat": 8
      }
    ],
    "groupedByMeal": {
      "breakfast": [...],
      "lunch": [...],
      "dinner": [...],
      "snack": [...]
    },
    "totals": {
      "calories": 1850,
      "protein": 85,
      "carbohydrates": 220,
      "fat": 65,
      "iron": 15.5,
      "calcium": 950
    },
    "targets": {
      "calories": 2200,
      "protein": 82,
      "carbohydrates": 275,
      "fat": 73
    },
    "progress": {
      "caloriesPercent": 84,
      "proteinPercent": 104,
      "carbsPercent": 80,
      "fatPercent": 89
    }
  },
  "disclaimer": "Postpartum nutritional needs vary. This guidance is general and may not account for your specific health conditions."
}
```

#### Get Nutrition Targets

```http
GET /food/targets
Authorization: Bearer <token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "hasProfile": true,
    "bmr": 1450,
    "tdee": 1994,
    "targetCalories": 2094,
    "macros": {
      "protein": 78,
      "carbohydrates": 262,
      "fat": 70
    },
    "breastfeedingAdjustment": 500,
    "disclaimer": "These calculations are estimates. Consult with a healthcare provider or registered dietitian for personalized advice."
  },
  "disclaimer": "Postpartum nutritional needs vary..."
}
```

#### AI Food Recognition (Premium)

```http
POST /food/recognize
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "imageUrl": "https://s3.amazonaws.com/momcare/uploads/food-123.jpg",
  "mealType": "lunch"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "recognized": true,
    "food": {
      "name": "Grilled Chicken Salad",
      "confidence": 0.92,
      "alternatives": ["Caesar Salad", "Garden Salad"],
      "calories": 420,
      "protein": 35,
      "carbohydrates": 15,
      "fat": 22
    },
    "suggestedEntry": {
      "name": "Grilled Chicken Salad",
      "mealType": "lunch",
      "calories": 420,
      "protein": 35,
      "carbohydrates": 15,
      "fat": 22,
      "isAiRecognized": true,
      "aiConfidence": 0.92
    }
  }
}
```

---

### Hydration Tracking

#### Log Hydration

```http
POST /hydration
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "amount": 250,
  "drinkType": "water"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Hydration logged successfully",
  "data": {
    "entry": {
      "id": "770e8400-e29b-41d4-a716-446655440001",
      "amount": 250,
      "drinkType": "water",
      "effectiveHydration": 250,
      "loggedAt": "2024-01-08T09:15:00.000Z"
    }
  }
}
```

#### Get Today's Progress

```http
GET /hydration/today
Authorization: Bearer <token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "date": "2024-01-08",
    "entries": [...],
    "totalMl": 1750,
    "totalGlasses": 7,
    "goalMl": 2800,
    "goalGlasses": 11,
    "progress": 0.63,
    "progressPercent": 63,
    "remainingMl": 1050,
    "remainingGlasses": 5,
    "isGoalMet": false,
    "byDrinkType": {
      "water": { "amount": 1500, "count": 6 },
      "tea": { "amount": 250, "count": 1 }
    },
    "recommendation": "Breastfeeding increases your hydration needs. Drink a glass of water each time you nurse or pump.",
    "nextReminder": {
      "time": "2024-01-08T10:45:00.000Z",
      "suggestedAmount": 250
    }
  }
}
```

#### Quick Add Preset

```http
POST /hydration/quick-add
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "preset": "glass"
}
```

**Presets:**
- `glass`: 250ml
- `bottle`: 500ml
- `large_bottle`: 750ml
- `small_cup`: 150ml

---

### Exercise & Workouts

#### Get Exercises

```http
GET /exercises?category=pelvic_floor&difficulty=beginner
Authorization: Bearer <token>
```

**Query Parameters:**
- `category`: pelvic_floor, core_reconnection, breathing, yoga, walking, strength, cardio, stretching, hiit
- `recoveryStage`: early_recovery, progressive_strengthening, building_strength, full_recovery
- `difficulty`: beginner, intermediate, advanced
- `maxDuration`: Maximum duration in minutes
- `page`: Page number (default: 1)
- `limit`: Items per page (default: 20)

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "exercises": [
      {
        "id": "880e8400-e29b-41d4-a716-446655440001",
        "name": "Kegel Exercises",
        "description": "Strengthen your pelvic floor muscles",
        "category": "pelvic_floor",
        "recoveryStage": "early_recovery",
        "difficulty": "beginner",
        "durationMinutes": 5,
        "caloriesBurned": 10,
        "equipment": [],
        "muscleGroups": ["pelvic_floor"],
        "videoUrl": "https://cdn.momcare.app/videos/kegel.mp4",
        "thumbnailUrl": "https://cdn.momcare.app/thumbnails/kegel.jpg",
        "instructions": [
          "Lie down or sit comfortably",
          "Squeeze your pelvic floor muscles",
          "Hold for 5 seconds",
          "Release and rest for 5 seconds",
          "Repeat 10-15 times"
        ],
        "benefits": [
          "Strengthens pelvic floor muscles",
          "Helps with bladder control"
        ],
        "warnings": [
          "Don't do Kegels while urinating",
          "Stop if you feel pain"
        ],
        "isPremium": false,
        "isFavorite": true
      }
    ],
    "filters": {
      "category": "pelvic_floor",
      "recoveryStage": "early_recovery",
      "difficulty": "beginner"
    }
  },
  "disclaimer": "Wait until cleared by your healthcare provider before starting exercise routines."
}
```

#### Get Personalized Recommendations

```http
GET /exercises/recommendations
Authorization: Bearer <token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "recommendations": [...],
    "recoveryStage": {
      "postpartumWeeks": 8,
      "stage": "progressive_strengthening",
      "title": "Progressive Strengthening (6-12 weeks)",
      "description": "Gradually rebuilding core strength and stamina",
      "allowedIntensity": "Light to Moderate",
      "exerciseTypes": ["pelvic_floor", "core_reconnection", "yoga", "walking", "stretching"]
    },
    "guidance": {
      "clearanceRequired": false,
      "message": "You're in Progressive Strengthening (6-12 weeks). These exercises are safe for your stage."
    }
  }
}
```

#### Start a Workout

```http
POST /workouts
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "exerciseIds": [
    "880e8400-e29b-41d4-a716-446655440001",
    "880e8400-e29b-41d4-a716-446655440002"
  ],
  "moodBefore": "good"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Workout started",
  "data": {
    "session": {
      "id": "990e8400-e29b-41d4-a716-446655440001",
      "startTime": "2024-01-08T10:00:00.000Z",
      "moodBefore": "good",
      "exercises": [...]
    }
  }
}
```

#### Complete a Workout

```http
PUT /workouts/{id}/complete
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "duration": 25,
  "caloriesBurned": 120,
  "moodAfter": "great",
  "notes": "Felt energized after!",
  "exerciseCompletions": [
    {
      "exerciseId": "880e8400-e29b-41d4-a716-446655440001",
      "completed": true,
      "reps": 15,
      "sets": 3
    }
  ]
}
```

---

### Health Endpoints

All health-related endpoints include a medical disclaimer in the response.

#### Get User Recovery Stage

```http
GET /profile/recovery-stage
Authorization: Bearer <token>
```

**Response:**
```json
{
  "success": true,
  "data": {
    "postpartumWeeks": 8,
    "stage": "progressive_strengthening",
    "title": "Progressive Strengthening (6-12 weeks)",
    "description": "Gradually rebuilding core strength and stamina",
    "allowedIntensity": "Light to Moderate",
    "exerciseTypes": ["pelvic_floor", "core_reconnection", "yoga", "walking", "stretching"],
    "exerciseCleared": true,
    "warning": null
  },
  "disclaimer": "Wait until cleared by your healthcare provider (typically 6 weeks postpartum) before starting or intensifying exercise routines."
}
```

---

## Error Responses

### Standard Error Format

```json
{
  "success": false,
  "message": "Error description",
  "code": "ERROR_CODE",
  "errors": [
    {
      "field": "email",
      "message": "Email is required"
    }
  ],
  "meta": {
    "timestamp": "2024-01-08T12:00:00.000Z",
    "path": "/api/v1/auth/register",
    "method": "POST"
  }
}
```

### Common Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `VALIDATION_ERROR` | 400 | Request validation failed |
| `UNAUTHORIZED` | 401 | Authentication required or failed |
| `FORBIDDEN` | 403 | Access denied |
| `NOT_FOUND` | 404 | Resource not found |
| `EMAIL_EXISTS` | 409 | Email already registered |
| `RATE_LIMITED` | 429 | Too many requests |
| `PREMIUM_REQUIRED` | 403 | Premium subscription required |
| `ACCOUNT_LOCKED` | 403 | Account temporarily locked |
| `TOKEN_EXPIRED` | 401 | Authentication token expired |
| `INTERNAL_ERROR` | 500 | Server error |

---

## Rate Limiting

| Endpoint Type | Limit | Window |
|---------------|-------|--------|
| General API | 100 requests | 15 minutes |
| Authentication | 5 requests | 15 minutes |
| Password Reset | 3 requests | 1 hour |
| File Upload | 30 requests | 1 hour |
| AI Features (Free) | 20 requests | 1 hour |
| AI Features (Premium) | 100 requests | 1 hour |

Rate limit headers are included in responses:
- `X-RateLimit-Limit`
- `X-RateLimit-Remaining`
- `X-RateLimit-Reset`
- `Retry-After` (when limited)

---

## Real-Time Features (Socket.io)

Connect to the WebSocket server with authentication:

```javascript
const socket = io('wss://api.momcare.app', {
  auth: {
    token: accessToken
  }
});
```

### Events

**Client to Server:**
- `join:community` - Join a community chat room
- `leave:community` - Leave a community chat room
- `chat:message` - Send a chat message
- `chat:typing` - Typing indicator
- `workout:start` - Start workout notification
- `workout:complete` - Complete workout notification
- `encouragement:send` - Send encouragement to partner

**Server to Client:**
- `notification` - General notification
- `achievement:earned` - Achievement notification
- `chat:message` - New chat message
- `chat:typing` - User typing indicator
- `progress:updated` - Progress update (for partner)
- `encouragement:received` - Encouragement message received

---

## Medical Disclaimers

All health-related endpoints include appropriate disclaimers:

- **General:** "This information is for educational purposes only and is not a substitute for professional medical advice."
- **Weight:** "Safe postpartum weight loss is typically 1-2 lbs per week."
- **Breastfeeding:** "If breastfeeding, maintain a minimum of 1800 calories daily."
- **Exercise:** "Wait until cleared by your healthcare provider before starting exercise routines."
- **Mental Health:** "If experiencing persistent feelings of sadness or anxiety, please contact a healthcare provider."

---

## HIPAA Compliance

This API is designed with HIPAA compliance in mind:

- All PHI (Protected Health Information) is encrypted at rest and in transit
- Audit logging for all data access
- Minimal data collection
- Secure authentication with token rotation
- Data retention policies enforced

---

## Support

For API support, contact: api-support@momcare.app

For security issues: security@momcare.app
