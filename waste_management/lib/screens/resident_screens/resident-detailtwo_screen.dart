import 'package:flutter/material.dart';

class DetailTwoScreen extends StatelessWidget {
  const DetailTwoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 10.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "How It Works",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // Feature List
                  featureItem(
                    Icons.location_on,
                    "Track Garbage Trucks",
                    "Get real-time updates on garbage truck locations.",
                  ),
                  featureItem(
                    Icons.notifications,
                    "Receive Notifications",
                    "Get real-time updates on garbage truck locations.",
                  ),
                  featureItem(
                    Icons.report,
                    "Report Issues",
                    "Stay informed about waste collection schedules.",
                  ),
                  featureItem(
                    Icons.check_box,
                    "Provide Feedback",
                    "Give feedback on the cleanliness of your area.",
                  ),

                  const SizedBox(height: 30),

                  // Spacer to push the switch down
                  Spacer(),
                ],
              ),
            ),
          ),

          // Buttons Section - now consistently positioned with first screen
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/resident_location_picker_screen');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF59A867),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                  ),
                  child: const Text(
                    "Get Start",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget featureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [Container(width: 3, height: 50, color: Colors.green)],
          ),
          const SizedBox(width: 10),
          Icon(icon, color: Colors.black, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
