import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/providers/dio_provider.dart';

class ReportsService {
  ReportsService(this._ref);

  final Ref _ref;

  Future<void> create({
    required String reportableType,
    required String reportableId,
    required String reason,
    String? description,
  }) {
    return _ref.read(dioProvider).post(
          ApiConstants.reports,
          data: {
            'reportable_type': reportableType,
            'reportable_id': reportableId,
            'reason': reason,
            'description': description,
          },
        );
  }
}

final reportsServiceProvider = Provider<ReportsService>((ref) => ReportsService(ref));
