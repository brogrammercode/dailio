import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'dart:ui' as ui;

import '../controllers/organization_repository.dart';
import '../models/create_organization_models.dart';
import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';

class CreateBranchPage extends StatefulWidget {
  final CreateOrganizationInput organizationInput;

  const CreateBranchPage({super.key, required this.organizationInput});

  @override
  State<CreateBranchPage> createState() => _CreateBranchPageState();
}

class _CreateBranchPageState extends State<CreateBranchPage> {
  final _formKey = GlobalKey<FormState>();

  // Branch Fields
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalController = TextEditingController();
  final _countryController = TextEditingController(text: 'India');

  final _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  Timer? _mapDebounce;
  List<dynamic> _suggestions = [];
  bool _isFetchingSuggestions = false;

  final MapController _mapController = MapController();
  LatLng _currentLocation =
      const LatLng(20.5937, 78.9629); // Default to India roughly

  bool _isCheckingCode = false;
  bool _isCodeUnique = true;
  bool _isLoading = false;
  bool _isDetectingLocation = false;
  bool _isMapDragging = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
    _codeController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _nameController.dispose();
    _codeController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalController.dispose();
    _countryController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (_codeController.text.isEmpty || _nameController.text.length > 2) {
      final base = _nameController.text
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toUpperCase();
      if (base.length >= 3) {
        final newCode = "$base-01";
        if (_codeController.text != newCode) {
          _codeController.text = newCode;
        }
      }
    }
  }

  void _onCodeChanged() {
    if (_codeController.text.isNotEmpty) {
      setState(() => _isCheckingCode = true);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isCheckingCode = false;
            _isCodeUnique = true;
          });
        }
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isFetchingSuggestions = true);
      try {
        final response = await Dio().get(
          'https://nominatim.openstreetmap.org/search',
          queryParameters: {
            'q': query,
            'format': 'json',
            'addressdetails': 1,
            'limit': 5,
          },
          options: Options(headers: {'User-Agent': 'com.dailio.app'}),
        );
        if (response.statusCode == 200 && mounted) {
          setState(() {
            _suggestions = response.data;
            _isFetchingSuggestions = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isFetchingSuggestions = false);
      }
    });
  }

  void _onSuggestionSelected(dynamic item) {
    _searchFocus.unfocus();
    setState(() {
      _suggestions = [];
      _searchController.text = item['display_name'] ?? '';
    });

    final lat = double.tryParse(item['lat'].toString()) ?? 0;
    final lon = double.tryParse(item['lon'].toString()) ?? 0;
    if (lat != 0 && lon != 0) {
      final newLoc = LatLng(lat, lon);
      _mapController.move(newLoc, 15.0);
      setState(() {
        _currentLocation = newLoc;
        _latController.text = lat.toString();
        _lngController.text = lon.toString();
      });
      _reverseGeocode(newLoc);
    }
  }

  Future<void> _detectLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services.')));
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Location permissions are denied.')));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Location permissions are permanently denied. Please enable in app settings.')));
      await Geolocator.openAppSettings();
      return;
    }

    setState(() => _isDetectingLocation = true);
    try {
      final position = await Geolocator.getCurrentPosition();
      final newLoc = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLocation = newLoc;
        _latController.text = newLoc.latitude.toString();
        _lngController.text = newLoc.longitude.toString();
      });
      _mapController.move(newLoc, 15.0);
      await _reverseGeocode(newLoc);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error detecting location: $e')));
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  Future<void> _reverseGeocode(LatLng location) async {
    try {
      final response = await Dio().get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': location.latitude,
          'lon': location.longitude,
          'format': 'json',
          'addressdetails': 1,
        },
        options: Options(headers: {'User-Agent': 'com.dailio.app'}),
      );
      if (response.statusCode == 200 && mounted) {
        final address = response.data['address'] ?? {};

        String rawCity = address['city'] ??
            address['state_district'] ??
            address['town'] ??
            address['village'] ??
            address['county'] ??
            '';
        rawCity =
            rawCity.replaceAll(' Division', '').replaceAll(' division', '');

        // Much more robust street + area logic
        String road = address['road'] ??
            address['street'] ??
            address['footway'] ??
            address['path'] ??
            address['house_number'] ??
            address['building'] ??
            '';
        String area = address['suburb'] ??
            address['neighbourhood'] ??
            address['residential'] ??
            address['quarter'] ??
            address['village'] ??
            address['hamlet'] ??
            '';

        String street = [road, area].where((e) => e.isNotEmpty).join(', ');

        String postcode = address['postcode']?.toString() ?? '';
        String country = address['country']?.toString() ?? 'India';

        // Final fallback if nominatim misses structured address keys but returns display_name
        if (street.trim().isEmpty || street.trim() == ',') {
          final displayName = response.data['display_name']?.toString() ?? '';
          final parts = displayName
              .split(',')
              .map((e) => e.trim())
              .where((e) =>
                  e.isNotEmpty &&
                  e.toLowerCase() != rawCity.toLowerCase() &&
                  e.toLowerCase() !=
                      (address['state']?.toString() ?? '').toLowerCase() &&
                  e.toLowerCase() != postcode.toLowerCase() &&
                  e.toLowerCase() != country.toLowerCase())
              .toList();
          if (parts.isNotEmpty) {
            street = parts.take(2).join(', '); // take first 1 or 2 parts
          }
        }

        setState(() {
          _streetController.text = street;
          _cityController.text = rawCity;
          _stateController.text = address['state'] ?? '';
          _postalController.text = postcode;
          _countryController.text = country;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  void _onMapPositionChanged(MapCamera position, bool hasGesture) {
    if (hasGesture) {
      if (!_isMapDragging) {
        setState(() => _isMapDragging = true);
      }
      setState(() {
        _currentLocation = position.center;
        _latController.text = position.center.latitude.toString();
        _lngController.text = position.center.longitude.toString();
      });

      if (_mapDebounce?.isActive ?? false) _mapDebounce!.cancel();
      _mapDebounce = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _isMapDragging = false);
          _reverseGeocode(position.center);
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      final repository = context.read<OrganizationRepository>();
      final lat = double.tryParse(_latController.text);
      final lng = double.tryParse(_lngController.text);

      final result = await repository.createOrganization(
        widget.organizationInput,
        CreateBranchInput(
          name: _nameController.text,
          address: _streetController.text,
          city: _cityController.text,
          state: _stateController.text,
          country: _countryController.text,
          postalCode: _postalController.text,
          latitude: lat,
          longitude: lng,
        ),
      );

      if (mounted) {
        final prefs = context.read<PreferencesStorage>();
        await prefs.setActiveContext(
          organizationId: result['organization']['id'],
          branchId: result['location']['id'],
          organizationName: result['organization']['name'],
          branchName: result['location']['name'],
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Organization & Branch Created!')));
          context.go(AppRoutes.home);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFB45309)),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A))),
      ],
    );
  }

  Widget _fieldLabel(String label, {bool required = false}) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151))),
        if (required) ...[
          const SizedBox(width: 4),
          const Text('*Required',
              style: TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
        ],
      ],
    );
  }

  Widget _buildMarkerWidget({required bool isGreen, String? label}) {
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
                  color: (isGreen ? Colors.green : Colors.black)
                      .withValues(alpha: 0.3),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F2F5),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Create Branch',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Row(
              children: [
                const Text('STEP 2 OF 2',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB45309),
                        letterSpacing: 0.5)),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: const LinearProgressIndicator(
                      value: 1.0,
                      backgroundColor: Color(0xFFE5E7EB),
                      color: Color(0xFFB45309),
                      minHeight: 3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Final Touch',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('OPERATIONAL BRANCH SETUP',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 6),
                    const Text(
                      'Every operational record, member admission, and attendance punch is scoped to a branch.',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
                    ),
                    const SizedBox(height: 32),

                    // Branch Identification
                    _sectionHeader(
                        Icons.storefront_outlined, 'Branch Identification'),
                    const SizedBox(height: 14),

                    _fieldLabel('Branch Name', required: true),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                          hintText: 'Main Branch - [City]'),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),

                    _fieldLabel('Branch Code'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _codeController,
                      decoration: InputDecoration(
                        hintText: 'e.g. BLR-01',
                        suffixIcon: _isCheckingCode
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFB45309))),
                              )
                            : _codeController.text.isNotEmpty && _isCodeUnique
                                ? const Icon(Icons.check_circle,
                                    color: Color(0xFF22C55E), size: 18)
                                : null,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Geolocation & Attendance Perimeter
                    Row(
                      children: [
                        const Icon(Icons.satellite_alt_outlined,
                            size: 18, color: Color(0xFFB45309)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Location Intelligence',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A))),
                        ),
                        TextButton.icon(
                          onPressed:
                              _isDetectingLocation ? null : _detectLocation,
                          icon: _isDetectingLocation
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.my_location, size: 14),
                          label: Text(
                              _isDetectingLocation
                                  ? 'Detecting...'
                                  : 'Auto-Detect',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Search Location
                    TextFormField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search location...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _isFetchingSuggestions
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFB45309))),
                              )
                            : _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _suggestions = []);
                                    },
                                  )
                                : null,
                      ),
                    ),

                    if (_suggestions.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        margin: const EdgeInsets.only(top: 4, bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(8),
                          itemCount: _suggestions.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _suggestions[index];
                            return ListTile(
                              leading: const Icon(Icons.location_on_outlined,
                                  color: Colors.grey),
                              title: Text(
                                item['display_name'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                              onTap: () => _onSuggestionSelected(item),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Map View
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB))),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Stack(
                          children: [
                            FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _currentLocation,
                                initialZoom: 14.0,
                                onPositionChanged: _onMapPositionChanged,
                              ),
                              children: [
                                ColorFiltered(
                                  colorFilter:
                                      const ColorFilter.matrix(<double>[
                                    0.33,
                                    0.5,
                                    0.16,
                                    0,
                                    10,
                                    0.33,
                                    0.5,
                                    0.16,
                                    0,
                                    10,
                                    0.33,
                                    0.5,
                                    0.16,
                                    0,
                                    10,
                                    0,
                                    0,
                                    0,
                                    1,
                                    0,
                                  ]),
                                  child: TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.dailio.app',
                                  ),
                                ),
                              ],
                            ),
                            Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                transform: Matrix4.translationValues(
                                    0, _isMapDragging ? -15 : 0, 0),
                                child: _buildMarkerWidget(
                                    isGreen: false, label: "Branch Location"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Extracted Location Fields (Read-Only)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _streetController,
                            readOnly: true,
                            decoration: const InputDecoration(
                                labelText: 'Street / Area',
                                filled: true,
                                fillColor: Color(0xFFF9FAFB)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            readOnly: true,
                            decoration: const InputDecoration(
                                labelText: 'City',
                                filled: true,
                                fillColor: Color(0xFFF9FAFB)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stateController,
                            readOnly: true,
                            decoration: const InputDecoration(
                                labelText: 'State',
                                filled: true,
                                fillColor: Color(0xFFF9FAFB)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _postalController,
                            readOnly: true,
                            decoration: const InputDecoration(
                                labelText: 'Postal Code',
                                filled: true,
                                fillColor: Color(0xFFF9FAFB)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _submit,
                      child: const Text('Complete Setup & Launch Branch',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => context.pop(),
                          child: const Text('Previous Step',
                              style: TextStyle(color: Color(0xFF6B7280))),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
