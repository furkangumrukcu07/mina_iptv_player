import 'dart:convert';

List<String> extractArrayObjectsFast(String json) {
  final result = <String>[];
  final units = json.codeUnits;
  final length = units.length;
  
  bool inString = false;
  bool escape = false;
  
  List<bool> isArrayScope = [];
  int depth = 0;
  int objectStart = -1;
  int objectDepth = -1;

  final quote = 34; // "
  final backslash = 92; // \
  final bracketOpen = 91; // [
  final bracketClose = 93; // ]
  final braceOpen = 123; // {
  final braceClose = 125; // }

  for (int i = 0; i < length; i++) {
    final c = units[i];
    
    if (inString) {
      if (escape) {
        escape = false;
      } else if (c == backslash) {
        escape = true;
      } else if (c == quote) {
        inString = false;
      }
      continue;
    }

    if (c == quote) {
      inString = true;
    } else if (c == bracketOpen) {
      isArrayScope.add(true);
      depth++;
    } else if (c == bracketClose) {
      if (isArrayScope.isNotEmpty) isArrayScope.removeLast();
      depth--;
    } else if (c == braceOpen) {
      isArrayScope.add(false);
      depth++;
      if (objectStart == -1 && isArrayScope.length >= 2 && isArrayScope[isArrayScope.length - 2] == true) {
        objectStart = i;
        objectDepth = depth;
      }
    } else if (c == braceClose) {
      if (objectStart != -1 && depth == objectDepth) {
        result.add(json.substring(objectStart, i + 1));
        objectStart = -1;
        objectDepth = -1;
      }
      if (isArrayScope.isNotEmpty) isArrayScope.removeLast();
      depth--;
    }
  }
  return result;
}

void main() {
  final json1 = '[{"id": 1, "name": "A"}, {"id": 2, "name": "B"}]';
  final json2 = '{"data": [{"id": 1}, {"id": 2}], "other": {}}';
  
  print('json1: ${extractArrayObjectsFast(json1)}');
  print('json2: ${extractArrayObjectsFast(json2)}');
}
