import 'package:aco_chat/services/biometric_authentication.dart';
import 'package:aco_chat/services/wallet_security.dart';
import 'package:aco_chat/shared/widgets/aco_page_header.dart';
import 'package:flutter/cupertino.dart';

Future<String?> showWalletUnlockDialog({
  required BuildContext context,
  required WalletSecretStore store,
  required String walletAddress,
  Key? passwordFieldKey,
}) async {
  final security = WalletSecurity();
  final hasDeviceProtection = await security.hasDeviceProtection(
    store: store,
    walletAddress: walletAddress,
  );
  final hasPasswordProtection = await security.hasPasswordProtection(
    store: store,
    walletAddress: walletAddress,
  );
  if (!context.mounted) return null;

  return showCupertinoModalPopup<String>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0x99000000),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: _WalletUnlockDialog(
            security: security,
            store: store,
            walletAddress: walletAddress,
            hasDeviceProtection: hasDeviceProtection,
            hasPasswordProtection: hasPasswordProtection,
            passwordFieldKey: passwordFieldKey,
          ),
        ),
      ),
    ),
  );
}

class _WalletUnlockDialog extends StatefulWidget {
  const _WalletUnlockDialog({
    required this.security,
    required this.store,
    required this.walletAddress,
    required this.hasDeviceProtection,
    required this.hasPasswordProtection,
    this.passwordFieldKey,
  });

  final WalletSecurity security;
  final WalletSecretStore store;
  final String walletAddress;
  final bool hasDeviceProtection;
  final bool hasPasswordProtection;
  final Key? passwordFieldKey;

  @override
  State<_WalletUnlockDialog> createState() => _WalletUnlockDialogState();
}

class _WalletUnlockDialogState extends State<_WalletUnlockDialog> {
  late bool _usingPassword = !widget.hasDeviceProtection;
  final _passwordController = TextEditingController();
  String? _error;
  bool _busy = false;
  var _authAttempt = 0;

  String get _confirmLabel {
    if (_usingPassword) return '确认';
    return _error == null ? '验证' : '重新验证';
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _unlockWithDevice() async {
    if (_busy || !mounted) return;
    final attempt = ++_authAttempt;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await BiometricAuthentication.authenticate(
        reason: '使用指纹或面容验证钱包操作',
      )) {
        throw const WalletSecurityException('设备验证未通过，可重试或输入钱包密码。');
      }
      if (attempt != _authAttempt) return;
      final mnemonic = await widget.security.unlockMnemonicWithDeviceProtection(
        store: widget.store,
        walletAddress: widget.walletAddress,
      );
      if (mounted) Navigator.of(context).pop(mnemonic);
    } on WalletSecurityException catch (error) {
      if (mounted && attempt == _authAttempt) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted && attempt == _authAttempt) {
        setState(() => _error = '设备解锁失败，可重试或输入钱包密码。');
      }
    } finally {
      if (mounted && attempt == _authAttempt) setState(() => _busy = false);
    }
  }

  Future<void> _unlockWithPassword() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final mnemonic = await widget.security.unlockMnemonic(
        store: widget.store,
        walletAddress: widget.walletAddress,
        password: _passwordController.text,
      );
      if (mounted) Navigator.of(context).pop(mnemonic);
    } on WalletSecurityException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '验证失败，请稍后重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmUnlock() {
    if (_usingPassword) return _unlockWithPassword();
    return _unlockWithDevice();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AcoPalette(
      CupertinoTheme.brightnessOf(context) == Brightness.dark,
    );

    return CupertinoPopupSurface(
      isSurfacePainted: false,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
        decoration: BoxDecoration(
          color: palette.surfaceRaised,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withValues(alpha: 0.24),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '安全验证',
                        style: TextStyle(
                          color: palette.mutedText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.hasDeviceProtection &&
                        widget.hasPasswordProtection)
                      CupertinoButton(
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        onPressed: () => setState(() {
                          if (_busy) {
                            ++_authAttempt;
                            _busy = false;
                          }
                          _usingPassword = !_usingPassword;
                          _error = null;
                        }),
                        child: Text(
                          _usingPassword ? '使用设备验证' : '使用密码',
                          style: TextStyle(
                            color: palette.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: palette.accent.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(
                  _usingPassword
                      ? CupertinoIcons.lock_fill
                      : CupertinoIcons.lock_shield_fill,
                  color: palette.accent,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _usingPassword ? '输入钱包密码' : '验证钱包操作',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _usingPassword
                    ? '验证通过后继续签名'
                    : _busy
                    ? '正在等待设备验证…'
                    : '使用指纹或面容继续',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              if (_usingPassword) ...[
                const SizedBox(height: 20),
                CupertinoTextField(
                  key: widget.passwordFieldKey,
                  controller: _passwordController,
                  autofocus: !widget.hasDeviceProtection,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _unlockWithPassword(),
                  onChanged: (_) => setState(() => _error = null),
                  placeholder: '钱包密码',
                  prefix: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 8),
                    child: Icon(
                      CupertinoIcons.lock,
                      color: palette.mutedText,
                      size: 17,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 15,
                  ),
                  style: TextStyle(color: palette.primaryText, fontSize: 16),
                  placeholderStyle: TextStyle(color: palette.mutedText),
                  decoration: BoxDecoration(
                    color: palette.inputSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.border),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CupertinoColors.systemRed,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(15),
                  color: palette.accent,
                  disabledColor: palette.accent.withValues(alpha: 0.42),
                  onPressed:
                      _busy ||
                          (_usingPassword &&
                              _passwordController.text.length < 8)
                      ? null
                      : _confirmUnlock,
                  child: _busy
                      ? const CupertinoActivityIndicator(
                          color: Color(0xFF111111),
                        )
                      : Text(
                          _confirmLabel,
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    '取消',
                    style: TextStyle(color: palette.mutedText, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
