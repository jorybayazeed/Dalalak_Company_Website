const admin = require('firebase-admin');
const fs = require('fs');

class IntegrationService {
  constructor() {
    this.db = null;
    this.isFirebaseInitialized = false;
    this.initializeFirebase();
  }

  initializeFirebase() {
    try {
      const credentialsPath = process.env.FIREBASE_CREDENTIALS_PATH;
      if (!credentialsPath || !fs.existsSync(credentialsPath)) {
        console.log('Firebase credentials not found. Running without Firebase data.');
        return;
      }

      const serviceAccount = JSON.parse(fs.readFileSync(credentialsPath, 'utf8'));

      if (admin.apps.length === 0) {
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
        });
      }

      this.db = admin.firestore();
      this.isFirebaseInitialized = true;
      console.log('Firebase initialized for real app data.');
    } catch (error) {
      console.error('Firebase initialization warning:', error.message);
      this.isFirebaseInitialized = false;
      this.db = null;
    }
  }

  _asNumber(value, fallback = 0) {
    const n = Number(value);
    return Number.isFinite(n) ? n : fallback;
  }

  _dateOnly(value) {
    if (!value) return '';
    if (typeof value === 'string') return value.slice(0, 10);
    if (value && typeof value.toDate === 'function') {
      return value.toDate().toISOString().slice(0, 10);
    }
    return '';
  }

  _bookingStatus(value) {
    const v = String(value || '').toLowerCase();
    if (v === 'confirmed') return 'Confirmed';
    if (v === 'cancelled' || v === 'canceled') return 'Cancelled';
    if (v === 'completed') return 'Completed';
    return 'Pending';
  }

  _bookingStatusFromDoc(doc) {
    if (doc && (doc.cancelledAt || doc.canceledAt)) {
      return 'Cancelled';
    }
    if (doc && doc.completedAt) {
      return 'Completed';
    }
    return this._bookingStatus(doc?.status);
  }

  _safeToDate(value) {
    if (!value) return null;
    if (value instanceof Date) return value;
    if (typeof value.toDate === 'function') {
      return value.toDate();
    }
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }

  async _getUsersByTypeVariants(typeVariants) {
    const variants = [...new Set((typeVariants || []).map((v) => String(v).trim()).filter(Boolean))];
    if (variants.length === 0) {
      return [];
    }

    const resultById = new Map();
    const chunks = [];
    for (let i = 0; i < variants.length; i += 10) {
      chunks.push(variants.slice(i, i + 10));
    }

    for (const chunk of chunks) {
      const snap = await this.db.collection('users').where('userType', 'in', chunk).get();
      snap.docs.forEach((doc) => {
        resultById.set(doc.id, doc);
      });
    }

    return [...resultById.values()];
  }

  _tourStatus(pkg) {
    if (pkg.isCancelled === true) return 'Cancelled';
    const status = String(pkg.status || 'Active');
    if (status === 'Published') return 'Active';
    return status;
  }

  _splitDuration(value) {
    const raw = String(value || '').trim();
    if (!raw) {
      return { durationValue: '', durationUnit: 'Hours' };
    }

    const parts = raw.split(/\s+/);
    return {
      durationValue: parts[0] || '',
      durationUnit: parts.slice(1).join(' ') || 'Hours',
    };
  }

  async _resolveGuideId(payload) {
    const directGuideId = String(payload.guideId || '').trim();
    if (directGuideId) {
      return directGuideId;
    }

    const guideName = String(payload.guide || payload.guideName || '').trim();
    if (!guideName || !this.isFirebaseInitialized) {
      return '';
    }

    const guidesSnap = await this.db.collection('users').where('userType', '==', 'tour_guide').get();
    const normalized = guideName.toLowerCase();
    const matched = guidesSnap.docs.find((doc) => {
      const fullName = String(doc.data().fullName || '').trim().toLowerCase();
      return fullName && fullName === normalized;
    });

    return matched ? matched.id : '';
  }

  async _buildTourPackageDoc(payload) {
    const { durationValue, durationUnit } = this._splitDuration(payload.duration);
    const guideId = await this._resolveGuideId(payload);

    return {
      tourTitle: String(payload.name || payload.tourTitle || '').trim(),
      destination: String(payload.city || payload.destination || '').trim(),
      region: String(payload.region || payload.city || payload.destination || '').trim(),
      durationValue,
      durationUnit,
      price: String(payload.price ?? ''),
      maxGroupSize: String(payload.capacity ?? payload.maxGroupSize ?? ''),
      tourDescription: payload.description ? String(payload.description) : String(payload.tourDescription || ''),
      activityType: String(payload.activityType || ''),
      availableDates: payload.date
        ? String(payload.date)
        : String(payload.availableDates || ''),
      activities: Array.isArray(payload.activities) ? payload.activities : [],
      guideId,
      status: 'Published',
      isCancelled: payload.status === 'Cancelled',
      views: this._asNumber(payload.views, 0),
      bookings: this._asNumber(payload.participants ?? payload.bookings, 0),
      rating: this._asNumber(payload.rating, 0),
      reviews: this._asNumber(payload.reviews, 0),
      image: Array.isArray(payload.images) && payload.images.length > 0
        ? String(payload.images[0])
        : String(payload.image || ''),
      mapLocation: payload.mapLocation ? String(payload.mapLocation) : '',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
  }

  async getGuides(actor) {
    if (!this.isFirebaseInitialized) return [];

    const companyId = String(actor?.id || '');
    if (this._isCompanyActor(actor) && !companyId) {
      return [];
    }

    const toursQuery = this._isCompanyActor(actor)
      ? this.db.collection('tourPackages').where('createdByCompanyId', '==', companyId)
      : this.db.collection('tourPackages');

    const [guideDocs, packagesSnap] = await Promise.all([
      this._getUsersByTypeVariants(['tour_guide', 'Tour Guide']),
      toursQuery.get(),
    ]);

    const guidesDocsFiltered = this._isCompanyActor(actor)
      ? guideDocs.filter((doc) => String(doc.data().createdByCompanyId || '') === companyId)
      : guideDocs;

    const tourCountByGuide = new Map();
    packagesSnap.docs.forEach((doc) => {
      const guideId = doc.data().guideId;
      if (!guideId) return;
      tourCountByGuide.set(guideId, (tourCountByGuide.get(guideId) || 0) + 1);
    });

    return guidesDocsFiltered.map((doc) => {
      const u = doc.data();
      const langs = Array.isArray(u.languages)
        ? u.languages
        : Array.isArray(u.languagesSpoken)
          ? u.languagesSpoken
          : [];
      const specs = Array.isArray(u.specializations) ? u.specializations : [];
      const specialization = specs.length > 0
        ? String(specs[0])
        : String(u.specialization || '');
      return {
        id: doc.id,
        name: u.fullName || u.email || 'Unknown Guide',
        languages: langs.map((l) => String(l)),
        city: u.city || 'N/A',
        specialization,
        yearsOfExperience: this._asNumber(u.yearsOfExperience, 0),
        image: u.image ? String(u.image) : '',
        phone: u.phone ? String(u.phone) : '',
        email: u.email ? String(u.email) : '',
        rating: this._asNumber(u.avgRating || u.rating, 0),
        totalTours: tourCountByGuide.get(doc.id) || 0,
        status: u.isProfileVerified ? 'Available' : 'Pending',
      };
    });
  }

  _buildGuidePayload(payload, { isCreate = false } = {}) {
    const doc = {};
    if (payload.name !== undefined) doc.fullName = String(payload.name).trim();
    if (payload.city !== undefined) doc.city = String(payload.city).trim();
    if (Array.isArray(payload.languages)) {
      const langs = payload.languages.map((l) => String(l).trim()).filter(Boolean);
      doc.languages = langs;
      doc.languagesSpoken = langs;
    }
    if (payload.email !== undefined) doc.email = String(payload.email);
    if (payload.phone !== undefined) doc.phone = String(payload.phone);
    if (payload.specialization !== undefined) {
      const s = String(payload.specialization).trim();
      doc.specialization = s;
      doc.specializations = s ? [s] : [];
    }
    if (payload.yearsOfExperience !== undefined) {
      doc.yearsOfExperience = this._asNumber(payload.yearsOfExperience, 0);
    }
    if (payload.image !== undefined) doc.image = String(payload.image);
    if (isCreate) {
      doc.userType = 'Tour Guide';
      doc.isProfileVerified = true;
      doc.avgRating = 0;
      doc.createdAt = admin.firestore.FieldValue.serverTimestamp();
    }
    doc.updatedAt = admin.firestore.FieldValue.serverTimestamp();
    return doc;
  }

  async createGuide(payload, actor) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const name = String(payload.name || '').trim();
    const city = String(payload.city || '').trim();
    const email = String(payload.email || '').trim();
    const password = String(payload.password || '').trim();
    if (!name || !city) {
      throw new Error('name and city are required');
    }
    if (!email) {
      throw new Error('email is required to create a login for the guide');
    }
    if (!password || password.length < 6) {
      throw new Error('password must be at least 6 characters');
    }

    let authUser;
    try {
      authUser = await admin.auth().createUser({
        email,
        password,
        displayName: name,
      });
    } catch (err) {
      if (err.code === 'auth/email-already-exists') {
        throw new Error('An account with this email already exists');
      }
      throw new Error(err.message || 'Failed to create login account');
    }

    const doc = this._buildGuidePayload(payload, { isCreate: true });

    if (this._isCompanyActor(actor)) {
      doc.createdByCompanyId = String(actor.id || '');
      doc.createdByCompanyEmail = String(actor.email || '');
      doc.createdByCompanyName = String(actor.name || '');
    }

    try {
      await this.db.collection('users').doc(authUser.uid).set(doc);
    } catch (err) {
      try {
        await admin.auth().deleteUser(authUser.uid);
      } catch (_) {}
      throw err;
    }

    return {
      id: authUser.uid,
      name: doc.fullName,
      languages: doc.languages || [],
      city: doc.city,
      specialization: doc.specialization || '',
      yearsOfExperience: doc.yearsOfExperience || 0,
      image: doc.image || '',
      phone: doc.phone || '',
      email,
      rating: 0,
      totalTours: 0,
      status: 'Available',
    };
  }

  async resetGuidePassword(guideId, newPassword, actor) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }
    const id = String(guideId || '').trim();
    if (!id) throw new Error('guideId is required');
    const password = String(newPassword || '').trim();
    if (!password || password.length < 6) {
      throw new Error('password must be at least 6 characters');
    }

    const snap = await this.db.collection('users').doc(id).get();
    if (!snap.exists) throw new Error('Guide not found');
    const guideData = snap.data() || {};

    if (this._isCompanyActor(actor)) {
      const ownerId = String(guideData.createdByCompanyId || '');
      const companyId = String(actor?.id || '');
      if (!companyId || ownerId !== companyId) {
        throw new Error('Forbidden');
      }
    }

    try {
      await admin.auth().updateUser(id, { password });
      return { success: true, created: false };
    } catch (err) {
      if (err.code !== 'auth/user-not-found') {
        throw new Error(err.message || 'Failed to reset password');
      }
    }

    const email = String(guideData.email || '').trim();
    if (!email) {
      throw new Error(
        'This guide has no email on file. Edit the guide and add an email first.',
      );
    }

    try {
      await admin.auth().createUser({
        uid: id,
        email,
        password,
        displayName: guideData.fullName || '',
      });
    } catch (err) {
      if (err.code === 'auth/email-already-exists') {
        throw new Error(
          'An auth account already exists with this email under a different ID. Change the email or contact support.',
        );
      }
      throw new Error(err.message || 'Failed to create login account');
    }
    return { success: true, created: true, email };
  }

  async updateGuide(guideId, payload, actor) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }
    const id = String(guideId || '').trim();
    if (!id) throw new Error('guideId is required');

    const ref = this.db.collection('users').doc(id);
    const existing = await ref.get();
    if (!existing.exists) throw new Error('Guide not found');

    if (this._isCompanyActor(actor)) {
      const data = existing.data() || {};
      const ownerId = String(data.createdByCompanyId || '');
      const companyId = String(actor?.id || '');
      if (!companyId || ownerId !== companyId) {
        throw new Error('Forbidden');
      }
    }

    const patch = this._buildGuidePayload(payload);
    await ref.update(patch);

    const snap = await ref.get();
    const u = snap.data() || {};
    const langs = Array.isArray(u.languages)
      ? u.languages
      : Array.isArray(u.languagesSpoken)
        ? u.languagesSpoken
        : [];
    const specs = Array.isArray(u.specializations) ? u.specializations : [];
    return {
      id: snap.id,
      name: u.fullName || '',
      languages: langs.map((l) => String(l)),
      city: u.city || '',
      specialization:
        specs.length > 0 ? String(specs[0]) : String(u.specialization || ''),
      yearsOfExperience: this._asNumber(u.yearsOfExperience, 0),
      image: u.image ? String(u.image) : '',
      phone: u.phone ? String(u.phone) : '',
      email: u.email ? String(u.email) : '',
      rating: this._asNumber(u.avgRating || u.rating, 0),
      totalTours: 0,
      status: u.isProfileVerified ? 'Available' : 'Pending',
    };
  }

  async deleteGuide(guideId) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const id = String(guideId || '').trim();
    if (!id) {
      throw new Error('guideId is required');
    }

    const guideRef = this.db.collection('users').doc(id);
    const guideSnap = await guideRef.get();
    if (!guideSnap.exists) {
      throw new Error('Guide not found');
    }

    // Keep referential consistency for existing tours that point to this guide.
    const toursSnap = await this.db.collection('tourPackages').where('guideId', '==', id).get();
    if (!toursSnap.empty) {
      throw new Error('Cannot delete guide with assigned tours');
    }

    await guideRef.delete();
  }

  _isCompanyActor(actor) {
    return Boolean(actor && actor.role === 'company');
  }

  _normalizeEmail(value) {
    return String(value || '').trim().toLowerCase();
  }

  async getCompanyAccountByEmail(email) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const normalizedEmail = this._normalizeEmail(email);
    if (!normalizedEmail) {
      return null;
    }

    const snap = await this.db
      .collection('companyAccounts')
      .where('email', '==', normalizedEmail)
      .limit(1)
      .get();

    if (snap.empty) {
      return null;
    }

    const doc = snap.docs[0];
    const data = doc.data() || {};
    return {
      id: doc.id,
      email: data.email || normalizedEmail,
      companyName: data.companyName || '',
      contactName: data.contactName || '',
      passwordHash: data.passwordHash || '',
      status: data.status || 'pending',
    };
  }

  async createCompanyRegistrationRequest(payload) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const companyName = String(payload.companyName || '').trim();
    const contactName = String(payload.contactName || '').trim();
    const commercialId = String(payload.commercialId || '').trim();
    const phone = String(payload.phone || '').trim();
    const city = String(payload.city || '').trim();
    const address = String(payload.address || '').trim();
    const email = this._normalizeEmail(payload.email);
    const passwordHash = String(payload.passwordHash || '').trim();

    if (!companyName || !contactName || !email || !passwordHash) {
      throw new Error('Missing required registration fields');
    }

    const [existingCompany, pendingRequests] = await Promise.all([
      this.db.collection('companyAccounts').where('email', '==', email).limit(1).get(),
      this.db
        .collection('companyRegistrationRequests')
        .where('email', '==', email)
        .where('status', '==', 'pending')
        .limit(1)
        .get(),
    ]);

    if (!existingCompany.empty) {
      throw new Error('A company account with this email already exists');
    }
    if (!pendingRequests.empty) {
      throw new Error('A pending registration request already exists for this email');
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const doc = {
      companyName,
      contactName,
      commercialId,
      phone,
      city,
      address,
      email,
      passwordHash,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
      reviewedAt: null,
      reviewedBy: null,
      reviewReason: '',
    };

    const ref = await this.db.collection('companyRegistrationRequests').add(doc);
    return {
      id: ref.id,
      companyName,
      contactName,
      email,
      status: 'pending',
    };
  }

  async getLatestCompanyRegistrationRequestByEmail(email) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const normalizedEmail = this._normalizeEmail(email);
    if (!normalizedEmail) {
      return null;
    }

    const snap = await this.db
      .collection('companyRegistrationRequests')
      .where('email', '==', normalizedEmail)
      .get();

    if (snap.empty) {
      return null;
    }

    const rows = snap.docs.map((doc) => ({
      id: doc.id,
      ...(doc.data() || {}),
    }));

    rows.sort((a, b) => {
      const aTs = a.updatedAt?.toMillis ? a.updatedAt.toMillis() : 0;
      const bTs = b.updatedAt?.toMillis ? b.updatedAt.toMillis() : 0;
      return bTs - aTs;
    });

    const latest = rows[0];
    return {
      id: latest.id,
      status: latest.status || 'pending',
      reviewReason: latest.reviewReason || '',
    };
  }

  async listCompanyRegistrationRequests(status) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const normalizedStatus = String(status || '').trim().toLowerCase();
    let query = this.db.collection('companyRegistrationRequests');
    if (normalizedStatus) {
      query = query.where('status', '==', normalizedStatus);
    }

    const snap = await query.get();
    const rows = snap.docs.map((doc) => {
      const data = doc.data() || {};
      return {
        id: doc.id,
        companyName: data.companyName || '',
        contactName: data.contactName || '',
        commercialId: data.commercialId || '',
        phone: data.phone || '',
        city: data.city || '',
        address: data.address || '',
        email: data.email || '',
        status: data.status || 'pending',
        reviewReason: data.reviewReason || '',
        createdAt: this._dateOnly(data.createdAt),
        reviewedAt: this._dateOnly(data.reviewedAt),
        reviewedBy: data.reviewedBy || '',
      };
    });

    rows.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    return rows;
  }

  async reviewCompanyRegistrationRequest(requestId, action, reviewer, reason) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const id = String(requestId || '').trim();
    const normalizedAction = String(action || '').trim().toLowerCase();
    if (!id || (normalizedAction !== 'approve' && normalizedAction !== 'reject')) {
      throw new Error('Invalid review request');
    }

    const requestRef = this.db.collection('companyRegistrationRequests').doc(id);
    const requestSnap = await requestRef.get();
    if (!requestSnap.exists) {
      throw new Error('Registration request not found');
    }

    const requestData = requestSnap.data() || {};
    if (requestData.status !== 'pending') {
      throw new Error('Registration request was already reviewed');
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const reviewerName = String(reviewer?.name || reviewer?.email || '').trim();
    const reviewReason = String(reason || '').trim();

    if (normalizedAction === 'approve') {
      const existingCompany = await this.db
        .collection('companyAccounts')
        .where('email', '==', this._normalizeEmail(requestData.email))
        .limit(1)
        .get();

      if (!existingCompany.empty) {
        throw new Error('A company account with this email already exists');
      }

      const companyRef = this.db.collection('companyAccounts').doc();
      const companyDoc = {
        email: this._normalizeEmail(requestData.email),
        companyName: String(requestData.companyName || '').trim(),
        contactName: String(requestData.contactName || '').trim(),
        commercialId: String(requestData.commercialId || '').trim(),
        phone: String(requestData.phone || '').trim(),
        city: String(requestData.city || '').trim(),
        address: String(requestData.address || '').trim(),
        passwordHash: String(requestData.passwordHash || ''),
        status: 'approved',
        approvedAt: now,
        approvedBy: reviewerName,
        createdAt: now,
        updatedAt: now,
      };

      await companyRef.set(companyDoc);
      await requestRef.update({
        status: 'approved',
        reviewedAt: now,
        reviewedBy: reviewerName,
        reviewReason,
        approvedCompanyId: companyRef.id,
        updatedAt: now,
      });

      await this.db.collection('companyProfiles').doc(companyRef.id).set(
        {
          companyId: companyRef.id,
          companyName: companyDoc.companyName,
          contactEmail: companyDoc.email,
          contactPhone: companyDoc.phone,
          city: companyDoc.city,
          address: companyDoc.address,
          commercialId: companyDoc.commercialId,
          createdAt: now,
          updatedAt: now,
        },
        { merge: true },
      );

      return {
        requestId: id,
        status: 'approved',
        approvedCompanyId: companyRef.id,
      };
    }

    await requestRef.update({
      status: 'rejected',
      reviewedAt: now,
      reviewedBy: reviewerName,
      reviewReason,
      updatedAt: now,
    });

    return {
      requestId: id,
      status: 'rejected',
    };
  }

  _assertTourOwnership(tourDocData, actor) {
    if (!this._isCompanyActor(actor)) {
      return;
    }

    const ownerCompanyId = String(tourDocData.createdByCompanyId || '');
    const actorCompanyId = String(actor.id || '');
    if (!ownerCompanyId || ownerCompanyId !== actorCompanyId) {
      throw new Error('Forbidden: tour does not belong to this company');
    }
  }

  async getTours(actor) {
    if (!this.isFirebaseInitialized) return [];

    const toursQuery = this._isCompanyActor(actor)
      ? this.db.collection('tourPackages').where('createdByCompanyId', '==', String(actor.id || ''))
      : this.db.collection('tourPackages');

    const [packagesSnap, guidesSnap] = await Promise.all([
      toursQuery.get(),
      this.db.collection('users').where('userType', '==', 'tour_guide').get(),
    ]);

    const guideNameById = new Map(
      guidesSnap.docs.map((doc) => [doc.id, doc.data().fullName || doc.data().email || 'Unknown Guide']),
    );

    const tours = packagesSnap.docs.map((doc) => {
      const p = doc.data();
      const dateStr = typeof p.availableDates === 'string'
        ? p.availableDates.split(',')[0].trim()
        : this._dateOnly(p.createdAt);

      return {
        id: doc.id,
        name: p.tourTitle || 'Unnamed Tour',
        companyName: p.createdByCompanyName || p.companyName || '',
        city: p.destination || 'N/A',
        price: this._asNumber(p.price, 0),
        date: dateStr || '',
        guide: guideNameById.get(p.guideId) || 'Unknown Guide',
        capacity: this._asNumber(p.maxGroupSize, 0),
        participants: this._asNumber(p.bookings, 0),
        status: this._tourStatus(p),
        duration: `${p.durationValue || ''} ${p.durationUnit || ''}`.trim(),
        description: p.tourDescription || '',
        mapLocation: p.mapLocation || '',
        images: p.image ? [String(p.image)] : [],
      };
    });

    tours.sort((a, b) => a.date.localeCompare(b.date));
    return tours;
  }

  async createTour(payload, actor) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const doc = await this._buildTourPackageDoc(payload);
    if (this._isCompanyActor(actor)) {
      let resolvedCompanyName = String(actor.name || '');
      const profileSnap = await this.db.collection('companyProfiles').doc(String(actor.id || '')).get();
      if (profileSnap.exists) {
        const profileName = String(profileSnap.data()?.companyName || '').trim();
        if (profileName) {
          resolvedCompanyName = profileName;
        }
      }

      doc.createdByCompanyId = String(actor.id || '');
      doc.createdByCompanyEmail = String(actor.email || '');
      doc.createdByCompanyName = resolvedCompanyName;
      doc.companyId = String(actor.id || '');
      doc.companyName = resolvedCompanyName;
      doc.organizationName = resolvedCompanyName;
      doc.company = {
        id: String(actor.id || ''),
        name: resolvedCompanyName,
        email: String(actor.email || ''),
      };
    }
    doc.createdAt = admin.firestore.FieldValue.serverTimestamp();

    const ref = await this.db.collection('tourPackages').add(doc);
    const created = await ref.get();
    const row = created.data() || {};
    return {
      id: ref.id,
      name: row.tourTitle || String(payload.name),
      companyName: row.createdByCompanyName || row.companyName || '',
      city: row.destination || String(payload.city),
      price: this._asNumber(row.price, this._asNumber(payload.price, 0)),
      date: (row.availableDates || String(payload.date || '')).split(',')[0].trim(),
      guide: payload.guide || 'Unknown Guide',
      capacity: this._asNumber(row.maxGroupSize, this._asNumber(payload.capacity, 0)),
      participants: this._asNumber(row.bookings, 0),
      status: this._tourStatus(row),
      duration: `${row.durationValue || ''} ${row.durationUnit || ''}`.trim(),
      description: row.tourDescription || '',
      mapLocation: row.mapLocation || '',
      images: row.image ? [String(row.image)] : [],
    };
  }

  async updateTour(tourId, payload, actor) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const tourRef = this.db.collection('tourPackages').doc(tourId);
    const existingSnap = await tourRef.get();
    if (!existingSnap.exists) {
      throw new Error('Tour not found');
    }
    this._assertTourOwnership(existingSnap.data() || {}, actor);

    const patch = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
    if (payload.name !== undefined) patch.tourTitle = String(payload.name);
    if (payload.city !== undefined) {
      patch.destination = String(payload.city);
      patch.region = String(payload.city);
    }
    if (payload.price !== undefined) patch.price = String(payload.price);
    if (payload.date !== undefined) patch.availableDates = String(payload.date);
    if (payload.capacity !== undefined) patch.maxGroupSize = String(payload.capacity);
    if (payload.description !== undefined) patch.tourDescription = String(payload.description);
    if (payload.activityType !== undefined) patch.activityType = String(payload.activityType);
    if (payload.activities !== undefined && Array.isArray(payload.activities)) patch.activities = payload.activities;
    if (payload.images !== undefined && Array.isArray(payload.images)) {
      patch.image = payload.images.length > 0 ? String(payload.images[0]) : '';
    }
    if (payload.status !== undefined) {
      patch.status = payload.status === 'Active' ? 'Published' : String(payload.status);
      patch.isCancelled = payload.status === 'Cancelled';
    }
    if (payload.duration !== undefined) {
      const parts = this._splitDuration(payload.duration);
      patch.durationValue = parts.durationValue;
      patch.durationUnit = parts.durationUnit;
    }
    if (payload.guideId !== undefined || payload.guide !== undefined || payload.guideName !== undefined) {
      patch.guideId = await this._resolveGuideId(payload);
    }

    await tourRef.update(patch);
    const snap = await tourRef.get();
    if (!snap.exists) throw new Error('Tour not found');
    const p = snap.data() || {};

    return {
      id: snap.id,
      name: p.tourTitle || '',
      companyName: p.createdByCompanyName || p.companyName || '',
      city: p.destination || '',
      price: this._asNumber(p.price, 0),
      date: typeof p.availableDates === 'string' ? p.availableDates.split(',')[0].trim() : '',
      guide: payload.guide || 'Unknown Guide',
      capacity: this._asNumber(p.maxGroupSize, 0),
      participants: this._asNumber(p.bookings, 0),
      status: this._tourStatus(p),
      duration: `${p.durationValue || ''} ${p.durationUnit || ''}`.trim(),
      description: p.tourDescription || '',
      mapLocation: p.mapLocation || '',
      images: p.image ? [String(p.image)] : [],
    };
  }

  async deleteTour(tourId, actor) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const tourRef = this.db.collection('tourPackages').doc(tourId);
    const snap = await tourRef.get();
    if (!snap.exists) {
      throw new Error('Tour not found');
    }
    this._assertTourOwnership(snap.data() || {}, actor);
    await tourRef.delete();
  }

  async getTourParticipants(tourId, actor) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const tourRef = this.db.collection('tourPackages').doc(tourId);
    const tourSnap = await tourRef.get();
    if (!tourSnap.exists) {
      throw new Error('Tour not found');
    }
    this._assertTourOwnership(tourSnap.data() || {}, actor);

    const rows = await this.getBookings();
    return rows
      .filter((item) => item.tourId === tourId)
      .map((item) => ({
        id: item.id,
        touristName: item.touristName,
        participants: this._asNumber(item.participants, 0),
        totalPrice: this._asNumber(item.totalPrice, 0),
        status: item.status,
      }));
  }

  async getCompanyProfile(actor) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }
    if (!this._isCompanyActor(actor)) {
      throw new Error('Forbidden: company account required');
    }

    const docId = String(actor.id || '');
    const ref = this.db.collection('companyProfiles').doc(docId);
    const snap = await ref.get();
    const data = snap.exists ? snap.data() : {};

    return {
      companyName: data.companyName || actor.name || '',
      branding: data.branding || '',
      logoUrl: data.logoUrl || '',
      primaryColor: data.primaryColor || '',
      contactEmail: data.contactEmail || actor.email || '',
      contactPhone: data.contactPhone || '',
      city: data.city || '',
      address: data.address || '',
      commercialId: data.commercialId || '',
      description: data.description || '',
      website: data.website || '',
    };
  }

  async updateCompanyProfile(actor, payload) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }
    if (!this._isCompanyActor(actor)) {
      throw new Error('Forbidden: company account required');
    }

    const docId = String(actor.id || '');
    const patch = {
      companyName: String(payload.companyName || '').trim(),
      branding: String(payload.branding || '').trim(),
      logoUrl: String(payload.logoUrl || '').trim(),
      primaryColor: String(payload.primaryColor || '').trim(),
      contactEmail: String(payload.contactEmail || '').trim(),
      contactPhone: String(payload.contactPhone || '').trim(),
      city: String(payload.city || '').trim(),
      address: String(payload.address || '').trim(),
      commercialId: String(payload.commercialId || '').trim(),
      description: String(payload.description || '').trim(),
      website: String(payload.website || '').trim(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const ref = this.db.collection('companyProfiles').doc(docId);
    await ref.set(
      {
        ...patch,
        companyId: docId,
        ownerEmail: String(actor.email || ''),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return this.getCompanyProfile(actor);
  }

  async getCompanySettings(actor) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }
    if (!this._isCompanyActor(actor)) {
      throw new Error('Forbidden: company account required');
    }

    const docId = String(actor.id || '');
    const ref = this.db.collection('companySettings').doc(docId);
    const snap = await ref.get();
    const data = snap.exists ? snap.data() : {};

    return {
      supportEmail: data.supportEmail || actor.email || '',
      supportPhone: data.supportPhone || '',
      city: data.city || '',
      description: data.description || '',
      logoUrl: data.logoUrl || '',
      openingTime: data.openingTime || '08:00',
      closingTime: data.closingTime || '18:00',
      timezone: data.timezone || 'Asia/Riyadh',
      currency: data.currency || 'SAR',
      madaEnabled: data.madaEnabled !== false,
      stcPayEnabled: data.stcPayEnabled !== false,
      applePayEnabled: data.applePayEnabled !== false,
    };
  }

  async updateCompanySettings(actor, payload) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }
    if (!this._isCompanyActor(actor)) {
      throw new Error('Forbidden: company account required');
    }

    const docId = String(actor.id || '');
    const patch = {
      supportEmail: String(payload.supportEmail || '').trim(),
      supportPhone: String(payload.supportPhone || '').trim(),
      city: String(payload.city || '').trim(),
      description: String(payload.description || '').trim(),
      logoUrl: String(payload.logoUrl || '').trim(),
      openingTime: String(payload.openingTime || '08:00').trim(),
      closingTime: String(payload.closingTime || '18:00').trim(),
      timezone: String(payload.timezone || 'Asia/Riyadh').trim(),
      currency: String(payload.currency || 'SAR').trim(),
      madaEnabled: Boolean(payload.madaEnabled),
      stcPayEnabled: Boolean(payload.stcPayEnabled),
      applePayEnabled: Boolean(payload.applePayEnabled),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const ref = this.db.collection('companySettings').doc(docId);
    await ref.set(
      {
        ...patch,
        companyId: docId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return this.getCompanySettings(actor);
  }

  async getCustomers(actor) {
    if (!this.isFirebaseInitialized) return [];

    if (this._isCompanyActor(actor)) {
      const scopedBookings = await this.getBookings(actor);
      const touristIds = [...new Set(scopedBookings.map((b) => b.ownerUserId).filter(Boolean))];
      if (touristIds.length === 0) {
        return [];
      }

      const rows = await Promise.all(
        touristIds.map(async (touristId) => {
          const userSnap = await this.db.collection('users').doc(touristId).get();
          if (!userSnap.exists) {
            return null;
          }

          const u = userSnap.data() || {};
          const touristBookings = scopedBookings.filter((b) => b.ownerUserId === touristId);
          const latestDate = touristBookings
            .map((b) => this._dateOnly(b.bookingDate || b.createdAt))
            .filter(Boolean)
            .sort()
            .pop() || '';

          return {
            id: touristId,
            name: u.fullName || u.email || 'Unknown Tourist',
            nationality: u.countryOfResidence || 'Unknown',
            bookings: touristBookings.length,
            language: Array.isArray(u.languagesSpoken) && u.languagesSpoken[0]
              ? String(u.languagesSpoken[0])
              : 'N/A',
            lastVisit: latestDate,
          };
        }),
      );

      return rows.filter(Boolean);
    }

    const touristDocs = await this._getUsersByTypeVariants(['tourist', 'Tourist']);

    const rows = await Promise.all(
      touristDocs.map(async (doc) => {
        const u = doc.data();
        const bookingsSnap = await this.db.collection('users').doc(doc.id).collection('upcomingBookings').get();
        const bookingRows = bookingsSnap.docs.map((b) => b.data());
        const latestDate = bookingRows
          .map((b) => this._dateOnly(b.bookingDate || b.createdAt || b.startDate))
          .filter(Boolean)
          .sort()
          .pop() || '';

        return {
          id: doc.id,
          name: u.fullName || u.email || 'Unknown Tourist',
          nationality: u.countryOfResidence || 'Unknown',
          bookings: bookingsSnap.size,
          language: Array.isArray(u.languagesSpoken) && u.languagesSpoken[0]
            ? String(u.languagesSpoken[0])
            : 'N/A',
          lastVisit: latestDate,
        };
      }),
    );

    return rows;
  }

  async getBookings(actor) {
    if (!this.isFirebaseInitialized) return [];

    const companyId = String(actor?.id || '');
    if (this._isCompanyActor(actor) && !companyId) {
      return [];
    }

    const packageQuery = this._isCompanyActor(actor)
      ? this.db.collection('tourPackages').where('createdByCompanyId', '==', companyId)
      : this.db.collection('tourPackages');

    const [touristDocs, packagesSnap] = await Promise.all([
      this._getUsersByTypeVariants(['tourist', 'Tourist']),
      packageQuery.get(),
    ]);

    const packageById = new Map(packagesSnap.docs.map((doc) => [doc.id, doc.data()]));

    if (this._isCompanyActor(actor) && packageById.size === 0) {
      return [];
    }

    const rows = [];
    for (const touristDoc of touristDocs) {
      const tourist = touristDoc.data();
      const bookingsSnap = await this.db
        .collection('users')
        .doc(touristDoc.id)
        .collection('upcomingBookings')
        .get();

      bookingsSnap.docs.forEach((doc) => {
        const b = doc.data();
        const tourId = b.packageId || b.tourId || '';

        if (this._isCompanyActor(actor) && !packageById.has(tourId)) {
          return;
        }

        const pkg = packageById.get(tourId) || {};
        const participants = this._asNumber(b.participants || b.numPeople, 1);
        const price = this._asNumber(pkg.price, 0);
        const bookedAtDate = this._safeToDate(b.bookedAt);
        const bookingDate = b.bookingDate || b.startDate || b.availableDates || (bookedAtDate ? bookedAtDate.toISOString().slice(0, 10) : null);
        rows.push({
          id: doc.id,
          touristName: b.guestName || tourist.fullName || tourist.email || 'Unknown Tourist',
          tourId,
          tourName: pkg.tourTitle || 'Unknown Tour',
          participants,
          totalPrice: this._asNumber(b.totalPrice, participants * price),
          status: this._bookingStatusFromDoc(b),
          ownerUserId: touristDoc.id,
          bookingDate,
          createdAt: b.createdAt || b.bookedAt || null,
        });
      });
    }

    return rows;
  }

  async updateBookingStatus(bookingId, status) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const allowed = new Set(['Confirmed', 'Pending', 'Cancelled', 'Completed']);
    if (!allowed.has(status)) {
      throw new Error('Invalid status');
    }

    const rows = await this.getBookings();
    const row = rows.find((r) => r.id === bookingId);
    if (!row) {
      throw new Error('Booking not found');
    }

    await this.db
      .collection('users')
      .doc(row.ownerUserId)
      .collection('upcomingBookings')
      .doc(bookingId)
      .update({ status });

    return { ...row, status };
  }

  async getReviews() {
    if (!this.isFirebaseInitialized) return [];

    const [packagesSnap, usersSnap] = await Promise.all([
      this.db.collection('tourPackages').get(),
      this.db.collection('users').get(),
    ]);

    const userNameById = new Map(
      usersSnap.docs.map((doc) => [doc.id, doc.data().fullName || doc.data().email || 'Anonymous']),
    );
    const guideNameById = new Map(
      usersSnap.docs
        .filter((doc) => doc.data().userType === 'tour_guide')
        .map((doc) => [doc.id, doc.data().fullName || doc.data().email || 'Unknown Guide']),
    );

    const reviews = [];
    for (const pkgDoc of packagesSnap.docs) {
      const pkg = pkgDoc.data();
      const ratingsSnap = await this.db
        .collection('tourPackages')
        .doc(pkgDoc.id)
        .collection('ratings')
        .get();

      ratingsSnap.docs.forEach((rDoc) => {
        const r = rDoc.data();
        reviews.push({
          id: `${pkgDoc.id}_${rDoc.id}`,
          touristName: userNameById.get(r.userId) || 'Anonymous',
          guideName: guideNameById.get(pkg.guideId) || 'Unknown Guide',
          rating: this._asNumber(r.rating, 0),
          comment: r.review || '',
        });
      });
    }

    return reviews;
  }

  _serializeReward(doc) {
    const r = doc.data() || {};
    const isActive = typeof r.isActive === 'boolean'
      ? r.isActive
      : r.status !== 'inactive';
    let validUntil = null;
    if (r.validUntil) {
      if (typeof r.validUntil.toDate === 'function') {
        validUntil = r.validUntil.toDate().toISOString().slice(0, 10);
      } else if (typeof r.validUntil === 'string') {
        validUntil = r.validUntil.slice(0, 10);
      }
    }
    const applicableTours = Array.isArray(r.applicableTours)
      ? r.applicableTours.map((t) => String(t))
      : [];
    return {
      id: doc.id,
      type: r.type || 'tour_discount',
      createdBy: r.createdBy || 'company',
      creatorId: r.creatorId || r.companyId || '',
      companyId: r.companyId || '',
      title: r.title || '',
      description: r.description || '',
      discountPercent: this._asNumber(r.discountPercent, 0),
      requiredLevel: this._asNumber(r.requiredLevel, 1),
      applicableTours,
      partnerName: r.partnerName || '',
      partnerCategory: r.partnerCategory || '',
      partnerLocation: r.partnerLocation || '',
      redemptionCode: r.redemptionCode || '',
      isActive,
      validUntil,
      totalAppliedCount: this._asNumber(r.totalAppliedCount, 0),
    };
  }

  _buildRewardDoc(data, { isCreate = false } = {}) {
    const doc = {};
    if (data.type !== undefined) doc.type = String(data.type);
    if (data.title !== undefined) doc.title = String(data.title).trim();
    if (data.description !== undefined) {
      doc.description = String(data.description);
    }
    if (data.discountPercent !== undefined) {
      doc.discountPercent = this._asNumber(data.discountPercent, 0);
    }
    if (data.requiredLevel !== undefined) {
      doc.requiredLevel = this._asNumber(data.requiredLevel, 1);
    }
    if (Array.isArray(data.applicableTours)) {
      doc.applicableTours = data.applicableTours
        .map((t) => String(t).trim())
        .filter(Boolean);
    }
    if (data.partnerName !== undefined) {
      doc.partnerName = String(data.partnerName);
    }
    if (data.partnerCategory !== undefined) {
      doc.partnerCategory = String(data.partnerCategory);
    }
    if (data.partnerLocation !== undefined) {
      doc.partnerLocation = String(data.partnerLocation);
    }
    if (data.redemptionCode !== undefined) {
      doc.redemptionCode = String(data.redemptionCode).trim();
    }
    if (data.isActive !== undefined) {
      doc.isActive = Boolean(data.isActive);
    } else if (data.status !== undefined) {
      doc.isActive = data.status !== 'inactive';
    }
    if (data.validUntil) {
      const parsed = new Date(data.validUntil);
      if (!Number.isNaN(parsed.getTime())) {
        doc.validUntil = admin.firestore.Timestamp.fromDate(parsed);
      }
    } else if (data.validUntil === null) {
      doc.validUntil = null;
    }
    if (isCreate) {
      doc.totalAppliedCount = 0;
      doc.createdAt = admin.firestore.FieldValue.serverTimestamp();
    }
    doc.updatedAt = admin.firestore.FieldValue.serverTimestamp();
    return doc;
  }

  _validateRewardForCreate(doc) {
    if (!doc.title || !doc.title.trim()) {
      throw new Error('Title is required');
    }
    const type = doc.type || 'tour_discount';
    if (type !== 'tour_discount' && type !== 'partner_coupon') {
      throw new Error('Invalid reward type');
    }
    const disc = this._asNumber(doc.discountPercent, 0);
    if (disc < 1 || disc > 100) {
      throw new Error('Discount must be between 1 and 100');
    }
    if (!Array.isArray(doc.applicableTours) || doc.applicableTours.length === 0) {
      throw new Error('Select at least one tour');
    }
    if (type === 'partner_coupon') {
      if (!(doc.partnerName || '').trim()) {
        throw new Error('Partner name is required for coupons');
      }
      if (!(doc.redemptionCode || '').trim()) {
        throw new Error('Redemption code is required for coupons');
      }
    }
  }

  async getRewards(actor) {
    if (!this.isFirebaseInitialized) return [];

    let query = this.db.collection('rewards');
    if (this._isCompanyActor(actor)) {
      const companyId = String(actor?.id || '');
      if (!companyId) return [];
      query = query.where('companyId', '==', companyId);
    }

    const snap = await query.get();
    const rewards = snap.docs.map((doc) => this._serializeReward(doc));
    rewards.sort((a, b) => (b.id || '').localeCompare(a.id || ''));
    return rewards;
  }

  async createReward(data, actor) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const doc = this._buildRewardDoc(data, { isCreate: true });
    if (!doc.type) doc.type = 'tour_discount';
    if (doc.isActive === undefined) doc.isActive = true;
    if (doc.requiredLevel === undefined) doc.requiredLevel = 1;

    if (this._isCompanyActor(actor)) {
      const companyId = String(actor.id || '');
      if (!companyId) throw new Error('Company actor missing id');
      doc.createdBy = 'company';
      doc.creatorId = companyId;
      doc.companyId = companyId;
    } else {
      doc.createdBy = data.createdBy || 'admin';
      doc.creatorId = data.creatorId || String(actor?.id || '');
      doc.companyId = data.companyId || '';
    }

    this._validateRewardForCreate(doc);

    const ref = await this.db.collection('rewards').add(doc);
    const snap = await ref.get();
    return this._serializeReward(snap);
  }

  async updateReward(id, data, actor) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const ref = this.db.collection('rewards').doc(id);
    const existing = await ref.get();
    if (!existing.exists) throw new Error('Reward not found');

    if (this._isCompanyActor(actor)) {
      const companyId = String(actor?.id || '');
      const ownerId = String(existing.data()?.companyId || '');
      if (!companyId || ownerId !== companyId) {
        throw new Error('Forbidden');
      }
    }

    const patch = this._buildRewardDoc(data);
    delete patch.id;
    await ref.update(patch);
    const snap = await ref.get();
    return this._serializeReward(snap);
  }

  async setRewardStatus(id, status, actor) {
    const isActive = status !== 'inactive';
    return this.updateReward(id, { isActive }, actor);
  }

  async deleteReward(id, actor) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }
    const ref = this.db.collection('rewards').doc(id);
    if (this._isCompanyActor(actor)) {
      const existing = await ref.get();
      if (!existing.exists) throw new Error('Reward not found');
      const companyId = String(actor?.id || '');
      const ownerId = String(existing.data()?.companyId || '');
      if (!companyId || ownerId !== companyId) {
        throw new Error('Forbidden');
      }
    }
    await ref.delete();
  }

  async getDashboardOverview(actor) {
    const [tours, bookings, guides] = await Promise.all([
      this.getTours(actor),
      this.getBookings(actor),
      this.getGuides(actor),
    ]);

    const activeTours = tours.filter((t) => t.status === 'Active').length;
    const todayBookings = bookings.filter((b) => b.status === 'Confirmed').length;
    const currentTourists = bookings
      .filter((b) => b.status === 'Confirmed' || b.status === 'Pending')
      .reduce((sum, b) => sum + this._asNumber(b.participants, 0), 0);
    const monthlyRevenue = bookings
      .filter((b) => b.status === 'Confirmed' || b.status === 'Completed')
      .reduce((sum, b) => sum + this._asNumber(b.totalPrice, 0), 0);

    const cityStatsMap = new Map();
    tours.forEach((tour) => {
      cityStatsMap.set(tour.city, (cityStatsMap.get(tour.city) || 0) + this._asNumber(tour.participants, 0));
    });
    const topCities = [...cityStatsMap.entries()]
      .map(([city, demand]) => ({ city, demand }))
      .sort((a, b) => b.demand - a.demand)
      .slice(0, 4);

    const topGuides = [...guides]
      .map((g) => ({ name: g.name, rating: this._asNumber(g.rating, 0) }))
      .sort((a, b) => b.rating - a.rating)
      .slice(0, 3);

    const now = new Date();
    const monthlyLabels = [];
    const monthlyBookings = [];
    for (let i = 6; i >= 0; i -= 1) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      monthlyLabels.push(d.toLocaleString('en', { month: 'short' }));
      const count = bookings.filter((b) => {
        const date = new Date(b.bookingDate || b.createdAt || now);
        return date.getFullYear() === d.getFullYear() && date.getMonth() === d.getMonth();
      }).length;
      monthlyBookings.push(count);
    }

    return {
      todayBookings,
      activeTours,
      currentTourists,
      monthlyRevenue,
      guidesCount: guides.length,
      monthlyBookings,
      monthlyLabels,
      topCities,
      topGuides,
    };
  }

  async getReportSummary(actor) {
    const [bookings, reviews, customers, tours, guides] = await Promise.all([
      this.getBookings(actor),
      this.getReviews(),
      this.getCustomers(actor),
      this.getTours(actor),
      this.getGuides(actor),
    ]);

    const monthlyRevenue = bookings
      .filter((b) => b.status === 'Confirmed' || b.status === 'Completed')
      .reduce((sum, b) => sum + this._asNumber(b.totalPrice, 0), 0);

    const reviewsCount = reviews.length;
    const customerSatisfaction = reviewsCount === 0
      ? 0
      : Number((reviews.reduce((sum, r) => sum + this._asNumber(r.rating, 0), 0) / reviewsCount).toFixed(1));

    const cancelled = bookings.filter((b) => b.status === 'Cancelled').length;
    const cancellationRate = bookings.length === 0
      ? 0
      : Number(((cancelled / bookings.length) * 100).toFixed(1));

    const cityDemand = new Map();
    tours.forEach((tour) => {
      cityDemand.set(tour.city, (cityDemand.get(tour.city) || 0) + this._asNumber(tour.participants, 0));
    });
    const bestCity = [...cityDemand.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] || 'N/A';

    const langs = new Set();
    guides.forEach((g) => (g.languages || []).forEach((l) => langs.add(l)));

    return {
      revenueGrowth: 0,
      customerSatisfaction,
      cancellationRate,
      monthlyRevenue,
      totalCustomers: customers.length,
      bestCity,
      topLanguages: [...langs].slice(0, 4),
    };
  }

  async getSyncStatus() {
    if (!this.isFirebaseInitialized) {
      return {
        isFirebaseInitialized: false,
        guides: 0,
        customers: 0,
        tours: 0,
        bookings: 0,
        reviews: 0,
        rewards: 0,
        timestamp: new Date().toISOString(),
      };
    }

    const [guides, customers, tours, bookings, reviews, rewards] = await Promise.all([
      this.getGuides(),
      this.getCustomers(),
      this.getTours(),
      this.getBookings(),
      this.getReviews(),
      this.getRewards(),
    ]);

    return {
      isFirebaseInitialized: true,
      guides: guides.length,
      customers: customers.length,
      tours: tours.length,
      bookings: bookings.length,
      reviews: reviews.length,
      rewards: rewards.length,
      timestamp: new Date().toISOString(),
    };
  }

  async syncGuidesFromFirebase() {
    const guides = await this.getGuides();
    return { synced: guides.length, total: guides.length };
  }

  async syncCustomersFromFirebase() {
    const customers = await this.getCustomers();
    return { synced: customers.length, total: customers.length };
  }

  async syncToursFromFirebase() {
    const tours = await this.getTours();
    return { synced: tours.length, total: tours.length };
  }

  async syncBookingsFromFirebase() {
    const bookings = await this.getBookings();
    return { synced: bookings.length, total: bookings.length };
  }

  async syncReviewsFromFirebase() {
    const reviews = await this.getReviews();
    return { synced: reviews.length, total: reviews.length };
  }

  async performFullSync() {
    const status = await this.getSyncStatus();
    return {
      guides: { synced: status.guides, total: status.guides },
      customers: { synced: status.customers, total: status.customers },
      tours: { synced: status.tours, total: status.tours },
      bookings: { synced: status.bookings, total: status.bookings },
      reviews: { synced: status.reviews, total: status.reviews },
      timestamp: new Date().toISOString(),
    };
  }

  async getPerformanceMetrics(actor) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const [tours, bookings, reviews, guides] = await Promise.all([
      this.getTours(actor),
      this.getBookings(actor),
      this.getReviews(),
      this.getGuides(actor),
    ]);

    const allowedTourIds = new Set(tours.map((t) => t.id));
    const allowedGuideNames = new Set(guides.map((g) => g.name));
    const scopedReviews = this._isCompanyActor(actor)
      ? reviews.filter((r) => allowedGuideNames.has(r.guideName))
      : reviews;

    const totalBookings = bookings.length;
    const confirmedBookings = bookings.filter((b) => b.status === 'Confirmed').length;
    const completedBookings = bookings.filter((b) => b.status === 'Completed').length;
    const cancelledBookings = bookings.filter((b) => b.status === 'Cancelled').length;

    const totalCapacity = tours.reduce((sum, t) => sum + this._asNumber(t.capacity, 0), 0);
    const totalParticipants = bookings
      .filter((b) => b.status === 'Confirmed' || b.status === 'Completed')
      .reduce((sum, b) => sum + this._asNumber(b.participants, 0), 0);
    const fillRate = totalCapacity === 0
      ? 0
      : Number(((totalParticipants / totalCapacity) * 100).toFixed(1));

    const completionRate = totalBookings === 0
      ? 0
      : Number(((completedBookings / totalBookings) * 100).toFixed(1));

    const overallSatisfaction = scopedReviews.length === 0
      ? 0
      : Number(
          (scopedReviews.reduce((s, r) => s + this._asNumber(r.rating, 0), 0) / scopedReviews.length)
            .toFixed(2),
        );

    const guideStats = new Map();
    guides.forEach((g) => {
      guideStats.set(g.name, {
        guideId: g.id,
        name: g.name,
        ratingSum: 0,
        ratingCount: 0,
        toursCount: g.totalTours || 0,
      });
    });
    scopedReviews.forEach((r) => {
      const entry = guideStats.get(r.guideName);
      if (!entry) return;
      entry.ratingSum += this._asNumber(r.rating, 0);
      entry.ratingCount += 1;
    });

    const guidePerformance = [...guideStats.values()]
      .map((entry) => ({
        guideId: entry.guideId,
        name: entry.name,
        averageRating: entry.ratingCount === 0
          ? 0
          : Number((entry.ratingSum / entry.ratingCount).toFixed(2)),
        reviewsCount: entry.ratingCount,
        toursCount: entry.toursCount,
      }))
      .sort((a, b) => b.averageRating - a.averageRating);

    const tourParticipationMap = new Map();
    tours.forEach((t) => {
      tourParticipationMap.set(t.id, {
        tourId: t.id,
        name: t.name,
        capacity: this._asNumber(t.capacity, 0),
        bookings: 0,
        participants: 0,
      });
    });
    bookings.forEach((b) => {
      if (!allowedTourIds.has(b.tourId)) return;
      const entry = tourParticipationMap.get(b.tourId);
      if (!entry) return;
      entry.bookings += 1;
      if (b.status === 'Confirmed' || b.status === 'Completed') {
        entry.participants += this._asNumber(b.participants, 0);
      }
    });

    const tourParticipation = [...tourParticipationMap.values()]
      .map((entry) => ({
        ...entry,
        fillRate: entry.capacity === 0
          ? 0
          : Number(((entry.participants / entry.capacity) * 100).toFixed(1)),
      }))
      .sort((a, b) => b.participants - a.participants)
      .slice(0, 8);

    const ratingBuckets = { five: 0, four: 0, three: 0, two: 0, one: 0 };
    scopedReviews.forEach((r) => {
      const v = Math.round(this._asNumber(r.rating, 0));
      if (v >= 5) ratingBuckets.five += 1;
      else if (v === 4) ratingBuckets.four += 1;
      else if (v === 3) ratingBuckets.three += 1;
      else if (v === 2) ratingBuckets.two += 1;
      else if (v >= 1) ratingBuckets.one += 1;
    });

    return {
      totalBookings,
      confirmedBookings,
      completedBookings,
      cancelledBookings,
      totalParticipants,
      totalCapacity,
      fillRate,
      completionRate,
      overallSatisfaction,
      reviewsCount: scopedReviews.length,
      guidePerformance,
      tourParticipation,
      ratingDistribution: ratingBuckets,
      generatedAt: new Date().toISOString(),
    };
  }

  async exportCompanyBackup(actor) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const [tours, guides, bookings, customers, reviews, rewards, profile] = await Promise.all([
      this.getTours(actor),
      this.getGuides(actor),
      this.getBookings(actor),
      this.getCustomers(actor),
      this.getReviews(),
      this.getRewards(actor),
      this._isCompanyActor(actor)
        ? this.getCompanyProfile(actor).catch(() => null)
        : Promise.resolve(null),
    ]);

    const allowedTourIds = new Set(tours.map((t) => t.id));
    const allowedGuideNames = new Set(guides.map((g) => g.name));
    const scopedReviews = this._isCompanyActor(actor)
      ? reviews.filter((r) => allowedGuideNames.has(r.guideName))
      : reviews;
    const scopedBookings = this._isCompanyActor(actor)
      ? bookings.filter((b) => allowedTourIds.has(b.tourId))
      : bookings;

    return {
      version: 1,
      type: 'company-backup',
      generatedAt: new Date().toISOString(),
      company: profile
        ? {
            id: String(actor?.id || ''),
            name: profile.companyName || actor?.name || '',
            email: profile.contactEmail || actor?.email || '',
          }
        : {
            id: String(actor?.id || ''),
            name: actor?.name || '',
            email: actor?.email || '',
            role: actor?.role || '',
          },
      counts: {
        tours: tours.length,
        guides: guides.length,
        bookings: scopedBookings.length,
        customers: customers.length,
        reviews: scopedReviews.length,
        rewards: rewards.length,
      },
      tours,
      guides,
      bookings: scopedBookings,
      customers,
      reviews: scopedReviews,
      rewards,
    };
  }

  async logBackupToFirebase(actor, backup) {
    if (!this.isFirebaseInitialized) return null;
    try {
      const ref = await this.db.collection('companyBackups').add({
        companyId: String(actor?.id || ''),
        companyName: String(actor?.name || ''),
        actorEmail: String(actor?.email || ''),
        actorRole: String(actor?.role || ''),
        type: backup.type || 'company-backup',
        counts: backup.counts || {},
        generatedAt: backup.generatedAt || new Date().toISOString(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (error) {
      console.warn('Failed to log backup to Firestore:', error.message);
      return null;
    }
  }

  async exportBackup() {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const collectionsToBackup = [
      'users',
      'tourPackages',
      'companyAccounts',
      'companyProfiles',
      'companyRegistrationRequests',
      'rewards',
    ];

    const data = {};
    for (const name of collectionsToBackup) {
      const snap = await this.db.collection(name).get();
      data[name] = snap.docs.map((doc) => ({
        id: doc.id,
        data: this._serializeForBackup(doc.data()),
      }));

      if (name === 'users') {
        const subCollections = ['upcomingBookings', 'points_events', 'quiz_attempts', 'challenge_attempts'];
        data[`${name}__subcollections`] = {};
        for (const userDoc of snap.docs) {
          const userBlock = {};
          for (const sub of subCollections) {
            const subSnap = await this.db.collection('users').doc(userDoc.id).collection(sub).get();
            if (subSnap.empty) continue;
            userBlock[sub] = subSnap.docs.map((d) => ({
              id: d.id,
              data: this._serializeForBackup(d.data()),
            }));
          }
          if (Object.keys(userBlock).length > 0) {
            data[`${name}__subcollections`][userDoc.id] = userBlock;
          }
        }
      }

      if (name === 'tourPackages') {
        data[`${name}__ratings`] = {};
        for (const pkgDoc of snap.docs) {
          const ratingsSnap = await this.db.collection('tourPackages').doc(pkgDoc.id).collection('ratings').get();
          if (ratingsSnap.empty) continue;
          data[`${name}__ratings`][pkgDoc.id] = ratingsSnap.docs.map((d) => ({
            id: d.id,
            data: this._serializeForBackup(d.data()),
          }));
        }
      }
    }

    return {
      version: 1,
      generatedAt: new Date().toISOString(),
      collections: data,
    };
  }

  _serializeForBackup(value) {
    if (value === null || value === undefined) return value;
    if (value && typeof value.toDate === 'function') {
      return { __type: 'timestamp', value: value.toDate().toISOString() };
    }
    if (Array.isArray(value)) {
      return value.map((item) => this._serializeForBackup(item));
    }
    if (typeof value === 'object') {
      const out = {};
      for (const [k, v] of Object.entries(value)) {
        out[k] = this._serializeForBackup(v);
      }
      return out;
    }
    return value;
  }

  _isTourIncomplete(pkg) {
    const title = String(pkg.tourTitle || '').trim();
    const destination = String(pkg.destination || '').trim();
    const price = this._asNumber(pkg.price, 0);
    const capacity = this._asNumber(pkg.maxGroupSize, 0);
    const dates = String(pkg.availableDates || '').trim();
    const duration = String(pkg.durationValue || '').trim();

    return (
      !title ||
      !destination ||
      price <= 0 ||
      capacity <= 0 ||
      !dates ||
      !duration
    );
  }

  async cleanupIncompleteTours({ dryRun = false } = {}) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const snap = await this.db.collection('tourPackages').get();
    const incomplete = [];
    snap.docs.forEach((doc) => {
      const pkg = doc.data() || {};
      if (this._isTourIncomplete(pkg)) {
        incomplete.push({
          id: doc.id,
          tourTitle: pkg.tourTitle || '',
          destination: pkg.destination || '',
          price: pkg.price || '',
          maxGroupSize: pkg.maxGroupSize || '',
          availableDates: pkg.availableDates || '',
        });
      }
    });

    if (dryRun) {
      return {
        dryRun: true,
        scanned: snap.size,
        incompleteCount: incomplete.length,
        incomplete,
      };
    }

    let deleted = 0;
    const failed = [];
    for (const item of incomplete) {
      try {
        const ratings = await this.db.collection('tourPackages').doc(item.id).collection('ratings').get();
        const batch = this.db.batch();
        ratings.docs.forEach((r) => batch.delete(r.ref));
        batch.delete(this.db.collection('tourPackages').doc(item.id));
        await batch.commit();
        deleted += 1;
      } catch (error) {
        failed.push({ id: item.id, message: error.message });
      }
    }

    return {
      dryRun: false,
      scanned: snap.size,
      incompleteCount: incomplete.length,
      deleted,
      failed,
      incomplete,
    };
  }

  async pushToursToFirebase(localTours) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const tours = Array.isArray(localTours) ? localTours : [];
    let synced = 0;
    const failed = [];

    for (const tour of tours) {
      try {
        const doc = await this._buildTourPackageDoc(tour);
        doc.createdAt = admin.firestore.FieldValue.serverTimestamp();
        await this.db.collection('tourPackages').doc(String(tour.id)).set(doc, { merge: true });
        synced += 1;
      } catch (error) {
        failed.push({ id: String(tour.id || ''), message: error.message });
      }
    }

    return {
      synced,
      total: tours.length,
      failed,
    };
  }
}

module.exports = new IntegrationService();
