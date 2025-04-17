// TODO Implement this library.
// lib/presentation/widgets/patient_summary_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:mama_care/domain/entities/patient_summary.dart'; // Import the entity
import 'package:mama_care/utils/app_colors.dart';   // Assuming AppColors
import 'package:mama_care/utils/text_styles.dart';  // Assuming TextStyles
import 'package:mama_care/utils/asset_helper.dart'; // For default avatar

class PatientSummaryCard extends StatelessWidget {
  final PatientSummary patient;
  final VoidCallback? onTap; // Callback when the card is tapped

  const PatientSummaryCard({
    super.key,
    required this.patient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasImage = patient.imageUrl != null && patient.imageUrl!.isNotEmpty;
    final fallbackImage = Image.asset(AssetsHelper.stretching).image; // Default avatar

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0), // Vertical spacing
      elevation: 1.5, // Subtle elevation
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias, // Clip ripple effect
      child: InkWell( // Make the whole card tappable
        onTap: onTap, // Trigger the callback
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Patient Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: hasImage ? NetworkImage(patient.imageUrl!) : fallbackImage,
                child: !hasImage ? const Icon(Icons.person_outline, size: 26, color: Colors.grey) : null,
              ),
              const SizedBox(width: 12),

              // Patient Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      style: TextStyles.titleCard.copyWith(color: AppColors.textDark), // Slightly darker title
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Display Due Date if available
                    if (patient.dueDate != null)
                      Row(
                        children: [
                           Icon(Icons.cake_outlined, size: 14, color: AppColors.textGrey), // Due date icon
                           const SizedBox(width: 4),
                           Text(
                              'Due: ${DateFormat.yMd().format(patient.dueDate!)}', // Format the date
                              style: TextStyles.smallGrey,
                           ),
                        ],
                      ),
                    // TODO: Add other relevant summary info here if needed (e.g., last visit, risk level indicator)
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Trailing action/indicator (e.g., navigate arrow)
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}