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

  /// 综合研判两个指标画像是否为同一指标变体 (名称亲缘 + 单位一致 + 参考区间重合 + 栏目兼容)
  bool _isProfileSimilar(MetricProfile a, MetricProfile b) {
    // 1. 单位比对：若两者都有单位且完全不同（如 g/L vs 10^9/L），直接否决
    final uA = _cleanUnit(a.unit);
    final uB = _cleanUnit(b.unit);
    if (uA.isNotEmpty && uB.isNotEmpty && uA != uB) {
      return false;
    }

    // 2. 名称比对
    final nA = _cleanName(a.rawName);
    final nB = _cleanName(b.rawName);
    if (nA.isEmpty || nB.isEmpty) return false;

    double nameScore = 0.0;
    if (nA == nB) {
      nameScore = 1.0;
    } else if (nA.contains(nB) || nB.contains(nA)) {
      final minLen = nA.length < nB.length ? nA.length : nB.length;
      nameScore = minLen >= 2 ? 0.85 : 0.5;
    } else {
      final lcs = _longestCommonSubstringLength(nA, nB);
      nameScore = (2.0 * lcs) / (nA.length + nB.length);
    }

    // 3. 参考范围比对
    double rangeScore = 0.5;
    if (a.referenceRange.isNotEmpty && b.referenceRange.isNotEmpty) {
      final rA = _extractRange(a.referenceRange);
      final rB = _extractRange(b.referenceRange);
      if (rA != null && rB != null) {
        final overlap = _rangeOverlapRatio(rA.$1, rA.$2, rB.$1, rB.$2);
        rangeScore = overlap;
      }
    }

    // 4. 单据类别兼容度
    final catA = normalizeCategory(a.category);
    final catB = normalizeCategory(b.category);
    final catScore = (catA == catB || catA.contains(catB) || catB.contains(catA)) ? 1.0 : 0.4;

    final unitScore = (uA.isNotEmpty && uB.isNotEmpty && uA == uB) ? 1.0 : 0.6;

    // 综合加权得分
    final totalScore = nameScore * 0.45 + unitScore * 0.25 + rangeScore * 0.20 + catScore * 0.10;
    return totalScore >= 0.72;
  }

  String _cleanUnit(String unit) {
    return unit.trim().toLowerCase().replaceAll(' ', '').replaceAll('／', '/').replaceAll('×10^9', '10^9');
  }

  String _cleanName(String name) {
    var s = name.trim().toLowerCase();
    // 移除中括号或前缀
    if (s.startsWith('[') && s.contains(']')) {
      s = s.substring(s.indexOf(']') + 1).trim();
    }
    return s.replaceAll(RegExp(r'[\(\)（）\s_\-\#\%]'), '');
  }

  int _longestCommonSubstringLength(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return 0;
    int maxLen = 0;
    for (int i = 0; i < s1.length; i++) {
      for (int j = 0; j < s2.length; j++) {
        int len = 0;
        while (i + len < s1.length && j + len < s2.length && s1[i + len] == s2[j + len]) {
          len++;
        }
        if (len > maxLen) maxLen = len;
      }
    }
    return maxLen;
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

  double _rangeOverlapRatio(double minA, double maxA, double minB, double maxB) {
    final start = minA > minB ? minA : minB;
    final end = maxA < maxB ? maxA : maxB;
    if (end <= start) return 0.0;
    final overlap = end - start;
    final unionStart = minA < minB ? minA : minB;
    final unionEnd = maxA > maxB ? maxA : maxB;
    final union = unionEnd - unionStart;
    return union > 0 ? (overlap / union) : 0.0;
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

    final prompt = '''
你是一位资深医疗化验与慢病健康数据标准化专家。
现在用户的慢性病记录软件中，由于不同医院化验单的叫法、简写、中英文、单据栏目或录入差异，导致明明是同一个检验项目，却被拆分成了不同的名字或不同的单据前缀。

【待分析的指标全景画像清单 (${profiles.length}项)】：
${jsonEncode(profiles.map((p) => p.toJson()).toList())}

【你的任务】：
请综合分析上述指标的：
1. 名称相似度与中英文缩写对应关系（如 ALT 与 谷丙转氨酶，WBC 与 白细胞）；
2. 检验单位（unit）是否一致；
3. 参考范围（referenceRange）数值是否高度相近；
4. 所属单据分类（category）是否同属一个医学专业领域；
5. 检查日期（dates）是否属于患者不同阶段的连续复查随访。

找出所有“本质上是同一个检验项目，但名字不同或栏目分类不同的项”，将它们归并为一个标准指标集群（Cluster）！
每个集群给出权威的国家标准医学全称（格式推荐: "中文标准全称 (国际英文缩写)"，如 "丙氨酸氨基转移酶 (ALT)"、"白细胞计数 (WBC)"），并统一归拢其标准单据分类（如 "肝功能"、"血常规"）。

【输出格式要求】：
请以纯 JSON 输出，严禁包含任何 Markdown 格式代码块或额外说明文字：
{
  "clusters": [
    {
      "standardName": "标准中文全称 (缩写)",
      "standardCategory": "标准单据分类",
      "matchedRawNames": ["原指标名1", "原指标名2"],
      "reason": "单位均为U/L且参考范围吻合，判定为同种肝生化指标"
    }
  ]
}
''';

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
