import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/utils/app_format.dart';
import '../../core/utils/share_helper.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../injection.dart';
import '../blocs/settings/settings_cubit.dart';
import 'lock_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _snack(BuildContext context, String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text, style: const TextStyle(color: Colors.white)),
      backgroundColor: error ? Colors.redAccent : positiveColor,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _togglePin(BuildContext context, SettingsState state) async {
    final cubit = context.read<SettingsCubit>();
    if (state.hasPin) {
      final pin = await Navigator.of(context).push<String>(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _PinSetupPage(verifyOnly: true),
      ));
      if (pin == null) return;
      if (await cubit.verifyPin(pin)) {
        await cubit.removePin();
        if (context.mounted) _snack(context, 'Đã tắt khóa ứng dụng');
      } else if (context.mounted) {
        _snack(context, 'Mã PIN không đúng', error: true);
      }
    } else {
      final pin = await Navigator.of(context).push<String>(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _PinSetupPage(),
      ));
      if (pin == null) return;
      await cubit.setPin(pin);
      if (context.mounted) _snack(context, 'Đã bật khóa ứng dụng');
    }
  }

  Future<void> _backup(BuildContext tileContext) async {
    try {
      final json = await sl<BackupRepository>().exportJson();
      if (!tileContext.mounted) return;
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await ShareHelper.shareFile(tileContext, 'chiapay_backup_$stamp.json', json, mimeType: 'application/json');
    } catch (e) {
      if (tileContext.mounted) _snack(tileContext, 'Sao lưu thất bại: $e', error: true);
    }
  }

  Future<void> _restore(BuildContext context) async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
    } catch (e) {
      if (context.mounted) _snack(context, 'Không mở được file: $e', error: true);
      return;
    }
    if (file == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Khôi phục dữ liệu?'),
        content: Text('Toàn bộ dữ liệu hiện tại sẽ được thay thế bằng nội dung của "${file!.name}". Thao tác này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Khôi phục', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final content = utf8.decode(await file.readAsBytes(), allowMalformed: false);
      await sl<BackupRepository>().importJson(content.startsWith('﻿') ? content.substring(1) : content);
      if (context.mounted) _snack(context, 'Đã khôi phục dữ liệu');
    } on FormatException catch (e) {
      if (context.mounted) _snack(context, e.message, error: true);
    } catch (e) {
      if (context.mounted) _snack(context, 'Khôi phục thất bại: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Cài đặt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => context.pop()),
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final cubit = context.read<SettingsCubit>();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              _SectionCard(
                title: 'Giao diện',
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(value: ThemeMode.system, label: Text('Hệ thống'), icon: Icon(Icons.brightness_auto_outlined)),
                          ButtonSegment(value: ThemeMode.light, label: Text('Sáng'), icon: Icon(Icons.light_mode_outlined)),
                          ButtonSegment(value: ThemeMode.dark, label: Text('Tối'), icon: Icon(Icons.dark_mode_outlined)),
                        ],
                        selected: {state.themeMode},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) => cubit.setThemeMode(s.first),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.attach_money_rounded),
                    title: const Text('Tiền tệ mặc định'),
                    subtitle: const Text('Áp dụng khi tạo nhóm mới'),
                    trailing: DropdownButton<String>(
                      value: state.defaultCurrency,
                      underline: const SizedBox.shrink(),
                      items: SettingsCubit.supportedCurrencies
                          .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold))))
                          .toList(),
                      onChanged: (c) {
                        if (c != null) cubit.setDefaultCurrency(c);
                      },
                    ),
                  ),
                ],
              ),
              _SectionCard(
                title: 'Bảo mật',
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.lock_outline_rounded),
                    title: const Text('Khóa ứng dụng bằng mã PIN'),
                    subtitle: const Text('Yêu cầu nhập PIN khi mở lại ứng dụng'),
                    value: state.hasPin,
                    onChanged: (_) => _togglePin(context, state),
                  ),
                ],
              ),
              _SectionCard(
                title: 'Dữ liệu',
                children: [
                  Builder(
                    builder: (tileContext) => ListTile(
                      leading: const Icon(Icons.backup_outlined),
                      title: const Text('Sao lưu dữ liệu'),
                      subtitle: const Text('Xuất toàn bộ nhóm, khoản chi ra file JSON'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _backup(tileContext),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_backup_restore_rounded),
                    title: const Text('Khôi phục dữ liệu'),
                    subtitle: const Text('Nhập từ file sao lưu ChiaPay'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _restore(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: const Text('Nhóm đã lưu trữ'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/archived'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'ChiaPay hoạt động offline – dữ liệu chỉ lưu trên thiết bị này.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
          child: Text(title.toUpperCase(),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: context.textSecondary)),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
          ),
          child: Material(type: MaterialType.transparency, child: Column(children: children)),
        ),
      ],
    );
  }
}

/// Đặt mã PIN mới (nhập 2 lần) hoặc nhập PIN hiện tại để xác minh. Trả về mã PIN qua Navigator.pop.
class _PinSetupPage extends StatefulWidget {
  final bool verifyOnly;

  const _PinSetupPage({this.verifyOnly = false});

  @override
  State<_PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<_PinSetupPage> {
  String? _first;
  bool _mismatch = false;

  void _onCompleted(String pin, PinPadController controller) {
    if (widget.verifyOnly) {
      Navigator.pop(context, pin);
      return;
    }
    if (_first == null) {
      setState(() => _first = pin);
      controller.clear();
    } else if (_first == pin) {
      Navigator.pop(context, pin);
    } else {
      setState(() {
        _first = null;
        _mismatch = true;
      });
      controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title;
    final String subtitle;
    if (widget.verifyOnly) {
      title = 'Nhập mã PIN hiện tại';
      subtitle = 'Để tắt khóa ứng dụng';
    } else if (_first == null) {
      title = 'Đặt mã PIN';
      subtitle = _mismatch ? 'Hai lần nhập không khớp, hãy nhập lại' : 'Nhập ${PinPad.pinLength} chữ số';
    } else {
      title = 'Nhập lại mã PIN';
      subtitle = 'Xác nhận mã PIN vừa nhập';
    }
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context))),
      body: SafeArea(
        child: PinPad(
          // Đổi key để xóa các chữ số đã nhập khi chuyển bước.
          key: ValueKey(_first == null),
          title: title,
          subtitle: subtitle,
          isError: _mismatch && _first == null,
          onCompleted: _onCompleted,
        ),
      ),
    );
  }
}
