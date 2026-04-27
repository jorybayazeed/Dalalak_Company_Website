import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({required this.baseUrl});

  final String baseUrl;
  String? _token;

  set token(String? value) {
    _token = value;
  }

  String? get token => _token;

  Map<String, String> _headers({bool withAuth = true}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (withAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Uri _uri(String path) {
    return Uri.parse('$baseUrl$path');
  }

  dynamic _parseResponse(http.Response response) {
    final dynamic decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    String message = 'Request failed (${response.statusCode})';
    if (decoded is Map<String, dynamic> && decoded['message'] is String) {
      message = decoded['message'] as String;
    }
    throw ApiException(message);
  }

  Future<LoginResponse> login({
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await http.post(
      _uri('/api/auth/login'),
      headers: _headers(withAuth: false),
      body: jsonEncode({'email': email, 'password': password, 'role': role}),
    );

    final json = _parseResponse(response) as Map<String, dynamic>;
    final loginResponse = LoginResponse.fromJson(json);
    _token = loginResponse.token;
    return loginResponse;
  }

  Future<void> logout() async {
    if (_token == null) {
      return;
    }
    final response = await http.post(
      _uri('/api/auth/logout'),
      headers: _headers(),
    );
    _parseResponse(response);
    _token = null;
  }

  Future<DashboardOverview> getDashboardOverview() async {
    final response = await http.get(_uri('/api/dashboard/overview'), headers: _headers());
    final json = _parseResponse(response) as Map<String, dynamic>;
    return DashboardOverview.fromJson(json);
  }

  Future<List<Tour>> getTours() async {
    final response = await http.get(_uri('/api/tours'), headers: _headers());
    final json = _parseResponse(response) as List<dynamic>;
    return json.map((item) => Tour.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Tour> createTour(CreateTourInput input) async {
    final response = await http.post(
      _uri('/api/tours'),
      headers: _headers(),
      body: jsonEncode(input.toJson()),
    );
    final json = _parseResponse(response) as Map<String, dynamic>;
    return Tour.fromJson(json);
  }

  Future<Tour> updateTour(String tourId, CreateTourInput input) async {
    final response = await http.put(
      _uri('/api/tours/$tourId'),
      headers: _headers(),
      body: jsonEncode(input.toJson()),
    );
    final json = _parseResponse(response) as Map<String, dynamic>;
    return Tour.fromJson(json);
  }

  Future<List<TourParticipant>> getTourParticipants(String tourId) async {
    final response = await http.get(
      _uri('/api/tours/$tourId/participants'),
      headers: _headers(),
    );
    final json = _parseResponse(response) as List<dynamic>;
    return json.map((item) => TourParticipant.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> deleteTour(String tourId) async {
    final response = await http.delete(
      _uri('/api/tours/$tourId'),
      headers: _headers(),
    );
    _parseResponse(response);
  }

  Future<List<Booking>> getBookings() async {
    final response = await http.get(_uri('/api/bookings'), headers: _headers());
    final json = _parseResponse(response) as List<dynamic>;
    return json.map((item) => Booking.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Booking> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    final response = await http.patch(
      _uri('/api/bookings/$bookingId/status'),
      headers: _headers(),
      body: jsonEncode({'status': status}),
    );

    final json = _parseResponse(response) as Map<String, dynamic>;
    return Booking.fromJson(json);
  }

  Future<List<Guide>> getGuides() async {
    final response = await http.get(_uri('/api/guides'), headers: _headers());
    final json = _parseResponse(response) as List<dynamic>;
    return json.map((item) => Guide.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Guide> createGuide(CreateGuideInput input) async {
    final response = await http.post(
      _uri('/api/guides'),
      headers: _headers(),
      body: jsonEncode(input.toJson()),
    );
    final json = _parseResponse(response) as Map<String, dynamic>;
    return Guide.fromJson(json);
  }

  Future<void> deleteGuide(String guideId) async {
    final response = await http.delete(
      _uri('/api/guides/$guideId'),
      headers: _headers(),
    );
    _parseResponse(response);
  }

  Future<List<Customer>> getCustomers() async {
    final response = await http.get(_uri('/api/customers'), headers: _headers());
    final json = _parseResponse(response) as List<dynamic>;
    return json.map((item) => Customer.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<ReviewItem>> getReviews() async {
    final response = await http.get(_uri('/api/reviews'), headers: _headers());
    final json = _parseResponse(response) as List<dynamic>;
    return json.map((item) => ReviewItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<NotificationItem>> getNotifications() async {
    final response = await http.get(_uri('/api/notifications'), headers: _headers());
    final json = _parseResponse(response) as List<dynamic>;
    return json.map((item) => NotificationItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ReportSummary> getReportSummary() async {
    final response = await http.get(_uri('/api/reports/summary'), headers: _headers());
    final json = _parseResponse(response) as Map<String, dynamic>;
    return ReportSummary.fromJson(json);
  }

  Future<List<Reward>> getRewards() async {
    final response = await http.get(_uri('/api/rewards'), headers: _headers());
    final json = _parseResponse(response) as List<dynamic>;
    return json.map((item) => Reward.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Reward> createReward(Map<String, dynamic> data) async {
    final response = await http.post(
      _uri('/api/rewards'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    final json = _parseResponse(response) as Map<String, dynamic>;
    return Reward.fromJson(json);
  }

  Future<Reward> updateReward(String id, Map<String, dynamic> data) async {
    final response = await http.put(
      _uri('/api/rewards/$id'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    final json = _parseResponse(response) as Map<String, dynamic>;
    return Reward.fromJson(json);
  }

  Future<Reward> setRewardStatus(String id, String status) async {
    final response = await http.patch(
      _uri('/api/rewards/$id/status'),
      headers: _headers(),
      body: jsonEncode({'status': status}),
    );
    final json = _parseResponse(response) as Map<String, dynamic>;
    return Reward.fromJson(json);
  }

  Future<void> deleteReward(String id) async {
    final response = await http.delete(_uri('/api/rewards/$id'), headers: _headers());
    _parseResponse(response);
  }

  Future<CompanySettings> getCompanySettings() async {
    final response = await http.get(_uri('/api/company/settings'), headers: _headers());
    final json = _parseResponse(response) as Map<String, dynamic>;
    return CompanySettings.fromJson(json);
  }

  Future<CompanySettings> updateCompanySettings(CompanySettings input) async {
    final response = await http.put(
      _uri('/api/company/settings'),
      headers: _headers(),
      body: jsonEncode(input.toJson()),
    );
    final json = _parseResponse(response) as Map<String, dynamic>;
    return CompanySettings.fromJson(json);
  }

  Future<CompanyProfile> getCompanyProfile() async {
    final response = await http.get(_uri('/api/company/profile'), headers: _headers());
    final json = _parseResponse(response) as Map<String, dynamic>;
    return CompanyProfile.fromJson(json);
  }

  Future<CompanyProfile> updateCompanyProfile(CompanyProfile input) async {
    final response = await http.put(
      _uri('/api/company/profile'),
      headers: _headers(),
      body: jsonEncode(input.toJson()),
    );
    final json = _parseResponse(response) as Map<String, dynamic>;
    return CompanyProfile.fromJson(json);
  }
}
