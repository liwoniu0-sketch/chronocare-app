import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import '../providers/settings_provider.dart';
import '../providers/records_provider.dart';
import '../services/webdav_service.dart';
import '../services/cloudflare_sync_service.dart';
import '../services/backup_service.dart';
import '../services/update_service.dart';
import 'advanced_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _webdavUrlCtrl;
  late TextEditingController _webdavUserCtrl;
  late TextEditingController _webdavPassCtrl;
  late TextEditingController _webdavDirCtrl;

  late TextEditingController _cfUrlCtrl;
  late TextEditingController _cfTokenCtrl;

  bool _isTestingWebdav = false;
  bool _isSyncing = false;
  bool _isDownloadingWebdav = false;

  bool _isTestingCf = false;
  bool _isSyncingCf = false;
  bool _isDownloadingCf = false;
  bool _isDualSyncing = false;
  String _syncProgressText = '';

  bool _isCheckingUpdate = false;
  double _downloadProgress = 0.0;
  bool _isDownloadingApk = false;

  @override
  void initState() {
    super.initState();
    final s = Provider.of<SettingsProvider>(context, listen: false).settings;
    _webdavUrlCtrl = TextEditingController(text: s.webdavUrl);
    _webdavUserCtrl = TextEditingController(text: s.webdavUsername);
    _webdavPassCtrl = TextEditingController(text: s.webdavPassword);
    _webdavDirCtrl = TextEditingController(text: s.webdavRemoteDir);

    _cfUrlCtrl = TextEditingController(text: s.cloudflareSyncUrl);
    _cfTokenCtrl = TextEditingController(text: s.cloudflareSyncToken);
  }

  @override
  void dispose() {
    _webdavUrlCtrl.dispose();
    _webdavUserCtrl.dispose();
    _webdavPassCtrl.dispose();
    _webdavDirCtrl.dispose();
    _cfUrlCtrl.dispose();
    _cfTokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<SettingsProvider>(context);
    final recordsProv = Provider.of<RecordsProvider>(context, listen: false);
    final s = prov.settings;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('应用设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 0. 高级功能入口卡片 (显眼置顶)
          Card(
            color: Colors.blue.shade50.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.blue.withOpacity(0.3)),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.tune, color: Colors.white),
              ),
              title: const Text('高级功能与深度配置', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('OCR 引擎切换、AI 模型微调、Prompt 自定义、生物锁'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blueAccent),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdvancedSettingsScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // 1. 本地数据全量备份与自定义保存文件夹 (用户关注重点)
          const Text('💾 本地完整备份与自定义保存目录', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 自定义保存目录设置
                  Row(
                    children: [
                      const Icon(Icons.folder_special, color: Colors.amber, size: 22),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '本地备份与导出保存目录',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.drive_file_move_outlined, size: 16),
                        label: const Text('自定义文件夹'),
                        onPressed: () => _pickCustomDirectory(context, s, prov),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder_open, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.customLocalBackupPath.isNotEmpty
                                ? s.customLocalBackupPath
                                : '[系统默认] /Downloads/ChronoCare/ 或 App 专属目录',
                            style: TextStyle(
                              fontSize: 12,
                              color: s.customLocalBackupPath.isNotEmpty ? Colors.blueAccent : Colors.grey,
                              fontWeight: s.customLocalBackupPath.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (s.customLocalBackupPath.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.restore, size: 18, color: Colors.grey),
                            tooltip: '恢复默认目录',
                            onPressed: () {
                              s.customLocalBackupPath = '';
                              prov.updateSettings(s);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已恢复为系统默认保存目录')),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.file_download, color: Colors.white, size: 20),
                    ),
                    title: const Text('导出完整数据备份 (ZIP 包)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('生成包含全部病历、检验指标、用药、提问及照片原图的 ZIP 包'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _exportBackup(s),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.file_upload, color: Colors.white, size: 20),
                    ),
                    title: const Text('从备份包恢复数据 (开箱即用)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('一键还原全部病历、化验单照片、API Keys 与所有设置'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _restoreBackup(prov, recordsProv),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 实时同步进度卡片
          if (_syncProgressText.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _syncProgressText,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.blueAccent),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 2. 双云双轨双保险全量同步
          const Text('🛡️ 多云双保险备份 (Cloudflare + WebDAV)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          // 2.0 双轨一键同步大卡片 (极客双保险)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: isDark ? Colors.blueGrey.shade900 : Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security, color: Colors.indigoAccent),
                      const SizedBox(width: 8),
                      const Text('全球双轨灾备', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigoAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('推荐启用', style: TextStyle(fontSize: 11, color: Colors.indigoAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '支持将所有检验指标、就诊用药、备忘及每一张化验单高清原图，同时双写备份至 Cloudflare 专属存储与 WebDAV 云盘。新手机无论何时一键导入，都能 100% 完美复原！',
                    style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _isDualSyncing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.cloud_sync, color: Colors.white, size: 18),
                      label: Text(
                        _isDualSyncing ? '正在双轨异地同步中...' : '一键双云全量备份 (Cloudflare + WebDAV)',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: _isDualSyncing || _isSyncingCf || _isSyncing ? null : () => _dualSyncNow(s, prov, recordsProv),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2.1 Cloudflare 专属全量云备份 (免绑卡 / 专有高可用)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('⚡ Cloudflare 专属永久云备份', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('一键备份全量指标与化验单高清原图，换新手机一键镜像复原'),
                    value: s.cloudflareSyncEnabled,
                    onChanged: (val) {
                      s.cloudflareSyncEnabled = val;
                      prov.updateSettings(s);
                    },
                  ),
                  if (s.cloudflareSyncEnabled) ...[
                    const Divider(height: 1),
                    TextField(
                      controller: _cfUrlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Cloudflare 专属同步节点',
                        hintText: 'https://chrono.lz1861.ccwu.cc',
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(height: 1),
                    TextField(
                      controller: _cfTokenCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '安全同步密钥 (Token)',
                        hintText: '专属高防密钥已自动预设',
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isTestingCf ? null : () => _testCloudflare(s),
                            child: _isTestingCf
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('测试连通'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                            icon: const Icon(Icons.cloud_upload, size: 16, color: Colors.white),
                            label: _isSyncingCf
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('全量上传', style: TextStyle(color: Colors.white)),
                            onPressed: _isSyncingCf ? null : () => _syncToCloudflare(s),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                            icon: const Icon(Icons.cloud_download, size: 16, color: Colors.white),
                            label: _isDownloadingCf
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('新机一键还原', style: TextStyle(color: Colors.white)),
                            onPressed: _isDownloadingCf ? null : () => _pullFromCloudflare(s, prov, recordsProv),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2.2 WebDAV 云端全量同步与定时策略
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('☁️ 坚果云 / WebDAV 自动同步', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('支持坚果云、Nextcloud、群晖 NAS 等 (同步全部图片与配置)'),
                    value: s.webdavEnabled,
                    onChanged: (val) {
                      s.webdavEnabled = val;
                      prov.updateSettings(s);
                    },
                  ),
                  if (s.webdavEnabled) ...[
                    const Divider(height: 1),
                    TextField(
                      controller: _webdavUrlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'WebDAV 服务器地址',
                        hintText: '如 https://dav.jianguoyun.com/dav/',
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(height: 1),
                    TextField(
                      controller: _webdavUserCtrl,
                      decoration: const InputDecoration(
                        labelText: '账号 / 邮箱',
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(height: 1),
                    TextField(
                      controller: _webdavPassCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '应用专属密码 / 授权 Token',
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(height: 1),
                    TextField(
                      controller: _webdavDirCtrl,
                      decoration: const InputDecoration(
                        labelText: '云端同步目录',
                        hintText: '/ChronoCare/',
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.sync, color: Colors.blueAccent),
                      title: const Text('同步触发策略'),
                      trailing: DropdownButton<String>(
                        value: s.autoSyncInterval,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'manual', child: Text('仅手动同步')),
                          DropdownMenuItem(value: 'on_startup', child: Text('每次打开 App 时')),
                          DropdownMenuItem(value: 'on_change', child: Text('每次数据变更时')),
                          DropdownMenuItem(value: 'daily', child: Text('每日定时自动同步')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            s.autoSyncInterval = val;
                            prov.updateSettings(s);
                          }
                        },
                      ),
                    ),
                    if (s.autoSyncInterval == 'daily') ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.access_time, color: Colors.blueAccent),
                        title: const Text('每日自动同步时间', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text('将在每天 ${s.autoSyncTime} 自动静默同步全部数据与图片'),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
                          onPressed: () => _pickSyncTime(context, s, prov),
                          child: Text(s.autoSyncTime),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isTestingWebdav ? null : () => _testWebdav(s),
                            child: _isTestingWebdav
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('测试连接'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                            icon: const Icon(Icons.cloud_upload, size: 16, color: Colors.white),
                            label: _isSyncing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('全量上传', style: TextStyle(color: Colors.white)),
                            onPressed: _isSyncing ? null : () => _syncNow(s),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                            icon: const Icon(Icons.cloud_download, size: 16, color: Colors.white),
                            label: _isDownloadingWebdav
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('从云端还原', style: TextStyle(color: Colors.white)),
                            onPressed: _isDownloadingWebdav ? null : () => _pullFromWebdav(s, prov, recordsProv),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. UI 与外观个性化
          const Text('🎨 外观与个性化', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_4_outlined),
                  title: const Text('外观模式'),
                  trailing: DropdownButton<String>(
                    value: s.themeMode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'system', child: Text('跟随系统')),
                      DropdownMenuItem(value: 'light', child: Text('浅色模式')),
                      DropdownMenuItem(value: 'dark', child: Text('深色模式 (高对比度)')),
                    ],
                    onChanged: (val) {
                      if (val != null) prov.updatePartial(themeMode: val);
                    },
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('紧凑卡片视图'),
                  subtitle: const Text('缩减卡片间距，一屏展示更多记录'),
                  value: s.compactCardMode,
                  onChanged: (val) => prov.updatePartial(compactCardMode: val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. 关于与 App 内检查更新
          const Text('ℹ️ 关于与更新 (永久固定签名)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.blueAccent),
                  title: const Text('脉络健康 (ChronoCare)'),
                  subtitle: Text('当前版本: v${UpdateService.currentVersion} (Build ${UpdateService.currentBuildNumber})'),
                  trailing: ElevatedButton(
                    onPressed: _isCheckingUpdate ? null : _checkAppUpdate,
                    child: _isCheckingUpdate
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('检查更新'),
                  ),
                ),
                if (_isDownloadingApk)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('正在下载最新安装包 (支持就地覆盖升级): ${(_downloadProgress * 100).toStringAsFixed(1)}%'),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: _downloadProgress),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Future<void> _pickCustomDirectory(BuildContext context, s, SettingsProvider prov) async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '请选择本地备份与导出保存文件夹',
      );
      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        s.customLocalBackupPath = selectedDirectory;
        await prov.updateSettings(s);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ 已成功将保存目录设置为:\n$selectedDirectory')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件夹失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickSyncTime(BuildContext context, s, SettingsProvider prov) async {
    final parts = s.autoSyncTime.split(':');
    final initialHour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 22 : 22;
    final initialMinute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );

    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minStr = picked.minute.toString().padLeft(2, '0');
      s.autoSyncTime = '$hourStr:$minStr';
      prov.updateSettings(s);
    }
  }

  Future<void> _testWebdav(s) async {
    _saveWebdavFields(s);
    setState(() => _isTestingWebdav = true);
    final ok = await WebDavService.instance.testConnection(s);
    setState(() => _isTestingWebdav = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '✅ WebDAV 连接测试成功！' : '❌ WebDAV 连接失败，请检查地址或密码'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _saveCloudFields(s) {
    _saveWebdavFields(s);
    s.cloudflareSyncUrl = _cfUrlCtrl.text.trim();
    s.cloudflareSyncToken = _cfTokenCtrl.text.trim();
  }

  Future<void> _testCloudflare(s) async {
    _saveCloudFields(s);
    setState(() => _isTestingCf = true);
    final res = await CloudflareSyncService.instance.testConnection(s);
    setState(() => _isTestingCf = false);

    if (mounted) {
      final success = res['success'] == true && res['authenticated'] == true;
      final msg = res['message'] ?? (success ? '连接成功！' : '连接失败');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ Cloudflare 专属节点测试成功: $msg' : '❌ Cloudflare 测试失败: $msg'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _syncToCloudflare(s) async {
    _saveCloudFields(s);
    setState(() {
      _isSyncingCf = true;
      _syncProgressText = '正在连接 Cloudflare 云端节点...';
    });
    try {
      await CloudflareSyncService.instance.uploadAllToCloudflare(
        s,
        onProgress: (step, prog) {
          if (mounted) setState(() => _syncProgressText = step);
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 全部数字指标、化验单原图与设置已 100% 备份至 Cloudflare！'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cloudflare 备份失败: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingCf = false;
          _syncProgressText = '';
        });
      }
    }
  }

  Future<void> _pullFromCloudflare(s, SettingsProvider prov, RecordsProvider recordsProv) async {
    _saveCloudFields(s);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('从 Cloudflare 恢复数据'),
        content: const Text('将从 Cloudflare 下载全部档案、配置，并自动补全下载所有化验单高清原图，还原为与旧手机 100% 一模一样。\n\n确认现在执行恢复吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认全量恢复', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _isDownloadingCf = true;
      _syncProgressText = '正在从 Cloudflare 检索备份数据...';
    });
    try {
      await CloudflareSyncService.instance.restoreAllFromCloudflare(
        s,
        onProgress: (step, prog) {
          if (mounted) setState(() => _syncProgressText = step);
        },
      );
      await prov.loadSettings();
      await recordsProv.loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 恢复成功！化验单原图与全部档案已 100% 还原！'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('云端恢复失败: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingCf = false;
          _syncProgressText = '';
        });
      }
    }
  }

  Future<void> _dualSyncNow(s, SettingsProvider prov, RecordsProvider recordsProv) async {
    _saveCloudFields(s);
    setState(() {
      _isDualSyncing = true;
      _syncProgressText = '正在启动双云双轨异地同步...';
    });
    try {
      await CloudflareSyncService.instance.dualCloudBackup(
        s,
        onProgress: (step, prog) {
          if (mounted) setState(() => _syncProgressText = step);
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🛡️ 双云双轨同步完成！Cloudflare 与 WebDAV 双保险落盘成功！'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('双轨同步失败: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDualSyncing = false;
          _syncProgressText = '';
        });
      }
    }
  }

  Future<void> _syncNow(s) async {
    _saveWebdavFields(s);
    setState(() => _isSyncing = true);
    try {
      await WebDavService.instance.uploadDataToWebDav(s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 全部数据、化验单图片与设置已成功同步至 WebDAV 云端！')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('同步失败: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _pullFromWebdav(s, SettingsProvider prov, RecordsProvider recordsProv) async {
    _saveWebdavFields(s);
    setState(() => _isDownloadingWebdav = true);
    try {
      await WebDavService.instance.restoreDataFromWebDav(s);
      await prov.loadSettings();
      await recordsProv.loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 已从 WebDAV 成功恢复全量数据、化验单照片与设置！')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('云端恢复失败: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isDownloadingWebdav = false);
    }
  }

  void _saveWebdavFields(s) {
    s.webdavUrl = _webdavUrlCtrl.text.trim();
    s.webdavUsername = _webdavUserCtrl.text.trim();
    s.webdavPassword = _webdavPassCtrl.text.trim();
    s.webdavRemoteDir = _webdavDirCtrl.text.trim();
  }

  Future<void> _exportBackup(s) async {
    try {
      final file = await BackupService.instance.createFullBackupZip(
        customTargetDirPath: s.customLocalBackupPath,
      );
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('🎉 本地全量备份成功'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('已将全部病历、检验指标、用药、提问与照片完整打包：'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SelectableText(
                    file.path,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('完成'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('打开文件所在位置'),
                onPressed: () async {
                  await OpenFilex.open(file.parent.path);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出备份失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _restoreBackup(SettingsProvider prov, RecordsProvider recordsProv) async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
      if (res != null && res.files.single.path != null) {
        final zipFile = File(res.files.single.path!);
        await BackupService.instance.restoreFromBackupZip(zipFile);
        await prov.loadSettings();
        await recordsProv.loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ 备份还原成功！所有病历、照片与设置已全部恢复')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('还原失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _checkAppUpdate() async {
    setState(() => _isCheckingUpdate = true);
    try {
      final info = await UpdateService.instance.checkUpdate();
      setState(() => _isCheckingUpdate = false);

      if (!mounted) return;

      if (info == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前已是最新版本 🎉')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('发现新版本: ${info.tagName}'),
          content: SingleChildScrollView(
            child: Text(info.body.isNotEmpty ? info.body : '包含最新功能优化与体验升级。'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('稍后再说'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (info.downloadUrl.isNotEmpty) {
                  setState(() => _isDownloadingApk = true);
                  await UpdateService.instance.downloadAndInstallApk(
                    downloadUrl: info.downloadUrl,
                    onProgress: (p) {
                      if (mounted) setState(() => _downloadProgress = p);
                    },
                  );
                  if (mounted) setState(() => _isDownloadingApk = false);
                }
              },
              child: const Text('立即更新 (覆盖安装)'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _isCheckingUpdate = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查更新失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
