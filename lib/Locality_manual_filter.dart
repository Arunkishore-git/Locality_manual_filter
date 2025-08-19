import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

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

  @override
  void initState() {
    super.initState();
    fetchClinicsFromFirestore();
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
    'area': data['area'] ?? '',             // 👈 Added
    'townCity': data['townCity'] ?? '',
    'state': data['state'] ?? '',
    'medicalId': data['medicalId'] ?? '',
    'council': data['council'] ?? '',
    'experience': data['experience'] ?? '',
    'qualification': data['qualification'] ?? '',
    'timing': data['timing'] ?? '',
  };
}).toList();

final areas = <String>{"All"};
for (var clinic in loadedClinics) {
  if (clinic['area'].toString().isNotEmpty) {
    areas.add(clinic['area']);   // 👈 Use area here
  }
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
        clinic['area'].toLowerCase().contains(selectedArea.toLowerCase())); // 👈 Changed
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Doctor App"),
        backgroundColor: const Color.fromARGB(255, 106, 179, 239),
        actions: [
          if (widget.isLoggedIn) ...[
            IconButton(
              icon: Icon(Icons.add),
              onPressed: navigateToAddClinic,
              tooltip: 'Add Clinic',
            ),
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
          Expanded(
            child: ListView.builder(
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                final clinic = filteredList[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    title: Text(clinic['name']),
                    subtitle: Text(
                      "Qualification: ${clinic['qualification']}\n"
                      "Phone: ${clinic['phone']}\n"
                      "Address: ${clinic['address']}\n"
                      "Area: ${clinic['area']}\n"   
                      "Timing: ${clinic['timing']}",
                      ),

                    isThreeLine: true,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- LoginPage and SignupPage remain same (no change) ---

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

  String address = "";
  final flatNoController = TextEditingController();
  final sectorController = TextEditingController();
  final landmarkController = TextEditingController();
  final areaController = TextEditingController();
  final townCityController = TextEditingController();
  final stateController = TextEditingController();

  void submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (address.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please add an Address")),
        );
        return;
      }

     final newClinic = {
  'name': nameController.text,
  'email': emailController.text,
  'phone': phoneController.text,
  'address': address,
  'area': areaController.text,             // 👈 Added
  'townCity': townCityController.text,     
  'state': stateController.text,           
  'medicalId': medicalIdController.text,
  'council': councilController.text,
  'experience': experienceController.text,
  'qualification': qualificationController.text,
  'timing': timingController.text,
  'createdAt': Timestamp.now(),
};


      try {
        await FirebaseFirestore.instance.collection('clinics').add(newClinic);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Clinic added!")));
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Failed to add clinic")));
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

  void openAddressDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("Add Address"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                buildTextField("Flat No / House No", flatNoController),
                buildTextField("Sector / Street / Village", sectorController),
                buildTextField("Landmark", landmarkController),
                buildTextField("Area", areaController),
                buildTextField("Town/City", townCityController),
                buildTextField("State", stateController),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (flatNoController.text.isEmpty ||
                    sectorController.text.isEmpty ||
                    landmarkController.text.isEmpty ||
                    areaController.text.isEmpty ||
                    townCityController.text.isEmpty ||
                    stateController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("All address fields are required")),
                  );
                  return;
                }

                setState(() {
                  address =
                      "${flatNoController.text}, ${sectorController.text}, ${landmarkController.text}, ${areaController.text}, ${townCityController.text}, ${stateController.text}";
                });
                Navigator.pop(ctx);
              },
              child: Text("Save"),
            )
          ],
        );
      },
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
              ElevatedButton(
                onPressed: submitForm,
                child: Text("Submit"),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: openAddressDialog,
                child: Text("Add Address"),
              ),
              if (address.isNotEmpty) ...[
                SizedBox(height: 10),
                Text("Address Added:\n$address",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
