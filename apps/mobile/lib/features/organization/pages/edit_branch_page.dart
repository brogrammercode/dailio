import 'package:iconsax/iconsax.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../controllers/organization_repository.dart';
import '../../context_selection/controllers/branch_repository.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/network/interceptors/logging_interceptor.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_picker_field.dart';
import '../../../core/widgets/dailio_qr_sheet.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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

  String _timezone = 'Asia/Kolkata';

  // Cached original values for dirty tracking
  Map<String, dynamic>? _branch;
  String _originalName = '';
  String _originalAddress = '';
  String _originalCity = '';
  String _originalState = '';
  String _originalCountry = '';
  String _originalPostal = '';
  String _originalTimezone = 'Asia/Kolkata';
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
        _timezone != _originalTimezone ||
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
    _originalTimezone = branch['timezone'] ?? 'Asia/Kolkata';

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
    _timezone = _originalTimezone;

    if (lat != 0 && lng != 0) {
      _currentLocation = LatLng(lat, lng);
      _latController.text = lat.toString();
      _lngController.text = lng.toString();
      try {
        _mapController.move(_currentLocation, 15.0);
      } catch (_) {}
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
          if (_timezone != _originalTimezone) 'timezone': _timezone,
          if (lat != _originalLat) 'latitude': lat,
          if (lng != _originalLng) 'longitude': lng,
        },
      );

      if (mounted) {
        _initData(result);
        if ((_nameController.text != _originalName ||
                _timezone != _originalTimezone) &&
            prefs.activeBranchId == widget.branchId) {
          await prefs.setActiveContext(
            organizationId: prefs.activeOrganizationId!,
            branchId: widget.branchId,
            organizationName: prefs.activeOrganizationName,
            branchName: _nameController.text,
            branchTimezone: _timezone,
          );
        }
        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Branch updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
      appBar: DailioSimpleAppBar(
        onBack: () => context.pop(),
        menuItems: const [
          DailioMenuItem(
            value: 'refresh',
            icon: Iconsax.refresh,
            label: 'Reload branch',
          ),
        ],
        onMenuSelected: (_) => _loadBranch(),
      ),
      body: SafeArea(
        child: _isLoading
            ? ShimmerLoader.settingsForm()
            : Stack(
                children: [
                  ListView(
                    padding: EdgeInsets.fromLTRB(
                        16.r, 16.r, 16.r, _isDirty ? 140.r : 40.r),
                    children: [
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildBasicInfo(),
                            SizedBox(height: 24.r),
                            _buildLocationSection(),
                            SizedBox(height: 24.r),
                            _buildQRSection(),
                            SizedBox(height: 24.r),
                            _buildSetupWizardSection(),
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
                        padding: EdgeInsets.fromLTRB(24.r, 16.r, 24.r, 32.r),
                        decoration:
                            BoxDecoration(color: Colors.white, boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10.r,
                              offset: Offset(0, (-4).r))
                        ]),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSaving ? null : _discardChanges,
                                style: OutlinedButton.styleFrom(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 16.r),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12.r)),
                                    side: BorderSide(
                                        color: Colors.grey.shade300)),
                                child: const Text('Discard',
                                    style: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            SizedBox(width: 16.r),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade800,
                                    foregroundColor: Colors.white,
                                    padding:
                                        EdgeInsets.symmetric(vertical: 16.r),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12.r))),
                                child: _isSaving
                                    ? SizedBox(
                                        width: 24.r,
                                        height: 24.r,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.r))
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text('Save Changes',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          SizedBox(width: 8.r),
                                          Icon(Iconsax.tick_circle, size: 18.r),
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

  // Kept for the legacy form layout contract; the page now uses the shared bar.
  // ignore: unused_element
  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: 40.r,
            height: 40.r,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8.r)),
            child: Icon(Iconsax.arrow_left, size: 18.r),
          ),
        ),
        SizedBox(width: 16.r),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit Branch',
                  style:
                      TextStyle(fontSize: 20.r, fontWeight: FontWeight.bold)),
              Text('Update branch details and location.',
                  style: TextStyle(fontSize: 11.r, color: Colors.grey)),
            ],
          ),
        ),
        if (_isDirty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 4.r),
            decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.orange.shade200)),
            child: Text('Unsaved',
                style: TextStyle(
                    fontSize: 10.r,
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
        SizedBox(height: 12.r),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Timezone',
                style: TextStyle(
                    fontSize: 12.r,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            SizedBox(height: 6.r),
            DailioPickerField<String>(
              initialValue: _timezone,
              items: const ['Asia/Kolkata', 'UTC', 'America/New_York']
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, style: TextStyle(fontSize: 14.r))))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _timezone = val);
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16.r, vertical: 14.r),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
              ),
            ),
          ],
        ),
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

  Widget _buildQRSection() {
    if (_branch == null) return const SizedBox();

    return _buildSection(
      title: 'Branch Invite QR',
      icon: Iconsax.scan_barcode,
      children: [
        Text(
          'Permanent invite QR for branch discovery, fast join, and gate attendance.',
          style: TextStyle(fontSize: 12.r, color: Colors.grey),
        ),
        SizedBox(height: 24.r),
        Center(
          child: FilledButton.icon(
            onPressed: _showJoinQr,
            icon: const Icon(Iconsax.scan_barcode),
            label: const Text('Show Join QR'),
          ),
        ),
      ],
    );
  }

  Future<void> _showJoinQr() async {
    try {
      final invite = await context
          .read<BranchRepository>()
          .createBranchInvite(widget.branchId);
      if (!mounted) return;
      final payload = invite['qr_payload']?.toString();
      if (payload == null || payload.isEmpty) {
        throw Exception('Invite QR was not created');
      }
      await showDailioQrSheet(
        context,
        title: 'Branch QR',
        payload: payload,
        subtitle:
            "${invite['organization']?['name'] ?? 'Organization'} • ${_branch?['name'] ?? 'Branch'}",
        detail: 'Keep this QR printed at the entrance for recurring use.',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not create invite: $error')));
      }
    }
  }

  // Legacy implementation retained temporarily for reference.
  // ignore: unused_element
  Future<void> _showLegacyJoinQr() async {
    try {
      final invite = await context
          .read<BranchRepository>()
          .createBranchInvite(widget.branchId);
      if (!mounted) return;
      final payload = invite['qr_payload']?.toString();
      if (payload == null || payload.isEmpty) {
        throw Exception('Invite QR was not created');
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Join QR • ${_branch?['name'] ?? 'Branch'}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 220.r,
              height: 220.r,
              child: QrImageView(data: payload, size: 220.r),
            ),
            SizedBox(height: 12.r),
            Text(
                '${invite['organization']?['name'] ?? 'Organization'} • ${_branch?['name'] ?? 'Branch'}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6.r),
            const Text('Permanent QR • no expiry or revocation',
                style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8.r),
            Text('Generating another QR never invalidates this one.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12.r)),
          ]),
          actions: [
            TextButton(
                onPressed: () async {
                  await context
                      .read<BranchRepository>()
                      .revokeInvite(widget.branchId, invite['id'].toString());
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: const Text('Revoke')),
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Done'))
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not create invite: $error')));
      }
    }
  }

  Widget _buildSetupWizardSection() {
    return _buildSection(
      title: 'Setup Checklist',
      icon: Iconsax.magic_star,
      children: [
        Text(
          'Follow these steps to get your facility fully running securely.',
          style: TextStyle(fontSize: 12.r, color: Colors.grey),
        ),
        SizedBox(height: 24.r),
        _buildWizardStep(
          icon: Iconsax.clock,
          title: '1. Create a Shift',
          description:
              'Head to Settings > Shift Management to define working hours for your staff.',
          isComplete: false,
        ),
        SizedBox(height: 16.r),
        _buildWizardStep(
          icon: Iconsax.receipt,
          title: '2. Setup Memberships',
          description:
              'Go to Settings > Subscription Plans to define your fee structures.',
          isComplete: false,
        ),
      ],
    );
  }

  Widget _buildWizardStep(
      {required IconData icon,
      required String title,
      required String description,
      required bool isComplete}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: isComplete ? Colors.green.shade50 : Colors.orange.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(icon,
              color: isComplete ? Colors.green : Colors.orange, size: 24.r),
        ),
        SizedBox(width: 16.r),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style:
                      TextStyle(fontSize: 14.r, fontWeight: FontWeight.bold)),
              SizedBox(height: 4.r),
              Text(description,
                  style: TextStyle(fontSize: 12.r, color: Colors.grey)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildSection(
      {required String title,
      required IconData icon,
      Widget? action,
      required List<Widget> children}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 13.r, fontWeight: FontWeight.w700))),
              if (action != null) action,
            ],
          ),
          SizedBox(height: 12.r),
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
            style: TextStyle(fontSize: 12.r, fontWeight: FontWeight.w500)),
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
            fillColor: Colors.white,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16.r, vertical: 12.r),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide:
                    BorderSide(color: Colors.orange.shade400, width: 1.5.r)),
          ),
          style: TextStyle(fontSize: 13.r),
          validator: validator,
        ),
      ],
    );
  }
}
