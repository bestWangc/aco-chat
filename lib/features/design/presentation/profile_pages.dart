part of 'aco_design_shell.dart';

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.palette,
    required this.onOpen,
    required this.displayName,
    required this.accountId,
    required this.username,
    this.onBack,
  });
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final String displayName;
  final String accountId;
  final String username;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
    children: [
      AcoPageHeader(
        palette: palette,
        onBack: onBack,
        backButtonOffset: const Offset(-16, 0),
      ),
      const SizedBox(height: 18),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: '编辑个人资料',
            child: GestureDetector(
              onTap: () => onOpen(AcoScreen.profileEdit),
              child: const AcoAvatar(size: 68),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: AcoTypography.titleLarge,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  username.startsWith('@') ? username : '@$username',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: AcoTypography.bodySmall,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'UID:${displayAccountId(accountId)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.mutedText, fontSize: 10),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -6),
            child: _ProfileHeaderButton(
              iconAsset: 'assets/icons/profile_scan.png',
              palette: palette,
              label: '扫描二维码',
              onPressed: () => onOpen(AcoScreen.scan),
            ),
          ),
          const SizedBox(width: 2),
          Transform.translate(
            offset: const Offset(-12, -6),
            child: _ProfileHeaderButton(
              iconAsset: 'assets/icons/profile_qr_code.png',
              palette: palette,
              label: '个人二维码',
              filled: true,
            ),
          ),
        ],
      ),
      const SizedBox(height: 42),
      _ProfileSection(
        palette: palette,
        title: '设置',
        actions: [
          _ProfileAction(
            palette: palette,
            iconAsset: 'assets/icons/profile/theme.svg',
            label: '主题模式',
            onPressed: () => onOpen(AcoScreen.profileTheme),
          ),
          _ProfileAction(
            palette: palette,
            iconAsset: 'assets/icons/profile/language.svg',
            label: '语言',
            onPressed: () => onOpen(AcoScreen.profileLanguage),
          ),
        ],
      ),
      const SizedBox(height: 28),
      Center(
        child: Text(
          '当前版本 v${AppConfig.appVersion}',
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.caption,
          ),
        ),
      ),
    ],
  );
}

class _ProfileQrPage extends StatelessWidget {
  const _ProfileQrPage({
    required this.palette,
    required this.displayName,
    required this.accountId,
    required this.username,
    required this.onBack,
  });

  final AcoPalette palette;
  final String displayName;
  final String accountId;
  final String username;
  final VoidCallback onBack;

  String get _handle => username.startsWith('@') ? username : '@$username';

  String get _qrData =>
      'aco://profile/${Uri.encodeComponent(username.replaceFirst('@', ''))}?uid=${Uri.encodeComponent(accountId)}';

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AcoPageHeader(
          palette: palette,
          title: '我的二维码',
          onBack: onBack,
          backButtonOffset: const Offset(-20, 0),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const AcoAvatar(size: 70),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: AcoTypography.title,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: AcoTypography.body,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'UID:${displayAccountId(accountId)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: AcoTypography.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Spacer(),
        Center(
          child: Container(
            width: 286,
            height: 286,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _black.withValues(alpha: palette.dark ? .32 : .08),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: QrImageView(
              data: _qrData,
              version: QrVersions.auto,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              backgroundColor: _white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: _black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: _black,
              ),
              semanticsLabel: '个人二维码：$_handle',
            ),
          ),
        ),
        const Spacer(),
        Text(
          '扫一扫上面的二维码图案，加我为朋友。',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.body,
          ),
        ),
      ],
    ),
  );
}

class _ProfileLoadingPage extends StatelessWidget {
  const _ProfileLoadingPage({required this.palette});

  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AcoPageHeader(palette: palette),
      Expanded(
        child: Center(
          child: Icon(
            CupertinoIcons.person_crop_circle,
            color: palette.mutedText,
            size: 44,
          ),
        ),
      ),
    ],
  );
}

class _ProfileEditPage extends StatefulWidget {
  const _ProfileEditPage({
    required this.palette,
    required this.initialName,
    required this.initialUsername,
    required this.accountId,
    this.onDisplayNameChanged,
    this.onUsernameChanged,
  });

  final AcoPalette palette;
  final String initialName;
  final String initialUsername;
  final String accountId;
  final ValueChanged<String>? onDisplayNameChanged;
  final ValueChanged<String>? onUsernameChanged;

  @override
  State<_ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<_ProfileEditPage> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _usernameController = TextEditingController(
    text: widget.initialUsername,
  );
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    if (name.isEmpty || username.isEmpty) return;
    setState(() => _saving = true);
    final client = AccountApiClient();
    try {
      final profile = await AccountSession(
        client,
      ).updateProfile(username: username, nickname: name);
      if (!mounted) return;
      widget.onDisplayNameChanged?.call(profile.nickname);
      widget.onUsernameChanged?.call(profile.username);
      Navigator.of(context).pop();
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '保存失败', error.localizedMessage);
    } catch (_) {
      if (mounted) _showNotice(context, '保存失败', '请检查网络后重试。');
    } finally {
      client.close();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: widget.palette,
    title: '编辑资料',
    titleFollowsBack: true,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      children: [
        Center(
          child: Column(
            children: [
              const AcoAvatar(size: 84),
              const SizedBox(height: 10),
              Text(
                '头像暂不支持修改',
                style: TextStyle(
                  color: widget.palette.mutedText,
                  fontSize: AcoTypography.caption,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Text(
          '基本资料',
          style: TextStyle(
            color: widget.palette.mutedText,
            fontSize: AcoTypography.bodySmall,
          ),
        ),
        const SizedBox(height: 12),
        AcoSurface(
          palette: widget.palette,
          radius: 20,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '昵称',
                style: TextStyle(
                  color: widget.palette.primaryText,
                  fontSize: AcoTypography.bodySmall,
                ),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                key: const Key('profile-name-input'),
                controller: _nameController,
                maxLength: 20,
                textInputAction: TextInputAction.next,
                onTapOutside: (_) => _dismissKeyboard(),
                cursorColor: _lime,
                style: TextStyle(
                  color: widget.palette.primaryText,
                  fontSize: AcoTypography.body,
                ),
                decoration: BoxDecoration(
                  color: widget.palette.surfaceRaised,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '用户名',
                style: TextStyle(
                  color: widget.palette.primaryText,
                  fontSize: AcoTypography.bodySmall,
                ),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                key: const Key('profile-username-input'),
                controller: _usernameController,
                maxLength: 20,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _dismissKeyboard(),
                onTapOutside: (_) => _dismissKeyboard(),
                cursorColor: _lime,
                style: TextStyle(
                  color: widget.palette.primaryText,
                  fontSize: AcoTypography.body,
                ),
                decoration: BoxDecoration(
                  color: widget.palette.surfaceRaised,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'UID',
                style: TextStyle(
                  color: widget.palette.mutedText,
                  fontSize: AcoTypography.caption,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayAccountId(widget.accountId),
                style: TextStyle(
                  color: widget.palette.primaryText,
                  fontSize: AcoTypography.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AcoLimeButton(
          label: _saving ? '保存中...' : '保存修改',
          onPressed: _saving ? () {} : _save,
        ),
      ],
    ),
  );
}
