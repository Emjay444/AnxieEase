import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  List<Marker> _markers = [];
  List<Map<String, dynamic>> _facilities = [];
  bool _isLoading = true;
  final Map<String, Marker> _facilityMarkers = {};

  @override
  void initState() {
    super.initState();
    _getCurrentLocationAndFacilities();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _getCurrentLocationAndFacilities() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _markers = [
          Marker(
            point: LatLng(position.latitude, position.longitude),
            child: const Icon(
              Icons.my_location,
              color: Colors.blue,
              size: 30,
            ),
          ),
        ];
      });

      // Move map to current location
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        14,
      );

      // Fetch nearby facilities
      await _fetchNearbyFacilities(position);
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _fetchNearbyFacilities(Position position) async {
    try {
      setState(() {
        _isLoading = true; // Set loading state at start
      });

      // Using Overpass API for more accurate results
      final query = '''
        [out:json][timeout:25];
        (
          way["amenity"="hospital"](around:10000,${position.latitude},${position.longitude});
          node["amenity"="hospital"](around:10000,${position.latitude},${position.longitude});
          way["amenity"="clinic"](around:10000,${position.latitude},${position.longitude});
          node["amenity"="clinic"](around:10000,${position.latitude},${position.longitude});
        );
        out body;
        >;
        out skel qt;
      ''';

      final response = await http.get(
        Uri.parse(
            'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}'),
        headers: {
          'User-Agent': 'CtrlZed/1.0',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List;

        // Clear previous markers and facility markers
        _facilityMarkers.clear();
        _markers = [_markers.first]; // Keep only current location marker

        // Process facilities
        final processedFacilities = elements
            .where((element) {
              if (!element.containsKey('tags')) return false;
              final tags = element['tags'] as Map;
              return tags['amenity'] == 'hospital' ||
                  tags['amenity'] == 'clinic';
            })
            .map((element) {
              final tags = element['tags'] as Map;
              final isHospital = tags['amenity'] == 'hospital';
              final name = tags['name'] ?? 'Unnamed Facility';
              final id = element['id'].toString();

              final lat = element['lat'] ?? element['center']?['lat'];
              final lon = element['lon'] ?? element['center']?['lon'];

              if (lat == null || lon == null) return null;

              final distance = Geolocator.distanceBetween(
                position.latitude,
                position.longitude,
                lat.toDouble(),
                lon.toDouble(),
              );

              // Create marker for this facility
              final marker = Marker(
                point: LatLng(lat.toDouble(), lon.toDouble()),
                child: Icon(
                  isHospital ? Icons.local_hospital : Icons.medical_services,
                  color: isHospital ? Colors.red : Colors.orange,
                ),
              );

              // Store marker with facility ID
              _facilityMarkers[id] = marker;
              _markers.add(marker);

              return {
                'id': id,
                'name': name,
                'type': isHospital ? 'Hospital' : 'Medical Facility',
                'address': tags['addr:street'] ??
                    tags['address'] ??
                    'Address not available',
                'distance': distance,
                'amenity': isHospital ? 'hospital' : 'clinic',
                'isHospital': isHospital,
              };
            })
            .whereType<Map<String, dynamic>>()
            .toList();

        setState(() {
          _facilities = processedFacilities
            ..sort((a, b) {
              if (a['isHospital'] && !b['isHospital']) return -1;
              if (!a['isHospital'] && b['isHospital']) return 1;
              return (a['distance'] as double)
                  .compareTo(b['distance'] as double);
            });
          _isLoading = false; // Set loading state to false after processing
        });
      }
    } catch (e) {
      print('Error fetching facilities: $e');
      if (mounted) {
        setState(() {
          _isLoading = false; // Make sure to set loading to false on error
          _facilities = []; // Clear facilities on error
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            // Header - Fixed
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: Colors.grey[800],
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Nearby Medical Facilities',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),

            // Map Section - Fixed
            Container(
              height: MediaQuery.of(context).size.height * 0.35,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  center: _currentPosition != null
                      ? LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        )
                      : const LatLng(14.5995, 120.9842),
                  zoom: 14,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(markers: _markers),
                ],
              ),
            ),

            // Results Header - Fixed
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _facilities.isNotEmpty
                        ? 'Nearby Facilities'
                        : 'No facilities found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  if (_facilities.isNotEmpty)
                    Text(
                      '${_facilities.length} found',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),

            // Results List - Scrollable
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                        bottom: 80, // Add padding for FAB
                      ),
                      itemCount: _facilities.length,
                      itemBuilder: (context, index) {
                        final facility = _facilities[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: facility['amenity'] == 'hospital'
                                    ? Colors.red[50]
                                    : Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                facility['amenity'] == 'hospital'
                                    ? Icons.local_hospital
                                    : Icons.medical_services,
                                color: facility['amenity'] == 'hospital'
                                    ? Colors.red
                                    : Colors.orange,
                              ),
                            ),
                            title: Text(
                              facility['name'],
                              style: TextStyle(
                                fontWeight: facility['amenity'] == 'hospital'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(facility['type']),
                                Text(
                                  '${(facility['distance'] / 1000).toStringAsFixed(1)} km away',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              final facilityId = facility['id'];
                              if (facilityId != null &&
                                  _facilityMarkers.containsKey(facilityId)) {
                                final marker = _facilityMarkers[facilityId]!;
                                _mapController.move(marker.point, 16);
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentPosition != null) {
            _mapController.move(
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              14,
            );
          }
        },
        backgroundColor: Colors.green[600],
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
