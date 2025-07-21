import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class FabController extends GetxController {
  final ScrollController scrollController = ScrollController();
  final RxBool isFabExpanded = false.obs;
  final RxList events = <dynamic>[].obs;

  var isFabDisabled = false.obs;

  // Add these new variables for scroll hide/show functionality
  final RxBool isFabVisible = true.obs;
  double lastScrollPosition = 0.0;

  // Add a small threshold to prevent excessive state changes
  static const double scrollThreshold = 10.0;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
  if (!scrollController.hasClients) return;

  final currentScrollPosition = scrollController.offset;
  final scrollDifference = (currentScrollPosition - lastScrollPosition).abs();

  // Add debouncing to prevent rapid state changes
  if (scrollDifference < scrollThreshold) return;

  // The issue might be here - rapid visibility changes
  if (currentScrollPosition > lastScrollPosition && currentScrollPosition > 50) {
    if (isFabVisible.value) {
      isFabVisible.value = false;
      if (isFabExpanded.value) {
        isFabExpanded.value = false;
      }
    }
  } else if (currentScrollPosition < lastScrollPosition) {
    if (!isFabVisible.value) {
      isFabVisible.value = true;
    }
  }

  lastScrollPosition = currentScrollPosition;
}

  
  // void _scrollListener() {
  //   if (!scrollController.hasClients) return;

  //   final currentScrollPosition = scrollController.offset;
  //   final scrollDifference = (currentScrollPosition - lastScrollPosition).abs();

  //   // Only process if scroll difference is significant enough
  //   if (scrollDifference < scrollThreshold) return;

  //   // If scrolling down significantly
  //   if (currentScrollPosition > lastScrollPosition &&
  //       currentScrollPosition > 50) {
  //     if (isFabVisible.value) {
  //       isFabVisible.value = false;
  //       // Only close FAB if it was expanded, but don't force it
  //       if (isFabExpanded.value) {
  //         isFabExpanded.value = false;
  //       }
  //     }
  //   }
  //   // If scrolling up
  //   else if (currentScrollPosition < lastScrollPosition) {
  //     if (!isFabVisible.value) {
  //       isFabVisible.value = true;
  //     }
  //   }

  //   lastScrollPosition = currentScrollPosition;
  // }

  void toggleFab() {
    // Simplified condition - only check if visible
    if (isFabVisible.value && !isFabDisabled.value) {
      HapticFeedback.lightImpact();
      isFabExpanded.toggle();
    }
  }

  // Method to disable FAB temporarily
  void temporarilyDisableFab() {
    isFabDisabled.value = true;
    isFabExpanded.value = false;

    // Enable after 10 seconds
    Future.delayed(const Duration(seconds: 2), () {
      // Check if controller is still initialized
      if (!isClosed) {
        isFabDisabled.value = false;
      }
    });
  }

  void closeFab() {
    isFabExpanded.value = false;
  }

  // Add this method to reset FAB state if needed
  void resetFabState() {
    isFabExpanded.value = false;
    isFabVisible.value = true;
    isFabDisabled.value = false;
  }

  @override
  void onClose() {
    scrollController.removeListener(_scrollListener);
    scrollController.dispose();
    super.onClose();
  }
}


// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';

// class FabController extends GetxController {
//   final ScrollController scrollController = ScrollController();
//   final RxBool isFabExpanded = false.obs;
//   final RxList events = <dynamic>[].obs;

//   var isFabDisabled = false.obs; // Variable to track disabled state
  
//   // Add these new variables for scroll hide/show functionality
//   final RxBool isFabVisible = true.obs;
//   double lastScrollPosition = 0.0;

//   @override
//   void onInit() {
//     super.onInit();
//     // Add scroll listener for hide/show functionality
//     scrollController.addListener(_scrollListener);
//   }

//   // New method to handle scroll events
//   void _scrollListener() {
//     final currentScrollPosition = scrollController.
//     offset;
    
//     // If scrolling down (current position > last position)
//     if (currentScrollPosition > lastScrollPosition && currentScrollPosition > 50) {
//       if (isFabVisible.value) {
//         isFabVisible.value = false;
//         // Also close FAB when hiding
//         isFabExpanded.value = false;
//       }
//     }
//     // If scrolling up (current position < last position)
//     else if (currentScrollPosition < lastScrollPosition) {
//       if (!isFabVisible.value) {
//         isFabVisible.value = true;
//       }
//     }
    
//     lastScrollPosition = currentScrollPosition;
//   }

//   void toggleFab() {
//     // Only toggle if the FAB is not disabled and is visible
//     if (!isFabDisabled.value && isFabVisible.value) {
//       HapticFeedback.lightImpact();
//       isFabExpanded.toggle();
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

//   @override
//   void onClose() {
//     scrollController.dispose();
//     super.onClose();
//   }
// }