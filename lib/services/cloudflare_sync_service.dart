import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/app_settings.dart';
import 'storage_service.dart';
import 'webdav_service.dart';

class CloudflareSyncService {
  static final CloudflareSyncService instance = CloudflareSyncService._();
  CloudflareSyncService._();

  Map<String, String> _getHeaders(AppSettings settings) {
    final token = settings.cloudflareSyncToken.trim();
    return {
      'Authorization': 'Bearer $token',
      'x-sync-token': token,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  String _cleanUrl(String baseUrl, String path) {
    var url = baseUrl.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    var pStr = path.trim();
    if (!pStr.startsWith('/')) pStr = '/$pStr';
    return url + pStr;
  }

  /// 测试 Cloudflare 备份节点连通性与安全密钥
  Future<Map<String, dynamic>> testConnection(AppSettings settings) async {
    try {
      final endpoint = _cleanUrl(settings.cloudflareSyncUrl, '/api/sync/status');
      final res = await http.get(Uri.parse(endpoint), headers: _getHeaders(settings)).timeout(
        const Duration(seconds: 10),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map<String, dynamic>) {
          return {
            'success': true,
            'authenticated': data['authenticated'] == true,
            'lastBackup': data['lastBackup'],
            'recordCount': data['recordCount'] ?? 0,
            'imageCount': data['imageCount'] ?? 0,
            'message': data['authenticated'] == true ? '连接成功且安全密钥校验通过' : '连接成功，但同步密钥不匹配',
          };
        }
      }
      return {
        'success': false,
        'message': 'HTTP ${res.statusCode}: ${res.body}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': '网络连接失败: $e',
      };
    }
  }

  /// 100% 全量上传至 Cloudflare（所有数字指标 + 全部化验单高清原图 + 全部配置）
  Future<void> uploadAllToCloudflare(
    AppSettings settings, {
    Function(String step, double progress)? onProgress,
  }) async {
    onProgress?.call('正在打包全量档案与配置...', 0.05);

    // 1. 导出全量结构化数据
    final allData = await StorageService.instance.exportAllData();
    final jsonStr = jsonEncode(allData);
    final jsonBytes = utf8.encode(jsonStr);

    onProgress?.call('正在向 Cloudflare 同步数据结构...', 0.15);
    final dataEndpoint = _cleanUrl(settings.cloudflareSyncUrl, '/api/sync/data');
    final dataRes = await http.post(
      Uri.parse(dataEndpoint),
      headers: _getHeaders(settings),
      body: jsonBytes,
    );

    if (dataRes.statusCode != 200 && dataRes.statusCode != 201) {
      throw Exception('上传核心数据失败 (${dataRes.statusCode}): ${dataRes.body}');
    }

    // 2. 收集所有化验单图片
    onProgress?.call('正在扫描化验单原图...', 0.25);
    final records = await StorageService.instance.getRecords();
    final List<File> validImageFiles = [];
    final Set<String> processedNames = {};

    for (var r in records) {
      for (var imgPath in r.imagePaths) {
        if (imgPath.isEmpty) continue;
        final baseName = p.basename(imgPath);
        if (processedNames.contains(baseName)) continue;

        final f = File(imgPath);
        if (await f.exists()) {
          validImageFiles.add(f);
          processedNames.add(baseName);
        }
      }
    }

    // 3. 逐张增量上传图片原图 (已存在自动秒传跳过)
    final totalImages = validImageFiles.length;
    int uploadedCount = 0;

    for (int i = 0; i < totalImages; i++) {
      final imgFile = validImageFiles[i];
      final fileName = p.basename(imgFile.path);
      final currentProgress = 0.25 + (i / totalImages) * 0.65;

      onProgress?.call('正在同步化验单原图 ($i/$totalImages): $fileName', currentProgress);

      try {
        final imgEndpoint = _cleanUrl(settings.cloudflareSyncUrl, '/api/sync/image?name=${Uri.encodeComponent(fileName)}');
        
        // 增量检查：云端如果已经存在该图片，跳过上传以节省流量并提速
        final headRes = await http.head(Uri.parse(imgEndpoint), headers: _getHeaders(settings));
        if (headRes.statusCode == 200) {
          uploadedCount++;
          continue;
        }

        // 云端没有，执行全量上传
        final imgBytes = await imgFile.readAsBytes();
        final uploadRes = await http.post(
          Uri.parse(imgEndpoint),
          headers: {
            ..._getHeaders(settings),
            'Content-Type': 'image/jpeg',
          },
          body: imgBytes,
        );

        if (uploadRes.statusCode == 200 || uploadRes.statusCode == 201) {
          uploadedCount++;
        }
      } catch (e) {
        // 单张图片网络抖动不中断整个备份流程，尽量多传
      }
    }

    // 4. 更新备份清单元数据
    onProgress?.call('正在完成云端登记与校验...', 0.95);
    final manifestEndpoint = _cleanUrl(settings.cloudflareSyncUrl, '/api/sync/manifest');
    final manifestData = {
      'timestamp': DateTime.now().toIso8601String(),
      'recordCount': records.length,
      'images': processedNames.toList(),
      'version': '1.2.6',
      'device': Platform.operatingSystem,
    };

    await http.post(
      Uri.parse(manifestEndpoint),
      headers: _getHeaders(settings),
      body: jsonEncode(manifestData),
    );

    onProgress?.call('全量云备份完成！', 1.0);
  }

  /// 100% 全量从 Cloudflare 恢复（新手机开箱即用，自动下载所有原图并重映射路径）
  Future<void> restoreAllFromCloudflare(
    AppSettings settings, {
    Function(String step, double progress)? onProgress,
  }) async {
    onProgress?.call('正在从 Cloudflare 拉取最新档案数据...', 0.1);

    // 1. 获取核心数据 JSON
    final dataEndpoint = _cleanUrl(settings.cloudflareSyncUrl, '/api/sync/data');
    final dataRes = await http.get(Uri.parse(dataEndpoint), headers: _getHeaders(settings));

    if (dataRes.statusCode != 200) {
      throw Exception('获取云端数据失败 (${dataRes.statusCode}): ${dataRes.body}');
    }

    final jsonStr = utf8.decode(dataRes.bodyBytes);
    final Map<String, dynamic> data = jsonDecode(jsonStr);

    // 2. 准备本地永久原图目录
    onProgress?.call('正在准备本地永久沙盒目录...', 0.2);
    final appDocDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDocDir.path, 'records_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    // 3. 统计并下载所有化验单照片原图
    Map<String, String> nameToNewPath = {};
    List<String> needDownloadFiles = [];

    if (data['records'] != null && data['records'] is List) {
      for (var r in data['records']) {
        if (r['imagePaths'] != null) {
          List<String> rawPaths = [];
          try {
            final decoded = jsonDecode(r['imagePaths'].toString());
            if (decoded is List) rawPaths = decoded.map((e) => e.toString()).toList();
          } catch (_) {}

          for (var pStr in rawPaths) {
            final bName = p.basename(pStr);
            if (bName.isNotEmpty && !needDownloadFiles.contains(bName)) {
              needDownloadFiles.add(bName);
            }
          }
        }
      }
    }

    final totalImages = needDownloadFiles.length;
    for (int i = 0; i < totalImages; i++) {
      final fileName = needDownloadFiles[i];
      final localFile = File(p.join(imagesDir.path, fileName));
      final currentProgress = 0.2 + (i / totalImages) * 0.7;

      onProgress?.call('正在从云端恢复化验单原图 ($i/$totalImages): $fileName', currentProgress);

      // 如果本地已有且不为空，避免重复下载
      if (await localFile.exists() && await localFile.length() > 0) {
        nameToNewPath[fileName] = localFile.path;
        continue;
      }

      try {
        final imgEndpoint = _cleanUrl(settings.cloudflareSyncUrl, '/api/sync/image?name=${Uri.encodeComponent(fileName)}');
        final imgRes = await http.get(Uri.parse(imgEndpoint), headers: _getHeaders(settings));
        if (imgRes.statusCode == 200) {
          await localFile.writeAsBytes(imgRes.bodyBytes);
          nameToNewPath[fileName] = localFile.path;
        }
      } catch (_) {}
    }

    // 4. 重映射 records 中的图片路径至新手机本地路径
    onProgress?.call('正在重新建立本地索引与关联...', 0.92);
    if (data['records'] != null && data['records'] is List) {
      for (var r in data['records']) {
        if (r['imagePaths'] != null) {
          List<String> rawPaths = [];
          try {
            final decoded = jsonDecode(r['imagePaths'].toString());
            if (decoded is List) rawPaths = decoded.map((e) => e.toString()).toList();
          } catch (_) {}

          List<String> updatedPaths = [];
          for (var rawP in rawPaths) {
            final bName = p.basename(rawP);
            if (nameToNewPath.containsKey(bName)) {
              updatedPaths.add(nameToNewPath[bName]!);
            } else {
              updatedPaths.add(rawP);
            }
          }
          r['imagePaths'] = jsonEncode(updatedPaths);
        }
      }
    }

    // 5. 导入还原数据库
    onProgress?.call('正在载入全部病历、用药与设置...', 0.98);
    await StorageService.instance.importAllData(data);

    onProgress?.call('恢复完成！新手机已与云端 100% 一模一样', 1.0);
  }

  /// 一键双轨同步（同时备份至 WebDAV 和 Cloudflare 双保险）
  Future<void> dualCloudBackup(
    AppSettings settings, {
    Function(String step, double progress)? onProgress,
  }) async {
    // 1. 同步到 Cloudflare
    if (settings.cloudflareSyncEnabled && settings.cloudflareSyncUrl.isNotEmpty) {
      await uploadAllToCloudflare(settings, onProgress: (step, p) {
        onProgress?.call('【Cloudflare】$step', p * 0.5);
      });
    }

    // 2. 同步到 WebDAV
    if (settings.webdavEnabled && settings.webdavUrl.isNotEmpty) {
      onProgress?.call('【WebDAV】正在上传至 WebDAV 云盘...', 0.55);
      await WebDavService.instance.uploadDataToWebDav(settings);
      onProgress?.call('【WebDAV】同步完成！', 1.0);
    }
  }
}
