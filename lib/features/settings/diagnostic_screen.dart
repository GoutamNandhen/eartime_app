import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/tracking_platform.dart';
import '../widgets/liquid_glass_surface.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  Map<String, dynamic>? _diagnosticData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await TrackingPlatform.getAudioDiagnostics();
      setState(() {
        _diagnosticData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Diagnostics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDiagnostics,
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Error: $_error', style: const TextStyle(color: AppColors.error)),
        ),
      );
    }

    if (_diagnosticData == null) {
      return const Center(child: Text('No data available'));
    }

    final data = _diagnosticData!;
    
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionTitle('System', theme),
        _buildDataRow('Android Version', data['androidVersion']),
        _buildDataRow('API Level', data['apiLevel']),
        const SizedBox(height: 24),
        
        _buildSectionTitle('Permissions', theme),
        _buildDataRow('BLUETOOTH_CONNECT', data['hasBluetoothConnect']),
        _buildDataRow('BLUETOOTH_SCAN', data['hasBluetoothScan']),
        _buildDataRow('FG_SERVICE_CONNECTED_DEVICE', data['hasFgServiceConnectedDevice']),
        const SizedBox(height: 24),

        _buildSectionTitle('Bluetooth Adapter', theme),
        _buildDataRow('State', data['bluetoothAdapterState']),
        const SizedBox(height: 24),

        _buildSectionTitle('Bluetooth A2DP (Source B)', theme),
        _buildDataRow('Connected Count', data['a2dpConnectedCount']),
        _buildListRow('Connected Names', data['a2dpConnectedNames']),
        const SizedBox(height: 24),

        _buildSectionTitle('AudioManager (Source A)', theme),
        _buildDataRow('Output Devices Count', data['audioManagerOutputCount']),
        const SizedBox(height: 12),
        ..._buildAudioManagerDevices(data['audioManagerDevices'], theme),
      ],
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: AppColors.primary,
          letterSpacing: 1.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value?.toString() ?? 'null',
              style: const TextStyle(color: AppColors.editorialWhite, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListRow(String label, dynamic listData) {
    if (listData is! List || listData.isEmpty) {
      return _buildDataRow(label, 'empty');
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 4),
          ...listData.map((item) => Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Text(
              '- ${item.toString()}',
              style: const TextStyle(color: AppColors.editorialWhite, fontWeight: FontWeight.w500),
            ),
          )),
        ],
      ),
    );
  }

  List<Widget> _buildAudioManagerDevices(dynamic devicesData, ThemeData theme) {
    if (devicesData is! List || devicesData.isEmpty) {
      return [const Text('No devices found', style: TextStyle(color: AppColors.onSurfaceVariant))];
    }

    return devicesData.map<Widget>((device) {
      if (device is! Map) return const SizedBox.shrink();
      
      return LiquidGlassSurface(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDataRow('Name', device['productName']),
            _buildDataRow('Type', device['type']),
            _buildDataRow('Address', device['address']),
            _buildDataRow('ID', device['id']),
            _buildDataRow('Is Sink', device['isSink']),
            _buildDataRow('Is Source', device['isSource']),
          ],
        ),
      );
    }).toList();
  }
}
