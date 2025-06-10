// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';

// class FabController extends GetxController {
//   final ScrollController scrollController = ScrollController();
//   final RxBool isFabExpanded = false.obs;
//   var isFabDisabled = false.obs; // Variable to track disabled state

//   void toggleFab() {
//     // Only toggle if the FAB is not disabled
//     if (!isFabDisabled.value) {
//       HapticFeedback.lightImpact();
//       isFabExpanded
//           .toggle(); // This already toggles the value, don't need to do it twice
//     }
//   }

//   // Method to disable FAB temporarily
//   void temporarilyDisableFab() {
//     isFabDisabled.value = true;

//     // Make sure FAB is closed when disabled
//     isFabExpanded.value = false;

//     // Enable after 10 seconds
//     Future.delayed(const Duration(seconds: 10), () {
//       isFabDisabled.value = false;
//     });
//   }

//   void closeFab() {
//     isFabExpanded.value = false;
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class FabController extends GetxController {
  final ScrollController scrollController = ScrollController();
  final RxBool isFabExpanded = false.obs;
  final RxList events = <dynamic>[].obs;

  var isFabDisabled = false.obs; // Variable to track disabled state
  
  // Add these new variables for scroll hide/show functionality
  final RxBool isFabVisible = true.obs;
  double lastScrollPosition = 0.0;

  @override
  void onInit() {
    super.onInit();
    // Add scroll listener for hide/show functionality
    scrollController.addListener(_scrollListener);
  }

  // New method to handle scroll events
  void _scrollListener() {
    final currentScrollPosition = scrollController.offset;
    
    // If scrolling down (current position > last position)
    if (currentScrollPosition > lastScrollPosition && currentScrollPosition > 50) {
      if (isFabVisible.value) {
        isFabVisible.value = false;
        // Also close FAB when hiding
        isFabExpanded.value = false;
      }
    }
    // If scrolling up (current position < last position)
    else if (currentScrollPosition < lastScrollPosition) {
      if (!isFabVisible.value) {
        isFabVisible.value = true;
      }
    }
    
    lastScrollPosition = currentScrollPosition;
  }

  void toggleFab() {
    // Only toggle if the FAB is not disabled and is visible
    if (!isFabDisabled.value && isFabVisible.value) {
      HapticFeedback.lightImpact();
      isFabExpanded.toggle();
    }
  }

  // Method to disable FAB temporarily
  void temporarilyDisableFab() {
    isFabDisabled.value = true;

    // Make sure FAB is closed when disabled
    isFabExpanded.value = false;

    // Enable after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      isFabDisabled.value = false;
    });
  }

  void closeFab() {
    isFabExpanded.value = false;
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
}