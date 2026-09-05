part of 'aco_design_shell.dart';

class _CreateLivePage extends StatefulWidget {
  const _CreateLivePage({
    required this.palette,
    this.live,
    this.walletLoginFuture,
  });
  final AcoPalette palette;
  final LiveSession? live;
  final Future<AccountProfile?>? walletLoginFuture;

  @override
  State<_CreateLivePage> createState() => _CreateLivePageState();
}

class _CreateLivePageState extends State<_CreateLivePage> {
  // Covers are resized and JPEG-compressed by image_picker before upload. Keep
  // a smaller client-side limit so mobile users do not waste bandwidth on
  // unnecessarily large originals (the API still enforces its 5 MB limit).
  static const _maxCoverSizeBytes = 3 * 1024 * 1024;

  final _titleController = TextEditingController();
  DateTime? _scheduledAt;
  Uint8List? _coverBytes;
  String? _joinPassword;
  bool _submitting = false;
  bool _coverChanged = false;

  bool get _isEditing => widget.live != null;

  @override
  void initState() {
    super.initState();
    final live = widget.live;
    if (live != null) {
      _titleController.text = live.title;
      _scheduledAt = live.scheduledAt;
      _joinPassword = live.access == 'password' ? '' : null;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  bool get _canConfirm =>
      _titleController.text.trim().isNotEmpty &&
      (_coverBytes != null || widget.live?.coverUrl.isNotEmpty == true) &&
      (!_isEditing || _scheduledAt != null);

  Future<void> _confirm() async {
    if (!_canConfirm || _submitting) return;
    _dismissKeyboard();
    final title = _titleController.text.trim();
    final apiClient = AccountApiClient();
    LiveSession? createdLive;
    setState(() => _submitting = true);
    try {
      // Startup account restoration is asynchronous; wait for its token.
      await widget.walletLoginFuture;
      final session = AccountSession(apiClient);
      if (widget.live case final live?) {
        await session.updateLive(
          liveId: live.id,
          title: title,
          coverUrl: live.coverUrl,
          coverBytes: _coverChanged ? _coverBytes : null,
          access: _joinPassword == null ? 'open' : 'password',
          joinPassword: _joinPassword?.isEmpty == true ? null : _joinPassword,
          scheduledAt: _scheduledAt,
        );
      } else if (_coverBytes case final coverBytes?) {
        createdLive = await session.createLive(
          title: title,
          coverBytes: coverBytes,
          access: _joinPassword == null ? 'open' : 'password',
          joinPassword: _joinPassword,
          scheduledAt: _scheduledAt,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(createdLive ?? true);
    } on AccountApiException catch (error) {
      if (mounted) {
        _showNotice(context, _isEditing ? '保存失败' : '创建失败', error.message);
      }
    } catch (_) {
      if (mounted) {
        _showNotice(context, _isEditing ? '保存失败' : '创建失败', '请检查网络后重试。');
      }
    } finally {
      apiClient.close();
      if (mounted) setState(() => _submitting = false);
    }
  }

  String get _scheduleLabel {
    final scheduledAt = _scheduledAt;
    if (scheduledAt == null) return '立即开播';
    final hour = scheduledAt.hour.toString().padLeft(2, '0');
    final minute = scheduledAt.minute.toString().padLeft(2, '0');
    return '${scheduledAt.month}月${scheduledAt.day}日 $hour:$minute';
  }

  Future<void> _selectSchedule() async {
    _dismissKeyboard();
    final now = DateTime.now();
    var selected = _scheduledAt ?? now.add(const Duration(hours: 1));
    final palette = widget.palette;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: palette.dark ? Brightness.dark : Brightness.light,
          primaryColor: palette.accent,
        ),
        child: Container(
          height: 332,
          color: palette.surface,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        onPressed: _isEditing
                            ? null
                            : () {
                                setState(() => _scheduledAt = null);
                                Navigator.of(sheetContext).pop();
                              },
                        child: Text(
                          '立即开播',
                          style: TextStyle(
                            color: _isEditing
                                ? palette.mutedText
                                : palette.accent,
                            fontSize: AcoTypography.bodySmall,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '选择开播时间',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.primaryText,
                            fontSize: AcoTypography.body,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        onPressed: () {
                          setState(() => _scheduledAt = selected);
                          Navigator.of(sheetContext).pop();
                        },
                        child: Text(
                          '确定',
                          style: TextStyle(
                            color: palette.accent,
                            fontSize: AcoTypography.body,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: palette.border),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.dateAndTime,
                    minimumDate: now,
                    initialDateTime: selected,
                    onDateTimeChanged: (value) => selected = value,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectCover() async {
    _dismissKeyboard();
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 720,
      imageQuality: 72,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;
    if (bytes.lengthInBytes > _maxCoverSizeBytes) {
      _showNotice(context, '图片过大', '请选择小于 3 MB 的会议封面。');
      return;
    }

    setState(() {
      _coverBytes = bytes;
      _coverChanged = true;
    });
  }

  String get _joinAccessLabel => _joinPassword == null ? '任何人直接加入' : '需要密码才能加入';

  Future<void> _selectJoinAccess() async {
    _dismissKeyboard();
    final palette = widget.palette;
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetContext) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: palette.dark ? Brightness.dark : Brightness.light,
          primaryColor: palette.accent,
        ),
        child: CupertinoActionSheet(
          title: const Text(
            '设置加入权限',
            style: TextStyle(fontSize: AcoTypography.bodyEmphasis),
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(sheetContext).pop('open'),
              child: const Text(
                '任何人直接加入',
                style: TextStyle(fontSize: AcoTypography.bodyEmphasis),
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(sheetContext).pop('password'),
              child: const Text(
                '需要密码才能加入',
                style: TextStyle(fontSize: AcoTypography.bodyEmphasis),
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text(
              '取消',
              style: TextStyle(fontSize: AcoTypography.bodyEmphasis),
            ),
          ),
        ),
      ),
    );

    if (choice == 'open') {
      setState(() => _joinPassword = null);
    } else if (choice == 'password') {
      await _setJoinPassword();
    }
  }

  Future<void> _setJoinPassword() async {
    _dismissKeyboard();
    final palette = widget.palette;
    var password = _joinPassword ?? '';
    final confirmedPassword = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: palette.dark ? Brightness.dark : Brightness.light,
          primaryColor: palette.accent,
        ),
        child: StatefulBuilder(
          builder: (context, setDialogState) => CupertinoAlertDialog(
            title: const Text('设置加入密码'),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: CupertinoTextField(
                autofocus: true,
                obscureText: true,
                maxLength: 20,
                onChanged: (value) => setDialogState(() => password = value),
                onSubmitted: (value) {
                  if (value.trim().length >= 4) {
                    Navigator.of(dialogContext).pop(value.trim());
                  }
                },
                placeholder: '输入至少 4 位密码',
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: password.trim().length >= 4
                    ? () => Navigator.of(dialogContext).pop(password.trim())
                    : null,
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmedPassword != null) {
      setState(() => _joinPassword = confirmedPassword);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final hasCover =
        _coverBytes != null || widget.live?.coverUrl.isNotEmpty == true;
    final canConfirm = _canConfirm && !_submitting;
    return _DetailScaffold(
      palette: palette,
      title: _isEditing ? '修改会议' : '创建会议',
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              children: [
                Container(
                  height: 156,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  decoration: BoxDecoration(
                    color: _createLiveCardColor(palette),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          controller: _titleController,
                          maxLength: 60,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _dismissKeyboard(),
                          onTapOutside: (_) => _dismissKeyboard(),
                          placeholder: '输入会议主题',
                          placeholderStyle: TextStyle(
                            color: palette.mutedText,
                            fontSize: AcoTypography.body,
                          ),
                          style: TextStyle(
                            color: palette.primaryText,
                            fontSize: AcoTypography.body,
                          ),
                          decoration: null,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_titleController.text.length}/60',
                          style: TextStyle(
                            color: palette.mutedText,
                            fontSize: AcoTypography.caption,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _CreateLiveRow(
                  palette: palette,
                  title: '预约时间',
                  value: _scheduleLabel,
                  highlighted: true,
                  onTap: _selectSchedule,
                ),
                const SizedBox(height: 12),
                _CreateLiveRow(
                  palette: palette,
                  title: '谁能加入？',
                  subtitle: _joinAccessLabel,
                  onTap: _selectJoinAccess,
                ),
                const SizedBox(height: 12),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _selectCover,
                  child: Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: _createLiveCardColor(palette),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        if (_coverBytes case final bytes?)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              bytes,
                              width: 54,
                              height: 52,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.medium,
                            ),
                          )
                        else if (widget.live?.coverUrl case final coverUrl?)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              _liveCoverUrl(coverUrl),
                              width: 54,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _LiveCoverThumbnailFallback(palette: palette),
                            ),
                          )
                        else
                          Container(
                            width: 54,
                            height: 52,
                            decoration: BoxDecoration(
                              color: palette.surfaceRaised,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              CupertinoIcons.photo,
                              color: palette.mutedText,
                              size: 26,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    '*',
                                    style: TextStyle(
                                      color: _danger,
                                      fontSize: AcoTypography.body,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    hasCover ? '更换封面' : '上传封面',
                                    style: TextStyle(
                                      color: palette.primaryText,
                                      fontSize: AcoTypography.body,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (hasCover)
                                Text(
                                  '已选择会议封面',
                                  style: TextStyle(
                                    color: palette.mutedText,
                                    fontSize: AcoTypography.caption,
                                  ),
                                )
                              else
                                Text(
                                  '建议使用横向图片',
                                  style: TextStyle(
                                    color: palette.mutedText,
                                    fontSize: AcoTypography.caption,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          CupertinoIcons.chevron_right,
                          color: palette.mutedText,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: CupertinoButton(
                  key: const Key('confirm-create-live-button'),
                  padding: EdgeInsets.zero,
                  onPressed: canConfirm ? _confirm : null,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: canConfirm
                          ? palette.accent
                          : _createLiveCardColor(palette),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _submitting
                        ? const CupertinoActivityIndicator(color: _black)
                        : Text(
                            _isEditing ? '保存' : '确认',
                            style: TextStyle(
                              color: canConfirm ? _black : palette.mutedText,
                              fontSize: AcoTypography.body,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _createLiveCardColor(AcoPalette palette) =>
    palette.dark ? const Color(0xFF161616) : palette.surface;

class _CreateLiveRow extends StatelessWidget {
  const _CreateLiveRow({
    required this.palette,
    required this.title,
    required this.onTap,
    this.value,
    this.subtitle,
    this.highlighted = false,
  });

  final AcoPalette palette;
  final String title;
  final String? value;
  final String? subtitle;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: onTap,
    child: Container(
      height: subtitle == null ? 52 : 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _createLiveCardColor(palette),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: AcoTypography.body,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: AcoTypography.caption,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (value != null) ...[
            Text(
              value!,
              style: TextStyle(
                color: highlighted ? palette.accent : palette.mutedText,
                fontSize: AcoTypography.body,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(
            CupertinoIcons.chevron_right,
            color: palette.mutedText,
            size: 20,
          ),
        ],
      ),
    ),
  );
}
