import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';
import '../models/check_item.dart';
import '../models/record.dart';

/// 权威医学标准指标定义
class CanonicalMetric {
  final String standardName; // 标准全称，如 "白细胞计数 (WBC)"
  final String pureName;     // 纯中文名，如 "白细胞计数"
  final String code;         // 英文代码，如 "WBC"
  final String category;     // 所属大类，如 "血常规"
  final List<String> aliases;// 所有别名/简写小写集合

  const CanonicalMetric({
    required this.standardName,
    required this.pureName,
    required this.code,
    required this.category,
    required this.aliases,
  });
}

class MedicalMetricService {
  static final MedicalMetricService instance = MedicalMetricService._();
  MedicalMetricService._();

  /// 常见慢病权威医学指标字典库 (覆盖血常规、尿常规、肝肾功、糖脂、甲功等 80+ 高频核心指标)
  static final List<CanonicalMetric> standardMetrics = [
    // 1. 血常规核心指标
    const CanonicalMetric(
      standardName: '白细胞计数 (WBC)',
      pureName: '白细胞计数',
      code: 'WBC',
      category: '血常规',
      aliases: ['wbc', '白细胞', '白细胞计数', '白细胞数', '白细胞数目', '血白细胞', 'leukocyte', 'white blood cell'],
    ),
    const CanonicalMetric(
      standardName: '红细胞计数 (RBC)',
      pureName: '红细胞计数',
      code: 'RBC',
      category: '血常规',
      aliases: ['rbc', '红细胞', '红细胞计数', '红细胞数', '红细胞数目', '血红细胞', 'erythrocyte', 'red blood cell'],
    ),
    const CanonicalMetric(
      standardName: '血红蛋白 (HGB/Hb)',
      pureName: '血红蛋白',
      code: 'HGB',
      category: '血常规',
      aliases: ['hgb', 'hb', '血红蛋白', '血红蛋白测定', '血红蛋白浓度', 'hemoglobin'],
    ),
    const CanonicalMetric(
      standardName: '血小板计数 (PLT)',
      pureName: '血小板计数',
      code: 'PLT',
      category: '血常规',
      aliases: ['plt', '血小板', '血小板计数', '血小板数', '血小板数目', 'platelet', 'thrombocyte'],
    ),
    const CanonicalMetric(
      standardName: '中性粒细胞绝对值 (NEUT#)',
      pureName: '中性粒细胞绝对值',
      code: 'NEUT#',
      category: '血常规',
      aliases: ['neut#', 'neut', '中性粒细胞', '中性粒细胞绝对值', '中性粒细胞数', '中性细胞绝对值', 'neutrophil'],
    ),
    const CanonicalMetric(
      standardName: '中性粒细胞百分比 (NEUT%)',
      pureName: '中性粒细胞百分比',
      code: 'NEUT%',
      category: '血常规',
      aliases: ['neut%', '中性粒细胞%', '中性粒细胞百分比', '中性细胞比率', '中性粒细胞比例'],
    ),
    const CanonicalMetric(
      standardName: '淋巴细胞绝对值 (LYMPH#)',
      pureName: '淋巴细胞绝对值',
      code: 'LYMPH#',
      category: '血常规',
      aliases: ['lymph#', 'lymph', '淋巴细胞', '淋巴细胞绝对值', '淋巴细胞数', 'lymphocyte'],
    ),
    const CanonicalMetric(
      standardName: '淋巴细胞百分比 (LYMPH%)',
      pureName: '淋巴细胞百分比',
      code: 'LYMPH%',
      category: '血常规',
      aliases: ['lymph%', '淋巴细胞%', '淋巴细胞百分比', '淋巴细胞比率', '淋巴细胞比例'],
    ),
    const CanonicalMetric(
      standardName: '红细胞压积 (HCT)',
      pureName: '红细胞压积',
      code: 'HCT',
      category: '血常规',
      aliases: ['hct', 'pvc', '红细胞压积', '红细胞比容', 'hematocrit'],
    ),
    const CanonicalMetric(
      standardName: '平均红细胞体积 (MCV)',
      pureName: '平均红细胞体积',
      code: 'MCV',
      category: '血常规',
      aliases: ['mcv', '平均红细胞体积', '红细胞平均体积'],
    ),
    const CanonicalMetric(
      standardName: '平均红细胞血红蛋白含量 (MCH)',
      pureName: '平均红细胞血红蛋白含量',
      code: 'MCH',
      category: '血常规',
      aliases: ['mch', '平均红细胞血红蛋白含量', '红细胞平均血红蛋白量'],
    ),

    // 2. 血糖与糖代谢指标
    const CanonicalMetric(
      standardName: '空腹血糖 (GLU/FBG)',
      pureName: '空腹血糖',
      code: 'GLU',
      category: '生化全套',
      aliases: ['glu', 'fbg', 'fpg', '血糖', '空腹血糖', '葡萄糖', '空腹葡萄糖', 'blood glucose', 'glucose'],
    ),
    const CanonicalMetric(
      standardName: '餐后2小时血糖 (2h-PBG)',
      pureName: '餐后2小时血糖',
      code: '2h-PBG',
      category: '生化全套',
      aliases: ['2h-pbg', 'pbg', '餐后血糖', '餐后2小时血糖', '餐后两小时血糖', '2小时餐后血糖'],
    ),
    const CanonicalMetric(
      standardName: '糖化血红蛋白 (HbA1c)',
      pureName: '糖化血红蛋白',
      code: 'HbA1c',
      category: '生化全套',
      aliases: ['hba1c', 'hba1-c', 'a1c', '糖化血红蛋白', '糖化血红蛋白a1c', '糖化血红蛋白测定', 'glycated hemoglobin'],
    ),

    // 3. 肝功能核心指标
    const CanonicalMetric(
      standardName: '丙氨酸氨基转移酶 (ALT/谷丙)',
      pureName: '丙氨酸氨基转移酶',
      code: 'ALT',
      category: '肝功能',
      aliases: ['alt', 'gpt', '谷丙转氨酶', '丙氨酸氨基转移酶', '谷氨酸丙酮酸转移酶', 'alanine aminotransferase'],
    ),
    const CanonicalMetric(
      standardName: '天门冬氨酸氨基转移酶 (AST/谷草)',
      pureName: '天门冬氨酸氨基转移酶',
      code: 'AST',
      category: '肝功能',
      aliases: ['ast', 'got', '谷草转氨酶', '天门冬氨酸氨基转移酶', '门冬氨酸氨基转移酶', 'aspartate aminotransferase'],
    ),
    const CanonicalMetric(
      standardName: 'γ-谷氨酰基转移酶 (GGT/γ-GT)',
      pureName: 'γ-谷氨酰基转移酶',
      code: 'GGT',
      category: '肝功能',
      aliases: ['ggt', 'r-gt', 'γ-gt', '谷氨酰转肽酶', 'γ-谷氨酰转肽酶', 'γ-谷氨酰基转移酶'],
    ),
    const CanonicalMetric(
      standardName: '碱性磷酸酶 (ALP/AKP)',
      pureName: '碱性磷酸酶',
      code: 'ALP',
      category: '肝功能',
      aliases: ['alp', 'akp', '碱性磷酸酶', 'alkaline phosphatase'],
    ),
    const CanonicalMetric(
      standardName: '总胆红素 (TBIL)',
      pureName: '总胆红素',
      code: 'TBIL',
      category: '肝功能',
      aliases: ['tbil', 't-bil', '总胆红素', '血清总胆红素', 'total bilirubin'],
    ),
    const CanonicalMetric(
      standardName: '直接胆红素 (DBIL)',
      pureName: '直接胆红素',
      code: 'DBIL',
      category: '肝功能',
      aliases: ['dbil', 'd-bil', '直接胆红素', '结合胆红素', 'direct bilirubin'],
    ),
    const CanonicalMetric(
      standardName: '间接胆红素 (IBIL)',
      pureName: '间接胆红素',
      code: 'IBIL',
      category: '肝功能',
      aliases: ['ibil', 'i-bil', '间接胆红素', '非结合胆红素', 'indirect bilirubin'],
    ),
    const CanonicalMetric(
      standardName: '总蛋白 (TP)',
      pureName: '总蛋白',
      code: 'TP',
      category: '肝功能',
      aliases: ['tp', '总蛋白', '血清总蛋白', 'total protein'],
    ),
    const CanonicalMetric(
      standardName: '白蛋白 (ALB)',
      pureName: '白蛋白',
      code: 'ALB',
      category: '肝功能',
      aliases: ['alb', '白蛋白', '清蛋白', '血清白蛋白', 'albumin'],
    ),
    const CanonicalMetric(
      standardName: '球蛋白 (GLB)',
      pureName: '球蛋白',
      code: 'GLB',
      category: '肝功能',
      aliases: ['glb', 'glob', '球蛋白', '血清球蛋白', 'globulin'],
    ),

    // 4. 肾功能核心指标
    const CanonicalMetric(
      standardName: '血肌酐 (Cr/CREA)',
      pureName: '血肌酐',
      code: 'Cr',
      category: '肾功能',
      aliases: ['cr', 'crea', 'cre', '肌酐', '血肌酐', '血清肌酐', 'creatinine', 'serum creatinine'],
    ),
    const CanonicalMetric(
      standardName: '尿素氮 (BUN/UREA)',
      pureName: '尿素氮',
      code: 'BUN',
      category: '肾功能',
      aliases: ['bun', 'urea', '尿素', '尿素氮', '血尿素', '血尿素氮', 'blood urea nitrogen'],
    ),
    const CanonicalMetric(
      standardName: '血尿酸 (UA/URIC)',
      pureName: '血尿酸',
      code: 'UA',
      category: '肾功能',
      aliases: ['ua', 'uric', '尿酸', '血尿酸', '血清尿酸', 'uric acid'],
    ),
    const CanonicalMetric(
      standardName: '估算肾小球滤过率 (eGFR)',
      pureName: '估算肾小球滤过率',
      code: 'eGFR',
      category: '肾功能',
      aliases: ['egfr', 'gfr', '肾小球滤过率', '估算肾小球滤过率'],
    ),
    const CanonicalMetric(
      standardName: '胱抑素C (Cys-C)',
      pureName: '胱抑素C',
      code: 'Cys-C',
      category: '肾功能',
      aliases: ['cysc', 'cys-c', '胱抑素c', '胱抑素-c', 'cystatin c'],
    ),

    // 5. 血脂核心指标
    const CanonicalMetric(
      standardName: '总胆固醇 (TC)',
      pureName: '总胆固醇',
      code: 'TC',
      category: '血脂全套',
      aliases: ['tc', 't-cho', 'cho', 'chol', '胆固醇', '总胆固醇', '血清总胆固醇', 'total cholesterol'],
    ),
    const CanonicalMetric(
      standardName: '甘油三酯 (TG)',
      pureName: '甘油三酯',
      code: 'TG',
      category: '血脂全套',
      aliases: ['tg', 'trig', '甘油三酯', '甘油三脂', '三酰甘油', 'triglycerides'],
    ),
    const CanonicalMetric(
      standardName: '高密度脂蛋白胆固醇 (HDL-C)',
      pureName: '高密度脂蛋白胆固醇',
      code: 'HDL-C',
      category: '血脂全套',
      aliases: ['hdl', 'hdl-c', '高密度脂蛋白', '高密度脂蛋白胆固醇', 'hdl-ch'],
    ),
    const CanonicalMetric(
      standardName: '低密度脂蛋白胆固醇 (LDL-C)',
      pureName: '低密度脂蛋白胆固醇',
      code: 'LDL-C',
      category: '血脂全套',
      aliases: ['ldl', 'ldl-c', '低密度脂蛋白', '低密度脂蛋白胆固醇', 'ldl-ch'],
    ),

    // 6. 甲状腺功能
    const CanonicalMetric(
      standardName: '促甲状腺激素 (TSH)',
      pureName: '促甲状腺激素',
      code: 'TSH',
      category: '甲状腺功能',
      aliases: ['tsh', '促甲状腺激素', '促甲状腺素', 'thyroid stimulating hormone'],
    ),
    const CanonicalMetric(
      standardName: '游离三碘甲状腺原氨酸 (FT3)',
      pureName: '游离三碘甲状腺原氨酸',
      code: 'FT3',
      category: '甲状腺功能',
      aliases: ['ft3', '游离t3', '游离三碘甲状腺原氨酸', 'free t3'],
    ),
    const CanonicalMetric(
      standardName: '游离甲状腺素 (FT4)',
      pureName: '游离甲状腺素',
      code: 'FT4',
      category: '甲状腺功能',
      aliases: ['ft4', '游离t4', '游离甲状腺素', 'free t4'],
    ),

    // 7. 尿常规核心项目 (与血常规清晰区分)
    const CanonicalMetric(
      standardName: '尿白细胞 (LEU)',
      pureName: '尿白细胞',
      code: 'LEU',
      category: '尿常规',
      aliases: ['尿白细胞', '尿wbc', '尿白细胞酯酶', 'leu', '尿液白细胞'],
    ),
    const CanonicalMetric(
      standardName: '尿潜血 (BLD/OB)',
      pureName: '尿潜血',
      code: 'BLD',
      category: '尿常规',
      aliases: ['尿潜血', '尿隐血', '尿红细胞', 'bld', 'ob', '尿液隐血'],
    ),
    const CanonicalMetric(
      standardName: '尿蛋白 (PRO)',
      pureName: '尿蛋白',
      code: 'PRO',
      category: '尿常规',
      aliases: ['尿蛋白', 'pro', '尿蛋白质', 'protein'],
    ),
    const CanonicalMetric(
      standardName: '尿葡萄糖 (GLU)',
      pureName: '尿葡萄糖',
      code: 'U-GLU',
      category: '尿常规',
      aliases: ['尿葡萄糖', '尿糖', 'u-glu', 'uglu'],
    ),
    const CanonicalMetric(
      standardName: '尿比重 (SG)',
      pureName: '尿比重',
      code: 'SG',
      category: '尿常规',
      aliases: ['尿比重', 'sg', '比重'],
    ),
    const CanonicalMetric(
      standardName: '尿酸碱度 (pH)',
      pureName: '尿酸碱度',
      code: 'pH',
      category: '尿常规',
      aliases: ['尿ph', '尿酸碱度', 'ph值', '尿液ph'],
    ),
  ];

  /// 规范化单据大类名称：将碎片化、带后缀的医院名称收敛为统一标准顶级大类
  String normalizeCategory(String rawCategory) {
    var c = rawCategory.trim();
    if (c.isEmpty) return '常规化验';

    final lower = c.toLowerCase();
    if (lower.contains('血常规') || lower.contains('血细胞') || lower.contains('全血细胞')) {
      return '血常规';
    }
    if (lower.contains('尿常规') || lower.contains('尿液') || lower.contains('尿沉渣')) {
      return '尿常规';
    }
    if (lower.contains('甲状腺') || lower.contains('甲功')) {
      return '甲状腺功能';
    }
    if (lower.contains('凝血') || lower.contains('出凝血') || lower.contains('凝血四项') || lower.contains('凝血六项')) {
      return '凝血功能';
    }
    if (lower.contains('肝功能') || lower.contains('肝功')) {
      return '肝功能';
    }
    if (lower.contains('肾功能') || lower.contains('肾功')) {
      return '肾功能';
    }
    if (lower.contains('血脂')) {
      return '血脂全套';
    }
    if (lower.contains('生化') || lower.contains('血液生化')) {
      return '生化全套';
    }
    if (lower.contains('肿瘤') || lower.contains('癌胚')) {
      return '肿瘤标志物';
    }
    if (lower.contains('心肌酶') || lower.contains('肌钙蛋白')) {
      return '心肌酶谱';
    }
    if (lower.contains('电解质') || lower.contains('离子')) {
      return '电解质';
    }
    if (lower.contains('糖耐量') || lower.contains('胰岛素') || lower.contains('c肽')) {
      return '糖代谢与胰岛功能';
    }
    if (lower.contains('便常规') || lower.contains('大便') || lower.contains('粪便')) {
      return '便常规';
    }

    // 剔除常见的无用后缀如 "检验报告单"、"分析报告"、"检验报告"
    c = c.replaceAll(RegExp(r'(检验)?(报告)?(单)?$'), '').trim();
    return c.isNotEmpty ? c : '常规化验';
  }

  /// 查找匹配的标准医学指标
  CanonicalMetric? findStandardMetric(String rawName, {String? category}) {
    var clean = rawName.trim();
    if (clean.isEmpty) return null;

    // 清理可能已经存在的单据前缀，如 [血常规] 白细胞 -> 白细胞
    if (clean.startsWith('[') && clean.contains(']')) {
      clean = clean.substring(clean.indexOf(']') + 1).trim();
    }

    final lowerClean = clean.toLowerCase();

    // 如果指定了单据类别或属于尿常规，优先匹配尿常规指标
    final isUrine = (category != null && category.contains('尿')) || lowerClean.startsWith('尿');

    for (var m in standardMetrics) {
      if (isUrine && m.category != '尿常规') continue;
      if (!isUrine && m.category == '尿常规') continue;

      for (var a in m.aliases) {
        if (lowerClean == a || lowerClean == a.toLowerCase()) {
          return m;
        }
      }
    }

    // 第二轮：不限定单据类别再匹配一次
    for (var m in standardMetrics) {
      for (var a in m.aliases) {
        if (lowerClean == a || lowerClean == a.toLowerCase()) {
          return m;
        }
      }
    }

    return null;
  }

  /// 规范化指标显示名称：如果能在标准库中找到同义词，返回带国际代码的标准名称；否则返回纯净名称
  String getStandardDisplayName(String rawName, {String? category}) {
    final matched = findStandardMetric(rawName, category: category);
    if (matched != null) {
      return matched.standardName;
    }
    var clean = rawName.trim();
    if (clean.startsWith('[') && clean.contains(']')) {
      clean = clean.substring(clean.indexOf(']') + 1).trim();
    }
    return clean;
  }

  /// 获取某指标的所有同义词/别名（包括各种大小写、中英文），用于走势聚合
  Set<String> getMetricSynonyms(String targetName, {String? category}) {
    final Set<String> syns = {};
    var clean = targetName.trim().toLowerCase();
    if (clean.startsWith('[') && clean.contains(']')) {
      clean = clean.substring(clean.indexOf(']') + 1).trim();
    }
    syns.add(clean);

    final standard = findStandardMetric(targetName, category: category);
    if (standard != null) {
      syns.add(standard.standardName.toLowerCase());
      syns.add(standard.pureName.toLowerCase());
      syns.add(standard.code.toLowerCase());
      for (var a in standard.aliases) {
        syns.add(a.toLowerCase());
      }
    }

    return syns;
  }

  /// 使用 AI 智能批量解析、理解并统一分类历史指标名称
  Future<Map<String, String>> aiClassifyAndStandardizeItemNames({
    required List<String> distinctNames,
    required AppSettings settings,
  }) async {
    final apiKey = settings.geminiApiKey.isNotEmpty ? settings.geminiApiKey : settings.customApiKey;
    if (apiKey.isEmpty) {
      // 若没有配置 API Key，直接使用本地医学库进行秒级规范化
      final Map<String, String> localResult = {};
      for (var name in distinctNames) {
        localResult[name] = getStandardDisplayName(name);
      }
      return localResult;
    }

    final model = settings.geminiModel.isNotEmpty ? settings.geminiModel : 'gemini-3.7-flash';
    final prompt = '''
你是一位资深医疗化验与慢病健康数据标准化专家。
现在用户的慢性病记录软件中，由于不同医院化验单的叫法、简写、中英文或录入差异，导致同一种指标被分成了多个不同的名字（例如："白细胞"、"WBC"、"白细胞计数" 本质是同一个指标；"ALT"、"谷丙转氨酶" 是同一个指标；"血肌酐"、"Cr" 是同一个指标）。

请分析以下用户当前录入的所有检验指标名称列表，将其映射标准化：
【要求】：
1. 将每一个输入的指标名称，映射为一个通用的权威标准医学指标名称（格式推荐: "中文标准全称 (国际英文缩写)"，如 "白细胞计数 (WBC)"、"空腹血糖 (GLU)"、"血肌酐 (Cr)"）；
2. 属于同一种检验指标的不同写法必须映射为【完全相同的同一个标准名称】！
3. 请以严格的 JSON Key-Value 格式返回，Key 为原始指标名，Value 为标准化后的名称。不要包含 Markdown 以外的解释文本。

【待标准化的指标列表 (${distinctNames.length}项)】:
${jsonEncode(distinctNames)}
''';

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [{"text": prompt}]
            }
          ],
          "generationConfig": {
            "response_mime_type": "application/json",
            "temperature": 0.1,
          }
        }),
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final text = data['candidates'][0]['content']['parts'][0]['text']?.toString() ?? '';
        var cleanJson = text.trim();
        if (cleanJson.startsWith('```json')) cleanJson = cleanJson.substring(7);
        if (cleanJson.startsWith('```')) cleanJson = cleanJson.substring(3);
        if (cleanJson.endsWith('```')) cleanJson = cleanJson.substring(0, cleanJson.length - 3);
        cleanJson = cleanJson.trim();

        final map = jsonDecode(cleanJson);
        if (map is Map) {
          final Map<String, String> resultMap = {};
          map.forEach((k, v) {
            resultMap[k.toString()] = v.toString();
          });
          return resultMap;
        }
      }
    } catch (_) {}

    // 本地医学库保底降级
    final Map<String, String> fallback = {};
    for (var name in distinctNames) {
      fallback[name] = getStandardDisplayName(name);
    }
    return fallback;
  }

  /// =========================================================================
  /// --- 🧠 AI 全局医学研判与多维指标智能对齐中枢 (名称/单位/参考值/日期综合研判) ---
  /// =========================================================================

  /// 从患者所有历史记录中提取出全量的【指标全景指纹】
  List<MetricProfile> extractMetricProfiles(List<CheckRecord> records) {
    final Map<String, _MetricAccumulator> accMap = {};

    for (var r in records) {
      final dateStr = r.checkDate.toIso8601String().split('T').first;
      final recCat = normalizeCategory(r.category);

      for (var it in r.items) {
        final name = it.itemName.trim();
        if (name.isEmpty) continue;

        final itemCat = it.category.trim().isNotEmpty ? normalizeCategory(it.category.trim()) : recCat;
        final key = '${name.toLowerCase()}@$itemCat';

        final acc = accMap.putIfAbsent(key, () => _MetricAccumulator(rawName: name, category: itemCat));
        acc.count++;
        if (!acc.dates.contains(dateStr)) acc.dates.add(dateStr);
        if (it.unit.trim().isNotEmpty) acc.units.add(it.unit.trim());
        if (it.referenceRange.trim().isNotEmpty) acc.ranges.add(it.referenceRange.trim());
        if (it.value.trim().isNotEmpty && acc.sampleValues.length < 3) {
          acc.sampleValues.add(it.value.trim());
        }
      }
    }

    return accMap.values.map((a) => a.toProfile()).toList();
  }

  /// 本地启发式多维对齐算法 (免 Key / 离线兜底，基于名称包含/编辑距离 + 单位一致性 + 参考区间重合度)
  List<MetricReconciliationCluster> heuristicallyClusterProfiles(List<MetricProfile> profiles) {
    final List<MetricReconciliationCluster> clusters = [];
    final Set<String> processedKeys = {};

    // 1. 第一阶段：利用内置 80+ 临床核心检验知识图谱进行高置信度收敛
    final Map<String, List<MetricProfile>> standardBucket = {};
    for (var p in profiles) {
      final std = findStandardMetric(p.rawName, category: p.category);
      if (std != null) {
        standardBucket.putIfAbsent(std.standardName, () => []).add(p);
      }
    }

    for (var entry in standardBucket.entries) {
      final stdName = entry.key;
      final group = entry.value;
      if (group.isEmpty) continue;

      final std = findStandardMetric(group.first.rawName, category: group.first.category);
      final cat = std?.category.isNotEmpty == true ? std!.category : group.first.category;
      final rawNames = group.map((p) => p.rawName).toSet().toList();

      clusters.add(MetricReconciliationCluster(
        standardName: stdName,
        standardCategory: cat,
        matchedRawNames: rawNames,
        reason: '命中权威医学知识图谱：统一收敛为标准检验指标与大类',
      ));

      for (var p in group) {
        processedKeys.add('${p.rawName.toLowerCase()}@${p.category}');
      }
    }

    // 2. 第二阶段：对于剩余未命中字典的个性化指标，执行两两多维亲缘比对
    final remaining = profiles.where((p) => !processedKeys.contains('${p.rawName.toLowerCase()}@${p.category}')).toList();
    final List<List<MetricProfile>> matchedGroups = [];

    for (var cur in remaining) {
      bool merged = false;
      for (var grp in matchedGroups) {
        final rep = grp.first;
        // 计算两两多维亲缘度
        if (_isProfileSimilar(cur, rep)) {
          grp.add(cur);
          merged = true;
          break;
        }
      }
      if (!merged) {
        matchedGroups.add([cur]);
      }
    }

    for (var grp in matchedGroups) {
      if (grp.length > 1) {
        // 多项被成功合并
        final bestRep = grp.reduce((a, b) => a.occurrenceCount >= b.occurrenceCount ? a : b);
        final rawNames = grp.map((p) => p.rawName).toSet().toList();
        final unitStr = bestRep.unit.isNotEmpty ? '单位均为 ${bestRep.unit}，' : '';
        final rangeStr = bestRep.referenceRange.isNotEmpty ? '参考范围相近，' : '';

        clusters.add(MetricReconciliationCluster(
          standardName: getStandardDisplayName(bestRep.rawName, category: bestRep.category),
          standardCategory: normalizeCategory(bestRep.category),
          matchedRawNames: rawNames,
          reason: '智能多维判定：$unitStr$rangeStr单据栏目与病程日期高度连续，判定为同种指标',
        ));
      }
    }

    return clusters;
  }

  /// 默认 AI 归拢提示词模板 (内置极度严苛的临床医学防误合铁律)
  static const String defaultReconciliationPromptTemplate = '''你是一位资深临床检验医学与慢病健康数据标准化权威专家。
现在用户的慢性病记录软件中，由于不同医院化验单的叫法、简写、中英文、单据栏目或录入差异，导致明明是同一个检验项目，却被拆分成了不同的名字或不同的单据前缀。

【待分析的指标全景画像清单】：
{{PROFILES_JSON}}

【⚠️ 核心医学判别最高红线（违背将导致医疗数据灾难，必须 100% 严格遵守）】：
1. 绝对严禁仅凭“单位相同”或“参考范围相近”就把不同项目混在一起！
   - 例如在生化全套中：谷丙转氨酶(ALT)、谷草转氨酶(AST)、碱性磷酸酶(ALP)、谷氨酰转肽酶(GGT)，它们的检验单位都是 U/L，参考范围也都在几十以内，但它们是完全不同的肝功能生化酶，绝对禁止合并！
   - 又如在电解质中：血钾(K+)、血钠(Na+)、血氯(Cl-)、二氧化碳结合力，单位都是 mmol/L，但它们是完全不同的化学元素与指标，绝对禁止合并！
   - 又如：肌酐(Cr) 与 尿酸(UA)、总胆固醇(TC) 与 甘油三酯(TG)、总胆红素(TBIL) 与 直接胆红素(DBIL)，绝对禁止合并！
2. 绝对严禁将“绝对计数”与“百分比”合并！
   - 例如：淋巴细胞百分比 (LYMPH%，单位%) 与 淋巴细胞绝对计数 (LYMPH#，单位 10^9/L) 是两个完全不同的临床观测值，绝对禁止合并！
   - 中性粒细胞百分比(NEUT%) 与 中性粒细胞绝对计数(NEUT#) 绝对禁止合并！单核、嗜酸、嗜碱细胞同理！
3. 绝对严禁将不同体液样本的项目合并！
   - 尿白细胞 与 血液白细胞 绝对禁止合并！尿蛋白 与 血清总蛋白 绝对禁止合并！尿糖 与 血糖 绝对禁止合并！

【✅ 什么是合法允许合并的项目（同义/变体归拢）】：
仅当两个项目在临床医学上【证实为同一种检验物质】，仅仅是因为以下原因被拆分时才允许合并：
1. 医院叫法或简写差异：如“谷丙转氨酶” vs “丙氨酸氨基转移酶” vs “ALT”；
2. 规范全称与简称：如“白细胞” vs “白细胞计数” vs “全血白细胞” vs “WBC”；
3. 单据栏目前缀差异：如“[全血细胞分析] 白细胞” vs “[血常规] 白细胞”；
4. 中英文差异：如“甘油三酯” vs “TG” vs “Triglycerides”。
且两者的单位量纲属性必须完全兼容（不可一个绝对值一个百分比），参考范围数量级相符。

【你的输出格式要求】：
请以纯 JSON 输出，严禁包含任何 Markdown 格式代码块（勿带 ```json）或额外说明文字：
{
  "clusters": [
    {
      "standardName": "标准中文全称 (国际缩写)",
      "standardCategory": "标准单据分类",
      "matchedRawNames": ["原指标名1", "原指标名2"],
      "reason": "临床证实为同一种检验物质(如ALT)，仅医院简称与全称叫法差异"
    }
  ]
}''';

  /// 构造最终发给 AI 的完整提示词
  String buildReconciliationPrompt(List<MetricProfile> profiles, {String? customTemplate}) {
    final template = (customTemplate != null && customTemplate.trim().isNotEmpty)
        ? customTemplate.trim()
        : defaultReconciliationPromptTemplate;

    final jsonStr = jsonEncode(profiles.map((p) => p.toJson()).toList());
    if (template.contains('{{PROFILES_JSON}}')) {
      return template.replaceAll('{{PROFILES_JSON}}', jsonStr);
    } else {
      return '$template\n\n【待分析的指标全景画像清单】：\n$jsonStr';
    }
  }

  /// 综合研判两个指标画像是否为同一指标变体 (严格层级门禁：医学本质一票否决制)
  bool _isProfileSimilar(MetricProfile a, MetricProfile b) {
    // 门禁 0：体液大类强隔离 (尿 vs 血/其他)
    final isUrineA = _isUrineCategory(a.category, a.rawName);
    final isUrineB = _isUrineCategory(b.category, b.rawName);
    if (isUrineA != isUrineB) {
      return false;
    }

    // 门禁 1：百分比 vs 绝对计数强隔离
    final isPercentA = _isPercentageMetric(a.rawName, a.unit);
    final isPercentB = _isPercentageMetric(b.rawName, b.unit);
    if (isPercentA != isPercentB) {
      return false; // 百分比与绝对值绝不合并
    }

    // 门禁 2：已知不同临床指标互斥一票否决 (如 ALT vs AST, 钾 vs 钠)
    if (_areKnownMutuallyExclusive(a.rawName, b.rawName)) {
      return false;
    }

    // 门禁 3：名称医学本质相似度核心门禁 (核心一票否决)
    final nA = _cleanName(a.rawName);
    final nB = _cleanName(b.rawName);
    if (nA.isEmpty || nB.isEmpty) return false;

    bool nameMatch = false;
    if (nA == nB) {
      nameMatch = true;
    } else {
      final stdA = findStandardMetric(a.rawName, category: a.category);
      final stdB = findStandardMetric(b.rawName, category: b.category);
      if (stdA != null && stdB != null && stdA.standardName == stdB.standardName) {
        nameMatch = true;
      } else {
        nameMatch = _isNameVariantByModifiers(nA, nB);
      }
    }

    // 🔴 核心铁律：若名称在医学上不构成同义变体，不管单位和参考值多么相同，一票否决！
    if (!nameMatch) {
      return false;
    }

    // 门禁 4：单位一致性核验（反向过滤，防止同名同字但在不同计量维度）
    final uA = _cleanUnit(a.unit);
    final uB = _cleanUnit(b.unit);
    if (uA.isNotEmpty && uB.isNotEmpty && uA != uB) {
      if (!_areUnitsCompatible(uA, uB)) {
        return false;
      }
    }

    // 门禁 5：参考范围数量级冲突核验（反向过滤）
    if (a.referenceRange.isNotEmpty && b.referenceRange.isNotEmpty) {
      final rA = _extractRange(a.referenceRange);
      final rB = _extractRange(b.referenceRange);
      if (rA != null && rB != null) {
        final midA = (rA.$1 + rA.$2) / 2.0;
        final midB = (rB.$1 + rB.$2) / 2.0;
        if (midA > 0 && midB > 0) {
          final ratio = midA > midB ? midA / midB : midB / midA;
          if (ratio > 5.0) {
            return false;
          }
        }
      }
    }

    return true;
  }

  bool _isUrineCategory(String category, String rawName) {
    final c = category.toLowerCase();
    final n = rawName.toLowerCase();
    return c.contains('尿') || n.startsWith('尿') || n.contains('尿常规');
  }

  bool _isPercentageMetric(String rawName, String unit) {
    final u = unit.toLowerCase();
    final n = rawName.toLowerCase();
    if (u.contains('%') || u.contains('百分比') || u.contains('percent')) return true;
    if (n.contains('%') || n.contains('百分比') || n.contains('百分率') || n.contains('比率') || n.contains('比值') || n.contains('ratio') || n.contains('pct')) {
      return true;
    }
    return false;
  }

  bool _areKnownMutuallyExclusive(String nameA, String nameB) {
    final a = _cleanName(nameA);
    final b = _cleanName(nameB);
    if (a == b) return false;

    // 肝酶组互斥
    const liverEnzymes = ['alt', 'ast', 'alp', 'ggt', 'ldh', '谷丙', '谷草', '碱性磷酸酶', '转肽酶', '乳酸脱氢酶'];
    for (int i = 0; i < liverEnzymes.length; i++) {
      for (int j = i + 1; j < liverEnzymes.length; j++) {
        final k1 = liverEnzymes[i];
        final k2 = liverEnzymes[j];
        if ((a.contains(k1) && b.contains(k2)) || (a.contains(k2) && b.contains(k1))) {
          return true;
        }
      }
    }

    // 电解质组互斥
    const electrolytes = [
      ['钾', 'k'],
      ['钠', 'na'],
      ['氯', 'cl'],
      ['钙', 'ca'],
      ['镁', 'mg'],
      ['磷', 'p', 'phos']
    ];
    for (int i = 0; i < electrolytes.length; i++) {
      for (int j = i + 1; j < electrolytes.length; j++) {
        final g1 = electrolytes[i];
        final g2 = electrolytes[j];
        bool hasG1(String s) => g1.any((k) => s == k || s.contains(k));
        bool hasG2(String s) => g2.any((k) => s == k || s.contains(k));
        if ((hasG1(a) && hasG2(b)) || (hasG1(b) && hasG2(a))) {
          return true;
        }
      }
    }

    // 脂类互斥
    const lipids = [
      ['总胆固醇', 'tc', 'chol'],
      ['甘油三酯', 'tg', 'trig'],
      ['高密度', 'hdl'],
      ['低密度', 'ldl']
    ];
    for (int i = 0; i < lipids.length; i++) {
      for (int j = i + 1; j < lipids.length; j++) {
        final g1 = lipids[i];
        final g2 = lipids[j];
        bool hasG1(String s) => g1.any((k) => s.contains(k));
        bool hasG2(String s) => g2.any((k) => s.contains(k));
        if ((hasG1(a) && hasG2(b)) || (hasG1(b) && hasG2(a))) {
          return true;
        }
      }
    }

    // 肾功互斥
    const renal = [
      ['肌酐', 'cr', 'crea'],
      ['尿酸', 'ua', 'uric'],
      ['尿素', 'ure', 'bun']
    ];
    for (int i = 0; i < renal.length; i++) {
      for (int j = i + 1; j < renal.length; j++) {
        final g1 = renal[i];
        final g2 = renal[j];
        bool hasG1(String s) => g1.any((k) => s.contains(k));
        bool hasG2(String s) => g2.any((k) => s.contains(k));
        if ((hasG1(a) && hasG2(b)) || (hasG1(b) && hasG2(a))) {
          return true;
        }
      }
    }

    // 血细胞大类互斥
    const bloodCells = [
      ['白细胞', 'wbc'],
      ['红细胞', 'rbc'],
      ['血小板', 'plt'],
      ['血红蛋白', 'hb', 'hgb'],
      ['淋巴细胞', 'lymph'],
      ['中性粒细胞', 'neut'],
      ['单核细胞', 'mono'],
      ['嗜酸', 'eos'],
      ['嗜碱', 'baso']
    ];
    for (int i = 0; i < bloodCells.length; i++) {
      for (int j = i + 1; j < bloodCells.length; j++) {
        final g1 = bloodCells[i];
        final g2 = bloodCells[j];
        bool hasG1(String s) => g1.any((k) => s.contains(k));
        bool hasG2(String s) => g2.any((k) => s.contains(k));
        if ((hasG1(a) && hasG2(b)) || (hasG1(b) && hasG2(a))) {
          return true;
        }
      }
    }

    return false;
  }

  bool _isNameVariantByModifiers(String nA, String nB) {
    final longStr = nA.length >= nB.length ? nA : nB;
    final shortStr = nA.length < nB.length ? nA : nB;

    if (!longStr.contains(shortStr)) return false;
    if (shortStr.length < 2) return false;

    // 剔除 shortStr 后的剩余部分
    final remainder = longStr.replaceFirst(shortStr, '');
    if (remainder.isEmpty) return true;

    // 检查剩余部分是否全部由无害医学修饰词组成
    const allowedModifiers = [
      '计数', '测定', '分析', '全血', '血清', '血浆', '空腹', '餐后', '绝对值', '总',
      '含量', '水平', '浓度', '检验', '定量', '常规', '五分类', '三分类', '项目', '检查',
      '比值', '比率'
    ];

    String testStr = remainder;
    for (var mod in allowedModifiers) {
      testStr = testStr.replaceAll(mod, '');
    }
    testStr = testStr.replaceAll(RegExp(r'[\d\+\-\*\#\s]'), '');
    return testStr.isEmpty;
  }

  bool _areUnitsCompatible(String uA, String uB) {
    if (uA == uB) return true;
    final cA = uA.replaceAll(' ', '').replaceAll('／', '/').replaceAll('^', '').replaceAll('*', '');
    final cB = uB.replaceAll(' ', '').replaceAll('／', '/').replaceAll('^', '').replaceAll('*', '');
    if (cA == cB) return true;

    if ((cA.contains('109/l') || cA.contains('10e9/l') || cA == 'g/l') &&
        (cB.contains('109/l') || cB.contains('10e9/l') || cB == 'g/l')) {
      return true;
    }
    if ((cA == 'u/l' || cA == 'iu/l') && (cB == 'u/l' || cB == 'iu/l')) {
      return true;
    }
    return false;
  }

  String _cleanUnit(String unit) {
    return unit.trim().toLowerCase().replaceAll(' ', '').replaceAll('／', '/').replaceAll('×10^9', '10^9');
  }

  String _cleanName(String name) {
    var s = name.trim().toLowerCase();
    if (s.startsWith('[') && s.contains(']')) {
      s = s.substring(s.indexOf(']') + 1).trim();
    }
    return s.replaceAll(RegExp(r'[\(\)（）\s_\-\#\%]'), '');
  }

  (double, double)? _extractRange(String refStr) {
    final matches = RegExp(r'[-+]?[0-9]*\.?[0-9]+').allMatches(refStr).map((m) => double.tryParse(m.group(0)!)).whereType<double>().toList();
    if (matches.length >= 2) {
      final min = matches[0] < matches[1] ? matches[0] : matches[1];
      final max = matches[0] > matches[1] ? matches[0] : matches[1];
      return (min, max);
    }
    return null;
  }

  /// AI 驱动的全局多维指标对齐中枢 (支持 Gemini / DeepSeek / OpenAI / 自定义 API，若无 Key 则自动降级为启发式引擎)
  Future<List<MetricReconciliationCluster>> reconcileMetricsWithAi({
    required List<MetricProfile> profiles,
    required AppSettings settings,
  }) async {
    if (profiles.isEmpty) return [];

    // 1. 判断是否配置了有效的 AI 凭据
    String apiKey = '';
    String apiUrl = '';
    String modelName = '';
    bool isOpenAiCompat = false;

    if (settings.deepSeekApiKey.isNotEmpty) {
      apiKey = settings.deepSeekApiKey;
      apiUrl = settings.deepSeekBaseUrl.isNotEmpty ? settings.deepSeekBaseUrl : 'https://api.deepseek.com/v1/chat/completions';
      modelName = settings.deepSeekModel.isNotEmpty ? settings.deepSeekModel : 'deepseek-chat';
      isOpenAiCompat = true;
    } else if (settings.openAiApiKey.isNotEmpty) {
      apiKey = settings.openAiApiKey;
      apiUrl = settings.openAiBaseUrl.isNotEmpty ? settings.openAiBaseUrl : 'https://api.openai.com/v1/chat/completions';
      modelName = settings.openAiModel.isNotEmpty ? settings.openAiModel : 'gpt-4o-mini';
      isOpenAiCompat = true;
    } else if (settings.customApiKey.isNotEmpty) {
      apiKey = settings.customApiKey;
      apiUrl = settings.customBaseUrl.isNotEmpty ? settings.customBaseUrl : 'https://api.openai.com/v1/chat/completions';
      modelName = settings.customModel.isNotEmpty ? settings.customModel : 'gpt-4o-mini';
      isOpenAiCompat = true;
    } else if (settings.geminiApiKey.isNotEmpty) {
      apiKey = settings.geminiApiKey;
      modelName = settings.geminiModel.isNotEmpty ? settings.geminiModel : 'gemini-3.7-flash';
      isOpenAiCompat = false;
    }

    // 若无任何 API Key，秒级启用本地启发式多维对齐引擎
    if (apiKey.isEmpty) {
      return heuristicallyClusterProfiles(profiles);
    }

    // 构造提示词 (优先使用用户在设置或弹窗中自定义的 Prompt 模板)
    final prompt = buildReconciliationPrompt(
      profiles,
      customTemplate: settings.aiReconciliationPrompt,
    );

    try {
      String jsonResponseText = '';

      if (isOpenAiCompat) {
        final res = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            "model": modelName,
            "messages": [
              {"role": "system", "content": "You are a clinical laboratory medicine data standardization AI. Respond in JSON only."},
              {"role": "user", "content": prompt}
            ],
            "temperature": 0.1,
          }),
        ).timeout(const Duration(seconds: 30));

        if (res.statusCode == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          jsonResponseText = data['choices']?[0]?['message']?['content']?.toString() ?? '';
        }
      } else {
        // Gemini 原生接口
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
        );
        final res = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "contents": [
              {
                "parts": [{"text": prompt}]
              }
            ],
            "generationConfig": {
              "response_mime_type": "application/json",
              "temperature": 0.1,
            }
          }),
        ).timeout(const Duration(seconds: 30));

        if (res.statusCode == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          jsonResponseText = data['candidates']?[0]?['content']?['parts']?[0]?['text']?.toString() ?? '';
        }
      }

      if (jsonResponseText.isNotEmpty) {
        var cleanJson = jsonResponseText.trim();
        if (cleanJson.startsWith('```json')) cleanJson = cleanJson.substring(7);
        if (cleanJson.startsWith('```')) cleanJson = cleanJson.substring(3);
        if (cleanJson.endsWith('```')) cleanJson = cleanJson.substring(0, cleanJson.length - 3);
        cleanJson = cleanJson.trim();

        final map = jsonDecode(cleanJson);
        final list = map['clusters'] as List?;
        if (list != null && list.isNotEmpty) {
          final List<MetricReconciliationCluster> aiClusters = [];
          for (var item in list) {
            final stdName = item['standardName']?.toString().trim() ?? '';
            final stdCat = item['standardCategory']?.toString().trim() ?? '';
            final matched = (item['matchedRawNames'] as List?)?.map((e) => e.toString().trim()).toList() ?? [];
            final reason = item['reason']?.toString().trim() ?? 'AI 综合医学研判已自动归拢';

            if (stdName.isNotEmpty && matched.length > 1) {
              aiClusters.add(MetricReconciliationCluster(
                standardName: stdName,
                standardCategory: stdCat.isNotEmpty ? normalizeCategory(stdCat) : '常规化验',
                matchedRawNames: matched,
                reason: reason,
              ));
            }
          }
          if (aiClusters.isNotEmpty) return aiClusters;
        }
      }
    } catch (_) {
      // AI 异常或网络超时，平滑降级
    }

    return heuristicallyClusterProfiles(profiles);
  }
}

class _MetricAccumulator {
  final String rawName;
  final String category;
  int count = 0;
  final List<String> dates = [];
  final List<String> units = [];
  final List<String> ranges = [];
  final List<String> sampleValues = [];

  _MetricAccumulator({required this.rawName, required this.category});

  MetricProfile toProfile() {
    String bestUnit = '';
    if (units.isNotEmpty) {
      final unitCounts = <String, int>{};
      for (var u in units) {
        unitCounts[u] = (unitCounts[u] ?? 0) + 1;
      }
      bestUnit = unitCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }

    String bestRange = '';
    if (ranges.isNotEmpty) {
      final rangeCounts = <String, int>{};
      for (var r in ranges) {
        rangeCounts[r] = (rangeCounts[r] ?? 0) + 1;
      }
      bestRange = rangeCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }

    return MetricProfile(
      rawName: rawName,
      category: category,
      unit: bestUnit,
      referenceRange: bestRange,
      dates: dates..sort(),
      sampleValues: sampleValues,
      occurrenceCount: count,
    );
  }

  /// =========================================================================
  /// --- 🏥 同医院历史复查档案自动对齐引擎 (源头对齐机制) ---
  /// =========================================================================
  /// 在化验单识别/整理完成时，自动比对该患者在该医院（或历史最近）的历史复查结果：
  /// 1. 自动对齐单据大类名称 (如上次叫“血常规”，本次AI识别叫“全血分析”，自动统一为上次名称)
  /// 2. 自动对齐指标命名 (如上次叫“白细胞”，本次叫“白细胞计数”或“WBC”，自动统一为上次名称)
  /// 3. 若发现全新项目，保留新指标并正常建档
  HospitalHistoryAlignmentResult alignWithHospitalHistory({
    required List<CheckItem> newItems,
    required String currentHospital,
    required String currentCategory,
    required List<CheckRecord> historyRecords,
  }) {
    if (newItems.isEmpty || historyRecords.isEmpty) {
      return HospitalHistoryAlignmentResult(
        alignedItems: newItems,
        alignedCategory: currentCategory,
        alignedItemCount: 0,
        alignmentNotes: [],
      );
    }

    final cleanCurrentHosp = currentHospital.trim().toLowerCase();

    // 1. 优先筛选同一家医院的历史记录
    List<CheckRecord> targetRecords = [];
    if (cleanCurrentHosp.isNotEmpty) {
      targetRecords = historyRecords.where((r) {
        final h = r.hospital.trim().toLowerCase();
        return h == cleanCurrentHosp ||
            (cleanCurrentHosp.length >= 3 && h.contains(cleanCurrentHosp)) ||
            (h.length >= 3 && cleanCurrentHosp.contains(h));
      }).toList();
    }

    // 2. 如果同医院无记录，降级参考该患者的历史复查记录池
    if (targetRecords.isEmpty) {
      targetRecords = List.from(historyRecords);
    }

    // 按复查日期倒序排序，最优先对齐最近一次复查记录
    targetRecords.sort((a, b) => b.checkDate.compareTo(a.checkDate));

    // 3. 单据栏目名称智能对齐
    String finalCategory = currentCategory.trim();
    final cleanCurrentCat = normalizeCategory(finalCategory);
    final List<String> notes = [];

    for (var r in targetRecords) {
      final histCat = r.category.trim();
      if (histCat.isEmpty) continue;
      if (normalizeCategory(histCat) == cleanCurrentCat) {
        if (finalCategory != histCat) {
          notes.add('单据栏目由 [$finalCategory] 统一为历史同医院分类 [$histCat]');
          finalCategory = histCat;
        }
        break;
      }
    }

    // 4. 收集历史指标候选池（优先同 category，其次跨 category，按时间倒序去重）
    final Map<String, CheckItem> histExactMap = {};
    final List<CheckItem> sameCatCandidateList = [];
    final List<CheckItem> otherCatCandidateList = [];
    final Set<String> seenHistKeys = {};

    for (var r in targetRecords) {
      final rCatNorm = normalizeCategory(r.category);
      final isSameCat = rCatNorm == cleanCurrentCat;

      for (var it in r.items) {
        final raw = it.itemName.trim();
        if (raw.isEmpty) continue;

        histExactMap.putIfAbsent(raw.toLowerCase(), () => it);

        final key = '${raw.toLowerCase()}@${it.category.toLowerCase()}';
        if (!seenHistKeys.contains(key)) {
          seenHistKeys.add(key);
          if (isSameCat) {
            sameCatCandidateList.add(it);
          } else {
            otherCatCandidateList.add(it);
          }
        }
      }
    }

    // 候选池按同栏目优先组合
    final List<CheckItem> allCandidateList = [
      ...sameCatCandidateList,
      ...otherCatCandidateList,
    ];

    int alignedCount = 0;
    final List<CheckItem> alignedItems = [];

    for (var newItem in newItems) {
      final rawNewName = newItem.itemName.trim();
      if (rawNewName.isEmpty) {
        alignedItems.add(newItem);
        continue;
      }

      // 情况 1：历史中已存在完全同名指标，直接保留，无须重命名
      if (histExactMap.containsKey(rawNewName.toLowerCase())) {
        alignedItems.add(newItem.copyWith(
          category: finalCategory.isNotEmpty ? finalCategory : newItem.category,
        ));
        continue;
      }

      // 情况 2：寻找历史中最相似、同义或前缀变体的指标
      CheckItem? matchedHistItem;
      String matchReason = '';

      final effectiveCategory = newItem.category.isNotEmpty ? newItem.category : finalCategory;
      final stdNew = findStandardMetric(rawNewName, category: effectiveCategory);

      for (var histIt in allCandidateList) {
        final rawHistName = histIt.itemName.trim();

        // 🚨 门禁 1：临床互斥黑名单一票否决 (如 ALT 与 AST 绝不合并)
        if (_areKnownMutuallyExclusive(rawNewName, rawHistName)) {
          continue;
        }

        // 🚨 门禁 2：百分比与绝对计数一票否决
        final isNewPct = _isPercentageMetric(rawNewName, newItem.unit);
        final isHistPct = _isPercentageMetric(rawHistName, histIt.unit);
        if (isNewPct != isHistPct) {
          continue;
        }

        // 🚨 门禁 3：体液大类（尿常规 vs 血液生化）一票否决
        final isNewUrine = _isUrineCategory(effectiveCategory, rawNewName);
        final isHistUrine = _isUrineCategory(histIt.category, rawHistName);
        if (isNewUrine != isHistUrine) {
          continue;
        }

        // 条件 A：两者在权威知识库中命中同一标准指标
        if (stdNew != null) {
          final stdHist = findStandardMetric(rawHistName, category: histIt.category);
          if (stdHist != null && stdHist.standardName == stdNew.standardName) {
            matchedHistItem = histIt;
            matchReason = '权威同义词对齐 (${stdNew.standardName})';
            break;
          }
        }

        // 条件 B：修饰词变体（如 "白细胞计数" 与 "白细胞"、"空腹血糖" 与 "血糖"）
        if (_isNameVariantByModifiers(rawNewName, rawHistName)) {
          matchedHistItem = histIt;
          matchReason = '指标命名习惯对齐';
          break;
        }

        // 条件 C：清洗核心词完全一致（去除中英文括号英文缩写及标点后一致）
        final cleanA = _cleanName(rawNewName);
        final cleanB = _cleanName(rawHistName);
        if (cleanA.length >= 2 && cleanA == cleanB) {
          matchedHistItem = histIt;
          matchReason = '核心名称一致';
          break;
        }
      }

      if (matchedHistItem != null) {
        alignedCount++;
        final prevName = matchedHistItem.itemName.trim();
        notes.add('[$rawNewName] 自动承接同医院历史命名 [$prevName] ($matchReason)');

        // 自动重命名为上次历史名称！
        final updated = newItem.copyWith(
          itemName: prevName,
          category: finalCategory.isNotEmpty
              ? finalCategory
              : (matchedHistItem.category.isNotEmpty ? matchedHistItem.category : newItem.category),
        );
        alignedItems.add(updated);
      } else {
        // 未匹配项：判定为该医院新增检查项目，保留本次识别原名
        alignedItems.add(newItem.copyWith(
          category: finalCategory.isNotEmpty ? finalCategory : newItem.category,
        ));
      }
    }

    return HospitalHistoryAlignmentResult(
      alignedItems: alignedItems,
      alignedCategory: finalCategory,
      alignedItemCount: alignedCount,
      alignmentNotes: notes,
    );
  }
}

/// 同医院历史对齐处理结果
class HospitalHistoryAlignmentResult {
  final List<CheckItem> alignedItems;
  final String alignedCategory;
  final int alignedItemCount;
  final List<String> alignmentNotes;

  HospitalHistoryAlignmentResult({
    required this.alignedItems,
    required this.alignedCategory,
    required this.alignedItemCount,
    required this.alignmentNotes,
  });
}

/// 指标全景指纹：聚合指标名、单据分类、单位、参考区间、出现日期与样本值
class MetricProfile {
  final String rawName;
  final String category;
  final String unit;
  final String referenceRange;
  final List<String> dates;
  final List<String> sampleValues;
  final int occurrenceCount;

  MetricProfile({
    required this.rawName,
    required this.category,
    required this.unit,
    required this.referenceRange,
    required this.dates,
    required this.sampleValues,
    required this.occurrenceCount,
  });

  Map<String, dynamic> toJson() => {
    'rawName': rawName,
    'category': category,
    'unit': unit,
    'referenceRange': referenceRange,
    'dates': dates,
    'sampleValues': sampleValues,
    'occurrenceCount': occurrenceCount,
  };
}

/// 指标归并集群结果
class MetricReconciliationCluster {
  final String standardName; // 统一后的标准名称 (如 "丙氨酸氨基转移酶 (ALT)")
  final String standardCategory; // 统一后的单据大类 (如 "肝功能")
  final List<String> matchedRawNames; // 归并进来的原始名称集合
  final String reason; // AI 或算法分析依据

  MetricReconciliationCluster({
    required this.standardName,
    required this.standardCategory,
    required this.matchedRawNames,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
    'standardName': standardName,
    'standardCategory': standardCategory,
    'matchedRawNames': matchedRawNames,
    'reason': reason,
  };
}
