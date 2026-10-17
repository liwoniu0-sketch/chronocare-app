import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/records_provider.dart';
import '../providers/settings_provider.dart';
import '../services/medical_metric_service.dart';
import 'record_detail_screen.dart';

class MetricsTrendTab extends StatefulWidget {
  final String? initialItemName;
  final String? initialCategory;

  const MetricsTrendTab({
    super.key,
    this.initialItemName,
    this.initialCategory,
  });

  @override
  State<MetricsTrendTab> createState() => _MetricsTrendTabState();
}

class _MetricsTrendTabState extends State<MetricsTrendTab> {
  String? _selectedItemName;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchKeyword = '';
  bool _hasAppliedInitialItem = false;
  bool _isStandardizing = false;

  /// 🌟 结合当前单据栏目与权威医学知识库的 5 级智能精准定位算法
  String? _resolveTargetItemName(
    List<String> allItems,
    String? targetName,
    String? targetCategory,
  ) {
    if (targetName == null || targetName.trim().isEmpty) return null;
    final cleanTarget = targetName.trim();
    final cleanCategory = (targetCategory ?? '').trim();

    // 0. 直接完全命中（如直接传入 "[血常规] 白细胞计数 (WBC)" 或未重名指标）
    if (allItems.contains(cleanTarget)) {
      return cleanTarget;
    }

    // 提取纯指标名与已嵌入的前缀单据
    String pureName = cleanTarget;
    String? embeddedCat;
    if (cleanTarget.startsWith('[') && cleanTarget.contains(']')) {
      final closeIdx = cleanTarget.indexOf(']');
      embeddedCat = cleanTarget.substring(1, closeIdx).trim();
      pureName = cleanTarget.substring(closeIdx + 1).trim();
    }
    final effectiveCategory = cleanCategory.isNotEmpty ? cleanCategory : (embeddedCat ?? '');
    final normCategory = MedicalMetricService.instance.normalizeCategory(effectiveCategory);

    // 🌟 1. 利用标准医学字典反查标准名 (例如传入 WBC/白细胞 -> 标准名 白细胞计数 (WBC))
    final canonical = MedicalMetricService.instance.findStandardMetric(pureName, category: normCategory);
    final standardDisplayName = canonical?.standardName ?? '';

    // 1.1 如果有标准显示名，优先在当前单据大类中匹配 "[$normCategory] $standardDisplayName"
    if (standardDisplayName.isNotEmpty) {
      final stdWithCat = '[$normCategory] $standardDisplayName';
      for (final item in allItems) {
        if (item.toLowerCase() == stdWithCat.toLowerCase()) return item;
      }
      // 1.2 在无分类的条目中匹配 "$standardDisplayName"
      for (final item in allItems) {
        if (item.toLowerCase() == standardDisplayName.toLowerCase()) return item;
      }
      // 1.3 在所有项中寻找包含标准名的项
      for (final item in allItems) {
        if (item.toLowerCase().contains(standardDisplayName.toLowerCase())) return item;
      }
    }

    // 2. 结合单据分类精确匹配 "[$normCategory] $pureName"
    if (normCategory.isNotEmpty) {
      final exactWithCat = '[$normCategory] $pureName';
      for (final item in allItems) {
        if (item.toLowerCase() == exactWithCat.toLowerCase()) return item;
      }
      // 容错匹配：单据分类包含
      for (final item in allItems) {
        if (item.startsWith('[') && item.contains(']')) {
          final closeIdx = item.indexOf(']');
          final cat = item.substring(1, closeIdx).trim().toLowerCase();
          final name = item.substring(closeIdx + 1).trim().toLowerCase();
          final effLower = normCategory.toLowerCase();
          if (name == pureName.toLowerCase() && (cat.contains(effLower) || effLower.contains(cat))) {
            return item;
          }
        }
      }
    }

    // 3. 纯指标名称精确匹配
    if (allItems.contains(pureName)) return pureName;
    for (final item in allItems) {
      if (item.toLowerCase() == pureName.toLowerCase()) return item;
    }

    // 4. 在带前缀的项中匹配纯指标名
    for (final item in allItems) {
      if (item.startsWith('[') && item.contains(']')) {
        final closeIdx = item.indexOf(']');
        final name = item.substring(closeIdx + 1).trim().toLowerCase();
        if (name == pureName.toLowerCase()) return item;
      }
    }

    // 5. 模糊包含纯指标名称
    for (final item in allItems) {
      if (item.toLowerCase().contains(pureName.toLowerCase())) return item;
    }

    return null;
  }

  Future<void> _runAiStandardization(BuildContext context) async {
    final prov = Provider.of<RecordsProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false).settings;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('AI 全局多维指标智能归拢'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '系统与 AI 将深度扫描全部复查化验单，综合研判：\n'
              '• 临床医学含义与中英文别名 (如 ALT 与 谷丙转氨酶)\n'
              '• 检验单位一致性 (如 U/L、mmol/L、10^9/L)\n'
              '• 参考区间吻合度 (如 0-40、3.5-9.5)\n'
              '• 单据大类与病程随访时间线 (如 全血细胞分析 收敛至 血常规)\n\n'
              'AI 研判完成后将自动统一指标名称与分类，彻底拼接连续走势图。',
              style: TextStyle(fontSize: 13, height: 1.45),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.bolt, size: 18, color: Colors.white),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            label: const Text('开始智能研判并对齐', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isStandardizing = true);
    try {
      final report = await prov.executeSmartMetricReconciliation(settings);

      if (mounted) {
        // 展示精美的 AI 归并分析报告
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.verified, color: Colors.green),
                const SizedBox(width: 8),
                Text('AI 智能对齐完成 (${report.modifiedRecordsCount}张单据已同步)'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 已全量扫描 ${report.totalProfilesScanned} 个指标画像。'
                      '${report.clusters.isEmpty ? '目前所有指标命名均高度规范，无须额外合并！' : '成功识别并收敛了以下指标集群：'}',
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    ...report.clusters.map((c) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(c.standardCategory, style: const TextStyle(color: Colors.white, fontSize: 11)),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  c.standardName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('涵盖原名: ${c.matchedRawNames.join('、')}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                          const SizedBox(height: 4),
                          Text('AI 依据: ${c.reason}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: const Text('我知道了', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI 归拢遇到异常: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isStandardizing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialItemName != null && widget.initialItemName!.isNotEmpty) {
      _selectedItemName = widget.initialItemName;
    }
  }

  @override
  void didUpdateWidget(covariant MetricsTrendTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialItemName != null &&
        (widget.initialItemName != oldWidget.initialItemName || widget.initialCategory != oldWidget.initialCategory)) {
      final prov = Provider.of<RecordsProvider>(context, listen: false);
      final allItems = prov.getAllItemNames();
      final resolved = _resolveTargetItemName(allItems, widget.initialItemName, widget.initialCategory);
      setState(() {
        if (resolved != null) {
          _selectedItemName = resolved;
          String pureName = widget.initialItemName!.trim();
          if (pureName.startsWith('[') && pureName.contains(']')) {
            pureName = pureName.substring(pureName.indexOf(']') + 1).trim();
          }
          _searchKeyword = pureName;
          _searchCtrl.text = pureName;
        } else {
          _selectedItemName = widget.initialItemName;
        }
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<RecordsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allItems = prov.getAllItemNames();

    if (allItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('暂无指标数据，请先录入或扫描复查化验单'),
          ],
        ),
      );
    }

    final bool canPop = Navigator.canPop(context);

    // 🌟 首次进入：结合当前单据栏目精准定位指标，并自动填充搜索词方便同名对比
    if (!_hasAppliedInitialItem && widget.initialItemName != null && widget.initialItemName!.isNotEmpty) {
      final resolved = _resolveTargetItemName(allItems, widget.initialItemName, widget.initialCategory);
      if (resolved != null) {
        _selectedItemName = resolved;
        String pureName = widget.initialItemName!.trim();
        if (pureName.startsWith('[') && pureName.contains(']')) {
          pureName = pureName.substring(pureName.indexOf(']') + 1).trim();
        }
        _searchKeyword = pureName;
        _searchCtrl.text = pureName;
      }
      _hasAppliedInitialItem = true;
    }

    // 若当前未选中或选中的不在可用指标中，再次执行智能解析
    if (_selectedItemName == null || !allItems.contains(_selectedItemName)) {
      final resolved = _resolveTargetItemName(allItems, widget.initialItemName, widget.initialCategory);
      if (resolved != null) {
        _selectedItemName = resolved;
      } else {
        final currentFiltered = prov.searchItemNames(_searchKeyword);
        _selectedItemName = currentFiltered.isNotEmpty ? currentFiltered.first : allItems.first;
      }
    }

    final filteredItems = prov.searchItemNames(_searchKeyword);

    final history = prov.getMetricHistory(_selectedItemName!);
    final bool isQualitativeProject = history.any((h) => h.isQualitative);

    // 提取最新的参考范围与上下限 (用于走势图基准线与参考区间展示)
    String standardRefRange = '';
    double? activeRefMin;
    double? activeRefMax;
    for (var h in history.reversed) {
      if (standardRefRange.isEmpty && h.referenceRange.trim().isNotEmpty) {
        standardRefRange = h.referenceRange.trim();
      }
      if (activeRefMin == null && h.refMin != null) {
        activeRefMin = h.refMin;
      }
      if (activeRefMax == null && h.refMax != null) {
        activeRefMax = h.refMax;
      }
      if (standardRefRange.isNotEmpty && (activeRefMin != null || activeRefMax != null)) {
        break;
      }
    }

    return Scaffold(
      appBar: canPop
          ? AppBar(
              title: Text(
                _selectedItemName != null ? '$_selectedItemName 走势' : '指标走势',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🌟 智能指标归拢整理入口
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFBBF7D0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.teal, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '同名/同义指标分散了？点击一键智能归拢合并历史走势',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : const Color(0xFF166534),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _isStandardizing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _runAiStandardization(context),
                          child: const Text('立即归拢', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                        ),
                ],
              ),
            ),

            // 1. 关键词即时搜索单独项目
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: '输入关键词搜索单独指标 (如: 尿蛋白、乙肝、肌酐、血糖、甲状腺)...',
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                    suffixIcon: _searchKeyword.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchKeyword = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchKeyword = val.trim();
                      final matched = prov.searchItemNames(_searchKeyword);
                      if (matched.isNotEmpty && !matched.contains(_selectedItemName)) {
                        _selectedItemName = matched.first;
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 搜索结果快捷标签栏 / 当前追踪指标选择器
            if (filteredItems.isNotEmpty) ...[
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filteredItems.length,
                  separatorBuilder: (c, i) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final name = filteredItems[index];
                    final isSelected = name == _selectedItemName;
                    return ChoiceChip(
                      label: Text(name, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      selected: isSelected,
                      selectedColor: isDark ? const Color(0xFF0284C7) : Colors.blue.shade600,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedItemName = name);
                      },
                    );
                  },
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text('未找到包含“$_searchKeyword”的指标，可重试其他关键词', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            const SizedBox(height: 14),

            if (history.isEmpty)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.grey, size: 36),
                        const SizedBox(height: 8),
                        Text('【$_selectedItemName】暂无历史记录', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              // 2. 走势图卡片 (数值型连续折线图 或 定性/阴阳性阶梯状态图)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isQualitativeProject ? Colors.teal : Colors.blueAccent,
                                  child: Icon(isQualitativeProject ? Icons.compare_arrows : Icons.show_chart, size: 16, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isQualitativeProject ? '$_selectedItemName 定性演变对比' : '$_selectedItemName 历史走势图',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (standardRefRange.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.verified_outlined, size: 12, color: Color(0xFF10B981)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '参考: $standardRefRange',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isQualitativeProject ? Colors.teal.withOpacity(0.15) : Colors.blue.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isQualitativeProject ? '定性/等级' : '单位: ${history.first.unit.isNotEmpty ? history.first.unit : "数值"}',
                                  style: TextStyle(fontSize: 11, color: isQualitativeProject ? Colors.teal : Colors.blueAccent, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      () {
                        final distinctOriginalNames = history.map((h) => h.originalItemName).where((n) => n.isNotEmpty).toSet();
                        if (distinctOriginalNames.length > 1) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blue.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.link, size: 12, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '已智能聚合跨期记录：${distinctOriginalNames.join("、")}',
                                      style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.touch_app_outlined, size: 13, color: Colors.blue.shade300),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '点击图表数据点或下方明细列表，可直接跳转并定位至对应的检查报告单',
                              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 220,
                        child: _buildLineChart(context, history, isDark, isQualitativeProject, activeRefMin, activeRefMax),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 3. 历次复查指标明细与【反向定位链接至大项目报告单】
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '历次检测明细与转归比对 (点击直达大报告单)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '共 ${history.length} 次记录',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  separatorBuilder: (c, i) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final dateStr = DateFormat('yyyy年MM月dd日').format(item.date);
                    final isAbnormal = item.status != 'normal' || (item.isQualitative && item.value > 0);

                    // 计算数值差值或定性转归
                    String diffStr = '';
                    if (item.isQualitative) {
                      diffStr = item.qualitativeChange;
                    } else if (index > 0) {
                      final prevVal = history[index - 1].value;
                      final diff = item.value - prevVal;
                      if (diff > 0) {
                        diffStr = ' (+${diff.toStringAsFixed(2)})';
                      } else if (diff < 0) {
                        diffStr = ' (${diff.toStringAsFixed(2)})';
                      } else {
                        diffStr = ' (持平)';
                      }
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      onTap: () {
                        // 🎯 核心跳转：点击指标直接跳转对应的检查单据报告单
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecordDetailScreen(
                              recordId: item.recordId,
                              initialCategory: item.parentCategory,
                            ),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        backgroundColor: isAbnormal ? Colors.red.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                        child: Icon(
                          isAbnormal ? (item.status == 'high' ? Icons.arrow_upward : Icons.priority_high) : Icons.check,
                          color: isAbnormal ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
                          size: 18,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.hospital,
                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // 醒目标注其对应的单据报告单
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.blue.withOpacity(0.35)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.description_outlined, size: 11, color: Colors.blueAccent),
                                      const SizedBox(width: 4),
                                      Text(
                                        '单据: ${item.parentCategory}',
                                        style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                // 🎯 重点：显示指标参考范围！
                                if (item.referenceRange.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: isDark ? const Color(0xFF475569) : Colors.grey.shade300),
                                    ),
                                    child: Text(
                                      '参考: ${item.referenceRange}',
                                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : Colors.black87),
                                    ),
                                  )
                                else if (standardRefRange.isNotEmpty)
                                  Text(
                                    '参考: $standardRefRange',
                                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                                  ),
                                if (item.originalItemName.isNotEmpty &&
                                    item.originalItemName.trim().toLowerCase() != _selectedItemName?.trim().toLowerCase())
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.purple.withOpacity(0.25)),
                                    ),
                                    child: Text(
                                      '原单: ${item.originalItemName}',
                                      style: const TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            if (item.notes.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text('备注: ${item.notes}', style: const TextStyle(fontSize: 11, color: Colors.amber), overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                item.valueStr.isNotEmpty ? '${item.valueStr} ${item.unit}' : '未注明',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isAbnormal
                                      ? (isDark ? const Color(0xFFFDA4AF) : Colors.red.shade700)
                                      : (isDark ? const Color(0xFF6EE7B7) : Colors.green.shade800),
                                ),
                              ),
                              if (diffStr.isNotEmpty)
                                Text(
                                  diffStr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: diffStr.contains('+') || diffStr.contains('转阳') || diffStr.contains('加重')
                                        ? Colors.redAccent
                                        : (diffStr.contains('转阴') || diffStr.contains('好转') ? Colors.green : Colors.grey),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(
    BuildContext context,
    List<MetricHistoryPoint> history,
    bool isDark,
    bool isQualitative,
    double? activeRefMin,
    double? activeRefMax,
  ) {
    if (history.isEmpty) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i].value));
    }

    final values = history.map((e) => e.value).toList();
    double minY = values.reduce((a, b) => a < b ? a : b);
    double maxY = values.reduce((a, b) => a > b ? a : b);

    if (isQualitative) {
      minY = 0;
      maxY = maxY < 3 ? 3 : maxY + 1;
    } else {
      if (activeRefMin != null && activeRefMin < minY) {
        minY = activeRefMin;
      }
      if (activeRefMax != null && activeRefMax > maxY) {
        maxY = activeRefMax;
      }
      if (minY == maxY) {
        minY = minY * 0.8;
        maxY = maxY * 1.2;
      } else {
        final pad = (maxY - minY) * 0.15;
        minY = (minY - pad) > 0 ? (minY - pad) : 0;
        maxY = maxY + pad;
      }
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (history.length - 1).toDouble() > 0 ? (history.length - 1).toDouble() : 1,
        minY: minY,
        maxY: maxY,
        // 🎯 核心：在图表内绘制标准参考范围上下限辅助虚线与标识
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (!isQualitative && activeRefMin != null)
              HorizontalLine(
                y: activeRefMin,
                color: const Color(0xFF10B981).withOpacity(0.55),
                strokeWidth: 1.2,
                dashArray: [5, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 6, bottom: 2),
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold),
                  labelResolver: (_) => '参考下限 $activeRefMin',
                ),
              ),
            if (!isQualitative && activeRefMax != null)
              HorizontalLine(
                y: activeRefMax,
                color: const Color(0xFF10B981).withOpacity(0.55),
                strokeWidth: 1.2,
                dashArray: [5, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.only(right: 6, top: 2),
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold),
                  labelResolver: (_) => '参考上限 $activeRefMax',
                ),
              ),
          ],
        ),
        // 🎯 核心：点击图表上的任意数据点，直接跳转定位到对应的检查报告单
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => isDark ? const Color(0xFF1E293B) : Colors.white,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                if (idx < 0 || idx >= history.length) return null;
                final pt = history[idx];
                final dateStr = DateFormat('yyyy-MM-dd').format(pt.date);
                final refStr = pt.referenceRange.isNotEmpty ? '\n参考: ${pt.referenceRange}' : '';
                return LineTooltipItem(
                  '$dateStr\n${pt.parentCategory}: ${pt.valueStr} ${pt.unit}$refStr\n[点击跳转报告单 ➔]',
                  TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
          touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
            if (event is FlTapUpEvent &&
                touchResponse != null &&
                touchResponse.lineBarSpots != null &&
                touchResponse.lineBarSpots!.isNotEmpty) {
              final spotIdx = touchResponse.lineBarSpots!.first.spotIndex;
              if (spotIdx >= 0 && spotIdx < history.length) {
                final targetItem = history[spotIdx];
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecordDetailScreen(
                      recordId: targetItem.recordId,
                      initialCategory: targetItem.parentCategory,
                    ),
                  ),
                );
              }
            }
          },
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: isQualitative ? 1 : ((maxY - minY) / 4 > 0 ? (maxY - minY) / 4 : 1),
          getDrawingHorizontalLine: (val) => FlLine(
            color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: isQualitative ? 46 : 42,
              getTitlesWidget: (val, meta) {
                if (isQualitative) {
                  if (val == 0) return _buildQualitativeLabel('阴性', Colors.green);
                  if (val == 0.5) return _buildQualitativeLabel('±', Colors.amber);
                  if (val == 1) return _buildQualitativeLabel('1+/阳', Colors.orange);
                  if (val == 2) return _buildQualitativeLabel('2+', Colors.redAccent);
                  if (val >= 3) return _buildQualitativeLabel('3+~4+', Colors.red);
                  return const Text('');
                }
                return Text(
                  val.toStringAsFixed(1),
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx >= 0 && idx < history.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      DateFormat('MM/dd').format(history[idx].date),
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: !isQualitative,
            isStepLineChart: isQualitative,
            color: isQualitative ? const Color(0xFF14B8A6) : const Color(0xFF38BDF8),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final isAb = history[index].status != 'normal' || (isQualitative && history[index].value > 0);
                return FlDotCirclePainter(
                  radius: isAb ? 5.5 : 4,
                  color: isAb ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  (isQualitative ? const Color(0xFF14B8A6) : const Color(0xFF38BDF8)).withOpacity(0.35),
                  (isQualitative ? const Color(0xFF14B8A6) : const Color(0xFF38BDF8)).withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualitativeLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
    );
  }
}
