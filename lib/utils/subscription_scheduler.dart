import 'package:flutter/foundation.dart';
import '../services/subscription_billing_service.dart';

/// Utility class to schedule and manage subscription billing checks
class SubscriptionScheduler {
  static final SubscriptionScheduler _instance = SubscriptionScheduler._internal();
  factory SubscriptionScheduler() => _instance;
  SubscriptionScheduler._internal();

  final SubscriptionBillingService _billingService = SubscriptionBillingService();
  bool _isInitialized = false;

  /// Initialize the subscription scheduler
  /// This should be called when the app starts
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ Subscription scheduler already initialized');
      return;
    }

    try {
      debugPrint('🔧 Initializing subscription scheduler...');
      
      // Run initial check
      await _billingService.checkAndSendBillingReminders();
      
      _isInitialized = true;
      debugPrint('✅ Subscription scheduler initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing subscription scheduler: $e');
    }
  }

  /// Manually trigger a billing check
  /// Useful for testing or manual refresh
  Future<void> triggerBillingCheck() async {
    try {
      debugPrint('🔄 Manual billing check triggered');
      await _billingService.checkAndSendBillingReminders();
      debugPrint('✅ Manual billing check completed');
    } catch (e) {
      debugPrint('❌ Error in manual billing check: $e');
    }
  }

  /// Check if scheduler is initialized
  bool get isInitialized => _isInitialized;
}
