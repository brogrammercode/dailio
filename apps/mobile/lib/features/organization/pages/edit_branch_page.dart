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
import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/shimmer_loader.dart';

class EditBranchPage extends StatefulWidget {
  final String branchId;
  const EditBranchPage({super.key, required this.branchId});

  @override
  State<EditBranchPage> createState() => _EditBranchPageState();
}

class _EditBranchPageState extends State<EditBranchPage> {
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
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDetectingLocation = false;
  bool _isMapDragging = false;

  // Cached original values for dirty tracking
  Map<String, dynamic>? _branch;
  String _originalName = '';
  String _originalAddress = '';
  String _originalCity = '';
  String _originalState = '';
  String _originalCountry = '';
  String _originalPostal = '';
  double _originalLat = 0;
  double _originalLng = 0;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFieldChanged);
    _streetController.addListener(_onFieldChanged);
    _cityController.addListener(_onFieldChanged);
    _stateController.addListener(_onFieldChanged);
    _countryController.addListener(_onFieldChanged);
    _postalController.addListener(_onFieldChanged);
    _latController.addListener(_onFieldChanged);
    _lngController.addListener(_onFieldChanged);
    _codeController.addListener(_onCodeChanged);

    _loadBranch();
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

  void _onFieldChanged() => setState(() {});

  bool get _isDirty {
    if (_branch == null) return false;
    final lat = double.tryParse(_latController.text) ?? 0;
    final lng = double.tryParse(_lngController.text) ?? 0;

    return _nameController.text != _originalName ||
        _streetController.text != _originalAddress ||
        _cityController.text != _originalCity ||
        _stateController.text != _originalState ||
        _countryController.text != _originalCountry ||
        _postalController.text != _originalPostal ||
        lat != _originalLat ||
        lng != _originalLng;
  }

  Future<void> _loadBranch() async {
    try {
      final repository = context.read<OrganizationRepository>();
      final prefs = context.read<PreferencesStorage>();
      final orgId = prefs.activeOrganizationId!;
      final branch = await repository.getBranchById(orgId, widget.branchId);

      if (mounted) {
        _initData(branch);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading branch: $e')));
      }
    }
  }

  void _initData(Map<String, dynamic> branch) {
    _branch = branch;
    _originalName = branch['name'] ?? '';
    _originalAddress = branch['address'] ?? '';
    _originalCity = branch['city'] ?? '';
    _originalState = branch['state'] ?? '';
    _originalPostal = branch['postal_code'] ?? '';
    _originalCountry = branch['country'] ?? 'India';

    final lat = double.tryParse(branch['latitude']?.toString() ?? '0') ?? 0;
    final lng = double.tryParse(branch['longitude']?.toString() ?? '0') ?? 0;
    _originalLat = lat;
    _originalLng = lng;

    _nameController.text = _originalName;
    _streetController.text = _originalAddress;
    _cityController.text = _originalCity;
    _stateController.text = _originalState;
    _postalController.text = _originalPostal;
    _countryController.text = _originalCountry;

    if (lat != 0 && lng != 0) {
      _currentLocation = LatLng(lat, lng);
      _latController.text = lat.toString();
      _lngController.text = lng.toString();
      try { _mapController.move(_currentLocation, 15.0); } catch (_) {}
    }
  }

  void _discardChanges() {
    if (_branch != null) {
      setState(() {
        _initData(_branch!);
      });
    }
  }

  void _onCodeChanged() {
    if (_codeController.text.isNotEmpty) {
      setState(() => _isCheckingCode = true);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted)
          setState(() {
            _isCheckingCode = false;
            _isCodeUnique = true;
          });
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
            content: Text('Location permissions are permanently denied.')));
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
        if (combinedStreet.isEmpty)
          combinedStreet = response.data['display_name']?.split(',')[0] ?? '';

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
    if (hasGesture && position.center != null) {
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

    setState(() => _isSaving = true);
    try {
      final repository = context.read<OrganizationRepository>();
      final prefs = context.read<PreferencesStorage>();
      final lat = double.tryParse(_latController.text);
      final lng = double.tryParse(_lngController.text);

      final result = await repository.updateBranch(
        prefs.activeOrganizationId!,
        widget.branchId,
        {
          if (_nameController.text != _originalName)
            'name': _nameController.text,
          if (_streetController.text != _originalAddress)
            'address': _streetController.text,
          if (_cityController.text != _originalCity)
            'city': _cityController.text,
          if (_stateController.text != _originalState)
            'state': _stateController.text,
          if (_countryController.text != _originalCountry)
            'country': _countryController.text,
          if (_postalController.text != _originalPostal)
            'postal_code': _postalController.text,
          if (lat != _originalLat) 'latitude': lat,
          if (lng != _originalLng) 'longitude': lng,
        },
      );

      if (mounted) {
        _initData(result);
        if (_nameController.text != _originalName &&
            prefs.activeBranchId == widget.branchId) {
          await prefs.setActiveContext(
            organizationId: prefs.activeOrganizationId!,
            branchId: widget.branchId,
            organizationName: prefs.activeOrganizationName,
            branchName: _nameController.text,
          );
        }
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Branch updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        child: _isLoading
            ? ShimmerLoader.profile()
            : Stack(
                children: [
                  ListView(
                    padding:
                        EdgeInsets.fromLTRB(24, 16, 24, _isDirty ? 140 : 40),
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 24),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildBasicInfo(),
                            const SizedBox(height: 24),
                            _buildLocationSection(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_isDirty)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                        decoration:
                            BoxDecoration(color: Colors.white, boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, -4))
                        ]),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSaving ? null : _discardChanges,
                                style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    side: BorderSide(
                                        color: Colors.grey.shade300)),
                                child: const Text('Discard',
                                    style: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade800,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12))),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text('Save Changes',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          SizedBox(width: 8),
                                          Icon(Iconsax.tick_circle, size: 18),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Iconsax.arrow_left, size: 18),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit Branch',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text('Update branch details and location.',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        if (_isDirty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200)),
            child: Text('Unsaved',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold)),
          ),
      ],
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

