const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 4000;
const DB_PATH = path.join(__dirname, 'data', 'db.json');
let integrationService = null;

try {
  integrationService = require('./integration-service');
} catch (e) {
  integrationService = null;
}

app.use(cors());
app.use(express.json());

function useRealData() {
  return Boolean(integrationService && integrationService.isFirebaseInitialized);
}

function ensureFirebaseDataMode(res) {
  if (useRealData()) {
    return true;
  }

  res.status(503).json({
    message: 'Firebase data source is required. Set FIREBASE_CREDENTIALS_PATH to use real app data.',
    code: 'FIREBASE_NOT_INITIALIZED',
  });
  return false;
}

function readDb() {
  const raw = fs.readFileSync(DB_PATH, 'utf8');
  return JSON.parse(raw);
}

function writeDb(db) {
  fs.writeFileSync(DB_PATH, JSON.stringify(db, null, 2), 'utf8');
}

function ensureCollections(db) {
  let changed = false;

  if (!Array.isArray(db.guides)) {
    db.guides = [];
    changed = true;
  }

  if (!Array.isArray(db.customers)) {
    db.customers = [];
    changed = true;
  }

  if (!Array.isArray(db.reviews)) {
    db.reviews = [];
    changed = true;
  }

  if (!Array.isArray(db.notifications)) {
    db.notifications = [];
    changed = true;
  }

  if (!Array.isArray(db.rewards)) {
    db.rewards = [];
    changed = true;
  }

  if (changed) {
    writeDb(db);
  }
}

const sessions = new Map();

function auth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'Unauthorized' });
  }

  const token = authHeader.replace('Bearer ', '').trim();
  const user = sessions.get(token);

  if (!user) {
    return res.status(401).json({ message: 'Invalid session' });
  }

  req.user = user;
  req.token = token;
  return next();
}

function roleToEnum(role) {
  if (role === 'admin') {
    return 'admin';
  }
  if (role === 'staff') {
    return 'staff';
  }
  return 'company';
}

function bookingToDto(booking, tours) {
  const tour = tours.find((item) => item.id === booking.tourId);
  const price = tour ? tour.price : 0;
  return {
    id: booking.id,
    touristName: booking.touristName,
    tourId: booking.tourId,
    tourName: tour ? tour.name : 'Unknown Tour',
    participants: booking.participants,
    totalPrice: booking.participants * price,
    status: booking.status,
  };
}

app.get('/api/health', (_, res) => {
  res.json({
    ok: true,
    service: 'dalalak-backend',
    integration: {
      serviceAvailable: Boolean(integrationService),
      firebaseInitialized: Boolean(integrationService && integrationService.isFirebaseInitialized),
    },
  });
});

app.get('/', (_, res) => {
  res.status(200).json({
    message: 'Dalalak backend is running.',
    docs: {
      health: '/api/health',
      login: '/api/auth/login',
      tours: '/api/tours',
    },
  });
});

app.post('/api/auth/login', (req, res) => {
  const { email, password, role } = req.body || {};

  if (!email || !password || !role) {
    return res.status(400).json({ message: 'email, password, and role are required' });
  }

  const db = readDb();
  const user = db.users.find((item) => item.email.toLowerCase() === String(email).toLowerCase());

  if (!user || user.password !== password || user.role !== roleToEnum(role)) {
    return res.status(401).json({ message: 'Invalid credentials' });
  }

  const token = crypto.randomUUID();
  const sessionUser = {
    id: user.id,
    name: user.name,
    email: user.email,
    role: user.role,
  };

  sessions.set(token, sessionUser);

  return res.json({ token, user: sessionUser });
});

app.post('/api/auth/logout', auth, (req, res) => {
  sessions.delete(req.token);
  return res.json({ success: true });
});

app.get('/api/dashboard/overview', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    const overview = await integrationService.getDashboardOverview();
    return res.json(overview);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.get('/api/tours', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    const tours = await integrationService.getTours(req.user);
    return res.json(tours);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.post('/api/tours', auth, async (req, res) => {
  const {
    name,
    city,
    price,
    date,
    guide,
    capacity,
    duration,
    description,
    mapLocation,
    images,
  } = req.body || {};

  if (!name || !city || !price || !date || !guide || !capacity || !duration) {
    return res.status(400).json({ message: 'Missing required tour fields' });
  }

  if (!ensureFirebaseDataMode(res)) return;

  try {
    const tour = await integrationService.createTour(req.body || {}, req.user);
    return res.status(201).json(tour);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.put('/api/tours/:id', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    const updated = await integrationService.updateTour(req.params.id, req.body || {}, req.user);
    return res.json(updated);
  } catch (error) {
    if (error.message === 'Tour not found') {
      return res.status(404).json({ message: error.message });
    }
    if (error.message === 'Forbidden: tour does not belong to this company') {
      return res.status(403).json({ message: error.message });
    }
    return res.status(500).json({ message: error.message });
  }
});

app.delete('/api/tours/:id', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    await integrationService.deleteTour(req.params.id, req.user);
    return res.json({ success: true });
  } catch (error) {
    if (error.message === 'Tour not found') {
      return res.status(404).json({ message: error.message });
    }
    if (error.message === 'Forbidden: tour does not belong to this company') {
      return res.status(403).json({ message: error.message });
    }
    return res.status(500).json({ message: error.message });
  }
});

app.get('/api/tours/:id/participants', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    const rows = await integrationService.getTourParticipants(req.params.id, req.user);
    return res.json(rows);
  } catch (error) {
    if (error.message === 'Tour not found') {
      return res.status(404).json({ message: error.message });
    }
    if (error.message === 'Forbidden: tour does not belong to this company') {
      return res.status(403).json({ message: error.message });
    }
    return res.status(500).json({ message: error.message });
  }
});

app.get('/api/company/profile', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    const profile = await integrationService.getCompanyProfile(req.user);
    return res.json(profile);
  } catch (error) {
    if (error.message === 'Forbidden: company account required') {
      return res.status(403).json({ message: error.message });
    }
    return res.status(500).json({ message: error.message });
  }
});

app.put('/api/company/profile', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    const profile = await integrationService.updateCompanyProfile(req.user, req.body || {});
    return res.json(profile);
  } catch (error) {
    if (error.message === 'Forbidden: company account required') {
      return res.status(403).json({ message: error.message });
    }
    return res.status(500).json({ message: error.message });
  }
});

app.get('/api/company/settings', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    const settings = await integrationService.getCompanySettings(req.user);
    return res.json(settings);
  } catch (error) {
    if (error.message === 'Forbidden: company account required') {
      return res.status(403).json({ message: error.message });
    }
    return res.status(500).json({ message: error.message });
  }
});

app.put('/api/company/settings', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    const settings = await integrationService.updateCompanySettings(req.user, req.body || {});
    return res.json(settings);
  } catch (error) {
    if (error.message === 'Forbidden: company account required') {
      return res.status(403).json({ message: error.message });
    }
    return res.status(500).json({ message: error.message });
  }
});

app.get('/api/bookings', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    const rows = await integrationService.getBookings();
    return res.json(rows);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.patch('/api/bookings/:id/status', auth, async (req, res) => {
  const { status } = req.body || {};
  const allowed = new Set(['Confirmed', 'Pending', 'Cancelled', 'Completed']);

  if (!allowed.has(status)) {
    return res.status(400).json({ message: 'Invalid status' });
  }

  if (!ensureFirebaseDataMode(res)) return;

  try {
    const row = await integrationService.updateBookingStatus(req.params.id, status);
    return res.json(row);
  } catch (error) {
    if (error.message === 'Booking not found') {
      return res.status(404).json({ message: error.message });
    }
    return res.status(500).json({ message: error.message });
  }
});

app.get('/api/guides', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    const guides = await integrationService.getGuides();
    return res.json(guides);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.post('/api/guides', auth, async (req, res) => {
  const { name, city, languages, email, phone } = req.body || {};

  if (!name || !city) {
    return res.status(400).json({ message: 'name and city are required' });
  }

  if (!ensureFirebaseDataMode(res)) return;

  try {
    const created = await integrationService.createGuide(req.body || {});
    return res.status(201).json(created);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.delete('/api/guides/:id', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    await integrationService.deleteGuide(req.params.id);
    return res.json({ success: true });
  } catch (error) {
    if (error.message === 'Guide not found') {
      return res.status(404).json({ message: error.message });
    }
    if (error.message === 'Cannot delete guide with assigned tours') {
      return res.status(409).json({ message: error.message });
    }
    return res.status(500).json({ message: error.message });
  }
});

app.get('/api/customers', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    const customers = await integrationService.getCustomers();
    return res.json(customers);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.get('/api/reviews', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    const reviews = await integrationService.getReviews();
    return res.json(reviews);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.get('/api/notifications', auth, (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;
  res.json([]);
});

app.get('/api/reports/summary', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    const summary = await integrationService.getReportSummary();
    return res.json(summary);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.get('/api/rewards', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    const rewards = await integrationService.getRewards();
    return res.json(rewards);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.post('/api/rewards', auth, async (req, res) => {
  const { title, description, type, value, minimumBookings, validUntil } = req.body || {};
  if (!title || !type || !value) {
    return res.status(400).json({ message: 'title, type, and value are required' });
  }

  if (!ensureFirebaseDataMode(res)) return;

  try {
    const reward = await integrationService.createReward(req.body || {});
    return res.status(201).json(reward);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.put('/api/rewards/:id', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    const reward = await integrationService.updateReward(req.params.id, req.body || {});
    return res.json(reward);
  } catch (error) {
    if (error.message === 'Reward not found') {
      return res.status(404).json({ message: error.message });
    }
    return res.status(500).json({ message: error.message });
  }
});

app.patch('/api/rewards/:id/status', auth, async (req, res) => {
  const { status } = req.body || {};
  if (status !== 'active' && status !== 'inactive') {
    return res.status(400).json({ message: 'status must be active or inactive' });
  }

  if (!ensureFirebaseDataMode(res)) return;

  try {
    const reward = await integrationService.setRewardStatus(req.params.id, status);
    return res.json(reward);
  } catch (error) {
    if (error.message === 'Reward not found') {
      return res.status(404).json({ message: error.message });
    }
    return res.status(500).json({ message: error.message });
  }
});

app.delete('/api/rewards/:id', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    await integrationService.deleteReward(req.params.id);
    return res.json({ success: true });
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

// =====================================================
// MOBILE APP INTEGRATION ENDPOINTS
// =====================================================

// Get integration status
app.get('/api/integration/status', auth, async (req, res) => {
  try {
    if (!integrationService) {
      return res.status(503).json({
        message: 'Integration service not available',
        isAvailable: false,
      });
    }
    const status = await integrationService.getSyncStatus();
    return res.json(status);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

// Sync guides from Firebase
app.post('/api/integration/sync/guides', auth, async (req, res) => {
  try {
    if (!integrationService || !integrationService.isFirebaseInitialized) {
      return res.status(503).json({
        message:
          'Firebase not initialized. Set FIREBASE_CREDENTIALS_PATH environment variable.',
        success: false,
      });
    }
    const result = await integrationService.syncGuidesFromFirebase();
    res.json({ success: true, ...result });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Sync customers from Firebase
app.post('/api/integration/sync/customers', auth, async (req, res) => {
  try {
    if (!integrationService || !integrationService.isFirebaseInitialized) {
      return res.status(503).json({
        message:
          'Firebase not initialized. Set FIREBASE_CREDENTIALS_PATH environment variable.',
        success: false,
      });
    }
    const result = await integrationService.syncCustomersFromFirebase();
    res.json({ success: true, ...result });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Sync tours from Firebase
app.post('/api/integration/sync/tours', auth, async (req, res) => {
  try {
    if (!integrationService || !integrationService.isFirebaseInitialized) {
      return res.status(503).json({
        message:
          'Firebase not initialized. Set FIREBASE_CREDENTIALS_PATH environment variable.',
        success: false,
      });
    }
    const result = await integrationService.syncToursFromFirebase();
    res.json({ success: true, ...result });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Push locally-managed tours to Firebase tourPackages for mobile app visibility
app.post('/api/integration/push/tours', auth, async (req, res) => {
  try {
    if (!integrationService || !integrationService.isFirebaseInitialized) {
      return res.status(503).json({
        message:
          'Firebase not initialized. Set FIREBASE_CREDENTIALS_PATH environment variable.',
        success: false,
      });
    }

    const tours = Array.isArray(req.body?.tours) ? req.body.tours : null;
    if (!tours) {
      return res.status(400).json({
        success: false,
        message: 'Provide tours array in request body: { "tours": [...] }',
      });
    }

    const result = await integrationService.pushToursToFirebase(tours);
    return res.json({ success: true, ...result });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// Sync bookings from Firebase
app.post('/api/integration/sync/bookings', auth, async (req, res) => {
  try {
    if (!integrationService || !integrationService.isFirebaseInitialized) {
      return res.status(503).json({
        message:
          'Firebase not initialized. Set FIREBASE_CREDENTIALS_PATH environment variable.',
        success: false,
      });
    }
    const result = await integrationService.syncBookingsFromFirebase();
    res.json({ success: true, ...result });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Sync reviews from Firebase
app.post('/api/integration/sync/reviews', auth, async (req, res) => {
  try {
    if (!integrationService || !integrationService.isFirebaseInitialized) {
      return res.status(503).json({
        message:
          'Firebase not initialized. Set FIREBASE_CREDENTIALS_PATH environment variable.',
        success: false,
      });
    }
    const result = await integrationService.syncReviewsFromFirebase();
    res.json({ success: true, ...result });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Full sync from Firebase (all collections)
app.post('/api/integration/sync', auth, async (req, res) => {
  try {
    if (!integrationService || !integrationService.isFirebaseInitialized) {
      return res.status(503).json({
        message:
          'Firebase not initialized. Set FIREBASE_CREDENTIALS_PATH environment variable.',
        success: false,
      });
    }
    const result = await integrationService.performFullSync();
    res.json({ success: true, ...result });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`Dalalak backend listening on port ${PORT}`);
});
