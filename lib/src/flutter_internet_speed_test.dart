import 'package:flutter_internet_speed_test/src/speed_test_utils.dart';
import 'package:flutter_internet_speed_test/src/test_result.dart';

import 'callbacks_enum.dart';
import 'flutter_internet_speed_test_platform_interface.dart';
import 'models/server_selection_response.dart';

typedef DefaultCallback = void Function();
typedef ResultCallback = void Function(TestResult download, TestResult upload);
typedef TestProgressCallback = void Function(double percent, TestResult data);
typedef ResultCompletionCallback = void Function(TestResult data);
typedef DefaultServerSelectionCallback = void Function(Client? client);

class FlutterInternetSpeedTest {
  static const _defaultDownloadTestServer =
      'http://speedtest.ftp.otenet.gr/files/test10Mb.db';
  static const _defaultUploadTestServer = 'http://speedtest.ftp.otenet.gr/';
  static const _defaultFileSize = 10 * 1024 * 1024; // 10 MB

  static final FlutterInternetSpeedTest _instance =
      FlutterInternetSpeedTest._private();

  bool _isTestInProgress = false;
  bool _isCancelled = false;

  factory FlutterInternetSpeedTest() => _instance;

  FlutterInternetSpeedTest._private();

  bool isTestInProgress() => _isTestInProgress;

  Future<void> startTesting({
    required ResultCallback onCompleted,
    DefaultCallback? onStarted,
    ResultCompletionCallback? onDownloadComplete,
    ResultCompletionCallback? onUploadComplete,
    TestProgressCallback? onProgress,
    DefaultCallback? onDefaultServerSelectionInProgress,
    DefaultServerSelectionCallback? onDefaultServerSelectionDone,
    ErrorCallback? onError,
    CancelCallback? onCancel,
    String? downloadTestServer,
    String? uploadTestServer,
    int fileSizeInBytes = _defaultFileSize,
    bool useFastApi = true,
  }) async {
    if (_isTestInProgress || await isInternetAvailable() == false) {
      onError?.call('No internet connection', 'No internet connection');
      return;
    }

    _isTestInProgress = true;
    onStarted?.call();

    if ((downloadTestServer == null || uploadTestServer == null) &&
        useFastApi) {
      onDefaultServerSelectionInProgress?.call();
      final serverSelectionResponse =
          await FlutterInternetSpeedTestPlatform.instance.getDefaultServer();
      onDefaultServerSelectionDone?.call(serverSelectionResponse?.client);
      downloadTestServer ??= serverSelectionResponse?.targets?.first.url;
      uploadTestServer ??= serverSelectionResponse?.targets?.first.url;
    }

    downloadTestServer ??= _defaultDownloadTestServer;
    uploadTestServer ??= _defaultUploadTestServer;

    if (_isCancelled) {
      onCancel?.call();
      _resetTestState();
      return;
    }

    await _startDownloadTest(
      downloadTestServer,
      fileSizeInBytes,
      onProgress,
      onDownloadComplete,
      onError,
      onCancel,
      (downloadResult) async {
        await _startUploadTest(
          uploadTestServer!,
          fileSizeInBytes,
          onProgress,
          onUploadComplete,
          onError,
          onCancel,
          (uploadResult) {
            onCompleted(downloadResult, uploadResult);
            _resetTestState();
          },
        );
      },
    );
  }

  Future<void> _startDownloadTest(
    String testServer,
    int fileSize,
    TestProgressCallback? onProgress,
    ResultCompletionCallback? onDownloadComplete,
    ErrorCallback? onError,
    CancelCallback? onCancel,
    ResultCompletionCallback onDone,
  ) async {
    final startDownloadTimeStamp = DateTime.now().millisecondsSinceEpoch;
    FlutterInternetSpeedTestPlatform.instance.startDownloadTesting(
      onDone: (transferRate, unit) {
        final downloadDuration =
            DateTime.now().millisecondsSinceEpoch - startDownloadTimeStamp;
        final downloadResult = TestResult(TestType.download, transferRate, unit,
            durationInMillis: downloadDuration);
        onProgress?.call(100, downloadResult);
        onDownloadComplete?.call(downloadResult);
        onDone(downloadResult);
      },
      onProgress: (percent, transferRate, unit) {
        onProgress?.call(
            percent, TestResult(TestType.download, transferRate, unit));
      },
      onError: (errorMessage, speedTestError) {
        onError?.call(errorMessage, speedTestError);
        _resetTestState();
      },
      onCancel: () {
        onCancel?.call();
        _resetTestState();
      },
      fileSize: fileSize,
      testServer: testServer,
    );
  }

  Future<void> _startUploadTest(
    String testServer,
    int fileSize,
    TestProgressCallback? onProgress,
    ResultCompletionCallback? onUploadComplete,
    ErrorCallback? onError,
    CancelCallback? onCancel,
    ResultCompletionCallback onDone,
  ) async {
    final startUploadTimeStamp = DateTime.now().millisecondsSinceEpoch;
    FlutterInternetSpeedTestPlatform.instance.startUploadTesting(
      onDone: (transferRate, unit) {
        final uploadDuration =
            DateTime.now().millisecondsSinceEpoch - startUploadTimeStamp;
        final uploadResult = TestResult(TestType.upload, transferRate, unit,
            durationInMillis: uploadDuration);
        onProgress?.call(100, uploadResult);
        onUploadComplete?.call(uploadResult);
        onDone(uploadResult);
      },
      onProgress: (percent, transferRate, unit) {
        onProgress?.call(
            percent, TestResult(TestType.upload, transferRate, unit));
      },
      onError: (errorMessage, speedTestError) {
        onError?.call(errorMessage, speedTestError);
        _resetTestState();
      },
      onCancel: () {
        onCancel?.call();
        _resetTestState();
      },
      fileSize: fileSize,
      testServer: testServer,
    );
  }

  void _resetTestState() {
    _isTestInProgress = false;
    _isCancelled = false;
  }

  void enableLog() {
    FlutterInternetSpeedTestPlatform.instance.toggleLog(value: true);
  }

  void disableLog() {
    FlutterInternetSpeedTestPlatform.instance.toggleLog(value: false);
  }

  Future<bool> cancelTest() async {
    _resetTestState();
    return await FlutterInternetSpeedTestPlatform.instance.cancelTest();
  }

  bool get isLogEnabled => FlutterInternetSpeedTestPlatform.instance.logEnabled;
}
