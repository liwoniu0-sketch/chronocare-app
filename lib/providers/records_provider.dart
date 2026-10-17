import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/disease.dart';
import '../models/record.dart';
import '../models/check_item.dart';
import '../models/category_group.dart';
import '../models/medication_plan.dart';
import '../models/consultation_question.dart';
import '../models/medication_inventory.dart';
import '../services/storage_service.dart';
import '../services/image_storage_service.dart';
import '../services/medical_metric_service.dart';

class MetricHistoryPoint {
  final DateTime date;
  final String hospital;
  final double value;
  final String valueStr;
  final String unit;
  final String referenceRange; // 参考范围，如 "3.5-9.5" 或 "阴性"
  final double? refMin; // 参考下限
  final double? refMax; // 参考上限
  final String status;
  final String notes;
  final String recordId;
  final String parentCategory; // 对应的检查栏目/大报告单名称
  final String diseaseName;
  final bool isQualitative;
  final String qualitativeChange;
  final String originalItemName; // 原始化验单指标名称

  MetricHistoryPoint({
    required this.date,
    required this.hospital,
    required this.value,
    required this.valueStr,
    required this.unit,
    this.referenceRange = '',
    this.refMin,
    this.refMax,
    required this.status,
    required this.notes,
    required this.recordId,
    required this.parentCategory,
    this.diseaseName = '',
    this.isQualitative = false,
    this.qualitativeChange = '',
    this.originalItemName = '',
  });
}

class MedicationComparisonGroup {
  final DateTime date;
  final List<MedicationPlanWithDiff> items;
  MedicationComparisonGroup({required this.date, required this.items});
}

class MedicationPlanWithDiff {
  final MedicationPlan plan;
  final String diffTag;
  final MedicationPlan? previousPlan;
  MedicationPlanWithDiff({required this.plan, required this.diffTag, this.previousPlan});
}

/// 同一种药物的聚合档案与完整剂量演变走势
class MedicationDrugTimeline {
  final String medicineName;
  final String diseaseId;
  final String diseaseName;
  final String currentStatus; // active, stopped
  final String latestDosage;
  final String latestFrequency;
  final DateTime latestDate;
  final DateTime firstDate;
  final List<MedicationAdjustmentPoint> historyPoints;

  MedicationDrugTimeline({
    required this.medicineName,
    required this.diseaseId,
    required this.diseaseName,
    required this.currentStatus,
    required this.latestDosage,
    required this.latestFrequency,
    required this.latestDate,
    required this.firstDate,
    required this.historyPoints,
  });
}

/// 单次剂量调整点 (用于绘制走势图与时间线对比)
class MedicationAdjustmentPoint {
  final String id;
  final DateTime date;
  final String dosageStr;
  final double numericDosage; // 解析出的剂量数字 (如 0.5)
  final String unit; // 解析出的剂量单位 (如 g, mg, 片, μg)
  final String frequency;
  final String changeType; // new, increase, decrease, stop, maintain, switch
  final String reason;
  final String notes;
  final String diffFromPrevious; // 如 "+0.25g (加量 🔺)", "-1片 (减量 🔻)", "首次开具 🟢"

  MedicationAdjustmentPoint({
    required this.id,
    required this.date,
    required this.dosageStr,
    required this.numericDosage,
    required this.unit,
    required this.frequency,
    required this.changeType,
    required this.reason,
    required this.notes,
    required this.diffFromPrevious,
  });
}

class QuestionsByDateGroup {
  final DateTime date;
  final List<ConsultationQuestion> questions;
  final List<ConsultationQuestion> previousDateQuestions;
  QuestionsByDateGroup({
    required this.date,
    required this.questions,
    this.previousDateQuestions = const [],
  });
}

class RecordsProvider with ChangeNotifier {
  List<Disease> _diseases = [];
  List<CheckRecord> _records = [];
  List<CategoryGroup> _categoryGroups = [];
  List<MedicationPlan> _medicationPlans = [];
  List<ConsultationQuestion> _consultationQuestions = [];
  List<MedicationInventory> _medicationInventories = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String _selectedDiseaseId = '';
  String _selectedCategory = '';

  List<Disease> get diseases => _diseases;
  List<CheckRecord> get records => _records;
  List<CategoryGroup> get categoryGroups => _categoryGroups;
  List<MedicationPlan> get medicationPlans => _medicationPlans;
  List<ConsultationQuestion> get consultationQuestions => _consultationQuestions;
  List<MedicationInventory> get medicationInventories => _medicationInventories;
  List<MedicationInventory> get shortageInventories => _medicationInventories.where((i) => i.isShortage).toList();
  int get shortageCount => shortageInventories.length;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedDiseaseId => _selectedDiseaseId;
  String get selectedCategory => _selectedCategory;

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    _diseases = await StorageService.instance.getDiseases();
    _records = await StorageService.instance.getRecords();
    _categoryGroups = await StorageService.instance.getCategoryGroups();
    _medicationPlans = await StorageService.instance.getMedicationPlans();
    _consultationQuestions = await StorageService.instance.getConsultationQuestions();
    _medicationInventories = await StorageService.instance.getMedicationInventories();

    if (_diseases.isEmpty) {
      final defaultDisease = Disease(
        id: 'dis_default_01',
        name: '慢病综合管理档案',
        stage: '随访监测期',
        colorHex: '#2563EB',
        targetNotes: '保持各项指标平稳，定期复查',
      );
      await StorageService.instance.saveDisease(defaultDisease);
      _diseases.add(defaultDisease);
    }

    _isLoading = false;
    notifyListeners();

    // 后台静默执行化验单原图自愈与永久化抢救迁移，确保图片永不丢失
    _autoHealAndMigrateImages();
  }

  Future<void> _autoHealAndMigrateImages() async {
    try {
      final settings = await StorageService.instance.getSettings();
      await ImageStorageService.instance.healAndMigrateAllRecords(
        records: _records,
        onSaveRecord: (updated) async {
          await StorageService.instance.saveRecord(updated);
        },
        customBackupPath: settings.customLocalImagesPath,
      );
    } catch (e) {
      debugPrint('自动自愈化验单图片路径异常: $e');
    }
  }

  List<CheckRecord> getFilteredRecords({String sortOrder = 'date_desc'}) {
    var list = List<CheckRecord>.from(_records);

    if (_selectedDiseaseId.isNotEmpty) {
      list = list.where((r) => r.diseaseId == _selectedDiseaseId).toList();
    }

    if (_selectedCategory.isNotEmpty) {
      list = list.where((r) => r.category == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) {
        final matchHospital = r.hospital.toLowerCase().contains(q);
        final matchAdvice = r.doctorAdvice.toLowerCase().contains(q);
        final matchNotes = r.overallNotes.toLowerCase().contains(q);
        final matchItems = r.items.any((i) =>
            i.itemName.toLowerCase().contains(q) ||
            i.value.toLowerCase().contains(q) ||
            i.notes.toLowerCase().contains(q));
        final matchMeds = r.medicationChanges.any((m) =>
            m.medicineName.toLowerCase().contains(q) ||
            m.reason.toLowerCase().contains(q));
        return matchHospital || matchAdvice || matchNotes || matchItems || matchMeds;
      }).toList();
    }

    if (sortOrder == 'date_desc') {
      list.sort((a, b) => b.checkDate.compareTo(a.checkDate));
    } else {
      list.sort((a, b) => a.checkDate.compareTo(b.checkDate));
    }

    return list;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedDiseaseId(String id) {
    _selectedDiseaseId = id;
    notifyListeners();
  }

  void setSelectedCategory(String cat) {
    _selectedCategory = cat;
    notifyListeners();
  }

  Disease? getDiseaseById(String id) {
    try {
      return _diseases.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDisease(Disease disease) async {
    await StorageService.instance.saveDisease(disease);
    final idx = _diseases.indexWhere((d) => d.id == disease.id);
    if (idx >= 0) {
      _diseases[idx] = disease;
    } else {
      _diseases.add(disease);
    }
    notifyListeners();
  }

  Future<void> addOrUpdateDisease(Disease disease) async {
    await saveDisease(disease);
  }

  Future<void> deleteDisease(String id) async {
    await StorageService.instance.deleteDisease(id);
    _diseases.removeWhere((d) => d.id == id);
    _medicationPlans.removeWhere((m) => m.diseaseId == id);
    _consultationQuestions.removeWhere((q) => q.diseaseId == id);
    notifyListeners();
  }

  Future<void> saveRecord(CheckRecord record) async {
    await StorageService.instance.saveRecord(record);
    final idx = _records.indexWhere((r) => r.id == record.id);
    if (idx >= 0) {
      _records[idx] = record;
    } else {
      _records.add(record);
    }
    notifyListeners();
  }

  Future<void> deleteRecord(String id) async {
    await StorageService.instance.deleteRecord(id);
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  Future<void> mergeOrSaveRecordByDate(CheckRecord newRecord) async {
    final newDateStr = DateFormat('yyyy-MM-dd').format(newRecord.checkDate);

    CheckRecord? existing;
    for (var r in _records) {
      final curDateStr = DateFormat('yyyy-MM-dd').format(r.checkDate);
      if (curDateStr == newDateStr) {
        if (newRecord.diseaseId.isEmpty || r.diseaseId == newRecord.diseaseId) {
          existing = r;
          break;
        }
      }
    }

    if (existing == null) {
      await saveRecord(newRecord);
      return;
    }

    final List<String> allImages = List.from(existing.imagePaths);
    for (var img in newRecord.imagePaths) {
      if (img.isNotEmpty && !allImages.contains(img)) {
        allImages.add(img);
      }
    }
    existing.imagePaths = allImages;

    // 以 [栏目分类 + 指标名称] 复合唯一键进行智能合并，避免不同化验单同名指标误覆盖
    final Map<String, CheckItem> itemMap = {};
    for (var it in existing.items) {
      final key = '${it.category.trim()}_${it.itemName.trim()}';
      itemMap[key] = it;
    }
    for (var it in newRecord.items) {
      final key = '${it.category.trim()}_${it.itemName.trim()}';
      if (itemMap.containsKey(key)) {
        final ex = itemMap[key]!;
        if (ex.value != it.value) {
          itemMap[key] = it;
        }
      } else {
        itemMap[key] = it;
      }
    }
    existing.items = itemMap.values.toList();

    if (newRecord.doctorAdvice.isNotEmpty) {
      if (existing.doctorAdvice.isEmpty) {
        existing.doctorAdvice = newRecord.doctorAdvice;
      } else if (!existing.doctorAdvice.contains(newRecord.doctorAdvice)) {
        existing.doctorAdvice = '${existing.doctorAdvice}\n${newRecord.doctorAdvice}';
      }
    }

    if (existing.hospital.isEmpty && newRecord.hospital.isNotEmpty) {
      existing.hospital = newRecord.hospital;
    }
    if (existing.department.isEmpty && newRecord.department.isNotEmpty) {
      existing.department = newRecord.department;
    }
    if (existing.doctorName.isEmpty && newRecord.doctorName.isNotEmpty) {
      existing.doctorName = newRecord.doctorName;
    }

    await saveRecord(existing);
  }

  Future<void> mergeCategoriesInRecord(String recordId, String fromCategory, String toCategory) async {
    final idx = _records.indexWhere((r) => r.id == recordId);
    if (idx < 0) return;

    final record = _records[idx];
    for (var it in record.items) {
      if (it.category.trim() == fromCategory.trim()) {
        it.category = toCategory.trim();
      }
    }

    await saveRecord(record);
  }

  Future<void> saveCategoryGroup(CategoryGroup group) async {
    await StorageService.instance.saveCategoryGroup(group);
    final idx = _categoryGroups.indexWhere((g) => g.id == group.id);
    if (idx >= 0) {
      _categoryGroups[idx] = group;
    } else {
      _categoryGroups.add(group);
    }
    notifyListeners();
  }

  Future<void> deleteCategoryGroup(String id) async {
    await StorageService.instance.deleteCategoryGroup(id);
    _categoryGroups.removeWhere((g) => g.id == id);
    notifyListeners();
  }

  Future<void> moveItemToGroup(String itemName, String targetGroupId) async {
    for (var g in _categoryGroups) {
      if (g.matchedItemNames.contains(itemName)) {
        g.matchedItemNames.remove(itemName);
        await StorageService.instance.saveCategoryGroup(g);
      }
    }

    if (targetGroupId.isNotEmpty) {
      final target = _categoryGroups.firstWhere((g) => g.id == targetGroupId);
      if (!target.matchedItemNames.contains(itemName)) {
        target.matchedItemNames.add(itemName);
        await StorageService.instance.saveCategoryGroup(target);
      }
    }
    notifyListeners();
  }

  List<String> getAllItemNames() {
    // 1. 统计每个指标在所有复查单据中出现的规范化栏目分类与标准医学名称
    final Map<String, Set<String>> canonicalNameToCategories = {};
    for (var r in _records) {
      final rawRecCat = r.category.trim();
      final normRecCat = MedicalMetricService.instance.normalizeCategory(rawRecCat);

      for (var it in r.items) {
        final rawName = it.itemName.trim();
        if (rawName.isEmpty) continue;

        final rawItemCat = it.category.trim().isNotEmpty ? it.category.trim() : rawRecCat;
        final normItemCat = MedicalMetricService.instance.normalizeCategory(rawItemCat);

        // 智能获取权威标准显示名 (如将 WBC/白细胞 统一定位为 白细胞计数 (WBC))
        final stdName = MedicalMetricService.instance.getStandardDisplayName(rawName, category: normItemCat);
        canonicalNameToCategories.putIfAbsent(stdName, () => {}).add(normItemCat);
      }
    }

    final Set<String> names = {};
    for (var entry in canonicalNameToCategories.entries) {
      final name = entry.key;
      final cats = entry.value;
      if (cats.length > 1) {
        // 跨不同大类的同名指标（如尿常规 vs 血常规），带上收敛后的规范大类前缀
        for (var cat in cats) {
          names.add('[$cat] $name');
        }
      } else {
        names.add(name);
      }
    }
    return names.toList()..sort();
  }

  List<String> searchItemNames(String query) {
    final all = getAllItemNames();
    final rawQ = query.trim().toLowerCase();
    if (rawQ.isEmpty) return all;

    // 分割字符集（过滤掉空格）与分词
    final qChars = rawQ.replaceAll(RegExp(r'\s+'), '').split('');
    final qWords = rawQ.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    // 智能子序列匹配：判断 chars 是否按顺序出现在 target 中 (如 "尿血" 按序出现在 "尿隐血" 中)
    bool isSubsequence(String target, List<String> chars) {
      if (chars.isEmpty) return false;
      int charIdx = 0;
      for (int i = 0; i < target.length && charIdx < chars.length; i++) {
        if (target[i] == chars[charIdx]) {
          charIdx++;
        }
      }
      return charIdx == chars.length;
    }

    final List<MapEntry<String, int>> scored = [];

    for (var name in all) {
      final nameLower = name.toLowerCase();
      String coreName = nameLower;
      if (coreName.startsWith('[') && coreName.contains(']')) {
        coreName = coreName.substring(coreName.indexOf(']') + 1).trim();
      }

      int score = 0;
      if (coreName == rawQ) {
        score = 120; // 核心指标完全相等
      } else if (coreName.startsWith(rawQ)) {
        score = 110; // 核心指标以关键词开头
      } else if (coreName.contains(rawQ)) {
        score = 100; // 核心指标连续包含关键词
      } else if (nameLower.contains(rawQ)) {
        score = 90; // 含单据大类连续包含关键词
      } else if (qWords.length > 1 && qWords.every((w) => nameLower.contains(w))) {
        score = 85; // 多词同时包含 (如 "尿 隐血")
      } else if (isSubsequence(coreName, qChars)) {
        score = 80; // 核心指标按序拆字子序列 (如搜 "尿血" 命中 "尿隐血")
      } else if (isSubsequence(nameLower, qChars)) {
        score = 70; // 完整名称按序拆字子序列
      } else if (qChars.length >= 2 && qChars.every((c) => coreName.contains(c))) {
        score = 60; // 核心指标包含所有字符 (支持字序颠倒)
      } else if (qChars.length >= 2 && qChars.every((c) => nameLower.contains(c))) {
        score = 50; // 完整名称包含所有字符
      }

      if (score > 0) {
        scored.add(MapEntry(name, score));
      }
    }

    // 按匹配质量高低排序，同分保留原有顺序
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  List<MetricHistoryPoint> getMetricHistory(String itemName) {
    final List<MetricHistoryPoint> rawPoints = [];
    final target = itemName.trim();

    // 🌟 1. 解析单据前缀：例如 [血常规] 白细胞计数 (WBC)
    String? filterCategory;
    String cleanItemName = target;
    if (target.startsWith('[') && target.contains(']')) {
      final closeIdx = target.indexOf(']');
      filterCategory = target.substring(1, closeIdx).trim().toLowerCase();
      cleanItemName = target.substring(closeIdx + 1).trim();
    }
    final targetNameLower = cleanItemName.toLowerCase();

    // 🌟 2. 获取该目标指标的所有同义词、别名与中英文缩写集合 (例如 WBC、白细胞、白细胞计数、leukocyte 等)
    final synonyms = MedicalMetricService.instance.getMetricSynonyms(
      cleanItemName,
      category: filterCategory,
    );

    for (var r in _records) {
      final dis = getDiseaseById(r.diseaseId);
      final rawRecCat = r.category.trim();

      for (var it in r.items) {
        final rawItemName = it.itemName.trim();
        final rawItemNameLower = rawItemName.toLowerCase();
        final rawItemCat = it.category.trim().isNotEmpty ? it.category.trim() : rawRecCat;
        final normItemCat = MedicalMetricService.instance.normalizeCategory(rawItemCat).toLowerCase();

        // 🌟 3. 核心智能判定：字面匹配 OR 命中医学同义词库 OR 规范名一致
        bool isMatch = (rawItemNameLower == targetNameLower) || synonyms.contains(rawItemNameLower);
        if (!isMatch) {
          final itStandard = MedicalMetricService.instance.findStandardMetric(rawItemName, category: normItemCat);
          if (itStandard != null && synonyms.contains(itStandard.standardName.toLowerCase())) {
            isMatch = true;
          }
        }

        if (!isMatch) continue;

        // 若指定了单据分类前缀，则严格比对规范化后的单据分类
        if (filterCategory != null && filterCategory.isNotEmpty) {
          if (normItemCat != filterCategory &&
              !normItemCat.contains(filterCategory) &&
              !filterCategory.contains(normItemCat)) {
            continue;
          }
        }

        double? val = it.numericValue;
        bool isQualitative = false;

        if (val == null) {
          final match = RegExp(r'[-+]?[0-9]*\.?[0-9]+').firstMatch(it.value);
          if (match != null) {
            val = double.tryParse(match.group(0)!);
          }
        }

        if (val == null) {
          isQualitative = true;
          final vStr = it.value.trim().toLowerCase();
          if (vStr.contains('阴') || vStr.contains('(-)') || vStr == '-' || vStr.contains('未见') || vStr.contains('正常')) {
            val = 0.0;
          } else if (vStr.contains('±') || vStr.contains('弱阳') || vStr.contains('可疑')) {
            val = 0.5;
          } else if (vStr.contains('4+') || vStr.contains('++++')) {
            val = 4.0;
          } else if (vStr.contains('3+') || vStr.contains('+++')) {
            val = 3.0;
          } else if (vStr.contains('2+') || vStr.contains('++')) {
            val = 2.0;
          } else if (vStr.contains('1+') || vStr.contains('+') || vStr.contains('阳') || vStr.contains('异常')) {
            val = 1.0;
          } else {
            val = 0.0;
          }
        }

        rawPoints.add(MetricHistoryPoint(
          date: r.checkDate,
          hospital: r.hospital.isNotEmpty ? r.hospital : '未注明医院',
          value: val,
          valueStr: it.value.isNotEmpty ? it.value : '未注明',
          unit: it.unit,
          referenceRange: it.referenceRange,
          refMin: it.refMin,
          refMax: it.refMax,
          status: it.status,
          notes: it.notes,
          recordId: r.id,
          parentCategory: it.category.isNotEmpty ? it.category : (r.category.isNotEmpty ? r.category : '常规化验单'),
          diseaseName: dis?.name ?? '',
          isQualitative: isQualitative,
          originalItemName: it.itemName,
        ));
      }
    }

    rawPoints.sort((a, b) => a.date.compareTo(b.date));

    final List<MetricHistoryPoint> finalPoints = [];
    for (int i = 0; i < rawPoints.length; i++) {
      final cur = rawPoints[i];
      String change = '';
      if (i > 0) {
        final prev = rawPoints[i - 1];
        if (cur.isQualitative || prev.isQualitative) {
          if (cur.value < prev.value) {
            change = cur.value == 0 ? '转阴 🟢' : '好转/减弱 🔻';
          } else if (cur.value > prev.value) {
            change = prev.value == 0 ? '转阳 🔴' : '加重/增强 🔺';
          } else {
            change = cur.value == 0 ? '持续阴性 ⚪' : '维持原样 ⚪';
          }
        }
      }

      finalPoints.add(MetricHistoryPoint(
        date: cur.date,
        hospital: cur.hospital,
        value: cur.value,
        valueStr: cur.valueStr,
        unit: cur.unit,
        referenceRange: cur.referenceRange,
        refMin: cur.refMin,
        refMax: cur.refMax,
        status: cur.status,
        notes: cur.notes,
        recordId: cur.recordId,
        parentCategory: cur.parentCategory,
        diseaseName: cur.diseaseName,
        isQualitative: cur.isQualitative,
        qualitativeChange: change,
      ));
    }

    return finalPoints;
  }

  // =========================================================================
  // --- 💊 慢病药物记录：同种药物聚合档案与剂量调整走势图 ---
  // =========================================================================

  Future<void> saveMedicationPlan(MedicationPlan plan) async {
    await StorageService.instance.saveMedicationPlan(plan);
    final idx = _medicationPlans.indexWhere((m) => m.id == plan.id);
    if (idx >= 0) {
      _medicationPlans[idx] = plan;
    } else {
      _medicationPlans.add(plan);
    }
    notifyListeners();
  }

  Future<void> deleteMedicationPlan(String id) async {
    await StorageService.instance.deleteMedicationPlan(id);
    _medicationPlans.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  /// 提取同一种药物的所有调药记录，聚合成独立档案并生成剂量时序走势
  List<MedicationDrugTimeline> getAggregatedMedicationTimelines({
    String searchQuery = '',
    String diseaseId = '',
  }) {
    var list = List<MedicationPlan>.from(_medicationPlans);
    if (diseaseId.isNotEmpty) {
      list = list.where((m) => m.diseaseId == diseaseId).toList();
    }

    // 按药品名称分组
    final Map<String, List<MedicationPlan>> groupedByName = {};
    for (var m in list) {
      final name = m.medicineName.trim();
      if (name.isEmpty) continue;
      groupedByName.putIfAbsent(name, () => []).add(m);
    }

    final List<MedicationDrugTimeline> timelines = [];

    for (var entry in groupedByName.entries) {
      final medName = entry.key;
      final rawPlans = entry.value;

      // 关键词搜索过滤
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        if (!medName.toLowerCase().contains(q) &&
            !rawPlans.any((p) => p.reason.toLowerCase().contains(q) || p.notes.toLowerCase().contains(q))) {
          continue;
        }
      }

      // 按日期升序排列，以便计算剂量前后变化
      rawPlans.sort((a, b) => a.date.compareTo(b.date));

      final List<MedicationAdjustmentPoint> points = [];
      double prevNumDosage = 0.0;

      for (int i = 0; i < rawPlans.length; i++) {
        final cur = rawPlans[i];
        final parsed = _parseDosageNumeric(cur.dosage);

        String diff = '维持方案 ⚪';
        if (i == 0) {
          diff = '初始用药方案 🟢';
        } else {
          final prev = rawPlans[i - 1];
          if (cur.status == 'stopped' || cur.changeType == 'stop') {
            diff = '遵医嘱停药 🔴';
          } else if (parsed.value > prevNumDosage && prevNumDosage > 0) {
            final delta = parsed.value - prevNumDosage;
            diff = '加量 +${delta.toStringAsFixed(2)}${parsed.unit} 🔺';
          } else if (parsed.value < prevNumDosage && prevNumDosage > 0) {
            final delta = prevNumDosage - parsed.value;
            diff = '减量 -${delta.toStringAsFixed(2)}${parsed.unit} 🔻';
          } else if (cur.dosage != prev.dosage || cur.frequency != prev.frequency) {
            diff = '频次/剂型调整 🔄';
          }
        }

        prevNumDosage = parsed.value;

        points.add(MedicationAdjustmentPoint(
          id: cur.id,
          date: cur.date,
          dosageStr: cur.dosage.isNotEmpty ? cur.dosage : '未注明',
          numericDosage: parsed.value,
          unit: parsed.unit,
          frequency: cur.frequency.isNotEmpty ? cur.frequency : '未注明',
          changeType: cur.changeType,
          reason: cur.reason,
          notes: cur.notes,
          diffFromPrevious: diff,
        ));
      }

      final latest = rawPlans.last;
      final dis = getDiseaseById(latest.diseaseId);

      timelines.add(MedicationDrugTimeline(
        medicineName: medName,
        diseaseId: latest.diseaseId,
        diseaseName: dis?.name ?? '',
        currentStatus: latest.status,
        latestDosage: latest.dosage,
        latestFrequency: latest.frequency,
        latestDate: latest.date,
        firstDate: rawPlans.first.date,
        historyPoints: points, // 按时间正序排列
      ));
    }

    // 默认按最新调药日期倒序排列（最近调整的药物排在最前）
    timelines.sort((a, b) => b.latestDate.compareTo(a.latestDate));
    return timelines;
  }

  /// 智能解析剂量字符串中的数值与单位 (如 "0.5g", "500mg", "1片", "50μg")
  _ParsedDosage _parseDosageNumeric(String dosage) {
    if (dosage.isEmpty) return _ParsedDosage(1.0, '');
    final match = RegExp(r'[-+]?[0-9]*\.?[0-9]+').firstMatch(dosage);
    if (match != null) {
      final numVal = double.tryParse(match.group(0)!) ?? 1.0;
      final unit = dosage.replaceAll(match.group(0)!, '').replaceAll('/', '').replaceAll('次', '').trim();
      return _ParsedDosage(numVal, unit.isNotEmpty ? unit : '剂量');
    }
    return _ParsedDosage(1.0, '剂量');
  }

  /// 获取按日期分组且携带与上一次日期自动比对的用药记录 (供日期流水视图使用)
  List<MedicationComparisonGroup> getMedicationComparisonGroups({String diseaseId = ''}) {
    var list = List<MedicationPlan>.from(_medicationPlans);
    if (diseaseId.isNotEmpty) {
      list = list.where((m) => m.diseaseId == diseaseId).toList();
    }

    list.sort((a, b) => a.date.compareTo(b.date));

    final Map<String, List<MedicationPlan>> groupedByDate = {};
    for (var m in list) {
      final dateKey = DateFormat('yyyy-MM-dd').format(m.date);
      groupedByDate.putIfAbsent(dateKey, () => []).add(m);
    }

    final sortedDateKeys = groupedByDate.keys.toList()..sort();
    final List<MedicationComparisonGroup> groups = [];

    for (int i = 0; i < sortedDateKeys.length; i++) {
      final dateKey = sortedDateKeys[i];
      final currentPlans = groupedByDate[dateKey]!;
      final currentDateTime = currentPlans.first.date;

      final List<MedicationPlanWithDiff> itemsWithDiff = [];

      List<MedicationPlan> prevPlans = [];
      if (i > 0) {
        final prevDateKey = sortedDateKeys[i - 1];
        prevPlans = groupedByDate[prevDateKey]!;
      }

      for (var plan in currentPlans) {
        final prevMatch = prevPlans.where(
          (p) => p.medicineName.trim().toLowerCase() == plan.medicineName.trim().toLowerCase(),
        ).toList();

        String diffTag = '维持原方案 ⚪';
        MedicationPlan? prevPlan;

        if (prevMatch.isEmpty) {
          diffTag = '本次新开药物 🟢';
        } else {
          prevPlan = prevMatch.first;
          if (plan.dosage != prevPlan.dosage || plan.frequency != prevPlan.frequency) {
            diffTag = '剂量/频次调整 🔄 (前次: ${prevPlan.dosage} ${prevPlan.frequency})';
          } else if (plan.changeType == 'stop' || plan.status == 'stopped') {
            diffTag = '已停用 🔴';
          } else {
            diffTag = '遵医嘱维持 ⚪';
          }
        }

        itemsWithDiff.add(MedicationPlanWithDiff(
          plan: plan,
          diffTag: diffTag,
          previousPlan: prevPlan,
        ));
      }

      groups.add(MedicationComparisonGroup(
        date: currentDateTime,
        items: itemsWithDiff,
      ));
    }

    return groups.reversed.toList();
  }

  // =========================================================================
  // --- 📝 复查提问备忘录与历史解答前后对比 ---
  // =========================================================================

  Future<void> saveConsultationQuestion(ConsultationQuestion q) async {
    await StorageService.instance.saveConsultationQuestion(q);
    final idx = _consultationQuestions.indexWhere((item) => item.id == q.id);
    if (idx >= 0) {
      _consultationQuestions[idx] = q;
    } else {
      _consultationQuestions.add(q);
    }
    notifyListeners();
  }

  Future<void> toggleQuestionAskedStatus(String questionId) async {
    final idx = _consultationQuestions.indexWhere((q) => q.id == questionId);
    if (idx >= 0) {
      final cur = _consultationQuestions[idx];
      cur.isAsked = !cur.isAsked;
      await saveConsultationQuestion(cur);
    }
  }

  Future<void> deleteConsultationQuestion(String id) async {
    await StorageService.instance.deleteConsultationQuestion(id);
    _consultationQuestions.removeWhere((q) => q.id == id);
    notifyListeners();
  }

  List<QuestionsByDateGroup> getQuestionsGroupedByDate({String diseaseId = ''}) {
    var list = List<ConsultationQuestion>.from(_consultationQuestions);
    if (diseaseId.isNotEmpty) {
      list = list.where((q) => q.diseaseId == diseaseId).toList();
    }

    list.sort((a, b) => a.targetDate.compareTo(b.targetDate));

    final Map<String, List<ConsultationQuestion>> grouped = {};
    for (var q in list) {
      final dateKey = DateFormat('yyyy-MM-dd').format(q.targetDate);
      grouped.putIfAbsent(dateKey, () => []).add(q);
    }

    final sortedDateKeys = grouped.keys.toList()..sort();
    final List<QuestionsByDateGroup> groups = [];

    for (int i = 0; i < sortedDateKeys.length; i++) {
      final dateKey = sortedDateKeys[i];
      final currentQuestions = grouped[dateKey]!;
      final currentDateTime = currentQuestions.first.targetDate;

      List<ConsultationQuestion> prevQuestions = [];
      if (i > 0) {
        final prevDateKey = sortedDateKeys[i - 1];
        prevQuestions = grouped[prevDateKey]!;
      }

      groups.add(QuestionsByDateGroup(
        date: currentDateTime,
        questions: currentQuestions,
        previousDateQuestions: prevQuestions,
      ));
    }

    return groups.reversed.toList();
  }

  // =========================================================================
  // --- 💊 药箱存量管理与缺药智能预警 ---
  // =========================================================================

  Future<void> saveMedicationInventory(MedicationInventory item) async {
    await StorageService.instance.saveMedicationInventory(item);
    final idx = _medicationInventories.indexWhere((i) => i.id == item.id);
    if (idx >= 0) {
      _medicationInventories[idx] = item;
    } else {
      _medicationInventories.insert(0, item);
    }
    notifyListeners();
  }

  Future<void> deleteMedicationInventory(String id) async {
    await StorageService.instance.deleteMedicationInventory(id);
    _medicationInventories.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  Future<void> batchImportMedicationInventories(List<MedicationInventory> items) async {
    for (var item in items) {
      await StorageService.instance.saveMedicationInventory(item);
      final idx = _medicationInventories.indexWhere((i) => i.medicineName.trim() == item.medicineName.trim() || i.id == item.id);
      if (idx >= 0) {
        _medicationInventories[idx] = item;
      } else {
        _medicationInventories.insert(0, item);
      }
    }
    notifyListeners();
  }

  Future<void> updateInventoryStock(String id, double delta) async {
    final idx = _medicationInventories.indexWhere((i) => i.id == id);
    if (idx >= 0) {
      final cur = _medicationInventories[idx];
      final newStock = (cur.currentStock + delta) > 0 ? (cur.currentStock + delta) : 0.0;
      cur.currentStock = newStock;
      cur.updatedAt = DateTime.now();
      await StorageService.instance.saveMedicationInventory(cur);
      notifyListeners();
    }
  }

  // =========================================================================
  // --- 🧬 智能指标归一化与全量历史数据对齐中枢 ---
  // =========================================================================

  /// 全局多维指标智能研判与自动对齐对并器 (综合指标名、单据栏目、单位、参考范围、日期)
  Future<MetricReconciliationReport> executeSmartMetricReconciliation(dynamic settings) async {
    // 1. 提取所有复查单据中的指标全景指纹 (名称、分类、单位、参考区间、日期、样本值)
    final profiles = MedicalMetricService.instance.extractMetricProfiles(_records);
    if (profiles.isEmpty) {
      return MetricReconciliationReport(
        modifiedRecordsCount: 0,
        clusters: [],
        totalProfilesScanned: 0,
      );
    }

    // 2. 双轨驱动：AI 大模型深度研判 + 本地启发式多维对齐兜底
    final clusters = await MedicalMetricService.instance.reconcileMetricsWithAi(
      profiles: profiles,
      settings: settings,
    );

    // 3. 构建映射快速字典：原始指标名(小写) -> 目标集群
    final Map<String, MetricReconciliationCluster> rawNameToCluster = {};
    for (var c in clusters) {
      for (var raw in c.matchedRawNames) {
        rawNameToCluster[raw.trim().toLowerCase()] = c;
      }
    }

    int modifiedCount = 0;
    for (var r in _records) {
      bool recordChanged = false;

      // 规范化单据大类 (如 "全血细胞分析" -> "血常规")
      final oldCat = r.category.trim();
      final newCat = MedicalMetricService.instance.normalizeCategory(oldCat);
      if (oldCat != newCat) {
        r.category = newCat;
        recordChanged = true;
      }

      // 规范化内部每个指标条目 (名称、单位、分类对齐)
      for (var it in r.items) {
        final rawName = it.itemName.trim();
        final rawLower = rawName.toLowerCase();

        // 优先查看集群归并映射
        final cluster = rawNameToCluster[rawLower];
        if (cluster != null) {
          if (it.itemName != cluster.standardName) {
            it.itemName = cluster.standardName;
            recordChanged = true;
          }
          if (it.category != cluster.standardCategory) {
            it.category = cluster.standardCategory;
            recordChanged = true;
          }
        } else {
          // 本地知识库权威名称对齐兜底
          final stdName = MedicalMetricService.instance.getStandardDisplayName(rawName, category: it.category);
          if (stdName != rawName) {
            it.itemName = stdName;
            recordChanged = true;
          }
        }

        // 同步规范化 item 自身的 category
        final oldItemCat = it.category.trim();
        final newItemCat = MedicalMetricService.instance.normalizeCategory(oldItemCat.isNotEmpty ? oldItemCat : newCat);
        if (oldItemCat != newItemCat) {
          it.category = newItemCat;
          recordChanged = true;
        }
      }

      if (recordChanged) {
        await StorageService.instance.saveRecord(r);
        modifiedCount++;
      }
    }

    if (modifiedCount > 0) {
      await loadData();
    }

    return MetricReconciliationReport(
      modifiedRecordsCount: modifiedCount,
      clusters: clusters,
      totalProfilesScanned: profiles.length,
    );
  }

  /// 兼容旧版调用入口
  Future<int> batchStandardizeRecordsWithAi(dynamic settings) async {
    final report = await executeSmartMetricReconciliation(settings);
    return report.modifiedRecordsCount;
  }
}

class MetricReconciliationReport {
  final int modifiedRecordsCount;
  final List<MetricReconciliationCluster> clusters;
  final int totalProfilesScanned;

  MetricReconciliationReport({
    required this.modifiedRecordsCount,
    required this.clusters,
    required this.totalProfilesScanned,
  });
}

class _ParsedDosage {
  final double value;
  final String unit;
  _ParsedDosage(this.value, this.unit);
}
