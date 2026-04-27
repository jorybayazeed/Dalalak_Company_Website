class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  final String id;
  final String name;
  final String email;
  final String role;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
    );
  }
}

class LoginResponse {
  const LoginResponse({
    required this.token,
    required this.user,
  });

  final String token;
  final AppUser user;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String,
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class DashboardOverview {
  const DashboardOverview({
    required this.todayBookings,
    required this.activeTours,
    required this.currentTourists,
    required this.monthlyRevenue,
    required this.guidesCount,
    required this.monthlyBookings,
    required this.monthlyLabels,
    required this.topCities,
    required this.topGuides,
  });

  final int todayBookings;
  final int activeTours;
  final int currentTourists;
  final int monthlyRevenue;
  final int guidesCount;
  final List<int> monthlyBookings;
  final List<String> monthlyLabels;
  final List<CityDemand> topCities;
  final List<GuideRating> topGuides;

  factory DashboardOverview.fromJson(Map<String, dynamic> json) {
    return DashboardOverview(
      todayBookings: (json['todayBookings'] as num).toInt(),
      activeTours: (json['activeTours'] as num).toInt(),
      currentTourists: (json['currentTourists'] as num).toInt(),
      monthlyRevenue: (json['monthlyRevenue'] as num).toInt(),
      guidesCount: (json['guidesCount'] as num).toInt(),
      monthlyBookings: (json['monthlyBookings'] as List<dynamic>).map((item) => (item as num).toInt()).toList(),
      monthlyLabels: (json['monthlyLabels'] as List<dynamic>).map((item) => item as String).toList(),
      topCities: (json['topCities'] as List<dynamic>)
          .map((item) => CityDemand.fromJson(item as Map<String, dynamic>))
          .toList(),
      topGuides: (json['topGuides'] as List<dynamic>)
          .map((item) => GuideRating.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CityDemand {
  const CityDemand({required this.city, required this.demand});

  final String city;
  final int demand;

  factory CityDemand.fromJson(Map<String, dynamic> json) {
    return CityDemand(
      city: json['city'] as String,
      demand: (json['demand'] as num).toInt(),
    );
  }
}

class GuideRating {
  const GuideRating({required this.name, required this.rating});

  final String name;
  final double rating;

  factory GuideRating.fromJson(Map<String, dynamic> json) {
    return GuideRating(
      name: json['name'] as String,
      rating: (json['rating'] as num).toDouble(),
    );
  }
}

class Tour {
  const Tour({
    required this.id,
    required this.name,
    required this.companyName,
    required this.city,
    required this.price,
    required this.date,
    required this.guide,
    required this.capacity,
    required this.participants,
    required this.status,
    required this.duration,
    required this.description,
    required this.mapLocation,
    required this.images,
  });

  final String id;
  final String name;
  final String companyName;
  final String city;
  final int price;
  final String date;
  final String guide;
  final int capacity;
  final int participants;
  final String status;
  final String duration;
  final String description;
  final String mapLocation;
  final List<String> images;

  String get participantsText => '$participants/$capacity';
  String get priceText => '$price SAR';

  factory Tour.fromJson(Map<String, dynamic> json) {
    return Tour(
      id: json['id'] as String,
      name: json['name'] as String,
      companyName: (json['companyName'] as String?) ?? '',
      city: json['city'] as String,
      price: (json['price'] as num).toInt(),
      date: json['date'] as String,
      guide: json['guide'] as String,
      capacity: (json['capacity'] as num).toInt(),
      participants: (json['participants'] as num).toInt(),
      status: json['status'] as String,
      duration: (json['duration'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      mapLocation: (json['mapLocation'] as String?) ?? '',
      images: ((json['images'] as List<dynamic>?) ?? const [])
          .map((item) => item as String)
          .toList(),
    );
  }
}

class CreateTourInput {
  const CreateTourInput({
    required this.name,
    required this.city,
    required this.price,
    required this.date,
    required this.guide,
    this.guideId,
    required this.capacity,
    required this.duration,
    required this.description,
    required this.mapLocation,
    required this.images,
  });

  final String name;
  final String city;
  final int price;
  final String date;
  final String guide;
  final String? guideId;
  final int capacity;
  final String duration;
  final String description;
  final String mapLocation;
  final List<String> images;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'city': city,
      'price': price,
      'date': date,
      'guide': guide,
      'guideId': guideId,
      'capacity': capacity,
      'duration': duration,
      'description': description,
      'mapLocation': mapLocation,
      'images': images,
    };
  }
}

class CreateGuideInput {
  const CreateGuideInput({
    required this.name,
    required this.city,
    required this.languages,
    this.email,
    this.phone,
  });

  final String name;
  final String city;
  final List<String> languages;
  final String? email;
  final String? phone;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'city': city,
      'languages': languages,
      'email': email,
      'phone': phone,
    };
  }
}

class TourParticipant {
  const TourParticipant({
    required this.id,
    required this.touristName,
    required this.participants,
    required this.totalPrice,
    required this.status,
  });

  final String id;
  final String touristName;
  final int participants;
  final int totalPrice;
  final String status;

  String get totalPriceText => '$totalPrice SAR';

  factory TourParticipant.fromJson(Map<String, dynamic> json) {
    return TourParticipant(
      id: json['id'] as String,
      touristName: json['touristName'] as String,
      participants: (json['participants'] as num).toInt(),
      totalPrice: (json['totalPrice'] as num).toInt(),
      status: json['status'] as String,
    );
  }
}

class Booking {
  const Booking({
    required this.id,
    required this.touristName,
    required this.tourId,
    required this.tourName,
    required this.participants,
    required this.totalPrice,
    required this.status,
  });

  final String id;
  final String touristName;
  final String tourId;
  final String tourName;
  final int participants;
  final int totalPrice;
  final String status;

  String get totalPriceText => '$totalPrice SAR';

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      touristName: json['touristName'] as String,
      tourId: json['tourId'] as String,
      tourName: json['tourName'] as String,
      participants: (json['participants'] as num).toInt(),
      totalPrice: (json['totalPrice'] as num).toInt(),
      status: json['status'] as String,
    );
  }
}

class Guide {
  const Guide({
    required this.id,
    required this.name,
    required this.languages,
    required this.city,
    required this.rating,
    required this.totalTours,
    required this.status,
  });

  final String id;
  final String name;
  final List<String> languages;
  final String city;
  final double rating;
  final int totalTours;
  final String status;

  String get languagesText => languages.join(', ');

  factory Guide.fromJson(Map<String, dynamic> json) {
    return Guide(
      id: json['id'] as String,
      name: json['name'] as String,
      languages: (json['languages'] as List<dynamic>).map((item) => item as String).toList(),
      city: json['city'] as String,
      rating: (json['rating'] as num).toDouble(),
      totalTours: (json['totalTours'] as num).toInt(),
      status: json['status'] as String,
    );
  }
}

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.nationality,
    required this.bookings,
    required this.language,
    required this.lastVisit,
  });

  final String id;
  final String name;
  final String nationality;
  final int bookings;
  final String language;
  final String lastVisit;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      name: json['name'] as String,
      nationality: json['nationality'] as String,
      bookings: (json['bookings'] as num).toInt(),
      language: json['language'] as String,
      lastVisit: json['lastVisit'] as String,
    );
  }
}

class ReviewItem {
  const ReviewItem({
    required this.id,
    required this.touristName,
    required this.guideName,
    required this.rating,
    required this.comment,
  });

  final String id;
  final String touristName;
  final String guideName;
  final int rating;
  final String comment;

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    return ReviewItem(
      id: json['id'] as String,
      touristName: json['touristName'] as String,
      guideName: json['guideName'] as String,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String,
    );
  }
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
  });

  final String id;
  final String title;
  final String message;
  final String type;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String,
    );
  }
}

class Reward {
  const Reward({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.value,
    required this.minimumBookings,
    this.validUntil,
    required this.status,
  });

  final String id;
  final String title;
  final String description;
  final String type;
  final String value;
  final int minimumBookings;
  final String? validUntil;
  final String status;

  bool get isActive => status == 'active';

  factory Reward.fromJson(Map<String, dynamic> json) {
    return Reward(
      id: json['id'] as String,
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      type: json['type'] as String,
      value: json['value'] as String,
      minimumBookings: (json['minimumBookings'] as num?)?.toInt() ?? 0,
      validUntil: json['validUntil'] as String?,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'type': type,
        'value': value,
        'minimumBookings': minimumBookings,
        'validUntil': validUntil,
        'status': status,
      };
}

class ReportSummary {
  const ReportSummary({
    required this.revenueGrowth,
    required this.customerSatisfaction,
    required this.cancellationRate,
    required this.monthlyRevenue,
    required this.totalCustomers,
    required this.bestCity,
    required this.topLanguages,
  });

  final int revenueGrowth;
  final double customerSatisfaction;
  final double cancellationRate;
  final int monthlyRevenue;
  final int totalCustomers;
  final String bestCity;
  final List<String> topLanguages;

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    return ReportSummary(
      revenueGrowth: (json['revenueGrowth'] as num).toInt(),
      customerSatisfaction: (json['customerSatisfaction'] as num).toDouble(),
      cancellationRate: (json['cancellationRate'] as num).toDouble(),
      monthlyRevenue: (json['monthlyRevenue'] as num).toInt(),
      totalCustomers: (json['totalCustomers'] as num).toInt(),
      bestCity: json['bestCity'] as String,
      topLanguages: (json['topLanguages'] as List<dynamic>).map((item) => item as String).toList(),
    );
  }
}

class CompanySettings {
  const CompanySettings({
    required this.supportEmail,
    required this.supportPhone,
    required this.city,
    required this.description,
    required this.logoUrl,
    required this.openingTime,
    required this.closingTime,
    required this.timezone,
    required this.currency,
    required this.madaEnabled,
    required this.stcPayEnabled,
    required this.applePayEnabled,
  });

  final String supportEmail;
  final String supportPhone;
  final String city;
  final String description;
  final String logoUrl;
  final String openingTime;
  final String closingTime;
  final String timezone;
  final String currency;
  final bool madaEnabled;
  final bool stcPayEnabled;
  final bool applePayEnabled;

  factory CompanySettings.fromJson(Map<String, dynamic> json) {
    return CompanySettings(
      supportEmail: (json['supportEmail'] as String?) ?? '',
      supportPhone: (json['supportPhone'] as String?) ?? '',
      city: (json['city'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      logoUrl: (json['logoUrl'] as String?) ?? '',
      openingTime: (json['openingTime'] as String?) ?? '08:00',
      closingTime: (json['closingTime'] as String?) ?? '18:00',
      timezone: (json['timezone'] as String?) ?? 'Asia/Riyadh',
      currency: (json['currency'] as String?) ?? 'SAR',
      madaEnabled: (json['madaEnabled'] as bool?) ?? true,
      stcPayEnabled: (json['stcPayEnabled'] as bool?) ?? true,
      applePayEnabled: (json['applePayEnabled'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'supportEmail': supportEmail,
        'supportPhone': supportPhone,
        'city': city,
        'description': description,
        'logoUrl': logoUrl,
        'openingTime': openingTime,
        'closingTime': closingTime,
        'timezone': timezone,
        'currency': currency,
        'madaEnabled': madaEnabled,
        'stcPayEnabled': stcPayEnabled,
        'applePayEnabled': applePayEnabled,
      };
}

class CompanyProfile {
  const CompanyProfile({
    required this.companyName,
    required this.branding,
    required this.logoUrl,
    required this.primaryColor,
    required this.contactEmail,
    required this.contactPhone,
    required this.city,
    required this.address,
    required this.commercialId,
    required this.description,
    required this.website,
  });

  final String companyName;
  final String branding;
  final String logoUrl;
  final String primaryColor;
  final String contactEmail;
  final String contactPhone;
  final String city;
  final String address;
  final String commercialId;
  final String description;
  final String website;

  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    return CompanyProfile(
      companyName: (json['companyName'] as String?) ?? '',
      branding: (json['branding'] as String?) ?? '',
      logoUrl: (json['logoUrl'] as String?) ?? '',
      primaryColor: (json['primaryColor'] as String?) ?? '',
      contactEmail: (json['contactEmail'] as String?) ?? '',
      contactPhone: (json['contactPhone'] as String?) ?? '',
      city: (json['city'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      commercialId: (json['commercialId'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      website: (json['website'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'companyName': companyName,
        'branding': branding,
        'logoUrl': logoUrl,
        'primaryColor': primaryColor,
        'contactEmail': contactEmail,
        'contactPhone': contactPhone,
        'city': city,
        'address': address,
        'commercialId': commercialId,
        'description': description,
        'website': website,
      };
}
