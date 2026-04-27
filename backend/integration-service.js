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

  async getGuides() {
    if (!this.isFirebaseInitialized) return [];

    const [guidesSnap, packagesSnap] = await Promise.all([
      this.db.collection('users').where('userType', '==', 'tour_guide').get(),
      this.db.collection('tourPackages').get(),
    ]);

    const tourCountByGuide = new Map();
    packagesSnap.docs.forEach((doc) => {
      const guideId = doc.data().guideId;
      if (!guideId) return;
      tourCountByGuide.set(guideId, (tourCountByGuide.get(guideId) || 0) + 1);
    });

    return guidesSnap.docs.map((doc) => {
      const u = doc.data();
      return {
        id: doc.id,
        name: u.fullName || u.email || 'Unknown Guide',
        languages: Array.isArray(u.languagesSpoken) ? u.languagesSpoken : [],
        city: u.city || u.specialization || 'N/A',
        rating: this._asNumber(u.avgRating || u.rating, 0),
        totalTours: tourCountByGuide.get(doc.id) || 0,
        status: u.isProfileVerified ? 'Available' : 'Pending',
      };
    });
  }

  async createGuide(payload) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const name = String(payload.name || '').trim();
    const city = String(payload.city || '').trim();
    if (!name || !city) {
      throw new Error('name and city are required');
    }

    const doc = {
      fullName: name,
      city,
      userType: 'tour_guide',
      languagesSpoken: Array.isArray(payload.languages)
        ? payload.languages.map((item) => String(item))
        : [],
      email: payload.email ? String(payload.email) : '',
      phone: payload.phone ? String(payload.phone) : '',
      isProfileVerified: true,
      avgRating: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const ref = await this.db.collection('users').add(doc);
    return {
      id: ref.id,
      name: doc.fullName,
      languages: doc.languagesSpoken,
      city: doc.city,
      rating: 0,
      totalTours: 0,
      status: 'Available',
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

  async getCustomers() {
    if (!this.isFirebaseInitialized) return [];

    const touristsSnap = await this.db.collection('users').where('userType', '==', 'tourist').get();

    const rows = await Promise.all(
      touristsSnap.docs.map(async (doc) => {
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

  async getBookings() {
    if (!this.isFirebaseInitialized) return [];

    const [touristsSnap, packagesSnap] = await Promise.all([
      this.db.collection('users').where('userType', '==', 'tourist').get(),
      this.db.collection('tourPackages').get(),
    ]);

    const packageById = new Map(packagesSnap.docs.map((doc) => [doc.id, doc.data()]));

    const rows = [];
    for (const touristDoc of touristsSnap.docs) {
      const tourist = touristDoc.data();
      const bookingsSnap = await this.db
        .collection('users')
        .doc(touristDoc.id)
        .collection('upcomingBookings')
        .get();

      bookingsSnap.docs.forEach((doc) => {
        const b = doc.data();
        const tourId = b.packageId || b.tourId || '';
        const pkg = packageById.get(tourId) || {};
        const participants = this._asNumber(b.participants || b.numPeople, 1);
        const price = this._asNumber(pkg.price, 0);
        rows.push({
          id: doc.id,
          touristName: b.guestName || tourist.fullName || tourist.email || 'Unknown Tourist',
          tourId,
          tourName: pkg.tourTitle || 'Unknown Tour',
          participants,
          totalPrice: this._asNumber(b.totalPrice, participants * price),
          status: this._bookingStatus(b.status),
          ownerUserId: touristDoc.id,
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

  async getRewards() {
    if (!this.isFirebaseInitialized) return [];

    const snap = await this.db.collection('rewards').get();
    return snap.docs.map((doc) => {
      const r = doc.data();
      return {
        id: doc.id,
        title: r.title || '',
        description: r.description || '',
        type: r.type || 'points',
        value: String(r.value || ''),
        minimumBookings: this._asNumber(r.minimumBookings, 0),
        validUntil: r.validUntil || null,
        status: r.status === 'inactive' ? 'inactive' : 'active',
      };
    });
  }

  async createReward(data) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const doc = {
      title: String(data.title),
      description: data.description ? String(data.description) : '',
      type: String(data.type),
      value: String(data.value),
      minimumBookings: this._asNumber(data.minimumBookings, 0),
      validUntil: data.validUntil || null,
      status: data.status === 'inactive' ? 'inactive' : 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const ref = await this.db.collection('rewards').add(doc);
    return {
      id: ref.id,
      title: doc.title,
      description: doc.description,
      type: doc.type,
      value: doc.value,
      minimumBookings: doc.minimumBookings,
      validUntil: doc.validUntil,
      status: doc.status,
    };
  }

  async updateReward(id, data) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }

    const patch = { ...data, updatedAt: admin.firestore.FieldValue.serverTimestamp() };
    delete patch.id;
    await this.db.collection('rewards').doc(id).update(patch);
    const snap = await this.db.collection('rewards').doc(id).get();
    if (!snap.exists) throw new Error('Reward not found');
    const r = snap.data() || {};

    return {
      id: snap.id,
      title: r.title || '',
      description: r.description || '',
      type: r.type || 'points',
      value: String(r.value || ''),
      minimumBookings: this._asNumber(r.minimumBookings, 0),
      validUntil: r.validUntil || null,
      status: r.status === 'inactive' ? 'inactive' : 'active',
    };
  }

  async setRewardStatus(id, status) {
    return this.updateReward(id, { status });
  }

  async deleteReward(id) {
    if (!this.isFirebaseInitialized) {
      throw new Error('Firebase is not initialized');
    }
    await this.db.collection('rewards').doc(id).delete();
  }

  async getDashboardOverview() {
    const [tours, bookings, guides] = await Promise.all([
      this.getTours(),
      this.getBookings(),
      this.getGuides(),
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

  async getReportSummary() {
    const [bookings, reviews, customers, tours, guides] = await Promise.all([
      this.getBookings(),
      this.getReviews(),
      this.getCustomers(),
      this.getTours(),
      this.getGuides(),
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
