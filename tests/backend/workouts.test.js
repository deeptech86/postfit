/**
 * MomCare API Tests - Workout Session Endpoints
 *
 * Tests for starting, tracking, and completing workout sessions
 */

const request = require('supertest');
const { ensureAuth } = require('./testHelper');

const BASE_URL = global.API_BASE_URL;
const API = global.API_VERSION;

describe('Workout Sessions API', () => {
  let authToken;
  let workoutSessionId;
  let exerciseId;

  beforeAll(async () => {
    authToken = await ensureAuth();

    // Get an exercise ID for workout tests
    const exercisesResponse = await request(BASE_URL)
      .get(`${API}/exercises`)
      .set('Authorization', `Bearer ${authToken}`);

    if (exercisesResponse.body.data.exercises.length > 0) {
      exerciseId = exercisesResponse.body.data.exercises[0].id;
    }
  });

  describe('POST /workouts/session/start', () => {
    it('should start a new workout session', async () => {
      const response = await request(BASE_URL)
        .post(`${API}/workouts/session/start`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          name: 'Morning Postpartum Routine',
          plannedExercises: exerciseId ? [exerciseId] : [],
        })
        .expect('Content-Type', /json/)
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Workout session started');
      expect(response.body.data).toHaveProperty('session');
      expect(response.body.data.session).toHaveProperty('id');
      expect(response.body.data.session.status).toBe('in_progress');
      expect(response.body.data.session.name).toBe('Morning Postpartum Routine');

      workoutSessionId = response.body.data.session.id;
    });

    it('should reject starting workout without authentication', async () => {
      const response = await request(BASE_URL)
        .post(`${API}/workouts/session/start`)
        .send({
          name: 'Test Workout',
        })
        .expect('Content-Type', /json/)
        .expect(401);

      expect(response.body.success).toBe(false);
      expect(response.body.code).toBe('UNAUTHORIZED');
    });
  });

  describe('GET /workouts/session/active', () => {
    it('should get currently active workout session', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/workouts/session/active`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('session');
      expect(response.body.data.session.id).toBe(workoutSessionId);
      expect(response.body.data.session.status).toBe('in_progress');
    });
  });

  describe('POST /workouts/session/:id/exercise', () => {
    it('should add exercise to active workout session', async () => {
      if (!exerciseId) {
        console.warn('Skipping test: No exercise ID available');
        return;
      }

      const response = await request(BASE_URL)
        .post(`${API}/workouts/session/${workoutSessionId}/exercise`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          exerciseId: exerciseId,
          sets: 3,
          reps: 10,
          durationSeconds: 180,
          notes: 'Felt good, no discomfort',
        })
        .expect('Content-Type', /json/)
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Exercise added to workout');
      expect(response.body.data).toHaveProperty('workoutExercise');
      expect(response.body.data.workoutExercise.sets).toBe(3);
      expect(response.body.data.workoutExercise.reps).toBe(10);
    });

    it('should reject negative sets or reps', async () => {
      if (!exerciseId) {
        console.warn('Skipping test: No exercise ID available');
        return;
      }

      const response = await request(BASE_URL)
        .post(`${API}/workouts/session/${workoutSessionId}/exercise`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          exerciseId: exerciseId,
          sets: -1,
          reps: 10,
        })
        .expect('Content-Type', /json/)
        .expect(400);

      expect(response.body.success).toBe(false);
    });
  });

  describe('PUT /workouts/session/:id/complete', () => {
    it('should complete workout session', async () => {
      const response = await request(BASE_URL)
        .put(`${API}/workouts/session/${workoutSessionId}/complete`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          notes: 'Great workout! Felt energized.',
          mood: 'energized',
        })
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Workout session completed');
      expect(response.body.data.session.status).toBe('completed');
      expect(response.body.data.session).toHaveProperty('completedAt');
      expect(response.body.data.session).toHaveProperty('totalDuration');
      expect(response.body.data.session).toHaveProperty('caloriesBurned');
    });

    it('should not allow completing already completed session', async () => {
      const response = await request(BASE_URL)
        .put(`${API}/workouts/session/${workoutSessionId}/complete`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({})
        .expect('Content-Type', /json/)
        .expect(400);

      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /workouts/sessions', () => {
    it('should get workout session history', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/workouts/sessions`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('sessions');
      expect(Array.isArray(response.body.data.sessions)).toBe(true);
      expect(response.body.data.sessions.length).toBeGreaterThan(0);
    });

    it('should filter sessions by date range', async () => {
      const today = new Date().toISOString().split('T')[0];
      const response = await request(BASE_URL)
        .get(`${API}/workouts/sessions?startDate=${today}&endDate=${today}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
    });

    it('should filter sessions by status', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/workouts/sessions?status=completed`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      response.body.data.sessions.forEach(session => {
        expect(session.status).toBe('completed');
      });
    });
  });

  describe('GET /workouts/session/:id', () => {
    it('should get specific workout session details', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/workouts/session/${workoutSessionId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('session');
      expect(response.body.data.session.id).toBe(workoutSessionId);
      expect(response.body.data.session).toHaveProperty('exercises');
      expect(Array.isArray(response.body.data.session.exercises)).toBe(true);
    });

    it('should return 404 for non-existent session', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/workouts/session/99999999`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(404);

      expect(response.body.success).toBe(false);
      expect(response.body.code).toBe('NOT_FOUND');
    });
  });

  describe('DELETE /workouts/session/:id', () => {
    it('should delete a workout session', async () => {
      const response = await request(BASE_URL)
        .delete(`${API}/workouts/session/${workoutSessionId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Workout session deleted');
    });

    it('should return 404 when deleting non-existent session', async () => {
      const response = await request(BASE_URL)
        .delete(`${API}/workouts/session/${workoutSessionId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(404);

      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /workouts/stats', () => {
    it('should get workout statistics', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/workouts/stats`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('totalWorkouts');
      expect(response.body.data).toHaveProperty('totalMinutes');
      expect(response.body.data).toHaveProperty('totalCalories');
      expect(response.body.data).toHaveProperty('averageWorkoutsPerWeek');
      expect(response.body.data).toHaveProperty('currentStreak');
    });

    it('should get stats for specific time period', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/workouts/stats?period=week`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('period');
      expect(response.body.data.period).toBe('week');
    });
  });

  describe('GET /workouts/weekly-progress', () => {
    it('should get weekly workout progress', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/workouts/weekly-progress`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('weeklyBreakdown');
      expect(Array.isArray(response.body.data.weeklyBreakdown)).toBe(true);
      expect(response.body.data.weeklyBreakdown).toHaveLength(7);
    });
  });

  describe('Recovery Stage Tracking', () => {
    it('should track exercises appropriate for recovery stage', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/workouts/stats`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.data).toHaveProperty('recoveryStageCompliance');
    });
  });

  describe('Medical Safety', () => {
    it('should include medical disclaimer in workout responses', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/workouts/sessions`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      const responseString = JSON.stringify(response.body);
      expect(responseString.toLowerCase()).toMatch(/consult|healthcare|cleared/);
    });
  });
});
