/**
 * MomCare API Tests - Food Tracking Endpoints
 *
 * Tests for food logging, nutrition tracking, and calorie management
 */

const request = require('supertest');
const { ensureAuth } = require('./testHelper');

const BASE_URL = global.API_BASE_URL;
const API = global.API_VERSION;

describe('Food Tracking API', () => {
  let authToken;
  let foodEntryId;

  beforeAll(async () => {
    authToken = await ensureAuth();
  });

  describe('POST /food/log', () => {
    it('should log a food entry with manual input', async () => {
      const response = await request(BASE_URL)
        .post(`${API}/food/log`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          mealType: 'breakfast',
          foodName: 'Oatmeal with berries',
          servingSize: 1,
          servingUnit: 'bowl',
          calories: 320,
          protein: 12,
          carbs: 54,
          fat: 8,
          fiber: 10,
          iron: 3.2,
          calcium: 150,
        })
        .expect('Content-Type', /json/)
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Food entry logged successfully');
      expect(response.body.data).toHaveProperty('foodEntry');
      expect(response.body.data.foodEntry).toHaveProperty('id');
      expect(response.body.data.foodEntry.foodName).toBe('Oatmeal with berries');
      expect(response.body.data.foodEntry.calories).toBe(320);

      foodEntryId = response.body.data.foodEntry.id;
    });

    it('should log food entry with AI recognition metadata', async () => {
      const response = await request(BASE_URL)
        .post(`${API}/food/log`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          mealType: 'lunch',
          foodName: 'Grilled chicken salad',
          servingSize: 1,
          servingUnit: 'plate',
          calories: 425,
          protein: 38,
          carbs: 22,
          fat: 18,
          recognitionMethod: 'ai',
          recognitionConfidence: 0.92,
          imageUrl: 'https://example.com/food-photos/12345.jpg',
        })
        .expect('Content-Type', /json/)
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.data.foodEntry.recognitionMethod).toBe('ai');
      expect(response.body.data.foodEntry.recognitionConfidence).toBe(0.92);
    });

    it('should reject food entry without authentication', async () => {
      const response = await request(BASE_URL)
        .post(`${API}/food/log`)
        .send({
          mealType: 'dinner',
          foodName: 'Test food',
          calories: 100,
        })
        .expect('Content-Type', /json/)
        .expect(401);

      expect(response.body.success).toBe(false);
      expect(response.body.code).toBe('UNAUTHORIZED');
    });

    it('should reject food entry with missing required fields', async () => {
      const response = await request(BASE_URL)
        .post(`${API}/food/log`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          foodName: 'Incomplete entry',
          // Missing mealType and calories
        })
        .expect('Content-Type', /json/)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.code).toBe('BAD_REQUEST');
    });

    it('should reject food entry with invalid meal type', async () => {
      const response = await request(BASE_URL)
        .post(`${API}/food/log`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          mealType: 'midnight-snack', // Invalid meal type
          foodName: 'Test food',
          calories: 100,
        })
        .expect('Content-Type', /json/)
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    it('should calculate breastfeeding calorie adjustment', async () => {
      const response = await request(BASE_URL)
        .post(`${API}/food/log`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          mealType: 'snack',
          foodName: 'Apple',
          calories: 95,
          carbs: 25,
        })
        .expect(201);

      expect(response.body.data).toHaveProperty('dailySummary');
      // User is breastfeeding, so daily target should be adjusted
      if (response.body.data.dailySummary.calorieTarget) {
        expect(response.body.data.dailySummary.calorieTarget).toBeGreaterThanOrEqual(1800);
      }
    });
  });

  describe('GET /food/entries', () => {
    it('should get food entries for the current user', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/food/entries`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('entries');
      expect(Array.isArray(response.body.data.entries)).toBe(true);
      expect(response.body.data.entries.length).toBeGreaterThan(0);
    });

    it('should filter food entries by date', async () => {
      const today = new Date().toISOString().split('T')[0];
      const response = await request(BASE_URL)
        .get(`${API}/food/entries?date=${today}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.entries.length).toBeGreaterThan(0);
    });

    it('should filter food entries by meal type', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/food/entries?mealType=breakfast`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      if (response.body.data.entries.length > 0) {
        expect(response.body.data.entries[0].mealType).toBe('breakfast');
      }
    });
  });

  describe('GET /food/entries/:id', () => {
    it('should get a specific food entry by ID', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/food/entries/${foodEntryId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.foodEntry.id).toBe(foodEntryId);
      expect(response.body.data.foodEntry.foodName).toBe('Oatmeal with berries');
    });

    it('should return 404 for non-existent food entry', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/food/entries/99999999`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(404);

      expect(response.body.success).toBe(false);
      expect(response.body.code).toBe('NOT_FOUND');
    });
  });

  describe('PUT /food/entries/:id', () => {
    it('should update a food entry', async () => {
      const response = await request(BASE_URL)
        .put(`${API}/food/entries/${foodEntryId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          calories: 350, // Updated from 320
          notes: 'Added honey',
        })
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.foodEntry.calories).toBe(350);
      expect(response.body.data.foodEntry.notes).toBe('Added honey');
    });

    it('should reject update with invalid data', async () => {
      const response = await request(BASE_URL)
        .put(`${API}/food/entries/${foodEntryId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          calories: -100, // Negative calories should be invalid
        })
        .expect('Content-Type', /json/)
        .expect(400);

      expect(response.body.success).toBe(false);
    });
  });

  describe('DELETE /food/entries/:id', () => {
    it('should delete a food entry', async () => {
      const response = await request(BASE_URL)
        .delete(`${API}/food/entries/${foodEntryId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Food entry deleted successfully');
    });

    it('should return 404 when deleting non-existent entry', async () => {
      const response = await request(BASE_URL)
        .delete(`${API}/food/entries/${foodEntryId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(404);

      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /food/nutrition-targets', () => {
    it('should get personalized nutrition targets', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/food/nutrition-targets`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('targets');
      expect(response.body.data.targets).toHaveProperty('calories');
      expect(response.body.data.targets).toHaveProperty('protein');
      expect(response.body.data.targets).toHaveProperty('carbs');
      expect(response.body.data.targets).toHaveProperty('fat');

      // Breastfeeding user should have minimum 1800 calories
      expect(response.body.data.targets.calories).toBeGreaterThanOrEqual(1800);
    });
  });

  describe('GET /food/daily-summary', () => {
    it('should get daily nutrition summary', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/food/daily-summary`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('date');
      expect(response.body.data).toHaveProperty('totalCalories');
      expect(response.body.data).toHaveProperty('totalProtein');
      expect(response.body.data).toHaveProperty('mealsLogged');
    });

    it('should get daily summary for specific date', async () => {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      const dateStr = yesterday.toISOString().split('T')[0];

      const response = await request(BASE_URL)
        .get(`${API}/food/daily-summary?date=${dateStr}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.date).toBe(dateStr);
    });
  });

  describe('Medical Safety Features', () => {
    it('should include medical disclaimer in nutrition targets', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/food/nutrition-targets`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      const responseString = JSON.stringify(response.body);
      expect(responseString.toLowerCase()).toMatch(/disclaimer|consult|healthcare/);
    });

    it('should enforce minimum calorie requirement for postpartum mothers', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/food/nutrition-targets`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      // Postpartum mothers should never have target below 1800 calories
      expect(response.body.data.targets.calories).toBeGreaterThanOrEqual(1800);
    });
  });
});
