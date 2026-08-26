import '../../../models/store_model.dart';

class DepartmentUtils {
  DepartmentUtils._();

  /// Normalize string by lowercasing, trimming, and stripping common Vietnamese diacritics
  static String normalize(String? text) {
    if (text == null) return '';
    var result = text.trim().toLowerCase();
    
    // Replace Vietnamese accents
    const withDia = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const noDia   = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    
    for (int i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], noDia[i]);
    }
    return result;
  }

  /// Determines whether a department definition or ID/name represents Production (Sản xuất / SX)
  static bool isProduction({
    String? deptId,
    String? deptName,
    String? shortName,
    List<DepartmentDefinition>? storeDepartments,
  }) {
    // 1. Direct ID match
    final cleanId = normalize(deptId);
    if (cleanId == 'sx' || cleanId == 'dept_sx' || cleanId == 'san_xuat' || cleanId == 'sanxuat') {
      return true;
    }

    // 2. Direct ShortName match (e.g. "SX")
    final cleanShort = normalize(shortName).toUpperCase();
    if (cleanShort == 'SX') {
      return true;
    }

    // 3. Direct Name match (e.g. "Sản xuất", "Sản Xuất", "San xuat")
    final cleanName = normalize(deptName);
    if (cleanName.contains('san xuat') || cleanName == 'sx') {
      return true;
    }

    // 4. Lookup inside store departments if deptId provided
    if (deptId != null && storeDepartments != null && storeDepartments.isNotEmpty) {
      final dept = storeDepartments.where((d) => d.id == deptId).firstOrNull;
      if (dept != null) {
        return isProduction(
          deptId: dept.id,
          deptName: dept.name,
          shortName: dept.shortName,
        );
      }
    }

    return false;
  }

  /// Check if the user is in a Production (SX) department shift today
  static bool isUserInProductionShiftToday({
    required String userId,
    required StoreModel store,
    String? memberDepartmentId,
    List<String>? todayShiftEntries,
  }) {
    // 1. If today has specific shift assignments in the weekly schedule
    if (todayShiftEntries != null) {
      if (todayShiftEntries.isEmpty) {
        // Explicitly no shifts scheduled on this workday -> Not a scheduled SX shift
        return false;
      }
      for (final entry in todayShiftEntries) {
        if (entry.contains('|')) {
          final deptId = entry.split('|')[1];
          if (isProduction(deptId: deptId, storeDepartments: store.departments)) {
            return true;
          }
        } else {
          // Entry has no explicit department override -> inherits member's default department
          if (memberDepartmentId != null && isProduction(deptId: memberDepartmentId, storeDepartments: store.departments)) {
            return true;
          }
        }
      }
      // If shifts are scheduled today but none of them match SX -> Not an SX shift
      return false;
    }

    // 2. Fallback ONLY if todayShiftEntries is null (no schedule model available):
    if (memberDepartmentId != null && isProduction(deptId: memberDepartmentId, storeDepartments: store.departments)) {
      return true;
    }

    return false;
  }
}
