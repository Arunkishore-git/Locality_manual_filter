import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(FilterBar());  
}

class FilterBar extends StatefulWidget {  
  @override
  State<FilterBar> createState() => _FilterBarState(); 
}

class _FilterBarState extends State<FilterBar> {   
  bool isLoggedIn = FirebaseAuth.instance.currentUser != null;

  void updateLoginState(bool loginState) {
    setState(() {
      isLoggedIn = loginState;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ClinicListPage(
        isLoggedIn: isLoggedIn,
        onLogout: () async {
          await FirebaseAuth.instance.signOut();
          updateLoginState(false);
        },
        onLoginSuccess: () => updateLoginState(true),
      ),
    );
  }
}

// 🔹 Convert address → lat/lng using OpenStreetMap Nominatim
Future<List<Map<String, dynamic>>> searchAddress(String query) async {
  if (query.isEmpty) return [];

  final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5");

  final response = await http.get(url, headers: {
    "User-Agent": "DoctorApp/1.0 (your_email@example.com)"
  });

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return List<Map<String, dynamic>>.from(data);
  }
  return [];
}


// 🔹 Add this function just below
Future<Map<String, double>?> getLatLngFromAddress(String address) async {
  final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json&limit=1");

  final response = await http.get(url, headers: {
    "User-Agent": "DoctorApp/1.0 (your_email@example.com)"
  });

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    if (data.isNotEmpty) {
      return {
        "lat": double.parse(data[0]["lat"]),
        "lng": double.parse(data[0]["lon"]),
      };
    }
  }
  return null;
}


class ClinicListPage extends StatefulWidget {
  final bool isLoggedIn;
  final VoidCallback onLogout;
  final VoidCallback onLoginSuccess;

  ClinicListPage({
    required this.isLoggedIn,
    required this.onLogout,
    required this.onLoginSuccess,
  });

  @override
  State<ClinicListPage> createState() => _ClinicListPageState();
}

class _ClinicListPageState extends State<ClinicListPage> {
  List<Map<String, dynamic>> clinicList = [];
  List<Map<String, dynamic>> filteredList = [];
  final searchController = TextEditingController();

  String selectedArea = "All";
  List<String> availableAreas = ["All"];

  Position? currentPosition;
  String? currentAddress;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return;

  LocationPermission permission = await Geolocator.requestPermission();
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) return;

  Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high);

  setState(() {
    currentPosition = position;
  });

  // 🔹 Fetch human-readable address
  final address = await getAddressFromLatLng(
      position.latitude, position.longitude);

  setState(() {
    currentAddress = address;
  });

  fetchClinicsFromFirestore();
}


  double calculateDistance(double lat, double lng) {
    if (currentPosition == null) return double.infinity;
    return Geolocator.distanceBetween(
      currentPosition!.latitude,
      currentPosition!.longitude,
      lat,
      lng,
    );
  }

  String formatDistance(double meters) {
    if (meters >= 1000) {
      return "${(meters / 1000).toStringAsFixed(1)} km away";
    } else {
      return "${meters.toStringAsFixed(0)} m away";
    }
  }

  Future<void> fetchClinicsFromFirestore() async {
    final querySnapshot =
        await FirebaseFirestore.instance.collection('clinics').get();

    final loadedClinics = querySnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'] ?? '',
        'email': data['email'] ?? '',
        'phone': data['phone'] ?? '',
        'address': data['address'] ?? '',
        'area': data['area'] ?? '',
        'townCity': data['townCity'] ?? '',
        'state': data['state'] ?? '',
        'medicalId': data['medicalId'] ?? '',
        'council': data['council'] ?? '',
        'experience': data['experience'] ?? '',
        'qualification': data['qualification'] ?? '',
        'timing': data['timing'] ?? '',
        'lat': (data['lat'] ?? 0.0).toDouble(),
        'lng': (data['lng'] ?? 0.0).toDouble(),
      };
    }).toList();

    final areas = <String>{"All"};
    for (var clinic in loadedClinics) {
      if (clinic['area'].toString().isNotEmpty) {
        areas.add(clinic['area']);
      }
    }

    if (currentPosition != null) {
      loadedClinics.sort((a, b) {
        final distA = calculateDistance(a['lat'], a['lng']);
        final distB = calculateDistance(b['lat'], b['lng']);
        return distA.compareTo(distB);
      });
    }

    setState(() {
      clinicList = loadedClinics;
      filteredList = List.from(loadedClinics);
      availableAreas = areas.toList();
    });
  }

  void filterClinics(String query) {
    final results = clinicList.where((clinic) {
      final matchesName =
          clinic['name'].toLowerCase().contains(query.toLowerCase());
      final matchesArea = (selectedArea == "All" ||
          clinic['area'].toLowerCase().contains(selectedArea.toLowerCase())); 
      return matchesName && matchesArea;
    }).toList();

    setState(() {
      filteredList = results;
    });
  }

  void filterByArea(String area) {
    setState(() {
      selectedArea = area;
    });
    filterClinics(searchController.text);
  }

  void navigateToAddClinic() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddClinicPage()),
    );

    if (result == true) {
      fetchClinicsFromFirestore();
    }
  }

  // 🔹 Step 1: Beautiful card UI
  Widget buildClinicCard(Map<String, dynamic> clinic) {
    final distance = calculateDistance(clinic['lat'], clinic['lng']);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        title: Text(
          clinic['name'] ?? 'Unnamed Clinic',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text("Qualification: ${clinic['qualification']}"),
            Text("Phone: ${clinic['phone']}"),
            Text("Address: ${clinic['address']}"),
            Text("Timing: ${clinic['timing']}"),
            if (currentPosition != null)
              Text(
                formatDistance(distance),
                style: TextStyle(color: Colors.blueGrey),
              ),
          ],
        ),
        trailing: Icon(Icons.local_hospital, color: Colors.blue),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🔹 Step 2: Gradient AppBar
      appBar: AppBar(
        title: Text("Doctor App", style: TextStyle(fontWeight: FontWeight.bold)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.lightBlueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if (widget.isLoggedIn) ...[
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: widget.onLogout,
              tooltip: 'Logout',
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          LoginPage(onLoginSuccess: widget.onLoginSuccess),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  side: BorderSide(color: Colors.blue),
                ),
                child: Text("Login/SignUp"),
              ),
            ),
        ],
      ),

      // 🔹 Step 3: FAB
      floatingActionButton: widget.isLoggedIn
          ? FloatingActionButton(
              onPressed: navigateToAddClinic,
              child: Icon(Icons.add),
              backgroundColor: Colors.blue,
            )
          : null,

      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search clinics...',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.search),
              ),
              onChanged: filterClinics,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text("Filter by Area: "),
                SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedArea,
                    items: availableAreas
                        .map((area) => DropdownMenuItem(
                              child: Text(area),
                              value: area,
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        filterByArea(value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          if (currentAddress != null)
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.my_location, color: Colors.blue, size: 20),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            "You are here: $currentAddress",
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    ),
  ),

          Expanded(
            child: ListView.builder(
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                return buildClinicCard(filteredList[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// 🔹 LoginPage, SignupPage, and AddClinicPage remain unchanged (as in your code above)


class LoginPage extends StatelessWidget {
  final VoidCallback onLoginSuccess;

  LoginPage({required this.onLoginSuccess});

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> loginUser(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      Navigator.pop(context);
      onLoginSuccess();
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Login failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Login"),
        backgroundColor: const Color.fromARGB(255, 106, 179, 239),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                    labelText: "Email", border: OutlineInputBorder()),
              ),
              SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: "Password", border: OutlineInputBorder()),
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => loginUser(context),
                child: Text("Login"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SignupPage()),
                  );
                },
                child: Text("Create New Account"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignupPage extends StatelessWidget {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  Future<void> signupUser(BuildContext context) async {
    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Account created successfully")),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Signup failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Sign Up"),
        backgroundColor: const Color.fromARGB(255, 106, 179, 239),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                  labelText: "Email", border: OutlineInputBorder()),
            ),
            SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: "Password", border: OutlineInputBorder()),
            ),
            SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: "Re-enter Password",
                  border: OutlineInputBorder()),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => signupUser(context),
              child: Text("Sign Up"),
            )
          ],
        ),
      ),
    );
  }
}

class AddClinicPage extends StatefulWidget {
  @override
  _AddClinicPageState createState() => _AddClinicPageState();
}

class _AddClinicPageState extends State<AddClinicPage> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final medicalIdController = TextEditingController();
  final councilController = TextEditingController();
  final experienceController = TextEditingController();
  final qualificationController = TextEditingController();
  final timingController = TextEditingController();
  final addressController = TextEditingController();
  List<Map<String, dynamic>> _addressSuggestions = [];

  // 🔹 Store geocoded lat/lng
  double? _latitude;
  double? _longitude;

  void submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        // If lat/lng not already set, geocode now
        final coords = _latitude != null && _longitude != null
            ? {"lat": _latitude, "lng": _longitude}
            : await getLatLngFromAddress(addressController.text);

        if (coords == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Could not find location for this address")),
          );
          return;
        }

        final newClinic = {
          'name': nameController.text,
          'email': emailController.text,
          'phone': phoneController.text,
          'address': addressController.text,
          'medicalId': medicalIdController.text,
          'council': councilController.text,
          'experience': experienceController.text,
          'qualification': qualificationController.text,
          'timing': timingController.text,
          'createdAt': Timestamp.now(),
          'lat': coords['lat'],
          'lng': coords['lng'],
        };

        await FirebaseFirestore.instance.collection('clinics').add(newClinic);

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Clinic added!")));
        Navigator.pop(context, true); // Return true to refresh clinic list
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to add clinic: $e")),
        );
      }
    }
  }

  Widget buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        decoration:
            InputDecoration(labelText: label, border: OutlineInputBorder()),
        validator: (value) =>
            value == null || value.isEmpty ? 'Enter $label' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Clinics"),
        backgroundColor: const Color.fromARGB(255, 106, 179, 239),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              buildTextField("Name", nameController),
              buildTextField("Email", emailController),
              buildTextField("Phone", phoneController),
              buildTextField("Medical ID", medicalIdController),
              buildTextField("Council & Year", councilController),
              buildTextField("Experience", experienceController),
              buildTextField("Qualification", qualificationController),
              buildTextField("Timing", timingController),

              SizedBox(height: 12),
              TextFormField(
                controller: addressController,
                decoration: InputDecoration(
                  labelText: "Address",
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) async {
                  final results = await searchAddress(value);
                  setState(() {
                    _addressSuggestions = results;
                  });
                },
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter Address' : null,
              ),

              // 🔹 Suggestions list
              ..._addressSuggestions.map((s) => ListTile(
                    title: Text(s["display_name"]),
                    onTap: () {
                      setState(() {
                        addressController.text = s["display_name"];
                        _addressSuggestions = [];
                      });
                    },
                  )),

              SizedBox(height: 10),

              // 🔹 Get Location button
              ElevatedButton(
                onPressed: () async {
                  if (addressController.text.isNotEmpty) {
                    try {
                      final coords =
                          await getLatLngFromAddress(addressController.text);
                      setState(() {
                        _latitude = coords?['lat'];
                        _longitude = coords?['lng'];
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                "Location Found: ($_latitude, $_longitude)")),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Could not find location")),
                      );
                    }
                  }
                },
                child: Text("Get Location"),
              ),

              SizedBox(height: 20),
              ElevatedButton(
                onPressed: submitForm,
                child: Text("Submit"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String> getAddressFromLatLng(double lat, double lng) async {
  final url = Uri.parse(
      "https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng");

  final response = await http.get(url, headers: {
    "User-Agent": "DoctorApp/1.0 (your_email@example.com)"
  });

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data["display_name"] ?? "Unknown location";
  } else {
    throw Exception("Failed to fetch address");
  }
}
