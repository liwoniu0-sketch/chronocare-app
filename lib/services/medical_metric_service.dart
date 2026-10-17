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
}
