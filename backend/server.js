const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');

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

  if (!Array.isArray(db.users)) {
    db.users = [];
    changed = true;
  }

  if (!Array.isArray(db.tours)) {
    db.tours = [];
    changed = true;
  }

  if (!Array.isArray(db.bookings)) {
    db.bookings = [];
    changed = true;
  }

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

  if (!Array.isArray(db.companyRegistrationRequests)) {
    db.companyRegistrationRequests = [];
    changed = true;
  }

  if (!Array.isArray(db.companyAccounts)) {
    db.companyAccounts = [];
    changed = true;
  }

  if (changed) {
    writeDb(db);
  }
}

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function findLocalCompanyAccountByEmail(db, email) {
  const normalized = normalizeEmail(email);
  if (!normalized) {
    return null;
  }

  return db.companyAccounts.find((item) => normalizeEmail(item.email) === normalized) || null;
}

function getLocalCompanyRequests(db, status = '') {
  const normalizedStatus = String(status || '').trim().toLowerCase();
  const rows = db.companyRegistrationRequests
    .slice()
    .sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')));

  if (!normalizedStatus) {
    return rows;
  }

  return rows.filter((row) => String(row.status || '').toLowerCase() === normalizedStatus);
}

function getLatestLocalCompanyRequestByEmail(db, email) {
  const normalized = normalizeEmail(email);
  if (!normalized) {
    return null;
  }

  const matching = db.companyRegistrationRequests
    .filter((item) => normalizeEmail(item.email) === normalized)
    .sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')));

  return matching[0] || null;
}

async function createLocalCompanyRegistrationRequest(payload) {
  const db = readDb();
  ensureCollections(db);

  const normalizedEmail = normalizeEmail(payload.email);
  if (!payload.companyName || !payload.contactName || !normalizedEmail || !payload.password) {
    throw new Error('Missing required registration fields');
  }

  const existingAccount = findLocalCompanyAccountByEmail(db, normalizedEmail);
  if (existingAccount) {
    throw new Error('A company account with this email already exists');
  }

  const existingPending = db.companyRegistrationRequests.find(
    (item) => normalizeEmail(item.email) === normalizedEmail && item.status === 'pending',
  );
  if (existingPending) {
    throw new Error('A pending registration request already exists for this email');
  }

  const passwordHash = await bcrypt.hash(String(payload.password), 12);
  const row = {
    id: crypto.randomUUID(),
    companyName: String(payload.companyName).trim(),
    contactName: String(payload.contactName).trim(),
    email: normalizedEmail,
    passwordHash,
    commercialId: String(payload.commercialId || '').trim(),
    phone: String(payload.phone || '').trim(),
    city: String(payload.city || '').trim(),
    address: String(payload.address || '').trim(),
    status: 'pending',
    reviewReason: '',
    reviewedBy: '',
    reviewedByEmail: '',
    reviewedAt: '',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  db.companyRegistrationRequests.push(row);
  writeDb(db);
  return row;
}

function reviewLocalCompanyRegistrationRequest(requestId, action, reviewer, reason = '') {
  const db = readDb();
  ensureCollections(db);

  const row = db.companyRegistrationRequests.find((item) => String(item.id) === String(requestId));
  if (!row) {
    throw new Error('Registration request not found');
  }

  if (row.status !== 'pending') {
    throw new Error('Registration request was already reviewed');
  }

  if (action !== 'approve' && action !== 'reject') {
    throw new Error('Invalid review request');
  }

  const now = new Date().toISOString();
  row.status = action === 'approve' ? 'approved' : 'rejected';
  row.reviewReason = String(reason || '').trim();
  row.reviewedBy = String(reviewer?.name || '').trim();
  row.reviewedByEmail = String(reviewer?.email || '').trim();
  row.reviewedAt = now;
  row.updatedAt = now;

  let account = null;
  if (action === 'approve') {
    const existingAccount = findLocalCompanyAccountByEmail(db, row.email);
    if (existingAccount) {
      throw new Error('A company account with this email already exists');
    }

    account = {
      id: crypto.randomUUID(),
      companyName: row.companyName,
      contactName: row.contactName,
      email: row.email,
      passwordHash: row.passwordHash,
      commercialId: row.commercialId,
      phone: row.phone,
      city: row.city,
      address: row.address,
      status: 'approved',
      createdAt: now,
      updatedAt: now,
      approvedRequestId: row.id,
      approvedBy: row.reviewedBy,
      approvedByEmail: row.reviewedByEmail,
      approvedAt: now,
    };
    db.companyAccounts.push(account);
  }

  writeDb(db);
  return {
    request: row,
    companyAccount: account,
  };
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

function adminOnly(req, res, next) {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({ message: 'Forbidden: admin role required' });
  }
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

function asNumber(value, fallback = 0) {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function asList(value) {
  return Array.isArray(value) ? value : [];
}

function localDateOnly(value) {
  if (!value) return '';
  return String(value).slice(0, 10);
}

function monthKeyFromIso(value) {
  if (!value) return '';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

function getLocalCompanyAccountByActor(db, actor) {
  if (!actor) return null;
  const byId = db.companyAccounts.find((item) => String(item.id) === String(actor.id));
  if (byId) return byId;
  return findLocalCompanyAccountByEmail(db, actor.email);
}

function getLocalCompanyName(db, actor) {
  const account = getLocalCompanyAccountByActor(db, actor);
  if (account) {
    return account.companyName || account.contactName || actor?.name || 'Your Company';
  }
  return actor?.name || 'Your Company';
}

function localCompanyTours(db, actor) {
  const tours = asList(db.tours);
  if (!actor || actor.role !== 'company') {
    return tours;
  }

  const own = tours.filter((item) => String(item.createdByCompanyId || '') === String(actor.id || ''));
  if (own.length > 0) {
    return own;
  }

  return tours;
}

function localTourToDto(tour, companyName) {
  return {
    id: String(tour.id || crypto.randomUUID()),
    name: String(tour.name || ''),
    companyName: String(tour.companyName || companyName || ''),
    city: String(tour.city || ''),
    price: asNumber(tour.price, 0),
    date: String(tour.date || ''),
    guide: String(tour.guide || ''),
    guideId: String(tour.guideId || ''),
    capacity: asNumber(tour.capacity, 0),
    participants: asNumber(tour.participants, 0),
    status: String(tour.status || 'Active'),
    duration: String(tour.duration || ''),
    description: String(tour.description || ''),
    mapLocation: String(tour.mapLocation || ''),
    images: asList(tour.images).map((item) => String(item)),
    createdAt: tour.createdAt || '',
    updatedAt: tour.updatedAt || '',
    createdByCompanyId: String(tour.createdByCompanyId || ''),
    createdByCompanyEmail: String(tour.createdByCompanyEmail || ''),
  };
}

function localGuideToDto(guide, tours) {
  const guideId = String(guide.id || '');
  const totalTours = tours.filter((tour) => String(tour.guideId || '') === guideId).length;

  return {
    id: guideId || crypto.randomUUID(),
    name: String(guide.name || 'Unknown Guide'),
    languages: asList(guide.languages).map((item) => String(item)),
    city: String(guide.city || 'N/A'),
    rating: asNumber(guide.rating, 0),
    totalTours,
    status: String(guide.status || 'Available'),
    email: String(guide.email || ''),
    phone: String(guide.phone || ''),
    createdByCompanyId: String(guide.createdByCompanyId || ''),
    createdByCompanyEmail: String(guide.createdByCompanyEmail || ''),
  };
}

function localReportSummary(db, actor) {
  const tours = localCompanyTours(db, actor);
  const toursById = new Map(tours.map((tour) => [tour.id, tour]));
  const bookings = asList(db.bookings).filter((booking) => toursById.has(booking.tourId));
  const customers = asList(db.customers);

  const totalBookings = bookings.length;
  const cancelled = bookings.filter((item) => String(item.status || '') === 'Cancelled').length;
  const completedRevenue = bookings
    .filter((item) => {
      const status = String(item.status || '');
      return status === 'Confirmed' || status === 'Completed';
    })
    .reduce((sum, booking) => {
      const tour = toursById.get(booking.tourId);
      return sum + asNumber(booking.participants, 0) * asNumber(tour?.price, 0);
    }, 0);

  const cityCount = new Map();
  tours.forEach((tour) => {
    const city = String(tour.city || '').trim();
    if (!city) return;
    cityCount.set(city, (cityCount.get(city) || 0) + 1);
  });

  const bestCityEntry = [...cityCount.entries()].sort((a, b) => b[1] - a[1])[0];
  const bestCity = bestCityEntry ? bestCityEntry[0] : 'N/A';

  const langCount = new Map();
  customers.forEach((customer) => {
    const lang = String(customer.language || '').trim();
    if (!lang) return;
    langCount.set(lang, (langCount.get(lang) || 0) + 1);
  });

  const topLanguages = [...langCount.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([lang]) => lang);

  return {
    revenueGrowth: totalBookings > 0 ? 12 : 0,
    customerSatisfaction: asList(db.reviews).length > 0
      ? Number((asList(db.reviews).reduce((sum, r) => sum + asNumber(r.rating, 0), 0) / asList(db.reviews).length).toFixed(1))
      : 0,
    cancellationRate: totalBookings > 0 ? Number(((cancelled / totalBookings) * 100).toFixed(1)) : 0,
    monthlyRevenue: completedRevenue,
    totalCustomers: customers.length,
    bestCity,
    topLanguages,
  };
}

function localDashboardOverview(db, actor) {
  const tours = localCompanyTours(db, actor);
  const toursById = new Map(tours.map((tour) => [tour.id, tour]));
  const bookings = asList(db.bookings).filter((booking) => toursById.has(booking.tourId));
  const guides = asList(db.guides);
  const reviews = asList(db.reviews);

  const companyGuides = actor?.role === 'company'
    ? guides.filter((guide) => {
      const owner = String(guide.createdByCompanyId || '');
      return !owner || owner === String(actor.id || '');
    })
    : guides;

  const today = localDateOnly(new Date().toISOString());
  const todayBookings = bookings.filter((item) => {
    const bDate = localDateOnly(item.date || item.createdAt);
    return bDate && bDate === today;
  }).length;

  const activeTours = tours.filter((tour) => String(tour.status || 'Active') === 'Active').length;
  const currentTourists = bookings
    .filter((item) => String(item.status || '') !== 'Cancelled')
    .reduce((sum, item) => sum + asNumber(item.participants, 0), 0);

  const monthlyRevenue = bookings
    .filter((item) => {
      const status = String(item.status || '');
      return status === 'Confirmed' || status === 'Completed';
    })
    .reduce((sum, item) => {
      const tour = toursById.get(item.tourId);
      return sum + asNumber(item.participants, 0) * asNumber(tour?.price, 0);
    }, 0);

  const lastSixMonths = [];
  const now = new Date();
  for (let i = 5; i >= 0; i -= 1) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    const label = d.toLocaleString('en-US', { month: 'short' });
    lastSixMonths.push({ key, label });
  }

  const bookingCountByMonth = new Map(lastSixMonths.map((m) => [m.key, 0]));
  bookings.forEach((booking) => {
    const key = monthKeyFromIso(booking.date || booking.createdAt);
    if (!key || !bookingCountByMonth.has(key)) return;
    bookingCountByMonth.set(key, (bookingCountByMonth.get(key) || 0) + 1);
  });

  const cityDemandMap = new Map();
  bookings.forEach((booking) => {
    const tour = toursById.get(booking.tourId);
    const city = String(tour?.city || '').trim();
    if (!city) return;
    cityDemandMap.set(city, (cityDemandMap.get(city) || 0) + asNumber(booking.participants, 0));
  });

  const topCities = [...cityDemandMap.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([city, demand]) => ({ city, demand }));

  const topGuides = companyGuides
    .map((guide) => ({
      name: String(guide.name || 'Unknown Guide'),
      rating: asNumber(guide.rating, 0),
    }))
    .sort((a, b) => b.rating - a.rating)
    .slice(0, 3);

  if (topGuides.length === 0 && reviews.length > 0) {
    const reviewByGuide = new Map();
    reviews.forEach((review) => {
      const name = String(review.guideName || '').trim();
      if (!name) return;
      const agg = reviewByGuide.get(name) || { sum: 0, count: 0 };
      agg.sum += asNumber(review.rating, 0);
      agg.count += 1;
      reviewByGuide.set(name, agg);
    });

    reviewByGuide.forEach((agg, name) => {
      topGuides.push({ name, rating: Number((agg.sum / agg.count).toFixed(1)) });
    });
    topGuides.sort((a, b) => b.rating - a.rating);
  }

  return {
    todayBookings,
    activeTours,
    currentTourists,
    monthlyRevenue,
    guidesCount: companyGuides.length,
    monthlyBookings: lastSixMonths.map((m) => bookingCountByMonth.get(m.key) || 0),
    monthlyLabels: lastSixMonths.map((m) => m.label),
    topCities,
    topGuides: topGuides.slice(0, 3),
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

app.post('/api/auth/login', async (req, res) => {
  const { email, password, role } = req.body || {};

  if (!email || !password || !role) {
    return res.status(400).json({ message: 'email, password, and role are required' });
  }

  try {
    const requestedRole = roleToEnum(role);

    if (requestedRole === 'company') {
      if (useRealData()) {
        const account = await integrationService.getCompanyAccountByEmail(email);
        if (!account) {
          const latestRequest = await integrationService.getLatestCompanyRegistrationRequestByEmail(email);
          if (latestRequest && latestRequest.status !== 'approved') {
            return res.status(403).json({
              message: 'Company account is not approved yet',
              code: 'COMPANY_NOT_APPROVED',
              status: latestRequest.status,
              reason: latestRequest.reviewReason,
            });
          }
          return res.status(401).json({ message: 'Invalid credentials' });
        }

        if (account.status !== 'approved') {
          return res.status(403).json({
            message: 'Company account is not approved yet',
            code: 'COMPANY_NOT_APPROVED',
            status: account.status,
          });
        }

        const validPassword = await bcrypt.compare(String(password), String(account.passwordHash || ''));
        if (!validPassword) {
          return res.status(401).json({ message: 'Invalid credentials' });
        }

        const token = crypto.randomUUID();
        const sessionUser = {
          id: account.id,
          name: account.companyName || account.contactName || account.email,
          email: account.email,
          role: 'company',
        };

        sessions.set(token, sessionUser);
        return res.json({ token, user: sessionUser });
      }

      const db = readDb();
      ensureCollections(db);

      const localAccount = findLocalCompanyAccountByEmail(db, email);
      if (localAccount) {
        if (localAccount.status !== 'approved') {
          return res.status(403).json({
            message: 'Company account is not approved yet',
            code: 'COMPANY_NOT_APPROVED',
            status: localAccount.status,
          });
        }

        const validPassword = await bcrypt.compare(
          String(password),
          String(localAccount.passwordHash || ''),
        );
        if (!validPassword) {
          return res.status(401).json({ message: 'Invalid credentials' });
        }

        const token = crypto.randomUUID();
        const sessionUser = {
          id: localAccount.id,
          name: localAccount.companyName || localAccount.contactName || localAccount.email,
          email: localAccount.email,
          role: 'company',
        };
        sessions.set(token, sessionUser);
        return res.json({ token, user: sessionUser });
      }

      const latestRequest = getLatestLocalCompanyRequestByEmail(db, email);
      if (latestRequest && latestRequest.status !== 'approved') {
        return res.status(403).json({
          message: 'Company account is not approved yet',
          code: 'COMPANY_NOT_APPROVED',
          status: latestRequest.status,
          reason: latestRequest.reviewReason,
        });
      }
    }

    const db = readDb();
    ensureCollections(db);
    const user = db.users.find((item) => item.email.toLowerCase() === String(email).toLowerCase());

    if (!user || user.password !== password || user.role !== requestedRole) {
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
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.post('/api/company-auth/register-request', async (req, res) => {
  const {
    companyName,
    contactName,
    email,
    password,
    commercialId,
    phone,
    city,
    address,
  } = req.body || {};

  if (!companyName || !contactName || !email || !password) {
    return res.status(400).json({
      message: 'companyName, contactName, email, and password are required',
    });
  }

  try {
    let requestRow;

    if (useRealData()) {
      const passwordHash = await bcrypt.hash(String(password), 12);
      requestRow = await integrationService.createCompanyRegistrationRequest({
        companyName,
        contactName,
        email,
        passwordHash,
        commercialId,
        phone,
        city,
        address,
      });
    } else {
      requestRow = await createLocalCompanyRegistrationRequest({
        companyName,
        contactName,
        email,
        password,
        commercialId,
        phone,
        city,
        address,
      });
    }

    return res.status(201).json({
      message: 'Registration request submitted and waiting for admin approval',
      request: requestRow,
    });
  } catch (error) {
    if (
      error.message === 'A company account with this email already exists'
      || error.message === 'A pending registration request already exists for this email'
      || error.message === 'Missing required registration fields'
    ) {
      return res.status(409).json({ message: error.message });
    }
    return res.status(500).json({ message: error.message });
  }
});

app.get('/api/admin/company-requests', auth, adminOnly, async (req, res) => {
  try {
    let rows;
    if (useRealData()) {
      rows = await integrationService.listCompanyRegistrationRequests(req.query.status);
    } else {
      const db = readDb();
      ensureCollections(db);
      rows = getLocalCompanyRequests(db, req.query.status);
    }
    return res.json(rows);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.patch('/api/admin/company-requests/:id', auth, adminOnly, async (req, res) => {
  const { action, reason } = req.body || {};

  if (action !== 'approve' && action !== 'reject') {
    return res.status(400).json({ message: 'action must be approve or reject' });
  }

  try {
    let result;
    if (useRealData()) {
      result = await integrationService.reviewCompanyRegistrationRequest(
        req.params.id,
        action,
        req.user,
        reason,
      );
    } else {
      result = reviewLocalCompanyRegistrationRequest(
        req.params.id,
        action,
        req.user,
        reason,
      );
    }
    return res.json(result);
  } catch (error) {
    if (error.message === 'Registration request not found') {
      return res.status(404).json({ message: error.message });
    }
    if (
      error.message === 'Registration request was already reviewed'
      || error.message === 'A company account with this email already exists'
      || error.message === 'Invalid review request'
    ) {
      return res.status(409).json({ message: error.message });
    }
    return res.status(500).json({ message: error.message });
  }
});

app.post('/api/auth/logout', auth, (req, res) => {
  sessions.delete(req.token);
  return res.json({ success: true });
});

app.get('/api/dashboard/overview', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    let overview;
    if (useRealData()) {
      overview = await integrationService.getDashboardOverview(req.user);
    } else {
      const db = readDb();
      ensureCollections(db);
      overview = localDashboardOverview(db, req.user);
    }
    return res.json(overview);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.get('/api/tours', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    let tours;
    if (useRealData()) {
      tours = await integrationService.getTours(req.user);
    } else {
      const db = readDb();
      ensureCollections(db);
      const companyName = getLocalCompanyName(db, req.user);
      tours = localCompanyTours(db, req.user).map((tour) => localTourToDto(tour, companyName));
    }
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
    let tour;
    if (useRealData()) {
      tour = await integrationService.createTour(req.body || {}, req.user);
    } else {
      const db = readDb();
      ensureCollections(db);
      const companyName = getLocalCompanyName(db, req.user);
      const now = new Date().toISOString();
      const created = {
        id: crypto.randomUUID(),
        name: String(name).trim(),
        city: String(city).trim(),
        price: asNumber(price, 0),
        date: String(date).trim(),
        guide: String(guide).trim(),
        guideId: String(req.body?.guideId || '').trim(),
        capacity: asNumber(capacity, 0),
        participants: 0,
        status: 'Active',
        duration: String(duration).trim(),
        description: String(description || '').trim(),
        mapLocation: String(mapLocation || '').trim(),
        images: asList(images).map((item) => String(item)),
        companyName,
        createdByCompanyId: String(req.user?.id || ''),
        createdByCompanyEmail: String(req.user?.email || ''),
        createdAt: now,
        updatedAt: now,
      };
      db.tours.push(created);
      writeDb(db);
      tour = localTourToDto(created, companyName);
    }
    return res.status(201).json(tour);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.put('/api/tours/:id', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    let updated;
    if (useRealData()) {
      updated = await integrationService.updateTour(req.params.id, req.body || {}, req.user);
    } else {
      const db = readDb();
      ensureCollections(db);
      const idx = db.tours.findIndex((item) => String(item.id) === String(req.params.id));
      if (idx === -1) {
        throw new Error('Tour not found');
      }

      const existing = db.tours[idx];
      if (
        req.user?.role === 'company'
        && String(existing.createdByCompanyId || '')
        && String(existing.createdByCompanyId || '') !== String(req.user.id || '')
      ) {
        throw new Error('Forbidden: tour does not belong to this company');
      }

      const merged = {
        ...existing,
        ...req.body,
        id: existing.id,
        createdByCompanyId: existing.createdByCompanyId || String(req.user?.id || ''),
        createdByCompanyEmail: existing.createdByCompanyEmail || String(req.user?.email || ''),
        updatedAt: new Date().toISOString(),
      };

      db.tours[idx] = merged;
      writeDb(db);
      updated = localTourToDto(merged, getLocalCompanyName(db, req.user));
    }
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
    if (useRealData()) {
      await integrationService.deleteTour(req.params.id, req.user);
    } else {
      const db = readDb();
      ensureCollections(db);
      const idx = db.tours.findIndex((item) => String(item.id) === String(req.params.id));
      if (idx === -1) {
        throw new Error('Tour not found');
      }

      const existing = db.tours[idx];
      if (
        req.user?.role === 'company'
        && String(existing.createdByCompanyId || '')
        && String(existing.createdByCompanyId || '') !== String(req.user.id || '')
      ) {
        throw new Error('Forbidden: tour does not belong to this company');
      }

      db.tours.splice(idx, 1);
      db.bookings = asList(db.bookings).filter((item) => String(item.tourId) !== String(req.params.id));
      writeDb(db);
    }
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
    let rows;
    if (useRealData()) {
      rows = await integrationService.getTourParticipants(req.params.id, req.user);
    } else {
      const db = readDb();
      ensureCollections(db);
      const tour = asList(db.tours).find((item) => String(item.id) === String(req.params.id));
      if (!tour) {
        throw new Error('Tour not found');
      }

      if (
        req.user?.role === 'company'
        && String(tour.createdByCompanyId || '')
        && String(tour.createdByCompanyId || '') !== String(req.user.id || '')
      ) {
        throw new Error('Forbidden: tour does not belong to this company');
      }

      rows = asList(db.bookings)
        .filter((item) => String(item.tourId) === String(req.params.id))
        .map((item) => ({
          id: String(item.id || crypto.randomUUID()),
          touristName: String(item.touristName || 'Tourist'),
          participants: asNumber(item.participants, 1),
          totalPrice: asNumber(item.participants, 1) * asNumber(tour.price, 0),
          status: String(item.status || 'Pending'),
        }));
    }
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
    let profile;
    if (useRealData()) {
      profile = await integrationService.getCompanyProfile(req.user);
    } else {
      if (!req.user || req.user.role !== 'company') {
        throw new Error('Forbidden: company account required');
      }

      const db = readDb();
      ensureCollections(db);
      const account = getLocalCompanyAccountByActor(db, req.user);
      if (!account) {
        throw new Error('Forbidden: company account required');
      }

      const stored = account.profile || {};
      profile = {
        companyName: stored.companyName || account.companyName || req.user.name || '',
        branding: stored.branding || '',
        logoUrl: stored.logoUrl || '',
        primaryColor: stored.primaryColor || '#1DB954',
        contactEmail: stored.contactEmail || account.email || req.user.email || '',
        contactPhone: stored.contactPhone || account.phone || '',
        city: stored.city || account.city || '',
        address: stored.address || account.address || '',
        commercialId: stored.commercialId || account.commercialId || '',
        description: stored.description || '',
        website: stored.website || '',
      };
    }
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
    let profile;
    if (useRealData()) {
      profile = await integrationService.updateCompanyProfile(req.user, req.body || {});
    } else {
      if (!req.user || req.user.role !== 'company') {
        throw new Error('Forbidden: company account required');
      }

      const db = readDb();
      ensureCollections(db);
      const account = getLocalCompanyAccountByActor(db, req.user);
      if (!account) {
        throw new Error('Forbidden: company account required');
      }

      const payload = req.body || {};
      account.profile = {
        ...(account.profile || {}),
        companyName: String(payload.companyName || account.companyName || ''),
        branding: String(payload.branding || ''),
        logoUrl: String(payload.logoUrl || ''),
        primaryColor: String(payload.primaryColor || '#1DB954'),
        contactEmail: String(payload.contactEmail || account.email || ''),
        contactPhone: String(payload.contactPhone || account.phone || ''),
        city: String(payload.city || account.city || ''),
        address: String(payload.address || account.address || ''),
        commercialId: String(payload.commercialId || account.commercialId || ''),
        description: String(payload.description || ''),
        website: String(payload.website || ''),
      };

      account.companyName = account.profile.companyName || account.companyName;
      account.city = account.profile.city || account.city;
      account.address = account.profile.address || account.address;
      account.phone = account.profile.contactPhone || account.phone;
      account.updatedAt = new Date().toISOString();
      writeDb(db);

      profile = account.profile;
    }
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
    let settings;
    if (useRealData()) {
      settings = await integrationService.getCompanySettings(req.user);
    } else {
      if (!req.user || req.user.role !== 'company') {
        throw new Error('Forbidden: company account required');
      }

      const db = readDb();
      ensureCollections(db);
      const account = getLocalCompanyAccountByActor(db, req.user);
      if (!account) {
        throw new Error('Forbidden: company account required');
      }

      settings = {
        supportEmail: account.settings?.supportEmail || account.email || req.user.email || '',
        supportPhone: account.settings?.supportPhone || account.phone || '',
        city: account.settings?.city || account.city || '',
        description: account.settings?.description || '',
        logoUrl: account.settings?.logoUrl || '',
        openingTime: account.settings?.openingTime || '08:00',
        closingTime: account.settings?.closingTime || '18:00',
        timezone: account.settings?.timezone || 'Asia/Riyadh',
        currency: account.settings?.currency || 'SAR',
        madaEnabled: account.settings?.madaEnabled !== false,
        stcPayEnabled: account.settings?.stcPayEnabled !== false,
        applePayEnabled: account.settings?.applePayEnabled !== false,
      };
    }
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
    let settings;
    if (useRealData()) {
      settings = await integrationService.updateCompanySettings(req.user, req.body || {});
    } else {
      if (!req.user || req.user.role !== 'company') {
        throw new Error('Forbidden: company account required');
      }

      const db = readDb();
      ensureCollections(db);
      const account = getLocalCompanyAccountByActor(db, req.user);
      if (!account) {
        throw new Error('Forbidden: company account required');
      }

      const payload = req.body || {};
      account.settings = {
        ...(account.settings || {}),
        supportEmail: String(payload.supportEmail || account.email || ''),
        supportPhone: String(payload.supportPhone || account.phone || ''),
        city: String(payload.city || account.city || ''),
        description: String(payload.description || ''),
        logoUrl: String(payload.logoUrl || ''),
        openingTime: String(payload.openingTime || '08:00'),
        closingTime: String(payload.closingTime || '18:00'),
        timezone: String(payload.timezone || 'Asia/Riyadh'),
        currency: String(payload.currency || 'SAR'),
        madaEnabled: payload.madaEnabled !== false,
        stcPayEnabled: payload.stcPayEnabled !== false,
        applePayEnabled: payload.applePayEnabled !== false,
      };
      account.updatedAt = new Date().toISOString();
      writeDb(db);
      settings = account.settings;
    }
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
    let rows;
    if (useRealData()) {
      rows = await integrationService.getBookings(req.user);
    } else {
      const db = readDb();
      ensureCollections(db);
      const tours = localCompanyTours(db, req.user);
      const toursById = new Map(tours.map((tour) => [tour.id, tour]));
      rows = asList(db.bookings)
        .filter((booking) => toursById.has(booking.tourId))
        .map((booking) => bookingToDto(booking, tours));
    }
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
    let row;
    if (useRealData()) {
      row = await integrationService.updateBookingStatus(req.params.id, status);
    } else {
      const db = readDb();
      ensureCollections(db);
      const idx = asList(db.bookings).findIndex((item) => String(item.id) === String(req.params.id));
      if (idx === -1) {
        throw new Error('Booking not found');
      }
      db.bookings[idx].status = status;
      db.bookings[idx].updatedAt = new Date().toISOString();
      writeDb(db);

      const tours = localCompanyTours(db, req.user);
      row = bookingToDto(db.bookings[idx], tours);
    }
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
    let guides;
    if (useRealData()) {
      guides = await integrationService.getGuides(req.user);
    } else {
      const db = readDb();
      ensureCollections(db);
      const tours = localCompanyTours(db, req.user);
      const source = req.user?.role === 'company'
        ? asList(db.guides).filter((item) => {
          const owner = String(item.createdByCompanyId || '');
          return !owner || owner === String(req.user.id || '');
        })
        : asList(db.guides);
      guides = source.map((guide) => localGuideToDto(guide, tours));
    }
    return res.json(guides);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.post('/api/guides', auth, async (req, res) => {
  return res.status(403).json({
    message: 'Guide creation is not allowed from company web. Choose guides from app Firebase list.',
    code: 'GUIDE_CREATE_DISABLED',
  });
});

app.delete('/api/guides/:id', auth, async (req, res) => {
  return res.status(403).json({
    message: 'Guide deletion is not allowed from company web. Guides are managed by app Firebase.',
    code: 'GUIDE_DELETE_DISABLED',
  });
});

app.get('/api/customers', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    let customers;
    if (useRealData()) {
      customers = await integrationService.getCustomers(req.user);
    } else {
      const db = readDb();
      ensureCollections(db);
      customers = asList(db.customers).map((item) => ({
        id: String(item.id || crypto.randomUUID()),
        name: String(item.name || item.touristName || 'Tourist'),
        nationality: String(item.nationality || 'N/A'),
        bookings: asNumber(item.bookings, 0),
        language: String(item.language || 'N/A'),
        lastVisit: String(item.lastVisit || ''),
      }));
    }
    return res.json(customers);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.get('/api/reviews', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    let reviews;
    if (useRealData()) {
      reviews = await integrationService.getReviews();
    } else {
      const db = readDb();
      ensureCollections(db);
      reviews = asList(db.reviews).map((item) => ({
        id: String(item.id || crypto.randomUUID()),
        touristName: String(item.touristName || item.name || 'Tourist'),
        guideName: String(item.guideName || 'Guide'),
        rating: asNumber(item.rating, 0),
        comment: String(item.comment || ''),
      }));
    }
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
    let summary;
    if (useRealData()) {
      summary = await integrationService.getReportSummary(req.user);
    } else {
      const db = readDb();
      ensureCollections(db);
      summary = localReportSummary(db, req.user);
    }
    return res.json(summary);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.get('/api/rewards', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    let rewards;
    if (useRealData()) {
      rewards = await integrationService.getRewards();
    } else {
      const db = readDb();
      ensureCollections(db);
      const rows = req.user?.role === 'company'
        ? asList(db.rewards).filter((item) => {
          const owner = String(item.createdByCompanyId || '');
          return !owner || owner === String(req.user.id || '');
        })
        : asList(db.rewards);

      rewards = rows.map((item) => ({
        id: String(item.id || crypto.randomUUID()),
        title: String(item.title || ''),
        description: String(item.description || ''),
        type: String(item.type || ''),
        value: String(item.value || ''),
        minimumBookings: asNumber(item.minimumBookings, 0),
        validUntil: item.validUntil ? String(item.validUntil) : null,
        status: String(item.status || 'active'),
      }));
    }
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
    let reward;
    if (useRealData()) {
      reward = await integrationService.createReward(req.body || {});
    } else {
      const db = readDb();
      ensureCollections(db);
      const row = {
        id: crypto.randomUUID(),
        title: String(title).trim(),
        description: String(description || '').trim(),
        type: String(type).trim(),
        value: String(value).trim(),
        minimumBookings: asNumber(minimumBookings, 0),
        validUntil: validUntil ? String(validUntil) : null,
        status: 'active',
        createdByCompanyId: String(req.user?.id || ''),
        createdByCompanyEmail: String(req.user?.email || ''),
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };
      db.rewards.push(row);
      writeDb(db);
      reward = row;
    }
    return res.status(201).json(reward);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.put('/api/rewards/:id', auth, async (req, res) => {
  if (!ensureFirebaseDataMode(res)) return;

  try {
    let reward;
    if (useRealData()) {
      reward = await integrationService.updateReward(req.params.id, req.body || {});
    } else {
      const db = readDb();
      ensureCollections(db);
      const idx = asList(db.rewards).findIndex((item) => String(item.id) === String(req.params.id));
      if (idx === -1) {
        throw new Error('Reward not found');
      }

      db.rewards[idx] = {
        ...db.rewards[idx],
        ...req.body,
        id: db.rewards[idx].id,
        updatedAt: new Date().toISOString(),
      };
      writeDb(db);
      reward = db.rewards[idx];
    }
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
    let reward;
    if (useRealData()) {
      reward = await integrationService.setRewardStatus(req.params.id, status);
    } else {
      const db = readDb();
      ensureCollections(db);
      const idx = asList(db.rewards).findIndex((item) => String(item.id) === String(req.params.id));
      if (idx === -1) {
        throw new Error('Reward not found');
      }

      db.rewards[idx].status = status;
      db.rewards[idx].updatedAt = new Date().toISOString();
      writeDb(db);
      reward = db.rewards[idx];
    }
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
    if (useRealData()) {
      await integrationService.deleteReward(req.params.id);
    } else {
      const db = readDb();
      ensureCollections(db);
      db.rewards = asList(db.rewards).filter((item) => String(item.id) !== String(req.params.id));
      writeDb(db);
    }
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
