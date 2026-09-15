/// 终端加载动画
/// 用 ANSI 转义码渲染不定态循环进度条: spinner + 消息文字 + 灰色点阵轨道 + 绿色渐变移动头部
library;

import 'dart:async';
import 'dart:io';

/// 加载动画控制器
///
/// 用法:
/// ```dart
/// await LoadingIndicator.run(() => parser.loadFromUrl(url), detail: url);
/// ```
class LoadingIndicator {
  /// 进度条前的消息文字
  final String message;

  /// 进度条后展示的获取来源(URL / 文件路径)
  final String detail;

  /// 帧刷新间隔
  final Duration interval;

  /// 延迟开始渲染的时间: 瞬间完成的操作(如本地文件读取)不显示动画, 避免闪烁
  final Duration delay;

  Timer? _timer;
  int _tick = 0;
  bool _started = false;
  bool _rendered = false;
  final Stopwatch _stopwatch = Stopwatch();

  LoadingIndicator({this.message = '正在获取 json 数据', this.detail = '', this.interval = const Duration(milliseconds: 80), this.delay = const Duration(milliseconds: 200)});

  /// 亮绿色 braille spinner 帧
  static const List<String> spinnerFrames = ['\u280B', '\u2819', '\u2839', '\u2838', '\u283C', '\u2834', '\u2826', '\u2827', '\u2807', '\u280F'];

  /// 灰色点阵轨道字符
  static const String trackChar = '⣿';

  static const String _reset = '\x1B[0m';
  static const String _gray = '\x1B[90m';

  /// 移动头部绿色渐变色阶: 头部最亮, 向尾迹逐渐变暗
  static const List<String> headColors = ['\x1B[92m', '\x1B[32m', '\x1B[38;5;28m', '\x1B[38;5;22m'];

  /// 循环进度条固定长度(短段)
  static const int barWidth = 20;

  /// 当前 stdout 是否支持 ANSI 转义码
  static bool get ansiSupported => stdout.supportsAnsiEscapes;

  /// 开始动画; 非交互终端(管道/CI)下不输出, 保持日志干净
  void start() {
    if (_started) return;
    _started = true;
    _stopwatch.start();
    if (!ansiSupported) return;
    _timer = Timer.periodic(interval, (_) => _render());
  }

  void _render() {
    // delay 窗口内不绘制: 本地文件读取瞬间完成, 避免动画闪烁
    if (_stopwatch.elapsed < delay) return;
    _rendered = true;
    stdout.write('\x1B[2K\r${renderFrame(_tick++, message: message, detail: _fitDetail())}');
  }

  /// 截断 detail 使整帧不超过终端宽度, 避免折行导致动画叠行
  String _fitDetail() {
    if (detail.isEmpty || !stdout.hasTerminal) return detail;
    // 预留 = spinner + 空格 + message + 空格 + 进度条 + 空格
    final reserved = 1 + 1 + displayWidth(message) + 1 + barWidth + 1;
    final max = stdout.terminalColumns - reserved;
    if (max <= 0) return '';
    if (displayWidth(detail) <= max) return detail;
    final buf = StringBuffer();
    var width = 0;
    for (final rune in detail.runes) {
      final w = _isWide(rune) ? 2 : 1;
      if (width + w > max - 1) break;
      buf.writeCharCode(rune);
      width += w;
    }
    return '$buf…';
  }

  /// 停止动画并清除其占用行
  void stop() {
    if (!_started) return;
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
    if (_rendered) stdout.write('\x1B[2K\r');
    _started = false;
    _rendered = false;
    _tick = 0;
  }

  /// 用加载动画包裹异步任务; 任务抛异常时保证动画被清除
  static Future<T> run<T>(Future<T> Function() task, {String message = '正在获取 json 数据', String detail = ''}) async {
    final indicator = LoadingIndicator(message: message, detail: detail);
    indicator.start();
    try {
      return await task();
    } finally {
      indicator.stop();
    }
  }

  /// 渲染单帧(纯函数): `{spinner} {message} {短进度条} {detail}`
  ///
  /// 头部位置 = tick % width, 带渐变尾迹从左到右无限循环
  static String renderFrame(int tick, {int width = barWidth, String message = '正在获取 json 数据', String detail = ''}) {
    final spinner = '${headColors.first}${spinnerFrames[tick % spinnerFrames.length]}$_reset';
    final head = tick % width;
    final bar = StringBuffer();
    for (var i = 0; i < width; i++) {
      // 头部及左侧尾迹按渐变色阶着色, 其余为灰色轨道
      final offset = (head - i) % width;
      if (offset < headColors.length) {
        bar.write('${headColors[offset]}█$_reset');
      } else {
        bar.write('$_gray$trackChar$_reset');
      }
    }
    final suffix = detail.isEmpty ? '' : ' $_gray$detail$_reset';
    return '$spinner $message $bar$suffix';
  }

  /// 估算字符串的终端显示宽度(CJK 等宽字符按 2 列计)
  static int displayWidth(String s) {
    var width = 0;
    for (final rune in s.runes) {
      width += _isWide(rune) ? 2 : 1;
    }
    return width;
  }

  static bool _isWide(int r) {
    return (r >= 0x1100 && r <= 0x115F) ||
        (r >= 0x2E80 && r <= 0x303E) ||
        (r >= 0x3041 && r <= 0x33FF) ||
        (r >= 0x3400 && r <= 0x4DBF) ||
        (r >= 0x4E00 && r <= 0x9FFF) ||
        (r >= 0xA000 && r <= 0xA4CF) ||
        (r >= 0xAC00 && r <= 0xD7A3) ||
        (r >= 0xF900 && r <= 0xFAFF) ||
        (r >= 0xFE30 && r <= 0xFE4F) ||
        (r >= 0xFF00 && r <= 0xFF60) ||
        (r >= 0xFFE0 && r <= 0xFFE6);
  }
}
