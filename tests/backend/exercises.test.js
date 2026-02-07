/**
 * MomCare API Tests - Exercise Library Endpoints
 *
 * Tests for browsing exercises, filtering by recovery stage, and favorites
 */

const request = require('supertest');
const { ensureAuth } = require('./testHelper');

const BASE_URL = global.API_BASE_URL;
const API = global.API_VERSION;

describe('Exercise Library API', () => {
  let authToken;
  let exerciseId;

  beforeAll(async () => {
    authToken = await ensureAuth();
  });

  describe('GET /exercises', () => {
    it('should get all exercises', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/exercises`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('exercises');
      expect(Array.isArray(response.body.data.exercises)).toBe(true);
      expect(response.body.data.exercises.length).toBeGreaterThan(0);

      // Store first exercise ID for later tests
      if (response.body.data.exercises.length > 0) {
        exerciseId = response.body.data.exercises[0].id;
      }
    });

    it('should filter exercises by recovery stage', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/exercises?recoveryStage=early`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      response.body.data.exercises.forEach(exercise => {
        expect(exercise.allowedStages).toContain('early');
      });
    });

    it('should filter exercises by category', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/exercises?category=pelvic_floor`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      if (response.body.data.exercises.length > 0) {
        expect(response.body.data.exercises[0].category).toBe('pelvic_floor');
      }
    });

    it('should filter exercises by difficulty', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/exercises?difficulty=beginner`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      response.body.data.exercises.forEach(exercise => {
        expect(exercise.difficulty).toBe('beginner');
      });
    });

    it('should search exercises by name', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/exercises?search=kegel`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      if (response.body.data.exercises.length > 0) {
        const firstExercise = response.body.data.exercises[0];
        expect(firstExercise.name.toLowerCase()).toContain('kegel');
      }
    });

    it('should return exercises suitable for user recovery stage', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/exercises/recommended`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('exercises');
      expect(response.body.data).toHaveProperty('userRecoveryStage');
    });
  });

  describe('GET /exercises/:id', () => {
    it('should get exercise details by ID', async () => {
      if (!exerciseId) {
        console.warn('Skipping test: No exercise ID available');
        return;
      }

      const response = await request(BASE_URL)
        .get(`${API}/exercises/${exerciseId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('exercise');
      expect(response.body.data.exercise.id).toBe(exerciseId);
      expect(response.body.data.exercise).toHaveProperty('name');
      expect(response.body.data.exercise).toHaveProperty('description');
      expect(response.body.data.exercise).toHaveProperty('instructions');
      expect(response.body.data.exercise).toHaveProperty('videoUrl');
    });

    it('should return 404 for non-existent exercise', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/exercises/99999999`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(404);

      expect(response.body.success).toBe(false);
      expect(response.body.code).toBe('NOT_FOUND');
    });
  });

  describe('POST /exercises/:id/favorite', () => {
    it('should add exercise to favorites', async () => {
      if (!exerciseId) {
        console.warn('Skipping test: No exercise ID available');
        return;
      }

      const response = await request(BASE_URL)
        .post(`${API}/exercises/${exerciseId}/favorite`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Exercise added to favorites');
    });

    it('should handle adding same exercise to favorites twice', async () => {
      if (!exerciseId) {
        console.warn('Skipping test: No exercise ID available');
        return;
      }

      const response = await request(BASE_URL)
        .post(`${API}/exercises/${exerciseId}/favorite`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
    });
  });

  describe('GET /exercises/favorites', () => {
    it('should get user favorite exercises', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/exercises/favorites`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('exercises');
      expect(Array.isArray(response.body.data.exercises)).toBe(true);
    });
  });

  describe('DELETE /exercises/:id/favorite', () => {
    it('should remove exercise from favorites', async () => {
      if (!exerciseId) {
        console.warn('Skipping test: No exercise ID available');
        return;
      }

      const response = await request(BASE_URL)
        .delete(`${API}/exercises/${exerciseId}/favorite`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Exercise removed from favorites');
    });
  });

  describe('Recovery Stage Safety', () => {
    it('should include safety warnings for early postpartum', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/exercises?recoveryStage=early`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      const responseString = JSON.stringify(response.body);
      expect(responseString.toLowerCase()).toMatch(/consult|healthcare|cleared|doctor/);
    });

    it('should flag advanced exercises as not suitable for early recovery', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/exercises?difficulty=advanced`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      if (response.body.data.exercises.length > 0) {
        response.body.data.exercises.forEach(exercise => {
          expect(exercise.allowedStages).not.toContain('early');
        });
      }
    });
  });

  describe('Exercise Categories', () => {
    it('should return exercises in standard categories', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/exercises`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      const validCategories = [
        'pelvic_floor',
        'core',
        'cardio',
        'strength',
        'yoga',
        'stretching',
        'breathing',
      ];

      response.body.data.exercises.forEach(exercise => {
        expect(validCategories).toContain(exercise.category);
      });
    });
  });

  describe('GET /exercises/categories', () => {
    it('should get all exercise categories with counts', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/exercises/categories`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('categories');
      expect(Array.isArray(response.body.data.categories)).toBe(true);

      response.body.data.categories.forEach(category => {
        expect(category).toHaveProperty('name');
        expect(category).toHaveProperty('count');
        expect(category).toHaveProperty('description');
      });
    });
  });
});
