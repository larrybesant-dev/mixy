import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../features/room/providers/stripe_coins_provider.dart';

/// Modal for purchasing coins via Stripe.
class BuyCoinModal {
  static void show(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BuyCoinModalContent(callerRef: ref),
    );
  }
}

class _BuyCoinModalContent extends ConsumerStatefulWidget {
  final WidgetRef callerRef;

  const _BuyCoinModalContent({required this.callerRef});

  @override
  ConsumerState<_BuyCoinModalContent> createState() =>
      _BuyCoinModalContentState();
}

class _BuyCoinModalContentState extends ConsumerState<_BuyCoinModalContent> {
  String? _selectedPackageId;

  Future<void> _purchase() async {
    final packageId = _selectedPackageId;
    if (packageId == null) return;

    final packages = ref.read(coinPackagesProvider);
    final package = packages.firstWhere((p) => p.id == packageId);

    final purchaseNotifier = ref.read(coinPurchaseProvider.notifier);

    try {
      await purchaseNotifier.purchaseCoins(package);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coins purchased successfully! 🎉'),
            backgroundColor: VelvetNoir.primary,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase failed: ${e.toString()}'),
            backgroundColor: VelvetNoir.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final packages = ref.watch(coinPackagesProvider);
    final purchaseState = ref.watch(coinPurchaseProvider);

    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) {
        return Container(
          color: VelvetNoir.surface,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: VelvetNoir.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Text(
                'Buy Coins',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: VelvetNoir.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'More coins = more gifts to send',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: VelvetNoir.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),

              // Coin packages grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: packages.length,
                itemBuilder: (_, i) {
                  final pkg = packages[i];
                  final isSelected = _selectedPackageId == pkg.id;

                  return InkWell(
                    onTap: () => setState(() => _selectedPackageId = pkg.id),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? VelvetNoir.primary
                              : VelvetNoir.outlineVariant,
                          width: isSelected ? 2 : 1,
                        ),
                        color: isSelected
                            ? VelvetNoir.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (pkg.isPopular)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: VelvetNoir.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Best Value',
                                style: TextStyle(
                                  color: VelvetNoir.surface,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 24),
                          const SizedBox(height: 8),
                          Text(
                            '${pkg.coins}',
                            style: const TextStyle(
                              color: VelvetNoir.primary,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Coins',
                            style: TextStyle(
                              color: VelvetNoir.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$${pkg.priceUSD.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: VelvetNoir.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Error message
              if (purchaseState.error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VelvetNoir.error.withValues(alpha: 0.2),
                    border: Border.all(color: VelvetNoir.error),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    purchaseState.error!,
                    style: const TextStyle(
                      color: VelvetNoir.onSurface,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Purchase button
              FilledButton.icon(
                onPressed: (_selectedPackageId == null ||
                        purchaseState.isLoading)
                    ? null
                    : _purchase,
                icon: purchaseState.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            VelvetNoir.primary,
                          ),
                        ),
                      )
                    : const Icon(Icons.paid),
                style: FilledButton.styleFrom(
                  backgroundColor: VelvetNoir.primary,
                  foregroundColor: VelvetNoir.surface,
                ),
                label: Text(
                  _selectedPackageId == null
                      ? 'Select a package'
                      : 'Buy Coins',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
