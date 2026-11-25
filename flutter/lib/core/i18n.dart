import 'package:material_ui/material_ui.dart';

/// The two interface languages. Anything that is not Chinese reads English.
enum AppLang { en, zh }

AppLang appLangOf(Locale locale) =>
    locale.languageCode == 'zh' ? AppLang.zh : AppLang.en;

/// Every fixed interface string. Data (device names, map names, file names and errors coming back
/// from Rust) is deliberately not translated: it is shown as the system or the profile spells it.
class L10n {
  const L10n(this.lang);

  final AppLang lang;

  bool get isZh => lang == AppLang.zh;

  String pick(String en, String zh) => isZh ? zh : en;

  // Shell ------------------------------------------------------------------

  String get startingEngine => pick('Starting engine...', '正在启动引擎…');
  String engineOffline(String error) =>
      pick('Engine offline: $error', '引擎离线：$error');
  String get storagePermission =>
      pick('Storage permission needed · Grant', '需要存储权限 · 授权');

  // Root menu --------------------------------------------------------------

  String get controller => pick('Controller', '控制器');
  String get output => pick('Output', '输出');
  String get mixer => pick('Mixer', '混音');
  String get preferences => pick('Preferences', '偏好');
  String get logs => pick('Logs', '日志');
  String get readingProfile => pick('Reading profile', '正在读取配置');

  String layout(String key) => switch (key) {
    'full' => pick('Full', '完整'),
    'landscape' => pick('Landscape', '横向'),
    'stacked' => pick('Stacked', '堆叠'),
    'allInOne' => pick('All-in-one', '一体'),
    _ => key,
  };

  String decks(int count) => isZh ? '$count Deck' : '$count Decks';

  // Controller -------------------------------------------------------------

  String get noController => pick('No controller connected', '未连接控制器');
  String get noPorts =>
      pick('No MIDI input ports found', '没有找到 MIDI 输入端口');
  String get map => pick('Map', '映射');
  String get mapFile => pick('Map file', '映射文件');
  String get builtInMap => pick('Built-in map', '内置映射');
  String get chooseUserMap => pick('Choose a user map…', '选择用户映射…');
  String get disable => pick('Disable', '停用');
  String get enabled => pick('Connected', '已连接');
  String get disconnected => pick('Disconnected', '未连接');
  String get builtIn => pick('Built-in', '内置');
  String get user => pick('User', '用户');
  String get inUse => pick('In use', '使用中');
  String get noMap => pick('No map', '未选择映射');
  String portsCount(int count) =>
      pick('$count MIDI port(s)', '$count 个 MIDI 端口');
  String get pickMapTitle => pick('Choose a map', '选择映射');
  String get pickMapFailed => pick('Could not read that file', '无法读取该文件');

  // Output -----------------------------------------------------------------

  String role(String role) => role == 'master'
      ? pick('Master', '主输出')
      : pick('Precue', '预听');
  String get device => pick('Device', '设备');
  String get channels => pick('Channels', '通道');
  String get defaultDevice => pick('Default device', '默认设备');
  String get addOutput => pick('Add a new output', '添加输出');
  String get outputAdded => pick('Output added', '输出已添加');
  String noChannels(String roleName) =>
      pick('No $roleName channels', '没有$roleName通道');
  String destinations(int count) =>
      pick('$count destination(s)', '$count 个输出');
  String get restartRequired =>
      pick('Restart app to apply output changes', '重启应用以应用输出改动');
  String get builtinReadOnly => pick(
    'The built-in profile is read-only; changes are disabled',
    '内置配置只读，改动已禁用',
  );
  String get restartTitle => pick('Restart required', '需要重启');
  String get restartBody => pick(
    'The audio output or sample rate changed. Restart now to apply it, or keep mixing and restart later.',
    '音频输出或采样率已改变。现在重启以应用，或继续使用并稍后重启。',
  );
  String get restartNow => pick('Restart now', '立即重启');
  String get restartLater => pick('Later', '稍后');
  String get restartManual => pick(
    'Restart the app to apply the change.',
    '重启应用以应用改动。',
  );
  String get ok => pick('OK', '好');

  // Settings ---------------------------------------------------------------

  String get profile => pick('Profile', '配置');
  String get audio => pick('Audio', '音频');
  String get analysis => pick('Analysis', '分析');
  String get display => pick('Display', '显示');
  String get library => pick('Library', '曲库');
  String get sampleRate => pick('Sample Rate', '采样率');
  String get crossfader => pick('Crossfader', '交叉推子');
  String get cueBlend => pick('Cue Blend', '监听混合');
  String get autoGain => pick('Auto Gain', '自动增益');
  String get classic => pick('Classic', '经典');
  String get constantPower => pick('Constant Power', '恒定功率');
  String get cut => pick('Cut', '切档');
  String get cue => pick('Cue', '监听');
  String get both => pick('Both', '两者');
  String get off => pick('Off', '关');
  String get on => pick('On', '开');
  String get changesWritten =>
      pick('Changes are written to the running profile', '改动会写入当前配置');
  String get restartHint => pick('restart required', '需要重启');
  String get noSettings => pick('No editable settings', '没有可编辑设置');

  // Browser ----------------------------------------------------------------

  String get libraryPane => pick('Library', '曲库');
  String get allLibraries => pick('All Libraries', '全部曲库');
  String get allLists => pick('All Lists', '全部列表');
  String get noLists => pick('No lists', '没有列表');
  String get allTracks => pick('All Tracks', '全部曲目');
  String get searchLibrary => pick('Search Library', '搜索曲库');
  String get noMatches => pick('No matches', '没有匹配');
  String get analyse => pick('Analyse', '分析');
  String get analysing => pick('Analysing…', '分析中…');
  String get add => pick('Add', '添加');
  String get folder => pick('Folder…', '文件夹…');
  String get usb => pick('USB', 'USB');
  String get local => pick('Local', '本地');
  String get rescan => pick('Rescan', '重新扫描');
  String get folders => pick('Folders', '文件夹');
  String get sources => pick('Sources', '来源');
  String get noFolders => pick('No folders added yet', '还没有添加文件夹');
  String get noSources => pick('No scanned sources', '没有已扫描的来源');
  String get addFolder => pick('Add a folder…', '添加文件夹…');
  String get addSource => pick('Add source', '添加来源');
  String get sourceHint => pick(
    'Add a folder, a USB volume, or open the library settings.',
    '添加文件夹、USB 卷，或打开曲库设置。',
  );
  String get chooseVolume =>
      pick('Choose a mounted volume', '选择已挂载的卷');
  String get noVolumes => pick('No removable volumes found', '没有找到可移动卷');
  String get librarySettings => pick('Library settings', '曲库设置');
  String tracksCount(int count) => isZh ? '$count 首' : '$count tracks';
  String minutes(int minutes) => isZh ? '$minutes 分钟' : '$minutes min';
  String get noTrack => pick('No Track', '没有曲目');
  String get allAnalysed => pick('All analysed', '全部已分析');
  String unanalysed(int count) =>
      isZh ? '未分析 $count 首' : '$count unanalysed';
  String analysingCount(int done, int total) =>
      pick('Analysing $done/$total', '正在分析 $done/$total');

  // Logs -------------------------------------------------------------------

  String get readingLog => pick('Reading log…', '正在读取日志…');
  String get noLogYet => pick('No log yet.', '暂无日志。');
  String couldNotReadLog(Object error) =>
      pick('Could not read the log: $error', '无法读取日志：$error');
}

/// Hands the current language down the tree. A missing scope falls back to English so a page can
/// still be tested on its own.
class L10nScope extends InheritedWidget {
  const L10nScope({required this.l10n, required super.child, super.key});

  final L10n l10n;

  static L10n of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<L10nScope>()?.l10n ??
      const L10n(AppLang.en);

  @override
  bool updateShouldNotify(L10nScope oldWidget) =>
      oldWidget.l10n.lang != l10n.lang;
}
