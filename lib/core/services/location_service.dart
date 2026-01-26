import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  static Future<String> detectCountryCode() async {
    try {
      final response =
          await http.get(Uri.parse('https://ipinfo.io/json'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['country'] ?? 'US';
      }
    } catch (_) {}
    return 'US';
  }
}
