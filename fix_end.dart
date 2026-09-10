import 'dart:io';

void main() {
  var file = File('apps/mobile/lib/features/organization/pages/create_branch_page.dart');
  var content = file.readAsStringSync();

  // Find the exact _buildMarkerWidget and replace it
  int startIdx = content.indexOf('Widget _buildMarkerWidget');
  if (startIdx != -1) {
    int endIdx = content.lastIndexOf('class _TrianglePainter');
    if (endIdx != -1) {
       // We can replace everything from _buildMarkerWidget to the end
       String newEnd = '''Widget _buildMarkerWidget({required bool isGreen, String? label}) {
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
}
''';
       content = content.substring(0, startIdx) + newEnd;
    }
  }

  file.writeAsStringSync(content);
}
