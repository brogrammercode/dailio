import 'package:iconsax/iconsax.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';

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
  LatLng _currentLocation = const LatLng(20.5937, 78.9629);

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
            'limit': 5
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services.')));
      }
      await Geolocator.openLocationSettings();
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Location permissions are denied.')));
        }
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location permissions are permanently denied.')));
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error detecting location: $e')));
      }
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
          'addressdetails': 1
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
        String road = address['road'] ??
            address['street'] ??
            address['footway'] ??
            address['path'] ??
            address['house_number'] ??
            address['building'] ??
            '';
        String neighbourhood = address['neighbourhood'] ??
            address['suburb'] ??
            address['residential'] ??
            '';
        String combinedStreet =
            [road, neighbourhood].where((e) => e.isNotEmpty).join(', ');
        if (combinedStreet.isEmpty) {
          combinedStreet = response.data['display_name']?.split(',')[0] ?? '';
        }

        setState(() {
          _streetController.text = combinedStreet;
          _cityController.text = rawCity;
          _stateController.text = address['state'] ?? '';
          _postalController.text = address['postcode'] ?? '';
          _countryController.text = address['country'] ?? 'India';
        });
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
  }

  void _onMapPositionChanged(MapCamera position, bool hasGesture) {
    if (hasGesture) {
      setState(() => _isMapDragging = true);
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
                        offset: Offset(0, 3))
                  ]),
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
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
                      offset: const Offset(0, 4))
                ]),
          ),
          Container(
              width: 2.5,
              height: 12,
              color: isGreen ? Colors.green : Colors.black),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildProgress(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildBasicInfo(),
                      const SizedBox(height: 24),
                      _buildLocationSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4))
        ]),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size(double.infinity, 0),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Complete Registration',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Icon(Iconsax.tick_circle, size: 18),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8)),
            child: IconButton(
                icon: const Icon(Iconsax.arrow_left, size: 20),
                onPressed: () => context.pop(),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create Branch',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Set up your first physical location.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        children: [
          const Text('STEP 2 OF 2',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange)),
          const SizedBox(width: 12),
          Expanded(
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                      value: 1.0,
                      backgroundColor: Colors.grey.shade200,
                      color: Colors.orange,
                      minHeight: 4))),
          const SizedBox(width: 12),
          Text('Branch Setup',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildBasicInfo() {
    return _buildSection(
      title: 'Branch Identification',
      icon: Iconsax.shop,
      children: [
        _buildTextField('Branch Name*', 'Main Branch - [City]',
            controller: _nameController,
            validator: (v) => v!.isEmpty ? 'Required' : null),
        const SizedBox(height: 12),
        _buildTextField('Branch Code', 'e.g. BLR-01',
            controller: _codeController,
            suffixIcon: _isCheckingCode
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.orange)))
                : (_codeController.text.isNotEmpty && _isCodeUnique
                    ? const Icon(Iconsax.tick_circle,
                        color: Colors.green, size: 18)
                    : null)),
      ],
    );
  }

  Widget _buildLocationSection() {
    return _buildSection(
      title: 'Location Intelligence',
      icon: Iconsax.global_search,
      action: TextButton.icon(
        onPressed: _isDetectingLocation ? null : _detectLocation,
        icon: _isDetectingLocation
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.my_location, size: 14),
        label: Text(_isDetectingLocation ? 'Detecting...' : 'Auto-Detect',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        style: TextButton.styleFrom(
            padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
      ),
      children: [
        _buildTextField('Search Location', 'Search...',
            controller: _searchController,
            focusNode: _searchFocus,
            onChanged: _onSearchChanged,
            prefixIcon: const Icon(Iconsax.search_normal_1,
                size: 18, color: Colors.grey),
            suffixIcon: _isFetchingSuggestions
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.orange)))
                : (_searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _suggestions = []);
                        })
                    : null)),
        if (_suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 4, bottom: 12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              itemCount: _suggestions.length,
              separatorBuilder: (c, i) => const Divider(height: 1),
              itemBuilder: (c, i) => ListTile(
                leading:
                    const Icon(Iconsax.location, color: Colors.grey, size: 18),
                title: Text(_suggestions[i]['display_name'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
                onTap: () => _onSuggestionSelected(_suggestions[i]),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                      initialCenter: _currentLocation,
                      initialZoom: 14.0,
                      onPositionChanged: _onMapPositionChanged),
                  children: [
                    ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
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
                        0
                      ]),
                      child: TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.dailio.app'),
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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildTextField('Street / Area', '',
                    controller: _streetController, readOnly: true)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildTextField('City', '',
                    controller: _cityController, readOnly: true)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildTextField('State', '',
                    controller: _stateController, readOnly: true)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildTextField('Postal Code', '',
                    controller: _postalController, readOnly: true)),
          ],
        ),
      ],
    );
  }

  Widget _buildSection(
      {required String title,
      required IconData icon,
      Widget? action,
      required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: Colors.orange, size: 18)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold))),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String hint,
      {TextEditingController? controller,
      FormFieldValidator<String>? validator,
      ValueChanged<String>? onChanged,
      Widget? prefixIcon,
      Widget? suffixIcon,
      bool readOnly = false,
      FocusNode? focusNode}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
            filled: true,
            fillColor: readOnly ? Colors.grey.shade50 : Colors.white,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
          ),
          style: const TextStyle(fontSize: 13),
          validator: validator,
        ),
      ],
    );
  }
}
