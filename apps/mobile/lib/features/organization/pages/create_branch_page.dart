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
import '../../../core/network/interceptors/logging_interceptor.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/dailio_onboarding_widgets.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
        final response =
            await (Dio()..interceptors.add(LoggingInterceptor())).get(
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
      final response =
          await (Dio()..interceptors.add(LoggingInterceptor())).get(
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
          branchTimezone: result['location']['timezone']?.toString(),
          roleSystemKey: 'OWNER',
          permissions: const ['ALL'],
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
      offset: Offset(0, (-16).r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 6.r),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6.r,
                        offset: Offset(0, 3))
                  ]),
              child: Text(label,
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 12.r,
                      fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            SizedBox(height: 6.r),
          ],
          Container(
            width: 20.r,
            height: 20.r,
            decoration: BoxDecoration(
                color: isGreen ? Colors.green : Colors.black,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.r),
                boxShadow: [
                  BoxShadow(
                      color: (isGreen ? Colors.green : Colors.black)
                          .withValues(alpha: 0.3),
                      blurRadius: 8.r,
                      offset: Offset(0, 4.r))
                ]),
          ),
          Container(
              width: 2.5.r,
              height: 12.r,
              color: isGreen ? Colors.green : Colors.black),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(onBack: () => context.pop()),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16.r, 14.r, 16.r, 96.r),
            children: [
              Text('Create first branch',
                  style:
                      TextStyle(fontSize: 22.r, fontWeight: FontWeight.w800)),
              SizedBox(height: 5.r),
              Text('Step 2 of 2 · Add the location people will use.',
                  style: TextStyle(fontSize: 13.r, color: Color(0xFF858585))),
              SizedBox(height: 20.r),
              LinearProgressIndicator(
                  value: 1,
                  minHeight: 3.r,
                  backgroundColor: Color(0xFFF0E6DC),
                  color: Color(0xFFCC5A00)),
              SizedBox(height: 22.r),
              const DailioOnboardingSectionLabel('BRANCH DETAILS'),
              TextFormField(
                controller: _nameController,
                decoration: dailioOnboardingInput('Branch name', Iconsax.shop),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Branch name is required'
                    : null,
              ),
              SizedBox(height: 10.r),
              TextFormField(
                controller: _codeController,
                decoration: dailioOnboardingInput(
                  'Branch code',
                  Iconsax.code,
                  suffixIcon: _isCheckingCode
                      ? Padding(
                          padding: EdgeInsets.all(13.r),
                          child: SizedBox(
                              width: 16.r,
                              height: 16.r,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.r)),
                        )
                      : _codeController.text.isNotEmpty && _isCodeUnique
                          ? Icon(Iconsax.tick_circle5,
                              color: Color(0xFF2E9D59), size: 18.r)
                          : null,
                ),
              ),
              SizedBox(height: 20.r),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const DailioOnboardingSectionLabel('LOCATION'),
                  TextButton.icon(
                    onPressed: _isDetectingLocation ? null : _detectLocation,
                    icon: Icon(Iconsax.gps, size: 15.r),
                    label: Text(
                        _isDetectingLocation ? 'Detecting…' : 'Use current'),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFCC5A00),
                        padding: EdgeInsets.zero),
                  ),
                ],
              ),
              TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: _onSearchChanged,
                decoration: dailioOnboardingInput(
                    'Search an address', Iconsax.search_normal_1),
              ),
              if (_suggestions.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(top: 6.r),
                  constraints: BoxConstraints(maxHeight: 180.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: const Color(0xFFE4E4E4)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => Divider(height: 1.r),
                    itemBuilder: (_, index) => ListTile(
                      dense: true,
                      leading: Icon(Iconsax.location, size: 17.r),
                      title: Text(_suggestions[index]['display_name'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.r)),
                      onTap: () => _onSuggestionSelected(_suggestions[index]),
                    ),
                  ),
                ),
              SizedBox(height: 12.r),
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: SizedBox(
                  height: 190.r,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _currentLocation,
                          initialZoom: 14,
                          onPositionChanged: _onMapPositionChanged,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.dailio.app',
                          ),
                        ],
                      ),
                      Center(child: _buildMarkerWidget(isGreen: false)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12.r),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _streetController,
                      readOnly: true,
                      decoration: dailioOnboardingInput(
                          'Street / area', Iconsax.location),
                    ),
                  ),
                  SizedBox(width: 10.r),
                  Expanded(
                    child: TextField(
                      controller: _cityController,
                      readOnly: true,
                      decoration:
                          dailioOnboardingInput('City', Iconsax.building_4),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.r),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _stateController,
                      readOnly: true,
                      decoration: dailioOnboardingInput('State', Iconsax.map_1),
                    ),
                  ),
                  SizedBox(width: 10.r),
                  Expanded(
                    child: TextField(
                      controller: _postalController,
                      readOnly: true,
                      decoration:
                          dailioOnboardingInput('Postal code', Iconsax.code),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(16.r, 8.r, 16.r, 12.r),
        child: DailioOnboardingButton(
          label: 'Create organization',
          icon: Iconsax.tick_circle,
          loading: _isLoading,
          onPressed: _submit,
        ),
      ),
    );
  }

  // Retained for compatibility with older branch setup variants.
  // ignore: unused_element
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.r, 16.r, 24.r, 8.r),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8.r)),
            child: IconButton(
                icon: Icon(Iconsax.arrow_left, size: 20.r),
                onPressed: () => context.pop(),
                constraints: BoxConstraints(minWidth: 40.r, minHeight: 40.r),
                padding: EdgeInsets.zero),
          ),
          SizedBox(width: 16.r),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create Branch',
                    style:
                        TextStyle(fontSize: 20.r, fontWeight: FontWeight.bold)),
                SizedBox(height: 4.r),
                Text('Set up your first physical location.',
                    style: TextStyle(fontSize: 12.r, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Retained for compatibility with older branch setup variants.
  // ignore: unused_element
  Widget _buildProgress() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.r, 8.r, 24.r, 16.r),
      child: Row(
        children: [
          Text('STEP 2 OF 2',
              style: TextStyle(
                  fontSize: 10.r,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange)),
          SizedBox(width: 12.r),
          Expanded(
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                      value: 1.0,
                      backgroundColor: Colors.grey.shade200,
                      color: Colors.orange,
                      minHeight: 4.r))),
          SizedBox(width: 12.r),
          Text('Branch Setup',
              style: TextStyle(fontSize: 10.r, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  // Retained for compatibility with older branch setup variants.
  // ignore: unused_element
  Widget _buildBasicInfo() {
    return _buildSection(
      title: 'Branch Identification',
      icon: Iconsax.shop,
      children: [
        _buildTextField('Branch Name*', 'Main Branch - [City]',
            controller: _nameController,
            validator: (v) => v!.isEmpty ? 'Required' : null),
        SizedBox(height: 12.r),
        _buildTextField('Branch Code', 'e.g. BLR-01',
            controller: _codeController,
            suffixIcon: _isCheckingCode
                ? Padding(
                    padding: EdgeInsets.all(12.r),
                    child: SizedBox(
                        width: 16.r,
                        height: 16.r,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.r, color: Colors.orange)))
                : (_codeController.text.isNotEmpty && _isCodeUnique
                    ? Icon(Iconsax.tick_circle, color: Colors.green, size: 18.r)
                    : null)),
      ],
    );
  }

  // Retained for compatibility with older branch setup variants.
  // ignore: unused_element
  Widget _buildLocationSection() {
    return _buildSection(
      title: 'Location Intelligence',
      icon: Iconsax.global_search,
      action: TextButton.icon(
        onPressed: _isDetectingLocation ? null : _detectLocation,
        icon: _isDetectingLocation
            ? SizedBox(
                width: 14.r,
                height: 14.r,
                child: CircularProgressIndicator(strokeWidth: 2.r))
            : Icon(Icons.my_location, size: 14.r),
        label: Text(_isDetectingLocation ? 'Detecting...' : 'Auto-Detect',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.r)),
        style: TextButton.styleFrom(
            padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
      ),
      children: [
        _buildTextField('Search Location', 'Search...',
            controller: _searchController,
            focusNode: _searchFocus,
            onChanged: _onSearchChanged,
            prefixIcon:
                Icon(Iconsax.search_normal_1, size: 18.r, color: Colors.grey),
            suffixIcon: _isFetchingSuggestions
                ? Padding(
                    padding: EdgeInsets.all(12.r),
                    child: SizedBox(
                        width: 16.r,
                        height: 16.r,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.r, color: Colors.orange)))
                : (_searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18.r),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _suggestions = []);
                        })
                    : null)),
        if (_suggestions.isNotEmpty)
          Container(
            constraints: BoxConstraints(maxHeight: 200.r),
            margin: EdgeInsets.only(top: 4.r, bottom: 12.r),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10.r,
                      offset: Offset(0, 4.r))
                ]),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.all(8.r),
              itemCount: _suggestions.length,
              separatorBuilder: (c, i) => Divider(height: 1.r),
              itemBuilder: (c, i) => ListTile(
                leading: Icon(Iconsax.location, color: Colors.grey, size: 18.r),
                title: Text(_suggestions[i]['display_name'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.r)),
                onTap: () => _onSuggestionSelected(_suggestions[i]),
              ),
            ),
          ),
        SizedBox(height: 16.r),
        Container(
          height: 200.r,
          decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey.shade200)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11.r),
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
        SizedBox(height: 16.r),
        Row(
          children: [
            Expanded(
                child: _buildTextField('Street / Area', '',
                    controller: _streetController, readOnly: true)),
            SizedBox(width: 12.r),
            Expanded(
                child: _buildTextField('City', '',
                    controller: _cityController, readOnly: true)),
          ],
        ),
        SizedBox(height: 12.r),
        Row(
          children: [
            Expanded(
                child: _buildTextField('State', '',
                    controller: _stateController, readOnly: true)),
            SizedBox(width: 12.r),
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
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8.r)),
                  child: Icon(icon, color: Colors.orange, size: 18.r)),
              SizedBox(width: 12.r),
              Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 14.r, fontWeight: FontWeight.bold))),
              if (action != null) action,
            ],
          ),
          SizedBox(height: 16.r),
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
            style: TextStyle(
                fontSize: 12.r,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        SizedBox(height: 6.r),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13.r, color: Colors.grey),
            filled: true,
            fillColor: readOnly ? Colors.grey.shade50 : Colors.white,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16.r, vertical: 12.r),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey.shade200)),
          ),
          style: TextStyle(fontSize: 13.r),
          validator: validator,
        ),
      ],
    );
  }
}
