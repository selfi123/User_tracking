import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; // For LatLng type
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    await FirebaseAuth.instance.signInAnonymously();
  } catch (e) {
    print("Firebase initialization error: $e");
    return;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'User Location Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const UserListScreen(),
    );
  }
}

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  _UserListScreenState createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  List<String> userIds = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchUserIds(); // Initial fetch
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      fetchUserIds(); // Fetch users every 10 seconds
    });
  }

  Future<void> fetchUserIds() async {
    try {
      QuerySnapshot snapshot =
      await FirebaseFirestore.instance.collection('locations').get();
      List<String> ids = snapshot.docs.map((doc) => doc.id).toList();

      setState(() {
        userIds = ids;
      });
    } catch (e) {
      print("Error fetching users: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select a User")),
      body: userIds.isEmpty
          ? const Center(child: Text("No users found"))
          : ListView.builder(
        itemCount: userIds.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(userIds[index]),
            trailing: const Icon(Icons.location_on, color: Colors.blue),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MapScreen(userIds[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  final String uid;
  const MapScreen(this.uid, {super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _currentLocation;
  Timer? _timer;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    startFetchingLocation();
  }

  Future<void> fetchLatestLocation() async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('locations')
          .doc(widget.uid)
          .get();

      if (snapshot.exists) {
        GeoPoint location = snapshot['location'];
        setState(() {
          _currentLocation = LatLng(location.latitude, location.longitude);
        });

        if (_currentLocation != null) {
          _mapController.move(_currentLocation!, 13.0);
        }
      } else {
        print("No location data found for UID: ${widget.uid}");
      }
    } catch (e) {
      print("Error fetching location: $e");
    }
  }

  void startFetchingLocation() {
    fetchLatestLocation();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      await fetchLatestLocation();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Location of ${widget.uid}")),
      body: _currentLocation == null
          ? const Center(child: Text("Fetching location..."))
          : FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentLocation!,
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                width: 80.0,
                height: 80.0,
                point: _currentLocation!,
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 40.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
