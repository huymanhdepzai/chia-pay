import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/settings_repository.dart';

class SettingsState extends Equatable {
  final bool loaded;
  final ThemeMode themeMode;
  final String defaultCurrency;
  final bool hasPin;

  /// Ứng dụng đang bị khóa, cần nhập mã PIN để mở.
  final bool isLocked;

  const SettingsState({
    this.loaded = false,
    this.themeMode = ThemeMode.system,
    this.defaultCurrency = 'VND',
    this.hasPin = false,
    this.isLocked = false,
  });

  SettingsState copyWith({bool? loaded, ThemeMode? themeMode, String? defaultCurrency, bool? hasPin, bool? isLocked}) {
    return SettingsState(
      loaded: loaded ?? this.loaded,
      themeMode: themeMode ?? this.themeMode,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      hasPin: hasPin ?? this.hasPin,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  @override
  List<Object?> get props => [loaded, themeMode, defaultCurrency, hasPin, isLocked];
}

/// Cài đặt toàn ứng dụng (Phân hệ 6): giao diện sáng/tối, tiền tệ mặc định, khóa bằng mã PIN.
class SettingsCubit extends Cubit<SettingsState> {
  static const supportedCurrencies = ['VND', 'USD', 'EUR'];

  static const _themeKey = 'theme_mode';
  static const _currencyKey = 'default_currency';
  static const _pinKey = 'pin_hash';

  final SettingsRepository repository;

  SettingsCubit(this.repository) : super(const SettingsState());

  Future<void> load() async {
    final theme = await repository.get(_themeKey);
    final currency = await repository.get(_currencyKey);
    final pin = await repository.get(_pinKey);
    emit(state.copyWith(
      loaded: true,
      themeMode: ThemeMode.values.firstWhere((m) => m.name == theme, orElse: () => ThemeMode.system),
      defaultCurrency: currency ?? 'VND',
      hasPin: pin != null,
      isLocked: pin != null,
    ));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await repository.set(_themeKey, mode.name);
    emit(state.copyWith(themeMode: mode));
  }

  Future<void> setDefaultCurrency(String currency) async {
    await repository.set(_currencyKey, currency);
    emit(state.copyWith(defaultCurrency: currency));
  }

  Future<void> setPin(String pin) async {
    await repository.set(_pinKey, _hash(pin));
    emit(state.copyWith(hasPin: true));
  }

  Future<void> removePin() async {
    await repository.remove(_pinKey);
    emit(state.copyWith(hasPin: false, isLocked: false));
  }

  /// Mở khóa nếu mã PIN đúng.
  Future<bool> unlock(String pin) async {
    final stored = await repository.get(_pinKey);
    if (stored == null || stored == _hash(pin)) {
      emit(state.copyWith(isLocked: false));
      return true;
    }
    return false;
  }

  Future<bool> verifyPin(String pin) async => await repository.get(_pinKey) == _hash(pin);

  /// Khóa lại khi ứng dụng chạy nền.
  void lock() {
    if (state.hasPin) emit(state.copyWith(isLocked: true));
  }

  String _hash(String pin) => sha256.convert(utf8.encode('chiapay:$pin')).toString();
}
