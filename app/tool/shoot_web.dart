// Chụp app đang chạy thật trong Chrome, ở đúng kích thước một chiếc điện thoại.
//
// Khác với `render_preview_test.dart`: công cụ kia dựng widget dưới
// `flutter test`, nên chữ ra ô vuông (font của flutter_test không có glyph
// Latin) và không có ảnh nào tự giải mã. Công cụ này chạy **app thật** nên
// thấy đúng thứ người dùng thấy — font, ảnh, layout ở bề rộng thật.
//
//   cd app
//   flutter build web --release
//   dart run tool/shoot_web.dart build/shots shot:trang-chu tap:359,40 shot:cai-dat
//
// Các bước: `shot:<tên>` chụp, `tap:<x>,<y>` bấm (toạ độ logic), `wait:<ms>`
// chờ. Không có bước nào thì chụp một tấm tên `shot`.
//
// Vì sao qua DevTools Protocol chứ không phải cờ `--screenshot` của Chrome:
// `--window-size` cộng `--force-device-scale-factor` cho ra viewport không
// đoán trước được, nên có lần ảnh chụp ở 390px trong khi Flutter dựng bố cục ở
// 780px — đúng loại sai lệch làm ta tin nhầm rằng giao diện đã đúng. CDP đặt
// thẳng kích thước logic và dpr nên hai thứ đó luôn khớp.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Kích thước máy tham chiếu: iPhone 14 / Pixel 7 đều quanh mức này, và 390 là
/// bề rộng hẹp nhất mà giao diện phải vừa.
const _width = 390;
const _height = 844;
const _pixelRatio = 3;

const _chromeCandidates = [
  r'C:\Program Files\Google\Chrome\Application\chrome.exe',
  r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
];

String _findChrome() {
  final fromEnv = Platform.environment['CHROME_EXECUTABLE'];
  if (fromEnv != null && File(fromEnv).existsSync()) return fromEnv;
  for (final path in _chromeCandidates) {
    if (File(path).existsSync()) return path;
  }
  stderr.writeln('Không tìm thấy Chrome. Đặt CHROME_EXECUTABLE trỏ vào chrome.exe.');
  exit(1);
}

const _mimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript',
  '.mjs': 'application/javascript',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.css': 'text/css',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.wav': 'audio/wav',
  '.ico': 'image/x-icon',
};

Future<HttpServer> _serve(Directory root) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaited(
    server.forEach((request) async {
      final path = request.uri.path == '/' ? '/index.html' : request.uri.path;
      final file = File('${root.path}$path');
      if (!file.existsSync()) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      final dot = path.lastIndexOf('.');
      request.response.headers.set(
        'content-type',
        dot < 0 ? 'application/octet-stream' : _mimeTypes[path.substring(dot)] ?? 'application/octet-stream',
      );
      await request.response.addStream(file.openRead());
      await request.response.close();
    }),
  );
  return server;
}

Future<Map<String, dynamic>> _findPage() async {
  for (var attempt = 0; attempt < 60; attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(
        Uri.parse('http://127.0.0.1:9222/json'),
      ))
          .close();
      final targets = jsonDecode(await response.transform(utf8.decoder).join());
      return (targets as List).cast<Map<String, dynamic>>().firstWhere(
            (target) => target['type'] == 'page',
          );
    } on Object {
      // Chrome chưa mở cổng gỡ lỗi, thử lại.
    } finally {
      client.close();
    }
  }
  stderr.writeln('Chrome không mở được cổng DevTools.');
  exit(1);
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Dùng: dart run tool/shoot_web.dart <thư mục ra> [shot:tên|tap:x,y|wait:ms ...]');
    exit(64);
  }
  final web = Directory('build/web');
  if (!File('${web.path}/index.html').existsSync()) {
    stderr.writeln('Chưa có build/web. Chạy `flutter build web --release` trước.');
    exit(1);
  }
  final outDir = Directory(args[0])..createSync(recursive: true);

  final server = await _serve(web);
  final profile = Directory.systemTemp.createTempSync('gamehub-cdp');
  final chrome = await Process.start(_findChrome(), [
    '--headless=new',
    '--disable-gpu',
    '--hide-scrollbars',
    '--no-first-run',
    '--remote-debugging-port=9222',
    '--user-data-dir=${profile.path}',
    'about:blank',
  ]);

  final page = await _findPage();
  final socket = await WebSocket.connect(page['webSocketDebuggerUrl'] as String);
  final pending = <int, Completer<Map<String, dynamic>>>{};
  var nextId = 0;
  socket.listen((raw) {
    final message = jsonDecode(raw as String) as Map<String, dynamic>;
    final id = message['id'] as int?;
    if (id != null) pending.remove(id)?.complete(message);
  });

  Future<Map<String, dynamic>> send(String method, [Map<String, dynamic>? params]) {
    final id = ++nextId;
    pending[id] = Completer<Map<String, dynamic>>();
    socket.add(jsonEncode({'id': id, 'method': method, 'params': params ?? {}}));
    return pending[id]!.future;
  }

  await send('Emulation.setDeviceMetricsOverride', {
    'width': _width,
    'height': _height,
    'deviceScaleFactor': _pixelRatio,
    'mobile': true,
  });
  await send('Page.enable');
  await send('Page.navigate', {
    'url': 'http://127.0.0.1:${server.port}/index.html',
  });
  // Bản web nạp CanvasKit và font trước khi vẽ khung đầu tiên; chụp sớm thì ra
  // trang trắng.
  await Future<void>.delayed(const Duration(seconds: 6));

  Future<void> shoot(String name) async {
    final result = await send('Page.captureScreenshot', {'format': 'png'});
    final data = (result['result'] as Map<String, dynamic>)['data'] as String;
    File('${outDir.path}/$name.png').writeAsBytesSync(base64Decode(data));
    stdout.writeln('chụp: ${outDir.path}/$name.png');
  }

  Future<void> tap(double x, double y) async {
    for (final type in ['mousePressed', 'mouseReleased']) {
      await send('Input.dispatchMouseEvent', {
        'type': type,
        'x': x,
        'y': y,
        'button': 'left',
        'clickCount': 1,
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 700));
  }

  if (args.length == 1) await shoot('shot');
  for (final step in args.skip(1)) {
    final value = step.substring(step.indexOf(':') + 1);
    switch (step.split(':').first) {
      case 'shot':
        await shoot(value);
      case 'wait':
        await Future<void>.delayed(Duration(milliseconds: int.parse(value)));
      case 'tap':
        final parts = value.split(',');
        await tap(double.parse(parts[0]), double.parse(parts[1]));
      case 'eval':
        // Đọc trạng thái thật trong trang: audioplayers trên web dựng thẻ
        // <audio>, nên soi được nó là biết nhạc có chạy hay không.
        final result = await send('Runtime.evaluate', {
          'expression': value,
          'returnByValue': true,
        });
        stdout.writeln('eval: ${jsonEncode(result['result'])}');
      default:
        stderr.writeln('Không hiểu bước "$step".');
    }
  }

  await socket.close();
  chrome.kill();
  await server.close(force: true);
  await Future<void>.delayed(const Duration(milliseconds: 400));
  try {
    profile.deleteSync(recursive: true);
  } on FileSystemException {
    // Chrome còn giữ file trong hồ sơ tạm; thư mục temp sẽ được dọn sau.
  }
  exit(0);
}
