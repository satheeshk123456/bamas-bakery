import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../models/review.dart';
import '../services/firestore_service.dart';

class ReviewsScreen extends StatefulWidget {
  final bool embedded;
  const ReviewsScreen({super.key, this.embedded = false});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final _firestore = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<List<Review>>(
      stream: _firestore.reviewsStream(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reviews = snap.data!;
        final avg = reviews.isEmpty
            ? 0.0
            : reviews.fold<double>(0, (s, r) => s + r.rating) / reviews.length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            // Summary card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reviews.isEmpty ? '—' : avg.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 34, fontWeight: FontWeight.bold),
                      ),
                      _Stars(rating: avg),
                    ],
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      reviews.isEmpty
                          ? 'No reviews yet — be the first to leave one!'
                          : 'Based on ${reviews.length} customer review${reviews.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openWriteSheet(context),
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: const Text('Write a Review'),
              ),
            ),
            const SizedBox(height: 22),
            if (reviews.isNotEmpty)
              Text('What people are saying',
                  style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...reviews.map((r) => _ReviewTile(review: r)),
          ],
        );
      },
    );

    if (widget.embedded) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Reviews',
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: body,
    );
  }

  void _openWriteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _WriteReviewSheet(firestore: _firestore),
    );
  }
}

class _Stars extends StatelessWidget {
  final double rating;
  final double size;
  const _Stars({required this.rating, this.size = 17});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = rating >= i + 1;
        final half = !filled && rating > i && rating < i + 1;
        return Icon(
          half
              ? Icons.star_half_rounded
              : (filled ? Icons.star_rounded : Icons.star_border_rounded),
          size: size,
          color: const Color(0xFFF5A623),
        );
      }),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Review review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppBranding.primary.withValues(alpha: 0.12),
                child: Text(
                  review.customerName.isNotEmpty
                      ? review.customerName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: AppBranding.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(review.customerName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              _Stars(rating: review.rating, size: 15),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(review.comment,
                style: const TextStyle(fontSize: 13.5, height: 1.35)),
          ],
        ],
      ),
    );
  }
}

class _WriteReviewSheet extends StatefulWidget {
  final FirestoreService firestore;
  const _WriteReviewSheet({required this.firestore});

  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  final _nameCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  double _rating = 5;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      _nameCtrl.text = prefs.getString('customerName') ?? '';
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter your name')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.firestore.addReview(
        customerName: _nameCtrl.text.trim(),
        rating: _rating,
        comment: _commentCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Write a Review',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          const Text('Your rating', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (i) {
              return IconButton(
                padding: const EdgeInsets.only(right: 4),
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _rating = i + 1),
                icon: Icon(
                  _rating >= i + 1
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 34,
                  color: const Color(0xFFF5A623),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Your name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Your comment (optional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Review'),
            ),
          ),
        ],
      ),
    );
  }
}
