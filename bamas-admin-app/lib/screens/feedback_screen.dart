import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/enquiry.dart';
import '../models/review.dart';
import '../services/feedback_service.dart';

/// Everything customers submit that isn't an order: the Enquiry
/// ("contact us") form and star-rating reviews. Both used to be written
/// straight to Firestore with no way for the admin to ever see them --
/// this screen closes that gap.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return '';
    return DateFormat('MMM d, h:mm a').format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback'),
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Enquiries'), Tab(text: 'Reviews')]),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_EnquiriesTab(formatDate: _formatDate), _ReviewsTab(formatDate: _formatDate)],
      ),
    );
  }
}

class _EnquiriesTab extends StatefulWidget {
  final String Function(String?) formatDate;
  const _EnquiriesTab({required this.formatDate});

  @override
  State<_EnquiriesTab> createState() => _EnquiriesTabState();
}

class _EnquiriesTabState extends State<_EnquiriesTab> {
  late Future<List<Enquiry>> _future;

  @override
  void initState() {
    super.initState();
    _future = feedbackService.listEnquiries();
  }

  Future<void> _refresh() async {
    setState(() => _future = feedbackService.listEnquiries());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Enquiry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(children: [
              const SizedBox(height: 80),
              Center(child: Text('Could not load enquiries.\n${snapshot.error}', textAlign: TextAlign.center)),
            ]);
          }
          final enquiries = snapshot.data ?? [];
          if (enquiries.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 100),
              Center(child: Text('No enquiries yet.', style: TextStyle(color: AppBranding.textMuted))),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: enquiries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final e = enquiries[i];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.name.isEmpty ? 'Customer' : e.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (e.createdAt != null)
                            Text(widget.formatDate(e.createdAt), style: const TextStyle(color: AppBranding.textMuted, fontSize: 11.5)),
                        ],
                      ),
                      if (e.phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(e.phone, style: const TextStyle(color: AppBranding.textMuted, fontSize: 12.5)),
                      ],
                      const SizedBox(height: 8),
                      Text(e.message),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: Icon(e.handled ? Icons.check_circle : Icons.check_circle_outline,
                              size: 18, color: e.handled ? AppBranding.success : AppBranding.textMuted),
                          label: Text(e.handled ? 'Handled' : 'Mark as handled'),
                          onPressed: () async {
                            setState(() => enquiries[i] = Enquiry(
                                  id: e.id,
                                  name: e.name,
                                  phone: e.phone,
                                  message: e.message,
                                  handled: !e.handled,
                                  createdAt: e.createdAt,
                                ));
                            try {
                              await feedbackService.markEnquiryHandled(e.id, !e.handled);
                            } catch (err) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $err')));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ReviewsTab extends StatefulWidget {
  final String Function(String?) formatDate;
  const _ReviewsTab({required this.formatDate});

  @override
  State<_ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<_ReviewsTab> {
  late Future<List<AdminReview>> _future;

  @override
  void initState() {
    super.initState();
    _future = feedbackService.listReviews();
  }

  Future<void> _refresh() async {
    setState(() => _future = feedbackService.listReviews());
    await _future;
  }

  Future<void> _delete(AdminReview review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete review?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await feedbackService.deleteReview(review.id);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<AdminReview>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(children: [
              const SizedBox(height: 80),
              Center(child: Text('Could not load reviews.\n${snapshot.error}', textAlign: TextAlign.center)),
            ]);
          }
          final reviews = snapshot.data ?? [];
          if (reviews.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 100),
              Center(child: Text('No reviews yet.', style: TextStyle(color: AppBranding.textMuted))),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = reviews[i];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(r.customerName, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 16, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(r.rating.toStringAsFixed(1)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppBranding.danger, size: 20),
                            onPressed: () => _delete(r),
                          ),
                        ],
                      ),
                      if (r.comment.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(r.comment),
                      ],
                      if (r.createdAt != null) ...[
                        const SizedBox(height: 6),
                        Text(widget.formatDate(r.createdAt), style: const TextStyle(color: AppBranding.textMuted, fontSize: 11.5)),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
