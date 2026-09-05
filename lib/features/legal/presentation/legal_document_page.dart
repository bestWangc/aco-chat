import 'package:aco_chat/core/theme/aco_typography.dart';
import 'package:aco_chat/shared/widgets/aco_page_header.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectionArea;

/// The in-app versions of the documents presented before wallet setup.
/// Keep the copy here in sync with any published version before release.
enum LegalDocument { userAgreement, privacyPolicy }

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({required this.document, super.key});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final palette = AcoPalette(isDark);
    final foreground = palette.primaryText;
    final muted = palette.mutedText;
    final surface = palette.background;
    final sections = document == LegalDocument.userAgreement
        ? _userAgreementSections
        : _privacyPolicySections;
    final title = document == LegalDocument.userAgreement ? '用户协议' : '隐私政策';

    return CupertinoPageScaffold(
      backgroundColor: surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AcoPageHeader(
                palette: palette,
                title: title,
                onBack: () => Navigator.of(context).maybePop(),
                backButtonOffset: Offset.zero,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
                children: [
                  Text(
                    '适用于 Aco Chat 的移动端服务',
                    style: TextStyle(
                      color: muted,
                      fontSize: AcoTypography.bodySmall,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  for (final section in sections) ...[
                    Text(
                      section.title,
                      style: TextStyle(
                        color: foreground,
                        fontSize: AcoTypography.bodyEmphasis,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      section.content,
                      style: TextStyle(
                        color: foreground.withValues(alpha: .82),
                        fontSize: AcoTypography.bodySmall,
                        height: 1.75,
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalSection {
  const _LegalSection(this.title, this.content);

  final String title;
  final String content;
}

const _userAgreementSections = [
  _LegalSection(
    '一、协议说明',
    '欢迎使用 Aco Chat。使用本应用、创建或导入钱包、注册账号或使用聊天、社区、会议等功能，即表示你已阅读、理解并同意本协议。未成年人应在监护人指导下使用本应用。',
  ),
  _LegalSection(
    '二、服务内容',
    'Aco Chat 提供数字钱包管理、链上信息展示、社交互动、内容发布、即时通信及其他相关功能。部分功能依赖区块链网络或第三方服务，实际可用性可能受网络、设备、地区或服务状态影响。',
  ),
  _LegalSection(
    '三、钱包与账号安全',
    '你应妥善保管助记词、私钥、密码及设备解锁信息，不得向任何人泄露。助记词和私钥一旦丢失、泄露或被他人获取，可能导致资产无法找回或被转移。任何基于正确凭证完成的操作，均可能被视为你本人作出。',
  ),
  _LegalSection(
    '四、使用规则',
    '你不得利用本应用从事违法违规活动，不得发布、传播或存储违法、有害、侵权、欺诈、骚扰、仇恨或误导性内容；不得干扰服务正常运行、尝试未授权访问，或侵犯他人的合法权益。',
  ),
  _LegalSection(
    '五、内容与知识产权',
    '你对自行发布的内容负责，并保证拥有必要的权利或授权。Aco Chat 的软件、界面、标识及相关内容受法律保护；未经许可，不得复制、修改、传播或用于商业用途。',
  ),
  _LegalSection(
    '六、链上与市场风险提示',
    '区块链交易具有不可撤销、价格波动和网络拥堵等特点。Aco Chat 不提供投资、交易或法律建议，也不保证任何数字资产、第三方项目或链上信息的价值、安全性、准确性或持续可用性。请独立判断并自行承担相关风险。',
  ),
  _LegalSection(
    '七、第三方服务',
    '本应用中的部分链接、内容、交易通道或功能可能由第三方提供。你使用第三方服务时，应同时遵守其规则与政策；因第三方服务产生的争议或损失，应按适用规则处理。',
  ),
  _LegalSection(
    '八、服务变更与责任限制',
    '在法律允许范围内，Aco Chat 可基于安全、维护、合规或产品运营需要调整、暂停或终止部分服务。因网络故障、不可抗力、设备异常、区块链网络问题或非因 Aco Chat 故意或重大过失造成的损失，Aco Chat 在法律允许范围内不承担责任。',
  ),
  _LegalSection(
    '九、协议更新',
    '本协议可能随服务发展而更新。更新后的版本将在应用内展示；你继续使用服务，视为接受更新后的协议。如你不同意更新内容，应停止使用相关服务。',
  ),
];

const _privacyPolicySections = [
  _LegalSection(
    '一、我们收集的信息',
    '为提供基础服务，我们可能处理你主动提供或在使用过程中产生的信息，包括钱包公开地址、账号资料、你发布或发送的内容、设备与应用版本信息、网络日志及故障诊断信息。我们不会主动要求你提供助记词或私钥。',
  ),
  _LegalSection(
    '二、信息的使用目的',
    '我们使用相关信息以完成账号和钱包功能、展示链上资产及服务内容、保障账号与交易安全、处理故障、改善产品体验，以及履行法律法规要求。除非取得你的同意或法律法规另有规定，我们不会将信息用于与上述目的无关的用途。',
  ),
  _LegalSection(
    '三、设备权限',
    '在你使用特定功能时，本应用可能请求相机权限以扫描二维码、麦克风权限以参与语音或会议、相册权限以选择图片，以及生物识别权限以保护钱包。你可以在系统设置中管理这些权限；拒绝非必要权限不会影响其他基础功能，但可能无法使用对应功能。',
  ),
  _LegalSection(
    '四、钱包数据与本地安全',
    '助记词、私钥及钱包解锁相关的敏感数据仅用于在你的设备上完成钱包操作。请不要通过聊天、截图、客服渠道或任何第三方页面泄露这些信息。钱包操作完成后产生的公开地址和链上记录，可能因区块链的公开、不可篡改特性而长期可被查询。',
  ),
  _LegalSection(
    '五、信息共享与公开',
    '除非取得你的单独同意、为实现你主动选择的功能、履行法定义务、保护用户或公众安全，或为处理争议和维护合法权益，我们不会向第三方出售你的个人信息。你在公开社区、会议或其他公开区域主动发布的内容，可能被其他用户查看和传播，请谨慎分享。',
  ),
  _LegalSection(
    '六、信息存储与保护',
    '我们将采取合理的技术和管理措施保护信息安全，并在实现服务目的所需的期限内保存相关信息。互联网环境并非绝对安全，请使用强密码、开启设备锁定，并及时更新应用。',
  ),
  _LegalSection(
    '七、你的权利',
    '你可以根据应用提供的功能访问、更正或删除部分账号资料和内容，也可以通过系统设置撤回已授予的权限。删除钱包或卸载应用前，请务必自行备份助记词；一旦遗失，相关资产可能无法恢复。',
  ),
  _LegalSection(
    '八、未成年人保护与政策更新',
    '我们重视未成年人个人信息保护。未成年人应在监护人同意和指导下使用本应用。我们可能更新本政策，并在应用内展示更新内容；你继续使用服务，视为接受更新后的政策。',
  ),
];
