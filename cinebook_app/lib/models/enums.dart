import 'package:flutter/material.dart';

import '../core/theme.dart';

//Display helpers for the backend's string enums.

String formatLabel(String? format) {
  switch (format) {
    case 'TWO_D':
      return '2D';
    case 'THREE_D':
      return '3D';
    default:
      return format ?? '';
  }
}

String screenTypeLabel(String? type) {
  switch (type) {
    case 'FOUR_DX':
      return '4DX';
    case 'DOLBY_ATMOS':
      return 'Dolby Atmos';
    case 'IMAX':
      return 'IMAX';
    case 'STANDARD':
      return 'Standard';
    default:
      return type ?? '';
  }
}

String seatCategoryLabel(String category) {
  switch (category) {
    case 'FRONT':
      return 'Front';
    case 'STANDARD':
      return 'Standard';
    case 'PREMIUM':
      return 'Premium';
    case 'RECLINER':
      return 'Recliner';
    default:
      return category;
  }
}

Color seatCategoryColor(String category) {
  switch (category) {
    case 'FRONT':
      return AppColors.seatFront;
    case 'STANDARD':
      return AppColors.seatStandard;
    case 'PREMIUM':
      return AppColors.seatPremium;
    case 'RECLINER':
      return AppColors.seatRecliner;
    default:
      return AppColors.surfaceVariant;
  }
}

//Booking + payment status styling for chips.
Color bookingStatusColor(String status) {
  switch (status) {
    case 'CONFIRMED':
      return AppColors.primary;
    case 'PENDING':
      return AppColors.onSurfaceVariant;
    case 'CANCELLED':
    case 'REFUNDED':
      return AppColors.error;
    default:
      return AppColors.onSurfaceVariant;
  }
}
