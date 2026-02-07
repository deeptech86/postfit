/**
 * MomCare API Tests - Hydration Tracking Endpoints
 *
 * Tests for water intake logging and hydration goals
 */

const request = require('supertest');
const { ensureAuth } = require('./testHelper');

const BASE_URL = global.API_BASE_URL;
const API = global.API_VERSION;

describe('Hydration Tracking API', () => {
  let authToken;
  let hydrationEntryId;

  beforeAll(async () => {
    authToken = await ensureAuth();
  });

  describe('POST /hydration/log', () => {
    it('should log water intake in milliliters', async () => {
      const response = await request(BASE_URL)
        .post(`${API}/hydration/log`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          amountMl: 250,
          drinkType: 'water',
        })
        .expect('Content-Type', /json/)
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Hydration logged successfully');
      expect(response.body.data).toHaveProperty('hydrationEntry');
      expect(response.body.data.hydrationEntry.amountMl).toBe(250);
      expect(response.body.data.hydrationEntry.drinkType).toBe('water');

      hydrationEntryId = response.body.data.hydrationEntry.id;
    });

    it('should log other drink types', async () => {
      const response = await request(BASE_URL)
        .post(`${API}/hydration/log`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          amountMl: 200,
          drinkType: 'herbal_tea',
        })
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.data.hydrationEntry.drinkType).toBe('herbal_tea');
    });

    it('should use quick-add preset amounts', async () => {
      const response = await request(BASE_URL)
        .post(`${API}/hydration/log`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          preset: 'glass', // 250ml
          drinkType: 'water',
        })
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.data.hydrationEntry.amountMl).toBe(250);
    });

    it('should reject negative amounts', async () => {
      const response = await request(BASE_URL)
        .post(`${API}/hydration/log`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          amountMl: -100,
          drinkType: 'water',
        })
        .expect('Content-Type', /json/)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.code).toBe('BAD_REQUEST');
    });

    it('should reject excessive amounts (> 2000ml single entry)', async () => {
      const response = await request(BASE_URL)
        .post(`${API}/hydration/log`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          amountMl: 5000, // Unrealistic amount
          drinkType: 'water',
        })
        .expect('Content-Type', /json/)
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    it('should include daily progress in response', async () => {
      const response = await request(BASE_URL)
        .post(`${API}/hydration/log`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          amountMl: 300,
          drinkType: 'water',
        })
        .expect(201);

      expect(response.body.data).toHaveProperty('dailyProgress');
      expect(response.body.data.dailyProgress).toHaveProperty('totalMl');
      expect(response.body.data.dailyProgress).toHaveProperty('goalMl');
      expect(response.body.data.dailyProgress).toHaveProperty('percentComplete');
    });
  });

  describe('GET /hydration/entries', () => {
    it('should get hydration entries for current user', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/hydration/entries`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('entries');
      expect(Array.isArray(response.body.data.entries)).toBe(true);
      expect(response.body.data.entries.length).toBeGreaterThan(0);
    });

    it('should filter entries by date', async () => {
      const today = new Date().toISOString().split('T')[0];
      const response = await request(BASE_URL)
        .get(`${API}/hydration/entries?date=${today}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      response.body.data.entries.forEach(entry => {
        expect(entry.loggedAt).toContain(today);
      });
    });
  });

  describe('GET /hydration/goal', () => {
    it('should get personalized hydration goal', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/hydration/goal`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('goalMl');
      expect(response.body.data).toHaveProperty('adjustments');

      // Breastfeeding user should have higher goal (30-50% increase)
      expect(response.body.data.goalMl).toBeGreaterThanOrEqual(2400); // Base 2000ml + 20% minimum
    });

    it('should show breastfeeding adjustment', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/hydration/goal`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.data.adjustments).toHaveProperty('breastfeeding');
      expect(response.body.data.adjustments.breastfeeding).toBeTruthy();
    });
  });

  describe('PUT /hydration/goal', () => {
    it('should update hydration goal', async () => {
      const response = await request(BASE_URL)
        .put(`${API}/hydration/goal`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          goalMl: 3000,
        })
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.goalMl).toBe(3000);
    });

    it('should reject unrealistic goals (< 1000ml or > 6000ml)', async () => {
      const response = await request(BASE_URL)
        .put(`${API}/hydration/goal`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          goalMl: 500, // Too low
        })
        .expect('Content-Type', /json/)
        .expect(400);

      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /hydration/daily-summary', () => {
    it('should get daily hydration summary', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/hydration/daily-summary`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('date');
      expect(response.body.data).toHaveProperty('totalMl');
      expect(response.body.data).toHaveProperty('goalMl');
      expect(response.body.data).toHaveProperty('entriesCount');
      expect(response.body.data).toHaveProperty('percentComplete');
    });

    it('should get summary for specific date', async () => {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      const dateStr = yesterday.toISOString().split('T')[0];

      const response = await request(BASE_URL)
        .get(`${API}/hydration/daily-summary?date=${dateStr}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.date).toBe(dateStr);
    });
  });

  describe('DELETE /hydration/entries/:id', () => {
    it('should delete a hydration entry', async () => {
      const response = await request(BASE_URL)
        .delete(`${API}/hydration/entries/${hydrationEntryId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Hydration entry deleted successfully');
    });

    it('should return 404 for non-existent entry', async () => {
      const response = await request(BASE_URL)
        .delete(`${API}/hydration/entries/99999999`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(404);

      expect(response.body.success).toBe(false);
      expect(response.body.code).toBe('NOT_FOUND');
    });
  });

  describe('GET /hydration/weekly-stats', () => {
    it('should get weekly hydration statistics', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/hydration/weekly-stats`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('weeklyAverage');
      expect(response.body.data).toHaveProperty('daysGoalMet');
      expect(response.body.data).toHaveProperty('dailyBreakdown');
      expect(Array.isArray(response.body.data.dailyBreakdown)).toBe(true);
      expect(response.body.data.dailyBreakdown).toHaveLength(7);
    });
  });

  describe('Breastfeeding Adjustments', () => {
    it('should apply breastfeeding adjustment to hydration goal', async () => {
      const response = await request(BASE_URL)
        .get(`${API}/hydration/goal`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      // Test user is breastfeeding, so goal should be adjusted
      const baseGoal = 2000; // Standard daily goal
      const adjustedGoal = response.body.data.goalMl;

      // Should be at least 30% higher for breastfeeding
      expect(adjustedGoal).toBeGreaterThanOrEqual(baseGoal * 1.3);
    });
  });
});
