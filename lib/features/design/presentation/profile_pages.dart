part of 'aco_design_shell.dart';

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.palette,
    required this.onOpen,
    required this.displayName,
    required this.accountId,
    required this.username,
    required this.avatarUrl,
    required this.hasAppUpdate,
    required this.onOpenAppUpdate,
    this.onBack,
  });
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final String displayName;
  final String accountId;
  final String username;
  final String avatarUrl;
  final bool hasAppUpdate;
  final Future<bool> Function() onOpenAppUpdate;
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
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AcoAvatar(size: 68, imageUrl: avatarUrl),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: palette.primaryText,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.background, width: 2),
                      ),
                      child: Icon(
                        CupertinoIcons.pencil,
                        size: 12,
                        color: palette.background,
                      ),
                    ),
                  ),
                ],
              ),
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
        child: Column(
          children: [
            GestureDetector(
              onTap: hasAppUpdate ? onOpenAppUpdate : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '当前版本 v${AppConfig.appVersion}',
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: AcoTypography.caption,
                    ),
                  ),
                  if (hasAppUpdate) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: _danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showConnectionDiagnostics(context, palette),
              child: Text(
                '连接诊断',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: AcoTypography.caption,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Future<void> _showConnectionDiagnostics(
    BuildContext context,
    AcoPalette palette,
  ) async {
    final config = const AppConfig();
    final diagnostics = await AccountApiClient.runConnectionDiagnostics();
    if (!context.mounted) return;
    final request = AccountApiClient.lastRequest ?? '暂无请求记录';
    final status = AccountApiClient.lastStatusCode?.toString() ?? '暂无';
    final duration = AccountApiClient.lastRequestDurationMilliseconds;
    final serverTiming = AccountApiClient.lastServerTiming;
    final response = AccountApiClient.lastResponseBody ?? '暂无返回内容';
    final error = AccountApiClient.lastError;
    final diagnosticText =
        'API：${config.apiBaseUrl}\n'
        '版本：${AppConfig.appVersion}\n'
        '请求：$request\n'
        '状态：$status\n'
        '耗时：${duration == null ? '暂无' : '${duration}ms'}\n'
        '${serverTiming == null ? '' : '服务端：$serverTiming\n'}'
        '返回：$response'
        '${error == null ? '' : '\n错误：$error'}\n\n'
        '链路探测：\n$diagnostics';
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('连接诊断'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SizedBox(
            height: 260,
            child: SingleChildScrollView(
              child: Text(
                diagnosticText,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: AcoTypography.caption,
                ),
                textAlign: TextAlign.left,
              ),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: diagnosticText));
            },
            child: const Text('复制'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

class _AvatarCropPage extends StatefulWidget {
  const _AvatarCropPage({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<_AvatarCropPage> {
  final CropController _controller = CropController();
  bool _cropping = false;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: _black,
    child: SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                CupertinoButton(
                  onPressed: _cropping ? null : () => Navigator.pop(context),
                  child: const Icon(
                    CupertinoIcons.back,
                    color: CupertinoColors.white,
                  ),
                ),
                const Expanded(
                  child: Text(
                    '裁剪头像',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                CupertinoButton(
                  onPressed: _cropping
                      ? null
                      : () {
                          setState(() => _cropping = true);
                          _controller.crop();
                        },
                  child: _cropping
                      ? const CupertinoActivityIndicator(
                          color: CupertinoColors.white,
                        )
                      : const Text('完成'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Crop(
              image: widget.imageBytes,
              controller: _controller,
              withCircleUi: true,
              interactive: true,
              fixCropRect: true,
              baseColor: _black,
              maskColor: _black.withValues(alpha: .72),
              onCropped: (result) {
                switch (result) {
                  case CropSuccess(:final croppedImage):
                    Navigator.pop(context, croppedImage);
                  case CropFailure():
                    if (mounted) setState(() => _cropping = false);
                }
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 10, 24, 24),
            child: Text(
              '拖动和缩放图片，圆形区域将作为头像保存',
              style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 14),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProfileQrPage extends StatelessWidget {
  const _ProfileQrPage({
    required this.palette,
    required this.displayName,
    required this.accountId,
    required this.username,
    required this.avatarUrl,
    required this.onBack,
  });

  final AcoPalette palette;
  final String displayName;
  final String accountId;
  final String username;
  final String avatarUrl;
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
            AcoAvatar(size: 70, imageUrl: avatarUrl),
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
    required this.initialAvatarUrl,
    this.onDisplayNameChanged,
    this.onUsernameChanged,
    this.onAvatarUrlChanged,
  });

  final AcoPalette palette;
  final String initialName;
  final String initialUsername;
  final String accountId;
  final String initialAvatarUrl;
  final ValueChanged<String>? onDisplayNameChanged;
  final ValueChanged<String>? onUsernameChanged;
  final ValueChanged<String>? onAvatarUrlChanged;

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
  bool _uploadingAvatar = false;
  late String _avatarUrl = widget.initialAvatarUrl;

  Future<void> _pickAvatar() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final imageBytes = await image.readAsBytes();
    if (!mounted) return;
    final croppedBytes = await Navigator.of(context).push<Uint8List>(
      CupertinoPageRoute(
        builder: (_) => _AvatarCropPage(imageBytes: imageBytes),
      ),
    );
    if (croppedBytes == null) return;
    setState(() => _uploadingAvatar = true);
    final client = AccountApiClient();
    try {
      final profile = await AccountSession(client).uploadAvatar(croppedBytes);
      if (!mounted) return;
      setState(() => _avatarUrl = profile.avatarUrl);
      widget.onAvatarUrlChanged?.call(profile.avatarUrl);
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '头像上传失败', error.localizedMessage);
    } catch (_) {
      if (mounted) _showNotice(context, '头像上传失败', '请检查网络后重试。');
    } finally {
      client.close();
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

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
              GestureDetector(
                onTap: _uploadingAvatar ? null : _pickAvatar,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AcoAvatar(size: 84, imageUrl: _avatarUrl),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: widget.palette.primaryText,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.palette.background,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          CupertinoIcons.pencil,
                          size: 13,
                          color: widget.palette.background,
                        ),
                      ),
                    ),
                    if (_uploadingAvatar) const CupertinoActivityIndicator(),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _uploadingAvatar ? '正在上传头像…' : '点击头像从相册选择',
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
