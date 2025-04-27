// lib/presentation/view/pregnancy_detail_view.dart

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for input formatters
//import 'package:mama_care/presentation/widgets/mama_care_app_bar.dart'; // Assuming you might want an AppBar
import 'package:mama_care/utils/app_colors.dart'; // Import your colors
import 'package:mama_care/utils/text_styles.dart'; // Import your text styles
import 'package:provider/provider.dart';
import 'package:mama_care/presentation/viewmodel/pregnancy_detail_viewmodel.dart';
import 'package:mama_care/utils/asset_helper.dart'; // Import your AssetHelper
import 'package:sizer/sizer.dart';
import 'package:logger/logger.dart'; // Import Logger
import 'package:mama_care/injection.dart'; // For locator

class PregnancyDetailView extends StatefulWidget {
  const PregnancyDetailView({super.key});

  @override
  State<PregnancyDetailView> createState() => _PregnancyDetailViewState();
}

class _PregnancyDetailViewState extends State<PregnancyDetailView> {
  final _formKey = GlobalKey<FormState>(); // Add a form key for validation
  final _babyWeightController = TextEditingController();
  final _babyHeightController = TextEditingController();
  final _carouselController = CarouselSliderController();
  final Logger _logger = locator<Logger>(); // Get logger instance
  int _currentPage = 0;

  @override
  void dispose() {
    _babyWeightController.dispose();
    _babyHeightController.dispose();
    super.dispose();
  }

  // Snackbar helper
  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- Handle Final Submission ---
  Future<void> _handleFinalSubmit() async {
    FocusManager.instance.primaryFocus?.unfocus(); // Dismiss keyboard

    // Validate the form
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnackbar("Please fill in all required fields.", isError: true);
      // Optionally, navigate back to the first slide with an error
      if (_currentPage != 0) {
        _carouselController.animateToPage(0);
      }
      return;
    }

    // Get the ViewModel
    final viewModel = context.read<PregnancyDetailViewModel>();

    // Ensure date was selected (it should be by design, but good practice)
    if (viewModel.startingDate == null) {
      _showSnackbar("Please select the first day of pregnancy.", isError: true);
      _carouselController.animateToPage(2); // Go to calendar slide
      return;
    }

    // Attempt to save
    _logger.i("Attempting to save pregnancy details...");
    final success = await viewModel.addPregnancyDetail();

    if (!mounted) return; // Check if widget is still mounted after async call

    if (success) {
      _showSnackbar("Pregnancy details saved successfully!");
      Navigator.pop(context); // Go back to previous screen
    } else {
      _showSnackbar(
        viewModel.errorMessage ?? "Failed to save details.",
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer to react to ViewModel changes (like loading state)
    return Consumer<PregnancyDetailViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          // Optional AppBar
          // appBar: const MamaCareAppBar(title: "Pregnancy Details"),
          extendBodyBehindAppBar: true, // If you want content behind AppBar
          backgroundColor: AppColors.primaryLight.withOpacity(
            0.8,
          ), // Use theme color
          bottomNavigationBar: _buildBottomNavBar(viewModel),
          body: Stack(
            // Stack for potential loading overlay
            children: [
              Form(
                // Wrap Carousel in a Form for validation
                key: _formKey,
                child: CarouselSlider(
                  carouselController: _carouselController,
                  items: [
                    // Pass controllers directly to build methods
                    _buildBabyWeightSlide(_babyWeightController),
                    _buildBabyHeightSlide(_babyHeightController),
                    _buildCalendarSlide(viewModel), // Pass VM for date change
                  ],
                  options: CarouselOptions(
                    height: 100.h, // Full screen height
                    enableInfiniteScroll: false, // Don't loop
                    viewportFraction: 1.0, // Show one slide at a time
                    enlargeCenterPage: false,
                    autoPlay: false, // Don't auto-play
                    scrollPhysics:
                        const NeverScrollableScrollPhysics(), // Disable manual swipe
                    onPageChanged: (index, reason) {
                      // Update the current page index for bottom navigation logic
                      setState(() {
                        _currentPage = index;
                      });
                    },
                  ),
                ),
              ),
              // Loading Overlay
              if (viewModel.isLoading)
                Opacity(
                  opacity: 0.7,
                  child: ModalBarrier(
                    dismissible: false,
                    color: Colors.black.withOpacity(
                      0.3,
                    ), // Semi-transparent overlay
                  ),
                ),
              if (viewModel.isLoading)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
            ],
          ),
        );
      },
    );
  }

  // --- Bottom Navigation Bar ---
  Widget _buildBottomNavBar(PregnancyDetailViewModel viewModel) {
    return BottomAppBar(
      color: AppColors.primary, // Use theme color
      elevation: 8.0, // Add some elevation
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Back Button (Visible on pages > 0)
            if (_currentPage > 0)
              IconButton(
                icon: const Icon(
                  Icons.chevron_left,
                  color: Colors.white,
                  size: 30,
                ),
                tooltip: "Previous",
                onPressed:
                    viewModel.isLoading
                        ? null
                        : () {
                          // Disable if loading
                          _carouselController.previousPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOut,
                          );
                        },
              )
            else
              const SizedBox(width: 48), // Placeholder to keep spacing
            // Indicator Dots or Text
            Text(
              "Step ${_currentPage + 1} of 3", // Indicate progress
              style: TextStyles.bodyWhite.copyWith(fontWeight: FontWeight.bold),
            ),

            // Next / Done Button
            IconButton(
              icon: Icon(
                _currentPage == 2 ? Icons.check_rounded : Icons.chevron_right,
                color: Colors.white,
                size: 30,
              ),
              tooltip: _currentPage == 2 ? "Save Details" : "Next",
              // Disable if loading, call appropriate function on press
              onPressed:
                  viewModel.isLoading
                      ? null
                      : () {
                        if (_currentPage == 2) {
                          // Update VM state before final submit
                          // (Handles potential parsing errors)
                          try {
                            final weight = double.tryParse(
                              _babyWeightController.text.trim(),
                            );
                            final height = double.tryParse(
                              _babyHeightController.text.trim(),
                            );
                            if (weight != null)
                              viewModel.onBabyWeightChanged(weight);
                            if (height != null)
                              viewModel.onBabyHeightChanged(height);
                          } catch (e) {
                            _logger.e(
                              "Error parsing weight/height before save",
                              error: e,
                            );
                          }
                          _handleFinalSubmit();
                        } else {
                          _carouselController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOut,
                          );
                        }
                      },
            ),
          ],
        ),
      ),
    );
  }

  // --- Slide Builder Methods ---

  // Takes the controller as an argument
  Widget _buildBabyWeightSlide(TextEditingController controller) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
        child: SingleChildScrollView(
          // Ensure scrollability on small screens
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                // Add a title
                "Baby's Estimated Weight",
                style: TextStyles.headline2.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 5.h),
              Card(
                elevation: 15,
                shadowColor: Colors.black.withOpacity(0.4),
                shape: CircleBorder(
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.8),
                    width: 8,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(50.0), // Adjust padding
                  child: Image.asset(
                    AssetsHelper.babyWeight,
                    height: 15.h, // Adjust size
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              TextFormField(
                // Use TextFormField for validation
                controller: controller,
                style: TextStyles.bodyBold.copyWith(
                  fontSize: 16.sp,
                ), // Style input text
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "Enter Weight (e.g., 1.5)",
                  hintStyle: TextStyles.bodyGrey,
                  suffixText: "kg", // Add unit indicator
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30), // Rounded border
                    borderSide: BorderSide.none, // No visible border line
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 2.h,
                    horizontal: 5.w,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d+\.?\d{0,2}'),
                  ), // Allow numbers and decimal
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter weight';
                  }
                  if (double.tryParse(value.trim()) == null) {
                    return 'Invalid number';
                  }
                  return null; // Valid
                },
                // Update ViewModel on change (optional, could do on submit)
                 onChanged: (value) {
                   final weight = double.tryParse(value);
                  if (weight != null) {
                     context.read<PregnancyDetailViewModel>().onBabyWeightChanged(weight);
                   }
                 },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Takes the controller as an argument
  Widget _buildBabyHeightSlide(TextEditingController controller) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                // Add a title
                "Baby's Estimated Height",
                style: TextStyles.headline2.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 5.h),
              Card(
                elevation: 15,
                shadowColor: Colors.black.withOpacity(0.4),
                shape: CircleBorder(
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.8),
                    width: 8,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(50.0),
                  child: Image.asset(
                    AssetsHelper.babyHeight,
                    height: 15.h,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              TextFormField(
                // Use TextFormField
                controller: controller,
                style: TextStyles.bodyBold.copyWith(fontSize: 16.sp),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "Enter Height (e.g., 30.5)",
                  hintStyle: TextStyles.bodyGrey,
                  suffixText: "cm",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 2.h,
                    horizontal: 5.w,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter height';
                  }
                  if (double.tryParse(value.trim()) == null) {
                    return 'Invalid number';
                  }
                  return null; // Valid
                },
                 onChanged: (value) {
                  final height = double.tryParse(value);
                   if (height != null) {
                    context.read<PregnancyDetailViewModel>().onBabyHeightChanged(height);
                   }
                 },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Takes the ViewModel as an argument
  Widget _buildCalendarSlide(PregnancyDetailViewModel viewModel) {
    // Use the date from the view model, default to now if null initially
    final initialDate =
        viewModel.startingDate != null
            ? DateTime.fromMillisecondsSinceEpoch(
              viewModel.startingDate! as int,
            )
            : DateTime.now();

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 5.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "First Day of Last Period", // More common terminology
              style: TextStyles.headline2.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4.h),
            Card(
              elevation: 10, // Slightly less elevation
              shape: RoundedRectangleBorder(
                // Rounded rectangle shape
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CalendarDatePicker(
                  // Key might help if initialDate changes need forcing a rebuild
                  key: ValueKey(initialDate.toIso8601String()),
                  initialDate: initialDate,
                  // Allow selecting dates in the past (up to ~1 year), but not future
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                  onDateChanged: (dateTime) {
                    // Update the ViewModel when the date changes
                    viewModel.onStartingDayChanged(dateTime);
                    _logger.d("Selected Start Date: $dateTime");
                  },
                  // Optional: Customize appearance
                   initialCalendarMode: DatePickerMode.day,
                ),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              "(Select the first day of your last menstrual period)",
              style: TextStyles.bodyWhite.copyWith(fontSize: 11.sp),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// REMOVE THE SEPARATE WIDGET CLASSES BELOW THIS LINE
// class BabyWeight extends StatelessWidget { ... } // DELETE
// class BabyHeight extends StatelessWidget { ... } // DELETE
// class CalendarDatePickerSlide extends StatefulWidget { ... } // DELETE
// class _CalendarDatePickerSlideState extends State<CalendarDatePickerSlide> { ... } // DELETE
