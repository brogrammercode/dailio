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
import '../../../core/storage/preferences_storage.dart';
import '../../../core/network/interceptors/logging_interceptor.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AddBranchPage extends StatefulWidget {
  const AddBranchPage({super.key});

  @override
  State<AddBranchPage> createState() => _AddBranchPageState();
}

class _AddBranchPageState extends State<AddBranchPage> {
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
      final prefs = context.read<PreferencesStorage>();
      final orgId = prefs.activeOrganizationId!;
      final lat = double.tryParse(_latController.text);
      final lng = double.tryParse(_lngController.text);

      await repository.createBranch(
        orgId,
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
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Branch created successfully!')));
        context.pop();
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
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24.r, 16.r, 24.r, 120.r),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildBasicInfo(),
                      SizedBox(height: 24.r),
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
        padding: EdgeInsets.fromLTRB(24.r, 16.r, 24.r, 32.r),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10.r,
              offset: Offset(0, (-4).r))
        ]),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade800,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16.r),
            minimumSize: const Size(double.infinity, 0),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r)),
          ),
          child: _isLoading
              ? SizedBox(
                  width: 24.r,
                  height: 24.r,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.r))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Create Branch',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(width: 8.r),
                    Icon(Iconsax.shop_add, size: 18.r),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.r, 16.r, 24.r, 8.r),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                Text('Add New Branch',
                    style:
                        TextStyle(fontSize: 20.r, fontWeight: FontWeight.bold)),
                SizedBox(height: 4.r),
                Text('Expand your organization to a new location.',
                    style: TextStyle(fontSize: 12.r, color: Colors.grey)),
              ],
            ),
          ),
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
