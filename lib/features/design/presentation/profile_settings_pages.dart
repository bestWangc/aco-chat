part of 'aco_design_shell.dart';

class _ProfileHeaderButton extends StatelessWidget {
  const _ProfileHeaderButton({
    required this.palette,
    required this.label,
    this.icon,
    this.iconAsset,
    this.onPressed,
    this.filled = false,
  }) : assert(icon != null || iconAsset != null);

  final IconData? icon;
  final String? iconAsset;
  final AcoPalette palette;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    const buttonSize = 44.0;
    const assetIconSize = 20.0;
    final visualSize = filled ? 40.0 : buttonSize;
    final child = iconAsset == null
        ? Icon(icon, color: palette.primaryText, size: filled ? 24 : 28)
        : Center(
            child: SizedBox(
              width: assetIconSize,
              height: assetIconSize,
              child: Image.asset(iconAsset!, filterQuality: FilterQuality.high),
            ),
          );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: SizedBox(
        width: buttonSize,
        height: buttonSize,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          child: Center(
            child: SizedBox(
              width: visualSize,
              height: visualSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: filled ? const Color(0xFF1C1C1C) : null,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.expand(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _ProfileOverviewSection extends StatelessWidget {
  const _ProfileOverviewSection({required this.palette});

  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => AcoSurface(
    palette: palette,
    backgroundColor: palette.dark ? const Color(0xFF1D1D1D) : null,
    minHeight: 194,
    radius: 24,
    padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '个人主页',
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.title,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 26),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _ProfileMetric(
              palette: palette,
              iconAsset: 'assets/icons/profile/like.svg',
              value: '3.2k',
              label: '我的点赞',
            ),
            _ProfileMetric(
              palette: palette,
              iconAsset: 'assets/icons/profile/followers.svg',
              value: '128',
              label: '粉丝',
            ),
            _ProfileMetric(
              palette: palette,
              iconAsset: 'assets/icons/profile/received-likes.svg',
              value: '15m',
              label: '获赞',
            ),
            _ProfileMetric(
              palette: palette,
              iconAsset: 'assets/icons/profile/subscriptions.svg',
              value: '78',
              label: '我的订阅',
            ),
          ],
        ),
      ],
    ),
  );
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.palette,
    required this.iconAsset,
    required this.value,
    required this.label,
  });

  final AcoPalette palette;
  final String iconAsset;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 58,
    child: Column(
      children: [
        SvgPicture.asset(iconAsset, width: 30, height: 30, fit: BoxFit.contain),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.bodyEmphasis,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.visible,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.caption,
          ),
        ),
      ],
    ),
  );
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.palette,
    required this.title,
    required this.actions,
  });

  final AcoPalette palette;
  final String title;
  final List<_ProfileAction> actions;

  @override
  Widget build(BuildContext context) => AcoSurface(
    palette: palette,
    backgroundColor: palette.dark ? const Color(0xFF1D1D1D) : null,
    minHeight: 130,
    radius: 24,
    padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.body,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 26),
        Row(
          mainAxisAlignment: actions.length <= 2
              ? MainAxisAlignment.start
              : MainAxisAlignment.spaceBetween,
          children: [
            for (final action in actions) ...[
              action,
              if (actions.length == 2 && action != actions.last)
                const SizedBox(width: 64),
            ],
          ],
        ),
      ],
    ),
  );
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.palette,
    required this.iconAsset,
    required this.label,
    required this.onPressed,
  });

  final AcoPalette palette;
  final String iconAsset;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: onPressed,
    child: SizedBox(
      width: 68,
      child: Column(
        children: [
          SvgPicture.asset(
            iconAsset,
            width: 24,
            height: 24,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 12),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.caption,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ThemeSettingsPage extends StatelessWidget {
  const _ThemeSettingsPage({
    required this.palette,
    required this.dark,
    required this.onThemeToggle,
  });

  final AcoPalette palette;
  final bool dark;
  final VoidCallback onThemeToggle;

  @override
  Widget build(BuildContext context) => _SettingsScaffold(
    palette: palette,
    title: '主题模式',
    sectionTitle: '外观偏好',
    child: Column(
      children: [
        _PreferenceOption(
          icon: CupertinoIcons.moon,
          title: '深色模式',
          subtitle: '适合低光环境',
          selected: dark,
          palette: palette,
          onPressed: dark ? null : onThemeToggle,
        ),
        Container(height: 1, color: palette.border),
        _PreferenceOption(
          icon: CupertinoIcons.sun_max,
          title: '浅色模式',
          subtitle: '清晰明亮的界面',
          selected: !dark,
          palette: palette,
          onPressed: null,
        ),
      ],
    ),
  );
}

class _LanguageSettingsPage extends StatefulWidget {
  const _LanguageSettingsPage({
    required this.palette,
    required this.initialLanguage,
    this.onLanguageChanged,
  });

  final AcoPalette palette;
  final String initialLanguage;
  final ValueChanged<String>? onLanguageChanged;

  @override
  State<_LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<_LanguageSettingsPage> {
  late String _selectedLanguage = widget.initialLanguage;

  void _selectLanguage(String language) {
    setState(() => _selectedLanguage = language);
    widget.onLanguageChanged?.call(language);
  }

  @override
  Widget build(BuildContext context) => _SettingsScaffold(
    palette: widget.palette,
    title: '语言',
    sectionTitle: '显示语言',
    child: Column(
      children: [
        for (final language in const [
          ('简体中文', 'Chinese (Simplified)'),
          ('English', 'English (US)'),
        ]) ...[
          _PreferenceOption(
            icon: CupertinoIcons.globe,
            title: language.$1,
            subtitle: language.$2,
            selected: _selectedLanguage == language.$1,
            enabled: language.$1 != 'English',
            palette: widget.palette,
            onPressed:
                language.$1 == 'English' || _selectedLanguage == language.$1
                ? null
                : () => _selectLanguage(language.$1),
          ),
          if (language.$1 != 'English')
            Container(height: 1, color: widget.palette.border),
        ],
      ],
    ),
  );
}

class _SettingsScaffold extends StatelessWidget {
  const _SettingsScaffold({
    required this.palette,
    required this.title,
    required this.sectionTitle,
    required this.child,
  });

  final AcoPalette palette;
  final String title;
  final String sectionTitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: palette,
    title: title,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      children: [
        Text(
          sectionTitle,
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.bodySmall,
          ),
        ),
        const SizedBox(height: 12),
        AcoSurface(
          palette: palette,
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: child,
        ),
      ],
    ),
  );
}

class _PreferenceOption extends StatelessWidget {
  const _PreferenceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.palette,
    required this.onPressed,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final AcoPalette palette;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final primaryColor = enabled
        ? palette.primaryText
        : palette.mutedText.withValues(alpha: .5);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? palette.accent : primaryColor,
              size: 21,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: AcoTypography.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: enabled
                          ? palette.mutedText
                          : palette.mutedText.withValues(alpha: .4),
                      fontSize: AcoTypography.caption,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: palette.accent,
              ),
          ],
        ),
      ),
    );
  }
}
