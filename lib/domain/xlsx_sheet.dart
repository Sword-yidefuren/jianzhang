import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// 读取 .xlsx 的第一个工作表，转成按行排列的纯文本单元格。
///
/// 只依赖 zip + XML，不执行公式、不读取样式；日期保持 Excel 序列值，
/// 由账单解析层按列判断。
class XlsxSheet {
  const XlsxSheet._();

  static List<List<String>> readFirstSheet(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const XlsxSheetException('不是有效的 Excel 文件');
    }

    final shared = _readSharedStrings(archive);
    final sheetPath = _firstSheetPath(archive);
    final sheetFile = _findFile(archive, sheetPath);
    if (sheetFile == null) {
      throw const XlsxSheetException('Excel 里没有工作表');
    }

    final XmlDocument document;
    try {
      document = XmlDocument.parse(_decode(sheetFile.content));
    } catch (_) {
      throw const XlsxSheetException('工作表内容损坏');
    }

    final rows = <List<String>>[];
    for (final row in document.descendants.whereType<XmlElement>().where(
      (element) => element.localName == 'row',
    )) {
      final cells = <String>[];
      var cursor = 0;
      for (final cell in row.descendants.whereType<XmlElement>().where(
        (element) => element.localName == 'c',
      )) {
        final reference = cell.getAttribute('r');
        final column = reference == null ? cursor : _columnIndex(reference);
        if (column < 0) continue;
        while (cells.length <= column) {
          cells.add('');
        }
        cells[column] = _cellText(cell, shared);
        cursor = column + 1;
      }
      while (cells.isNotEmpty && cells.last.isEmpty) {
        cells.removeLast();
      }
      rows.add(cells);
    }

    while (rows.isNotEmpty && rows.last.every((cell) => cell.isEmpty)) {
      rows.removeLast();
    }
    if (rows.isEmpty) throw const XlsxSheetException('工作表是空的');
    return rows;
  }

  static String _firstSheetPath(Archive archive) {
    final workbookFile = _findFile(archive, 'xl/workbook.xml');
    final relsFile = _findFile(archive, 'xl/_rels/workbook.xml.rels');
    if (workbookFile != null && relsFile != null) {
      try {
        final workbook = XmlDocument.parse(_decode(workbookFile.content));
        final sheet = workbook.descendants.whereType<XmlElement>().firstWhere(
          (element) => element.localName == 'sheet',
        );
        final relationId = sheet.attributes
            .where((attribute) => attribute.name.local == 'id')
            .map((attribute) => attribute.value)
            .firstOrNull;
        if (relationId != null) {
          final rels = XmlDocument.parse(_decode(relsFile.content));
          final relation = rels.descendants
              .whereType<XmlElement>()
              .where((element) => element.localName == 'Relationship')
              .where((element) => element.getAttribute('Id') == relationId)
              .firstOrNull;
          final target = relation?.getAttribute('Target');
          if (target != null && target.isNotEmpty) {
            final normalized = target.startsWith('/')
                ? target.substring(1)
                : 'xl/$target';
            if (_findFile(archive, normalized) != null) return normalized;
          }
        }
      } catch (_) {
        // 工作簿关系损坏时退回固定路径。
      }
    }
    final fallback = _findFile(archive, 'xl/worksheets/sheet1.xml');
    if (fallback != null) return 'xl/worksheets/sheet1.xml';
    for (final file in archive.files) {
      if (file.isFile &&
          file.name.startsWith('xl/worksheets/') &&
          file.name.endsWith('.xml')) {
        return file.name;
      }
    }
    throw const XlsxSheetException('Excel 里没有工作表');
  }

  static List<String> _readSharedStrings(Archive archive) {
    final file = _findFile(archive, 'xl/sharedStrings.xml');
    if (file == null) return const [];
    try {
      final document = XmlDocument.parse(_decode(file.content));
      return document.descendants
          .whereType<XmlElement>()
          .where((element) => element.localName == 'si')
          .map(
            (item) => item.descendants
                .whereType<XmlElement>()
                .where((element) => element.localName == 't')
                .map((text) => text.innerText)
                .join(),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String _cellText(XmlElement cell, List<String> shared) {
    final type = cell.getAttribute('t');
    final inline = cell.descendants
        .whereType<XmlElement>()
        .where((element) => element.localName == 'is')
        .firstOrNull;
    if (type == 'inlineStr' && inline != null) {
      return _cleanText(inline.innerText);
    }
    if (type == 's') {
      final index = int.tryParse(_value(cell));
      if (index != null && index >= 0 && index < shared.length) {
        return _cleanText(shared[index]);
      }
      return '';
    }
    if (type == 'e') return '';
    return _cleanText(_value(cell));
  }

  static String _value(XmlElement cell) {
    for (final element in cell.descendants.whereType<XmlElement>()) {
      if (element.localName == 'v') return element.innerText;
    }
    return '';
  }

  static String _cleanText(String value) =>
      value.replaceAll('_x000D_', '').replaceAll('\r', '').trim();

  static String _decode(List<int> bytes) {
    final text = utf8.decode(bytes);
    return text.startsWith('\uFEFF') ? text.substring(1) : text;
  }

  static ArchiveFile? _findFile(Archive archive, String name) {
    for (final file in archive.files) {
      if (file.isFile && file.name == name) return file;
    }
    return null;
  }

  static int _columnIndex(String reference) {
    var column = 0;
    for (final code in reference.codeUnits) {
      if (code < 0x41 || code > 0x5A) break;
      column = column * 26 + (code - 0x40);
    }
    return column - 1;
  }
}

class XlsxSheetException implements Exception {
  const XlsxSheetException(this.message);

  final String message;

  @override
  String toString() => message;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
