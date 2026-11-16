import 'package:flutter/material.dart';

class AdminConfig {
  final String brandHandle;
  final bool forceWatermark;
  final bool proFeaturesEnabled;
  final bool aiEnabled;
  final String adminPin;
  final int totalExports;

  const AdminConfig({
    this.brandHandle = '@CineFlowStudio',
    this.forceWatermark = false,
    this.proFeaturesEnabled = true,
    this.aiEnabled = true,
    this.adminPin = '1234',
    this.totalExports = 0,
  });

  AdminConfig copyWith({
    String? brandHandle,
    bool? forceWatermark,
    bool? proFeaturesEnabled,
    bool? aiEnabled,
    String? adminPin,
    int? totalExports,
  }) {
    return AdminConfig(
      brandHandle: brandHandle ?? this.brandHandle,
      forceWatermark: forceWatermark ?? this.forceWatermark,
      proFeaturesEnabled: proFeaturesEnabled ?? this.proFeaturesEnabled,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      adminPin: adminPin ?? this.adminPin,
      totalExports: totalExports ?? this.totalExports,
    );
  }
}

class AdminPanelSheet extends StatefulWidget {
  final AdminConfig config;
  final ValueChanged<AdminConfig> onChanged;
  final VoidCallback onClearAllEdits;

  const AdminPanelSheet({
    super.key,
    required this.config,
    required this.onChanged,
    required this.onClearAllEdits,
  });

  @override
  State<AdminPanelSheet> createState() => _AdminPanelSheetState();
}

class _AdminPanelSheetState extends State<AdminPanelSheet> {
  final TextEditingController _pinController = TextEditingController();
  late final TextEditingController _brandController;
  bool _unlocked = false;
  String? _pinError;

  @override
  void initState() {
    super.initState();
    _brandController = TextEditingController(text: widget.config.brandHandle);
  }

  @override
  void dispose() {
    _pinController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  void _verifyPin() {
    if (_pinController.text.trim() == widget.config.adminPin) {
      setState(() {
        _unlocked = true;
        _pinError = null;
      });
    } else {
      setState(() => _pinError = 'Galat PIN! Default PIN: 1234');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: !_unlocked ? _buildLockScreen() : _buildAdminDashboard(),
    );
  }

  Widget _buildLockScreen() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.admin_panel_settings, color: Color(0xFF38BDF8), size: 36),
        const SizedBox(height: 8),
        const Text(
          'Admin Panel Login',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Settings control karne ke liye Admin PIN daalein (Default: 1234)',
          style: TextStyle(color: Colors.white60, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          style: const TextStyle(color: Colors.white, letterSpacing: 4),
          decoration: InputDecoration(
            hintText: 'Enter PIN',
            hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 0),
            errorText: _pinError,
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _verifyPin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: const Color(0xFF090D16),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Unlock Admin Panel', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminDashboard() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.admin_panel_settings, color: Color(0xFF10B981), size: 22),
              const SizedBox(width: 8),
              const Text(
                'App Admin Control',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Exports: ${widget.config.totalExports}',
                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _brandController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            onChanged: (v) => widget.onChanged(widget.config.copyWith(brandHandle: v)),
            decoration: InputDecoration(
              labelText: 'Default Channel / Brand Handle',
              labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pro Features Enabled', style: TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: const Text('Color Grading, Effects & 4K Export', style: TextStyle(color: Colors.white54, fontSize: 11)),
            value: widget.config.proFeaturesEnabled,
            activeColor: const Color(0xFF10B981),
            onChanged: (v) => widget.onChanged(widget.config.copyWith(proFeaturesEnabled: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('AI Studio Enabled', style: TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: const Text('Auto-Enhance, Viral Hooks & AI Captions', style: TextStyle(color: Colors.white54, fontSize: 11)),
            value: widget.config.aiEnabled,
            activeColor: const Color(0xFFA855F7),
            onChanged: (v) => widget.onChanged(widget.config.copyWith(aiEnabled: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Force Brand Watermark', style: TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: const Text('Har exported video par watermark lagaye', style: TextStyle(color: Colors.white54, fontSize: 11)),
            value: widget.config.forceWatermark,
            activeColor: const Color(0xFFF59E0B),
            onChanged: (v) => widget.onChanged(widget.config.copyWith(forceWatermark: v)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    widget.onClearAllEdits();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.refresh, color: Colors.redAccent, size: 16),
                  label: const Text('Reset Editor', style: TextStyle(color: Colors.redAccent)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save & Close'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
