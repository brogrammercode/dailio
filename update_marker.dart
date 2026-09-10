import 'dart:io';

void main() {
  var file = File('apps/mobile/lib/features/organization/pages/create_branch_page.dart');
  var content = file.readAsStringSync();

  // Fix Marker
  var markerRegex = RegExp(r'Widget _buildMarkerWidget.*?\}\s*\}', dotAll: true);
  var newMarker = '''Widget _buildMarkerWidget({required bool isGreen, String? label}) {
    return Transform.translate(
      offset: const Offset(0, -16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isGreen ? Colors.green : Colors.black,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: (isGreen ? Colors.green : Colors.black).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          Container(
            width: 2.5,
            height: 12,
            color: isGreen ? Colors.green : Colors.black,
          ),
        ],
      ),
    );
  }
}''';
  if (content.contains('_buildMarkerWidget')) {
    content = content.replaceFirst(markerRegex, newMarker);
  }

  // Remove the TrianglePainter entirely as it's no longer used
  var triangleRegex = RegExp(r'class _TrianglePainter extends CustomPainter \{.*?\}', dotAll: true);
  content = content.replaceFirst(triangleRegex, '');

  // Fix display_name fallback City/Postcode removal
  var geocodeRegex = RegExp(r'// Final fallback if nominatim misses structured.*?String postcode = address\[.postcode.\] \?\? ..;', dotAll: true);
  var newGeocode = '''String postcode = address['postcode']?.toString() ?? '';
        String country = address['country']?.toString() ?? 'India';

        // Final fallback if nominatim misses structured address keys but returns display_name
        if (street.trim().isEmpty || street.trim() == ',') {
           final displayName = response.data['display_name']?.toString() ?? '';
           final parts = displayName.split(',')
             .map((e) => e.trim())
             .where((e) => e.isNotEmpty 
                && e.toLowerCase() != rawCity.toLowerCase() 
                && e.toLowerCase() != (address['state']?.toString() ?? '').toLowerCase()
                && e.toLowerCase() != postcode.toLowerCase()
                && e.toLowerCase() != country.toLowerCase())
             .toList();
           if (parts.isNotEmpty) {
             street = parts.take(2).join(', '); // take first 1 or 2 parts
           }
        }''';
  content = content.replaceFirst(geocodeRegex, newGeocode);

  file.writeAsStringSync(content);
}
