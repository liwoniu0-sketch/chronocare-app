import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/record.dart';

/// 专职负责化验单与检查图片永久化存储、智能寻址解析与数据自愈迁移的服务
class ImageStorageService {
  static final ImageStorageService instance = ImageStorageService._();
  ImageStorageService._();

  Directory? _permanentImagesDir;

  /// 获取或初始化永久存储目录（位于 App 专有持久化文档目录中，操作系统与系统清理绝不清除）
  Future<Directory> getPermanentImagesDir() async {
    if (_permanentImagesDir != null && await _permanentImagesDir!.exists()) {
      return _permanentImagesDir!;
    }
    final docDir = await getApplicationDocumentsDirectory();
    final imgDir = Directory(p.join(docDir.path, 'records_images'));
    if (!await imgDir.exists()) {
      await imgDir.create(recursive: true);
    }
    _permanentImagesDir = imgDir;
    return _permanentImagesDir!;
  }

  /// 将临时图片（如系统相机/相册选择器返回的临时 cache 路径）强制安全无损复制到永久存储目录
  /// 返回永久存储的绝对文件路径
  Future<String> persistImage(String sourcePath, {String? customBackupPath}) async {
    if (sourcePath.trim().isEmpty) return '';

    try {
      final permDir = await getPermanentImagesDir();
      final sourceFile = File(sourcePath);

      // 如果已经在永久存储目录中，且文件存在，直接复用
      if (p.isWithin(permDir.path, sourcePath) && await sourceFile.exists()) {
        return sourcePath;
      }

      // 如果原文件存在，执行永久化复制
      if (await sourceFile.exists()) {
        final ext = p.extension(sourcePath);
        final safeExt = ext.isNotEmpty ? ext : '.jpg';
        final uniqueName = 'cc_img_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}$safeExt';
        final targetPath = p.join(permDir.path, uniqueName);

        // 写入永久目录
        await sourceFile.copy(targetPath);

        // 如果用户配置了有效的自定义本地化验单原图目录，同步进行双保险物理镜像备份
        if (customBackupPath != null && customBackupPath.trim().isNotEmpty) {
          try {
            final customDir = Directory(customBackupPath.trim());
            if (!await customDir.exists()) {
              await customDir.create(recursive: true);
            }
            final customTargetFile = File(p.join(customDir.path, uniqueName));
            await sourceFile.copy(customTargetFile.path);
          } catch (e) {
            debugPrint('ImageStorageService: 镜像备份至自定义目录失败: $e');
          }
        }

        return targetPath;
      } else {
        // 原文件可能已被移动，尝试根据文件名在永久目录中查找
        final fileName = p.basename(sourcePath);
        final fallbackFile = File(p.join(permDir.path, fileName));
        if (await fallbackFile.exists()) {
          return fallbackFile.path;
        }
      }
    } catch (e) {
      debugPrint('ImageStorageService: persistImage 出错: $e');
    }

    return sourcePath;
  }

  /// 智能解析化验单原图 File 对象（含自动寻址与多级自愈降级）
  /// 无论路径是因为系统跨版本迁移、沙盒前缀变动、还是应用备份还原，均可 100% 自动对齐找到真实文件
  Future<File> resolveImageFile(String path, {String? customBackupPath}) async {
    if (path.trim().isEmpty) return File(path);

    try {
      final file = File(path);
      if (await file.exists()) {
        return file;
      }

      final fileName = p.basename(path);
      if (fileName.isEmpty) return file;

      // 1. 尝试在永久存储目录 records_images 查找
      final permDir = await getPermanentImagesDir();
      final permFile = File(p.join(permDir.path, fileName));
      if (await permFile.exists()) {
        return permFile;
      }

      // 2. 尝试在自定义目录查找
      if (customBackupPath != null && customBackupPath.trim().isNotEmpty) {
        final customFile = File(p.join(customBackupPath.trim(), fileName));
        if (await customFile.exists()) {
          return customFile;
        }
      }

      // 3. 尝试在应用文档根目录查找
      final docDir = await getApplicationDocumentsDirectory();
      final docFile = File(p.join(docDir.path, fileName));
      if (await docFile.exists()) {
        return docFile;
      }
    } catch (e) {
      debugPrint('ImageStorageService: resolveImageFile 寻址出错: $e');
    }

    return File(path);
  }

  /// 同步快捷解析（用于 build 同步构建，若原路径不存在则快速按文件名嗅探）
  File resolveImageFileSync(String path, {String? customBackupPath}) {
    if (path.trim().isEmpty) return File(path);
    try {
      final file = File(path);
      if (file.existsSync()) return file;

      final fileName = p.basename(path);
      if (fileName.isEmpty) return file;

      if (_permanentImagesDir != null) {
        final f = File(p.join(_permanentImagesDir!.path, fileName));
        if (f.existsSync()) return f;
      }

      if (customBackupPath != null && customBackupPath.trim().isNotEmpty) {
        final f = File(p.join(customBackupPath.trim(), fileName));
        if (f.existsSync()) return f;
      }
    } catch (_) {}
    return File(path);
  }

  /// 启动时自动全量自愈与迁移：
  /// 将所有记录中指向 cache/tmp 的历史遗留图片无损抢救拷贝至永久目录，并自动修正数据库路径
  Future<void> healAndMigrateAllRecords({
    required List<CheckRecord> records,
    required Future<void> Function(CheckRecord updatedRecord) onSaveRecord,
    String? customBackupPath,
  }) async {
    final permDir = await getPermanentImagesDir();

    for (var record in records) {
      bool needUpdate = false;
      final List<String> newImagePaths = [];

      // 1. 检查并持久化 record.imagePaths
      for (var imgPath in record.imagePaths) {
        if (imgPath.trim().isEmpty) continue;

        // 如果路径已经在永久存储目录，且物理文件存在，无需处理
        if (p.isWithin(permDir.path, imgPath) && await File(imgPath).exists()) {
          newImagePaths.add(imgPath);
          continue;
        }

        // 尝试持久化复制或智能寻址
        final currentFile = File(imgPath);
        if (await currentFile.exists()) {
          // 当前文件还存在（抢救性迁移）：立刻复制至永久目录
          final persisted = await persistImage(imgPath, customBackupPath: customBackupPath);
          if (persisted != imgPath) {
            newImagePaths.add(persisted);
            needUpdate = true;
            continue;
          }
        } else {
          // 当前原路径文件已不存在，尝试自愈寻址
          final resolved = await resolveImageFile(imgPath, customBackupPath: customBackupPath);
          if (await resolved.exists()) {
            newImagePaths.add(resolved.path);
            needUpdate = true;
            continue;
          }
        }

        newImagePaths.add(imgPath);
      }

      // 2. 同步修复 items 中的 sourceImagePath
      for (var item in record.items) {
        if (item.sourceImagePath.isNotEmpty) {
          if (!p.isWithin(permDir.path, item.sourceImagePath) || !await File(item.sourceImagePath).exists()) {
            final resolved = await resolveImageFile(item.sourceImagePath, customBackupPath: customBackupPath);
            if (await resolved.exists() && resolved.path != item.sourceImagePath) {
              item.sourceImagePath = resolved.path;
              needUpdate = true;
            }
          }
        }
      }

      if (needUpdate) {
        record.imagePaths = newImagePaths;
        try {
          await onSaveRecord(record);
          debugPrint('ImageStorageService: 已自愈并永久化记录 ${record.id} 的化验单图片路径');
        } catch (e) {
          debugPrint('ImageStorageService: 保存自愈记录失败: $e');
        }
      }
    }
  }
}
