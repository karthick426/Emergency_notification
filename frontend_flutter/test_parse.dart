import 'dart:io';

List<List<String>> parseCsvString(String input) {
  List<List<String>> result = [];
  bool inQuotes = false;
  String current = '';
  List<String> row = [];

  for (int i = 0; i < input.length; i++) {
    String char = input[i];

    if (char == '"') {
      inQuotes = !inQuotes;
    } else if (char == ',' && !inQuotes) {
      row.add(current);
      current = '';
    } else if ((char == '\n' || char == '\r') && !inQuotes) {
      if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
        i++; // skip \n
      }
      row.add(current);
      result.add(row);
      row = [];
      current = '';
    } else {
      current += char;
    }
  }

  if (row.isNotEmpty || current.isNotEmpty) {
    row.add(current);
    result.add(row);
  }

  return result;
}

void main() {
  String content = File('../hospital_directory.csv').readAsStringSync();
  var lines = parseCsvString(content);
  print('Lines parsed: ${lines.length}');
  if (lines.isNotEmpty) {
    var header = lines.first.map((e) => e.toString().replaceAll('"', '').trim()).toList();
    print('Header: $header');
    print('Name index: ${header.indexWhere((e) => e.contains('Hospital_Name'))}');
    print('State index: ${header.indexWhere((e) => e.contains('State'))}');
    
    // Test the first row
    if (lines.length > 1) {
      var row1 = lines[1].map((e) => e.toString().replaceAll('"', '').trim()).toList();
      print('Row 1 State: ${row1[header.indexWhere((e) => e.contains('State'))]}');
    }
  }
}
