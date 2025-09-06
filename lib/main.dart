
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Doctor Detail Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DummyHomePage(),
    );
  }
}

class DummyHomePage extends StatelessWidget {
  const DummyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 🔹 Dummy doctor data for testing
    final doctorData = {
      'name': 'Dr. John Doe',
      'email': 'john.doe@example.com',
      'phoneNumber': '9876543210',
      'medicalIdNumber': 'MED12345',
      'address': '123 Main Street',
      'role': 'Cardiologist',
      'createdAt': Timestamp.now(),
      'admin_approved': false,
    };

    return Scaffold(
      appBar: AppBar(title: const Text("Home Page")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DoctorDetailPage(
                  doctorId: "dummyDoctorId", // replace with Firestore doc ID in real app
                  doctorData: doctorData,
                ),
              ),
            );
          },
          child: const Text("Go to Doctor Detail Page"),
        ),
      ),
    );
  }
}

class DoctorDetailPage extends StatefulWidget {
  final String doctorId;
  final Map<String, dynamic> doctorData;

  const DoctorDetailPage({
    super.key,
    required this.doctorId,
    required this.doctorData,
  });

  @override
  State<DoctorDetailPage> createState() => _DoctorDetailPageState();
}

class _DoctorDetailPageState extends State<DoctorDetailPage> {
  late bool isApproved;

  @override
  void initState() {
    super.initState();
    isApproved = widget.doctorData['admin_approved'] ?? false;
  }

  Future<void> _updateApproval(bool value) async {
    await FirebaseFirestore.instance
        .collection('doctors')
        .doc(widget.doctorId)
        .update({'admin_approved': value});
    setState(() {
      isApproved = value;
    });
  }

  Future<void> _deleteDoctor() async {
    final confirm = await _showDeleteConfirmDialog();
    if (confirm) {
      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.doctorId)
          .delete();
      if (mounted) Navigator.pop(context); // close detail page after delete
    }
  }

  Future<bool> _showDeleteConfirmDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Delete"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Type CONFIRM to delete this doctor"),
              TextField(controller: controller),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context, false),
            ),
            ElevatedButton(
              child: const Text("Delete"),
              onPressed: () {
                if (controller.text.trim().toUpperCase() == "CONFIRM") {
                  Navigator.pop(context, true);
                }
              },
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = widget.doctorData['createdAt'];
    String formattedDate = "Not Available";
    if (createdAt != null && createdAt is Timestamp) {
      final DateTime dateTime = createdAt.toDate();
      formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.doctorData['name'] ?? "Doctor Details")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DetailRow(
                  label: "Name",
                  value: widget.doctorData['name'] ?? "",
                  fontSize: 17,
                ),
                DetailRow(
                  label: "Email",
                  value: widget.doctorData['email'] ?? "",
                  fontSize: 17,
                ),
                DetailRow(
                  label: "Phone",
                  value: widget.doctorData['phoneNumber'] ?? "",
                  fontSize: 16,
                ),
                DetailRow(
                  label: "Medical Id",
                  value: widget.doctorData['medicalIdNumber'] ?? "",
                  fontSize: 16,
                ),
                DetailRow(
                  label: "Address",
                  value: widget.doctorData['address'] ?? "",
                  fontSize: 16,
                ),
                DetailRow(
                  label: "Role",
                  value: widget.doctorData['role'] ?? "",
                  fontSize: 16,
                ),
                DetailRow(
                  label: "Account Created At",
                  value: formattedDate,
                  fontSize: 14,
                  color: Colors.grey,
                ),
                const SizedBox(height: 20),
              ],
            ),

            const SizedBox(height: 20),

            // 🔹 Toggle for approval
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Admin Approved"),
                Switch(
                  value: isApproved,
                  onChanged: (val) => _updateApproval(val),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 🔹 Delete button
            ElevatedButton.icon(
              icon: const Icon(Icons.delete, color: Colors.white),
              label: const Text("Delete Doctor"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _deleteDoctor,
            ),
          ],
        ),
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final double fontSize;
  final Color? color;

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.fontSize = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: "$label: ",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: fontSize,
                color: color ?? Colors.black,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: fontSize,
                color: color ?? Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
