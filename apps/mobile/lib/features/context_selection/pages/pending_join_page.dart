import 'package:flutter/material.dart';

class PendingJoinPage extends StatelessWidget {
  const PendingJoinPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Request Pending')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top, size: 64),
            SizedBox(height: 16),
            Text('Your request is under review.'),
          ],
        ),
      ),
    );
  }
}
