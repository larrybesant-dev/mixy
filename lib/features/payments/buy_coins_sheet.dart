import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../presentation/providers/wallet_provider.dart';

// ── Coin package definitions ─────────────────────────────────────────────────

class _CoinPackage {
  const _CoinPackage({
    required this.id,
    required this.coins,
    required this.price,
    this.bonusCoins = 0,
    this.tag,
  });

  final String id;
  final int coins;
  final double price;
  final int bonusCoins;
  final String? tag; // e.g. 'Popular' or 'Best Value'

  int get totalCoins => coins + bonusCoins;
  String get priceLabel => '\$${price.toStringAsFixed(2)}';
}

const _kPackages = <_CoinPackage>[
  _CoinPackage(id: 'coins_70', coins: 70, price: 0.99),
  _CoinPackage(id: 'coins_350', coins: 350, price: 4.99),
  _CoinPackage(
    id: 'coins_1400',
    coins: 1400,
    price: 19.99,
    bonusCoins: 100,
    tag: 'Popular',
  ),
  _CoinPackage(
    id: 'coins_3500',
    coins: 3500,
    price: 49.99,
    bonusCoins: 500,
    tag: 'Best Value',
  ),
];

// ── Public API ────────────────────────────────────────────────────────────────

class BuyCoinsSheet {
  /// Show the Buy Coins bottom sheet.
  ///
  /// ```dart
  /// BuyCoinsSheet.show(context, ref);
  /// ```
  static Future<void> show(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const _BuyCoinsSheetContent(),
      ),
    );
  }
}

// ── Sheet content ─────────────────────────────────────────────────────────────

class _BuyCoinsSheetContent extends ConsumerStatefulWidget {
  const _BuyCoinsSheetContent();

  @override
  ConsumerState<_BuyCoinsSheetContent> createState() =>
      _BuyCoinsSheetContentState();
}

class _BuyCoinsSheetContentState extends ConsumerState<_BuyCoinsSheetContent> {
  String? _loadingPackageId;
  String? _errormessage;

  Future<void> _purchase(_CoinPackage package) async {
    if (_loadingPackageId != null) return;

    setState(() {
      _loadingPackageId = package.id;
      _errormessage = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'createCheckoutSessionCallable',
      );
      final result = await callable.call<Map<String, dynamic>>(
        <String, dynamic>{
          'packageId': package.id,
          'coins': package.totalCoins,
          'price': package.price,
        },
      );
      final data = Map<String, dynamic>.from(result.data);
      final url = _asString(data['url']);
      if (url.isEmpty) throw Exception('No checkout URL returned.');

      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open checkout page.');
      }

      if (mounted) Navigator.of(context).pop();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _errormessage = e.message ?? 'Purchase failed.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errormessage = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loadingPackageId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final walletAsync = ref.watch(walletDetailsProvider);
    final coinBalance = walletAsync.valueOrNull?.coinBalance ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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

          // Header row
          Row(
            children: [
              const Text('🪙', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Buy Coins',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: VelvetNoir.primary,
                  ),
                ),
              ),
              // Current balance badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: VelvetNoir.surfaceHigh,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: VelvetNoir.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      '$coinBalance',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: VelvetNoir.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Package grid — 2 columns
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _kPackages.length,
            itemBuilder: (_, i) => _PackageTile(
              package: _kPackages[i],
              isLoading: _loadingPackageId == _kPackages[i].id,
              onTap: () => _purchase(_kPackages[i]),
            ),
          ),

          if (_errormessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errormessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 16),
          Text(
            kIsWeb
                ? 'You\'ll be redirected to Stripe to complete your purchase securely.'
                : 'Coins are credited to your wallet instantly after purchase.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: VelvetNoir.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Package tile ──────────────────────────────────────────────────────────────

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.package,
    required this.isLoading,
    required this.onTap,
  });

  final _CoinPackage package;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPopular = package.tag != null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Card
        InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isPopular
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        VelvetNoir.surfaceHigh,
                        VelvetNoir.surfaceHighest,
                      ],
                    )
                  : null,
              color: isPopular ? null : VelvetNoir.surfaceHigh,
              border: Border.all(
                color: isPopular
                    ? VelvetNoir.primary
                    : VelvetNoir.outlineVariant,
                width: isPopular ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 4),
                          Text(
                            _formatNumber(package.totalCoins),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: VelvetNoir.primary,
                            ),
                          ),
                        ],
                      ),
                      if (package.bonusCoins > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '+${_formatNumber(package.bonusCoins)} bonus',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: VelvetNoir.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isPopular
                              ? VelvetNoir.primary
                              : VelvetNoir.surfaceHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          package.priceLabel,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: isPopular
                                ? VelvetNoir.surface
                                : VelvetNoir.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        // Tag badge (top-right)
        if (package.tag != null)
          Positioned(
            top: -8,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: VelvetNoir.secondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                package.tag!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatNumber(int n) {
  if (n >= 1000) {
    final k = n / 1000;
    return k == k.truncateToDouble()
        ? '${k.toInt()}K'
        : '${k.toStringAsFixed(1)}K';
  }
  return '$n';
}

String _asString(dynamic value) {
  if (value is String) return value.trim();
  return '';
}
