import 'dart:convert';
import 'dart:io' as dio;

import 'package:http/http.dart' as http;

// import 'package:dio/dio.dart';
import 'package:intl_utils/src/constants/constants.dart';
import 'package:intl_utils/src/intl_translation/extract_messages.dart';
import 'package:intl_utils/src/utils/file_utils.dart';
import 'package:path/path.dart' as path;

import '../RemoteConfig.dart';

///
/// Created by hai046 on 2022/7/9.
///
///
final remoteConfig = FeishuRemoteConfig();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class FeishuRemoteConfig implements RemoteConfig {
  @override
  Map<String, dynamic> get messages => {};

  final String LANGUAGE_PRIFIX = 'Value-';

  Future<void> config() async {
    // var _dio = Dio();
    http
        .post(Uri.parse('http://info.xianlai.ren/api/v1/info/feishu/sheet'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(<String, String>{
              "Spreadsheet": "shtcnLyY7kKg5gdcKnhrPFNjx6D",
              "region": "24c03a"
            }))
        .timeout(Duration(seconds: 10))
        .then((response) {
      var result = jsonDecode(response.body) as Map<String, dynamic>;
      if (result['errCode'] == 0) {
        var data = result['data'];
        var valueRanges = data['valueRange'];
        if (valueRanges.isNotEmpty) {
          var languages = {};
          Map<String, Map<String, dynamic>?> languagesValue =
              <String, Map<String, dynamic>?>{};
          var values = valueRanges['values'];
          int index = 0;
          for (String lan in values[0]) {
            if (lan.startsWith(LANGUAGE_PRIFIX)) {
              var key = lan.substring(LANGUAGE_PRIFIX.length);
              languages[key] = index;
              languagesValue[key] = {};
            }
            index++;
          }
          for (var row in values.skip(1)) {
            for (var lan in languages.keys) {
              var colIndex = languages[lan];
              languagesValue[lan]![row[1]] = row[colIndex];
            }
          }
          _generateArb(languagesValue);
        }
      }

      // print(result);
    });
  }

  final MessageExtraction extraction = MessageExtraction();

  @override
  operator [](String messageName) {
    return messages[messageName];
  }

  void _generateArb(Map<String, Map<String, dynamic>?> languagesValue) {
    print(
        'Compare https://xianlaigame.feishu.cn/sheets/shtcnLyY7kKg5gdcKnhrPFNjx6D Feishu config support language: ${languagesValue.keys}');
    getArbFiles(defaultArbDir).forEach((element) {
      var name =
          path.basenameWithoutExtension(element.path).substring('intl_'.length);
      print('Find project arb file language: $name');
      if (languagesValue.containsKey(name)) {
        print('Find arb file march feishu doc col $name');
        var arbFile = dio.File(element.path);
        var localJson =
            json.decode(arbFile.readAsStringSync()) as Map<String, dynamic>;

        var feishuMap = languagesValue[name];
        Map<String, dynamic> result = <String, dynamic>{};
        //Copy local value first
        localJson.forEach((key, value) {
          result[key] = value;
        });
        bool changed = false;
        var msgs = [];
        msgs.add("\n\n");
        feishuMap!.forEach((key, value) {
          if (key == "" || key == null || value == null || value == '') {
            msgs.add("!!! Remote key: $key value $value is Null !!! ");
            return;
          }

          if (localJson.containsKey(key)) {
            var localValue = result[key];
            if ('$value' != '$localValue') {
              msgs.add(
                  'Remote value replace local value Key: "$key" ,local value: "$localValue" replace to remote value: "$value"');
              changed = true;
              result[key] = value;
            }
          } else {
            changed = true;
            msgs.add('Add remote value, Key: "$key", remote value: "$value"');
            result[key] = value;
          }
        });
        if (changed) {
          print(msgs.join('\n$name: '));
          var jsonEncoder = JsonEncoder.withIndent('  ');
          String convert = jsonEncoder.convert(result);
          arbFile.writeAsBytes(utf8.encode(convert));
        } else {
          print("Not change");
        }
      }
    });
  }
}
