import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../services/cart_service.dart';
import '../services/review_service.dart';
import '../services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/auth_required_message.dart';
import './cart_page.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({Key? key, required this.product}) : super(key: key);

  @override
  _ProductDetailPageState createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> with SingleTickerProviderStateMixin {
  final CartService _cartService = CartService();
  final ReviewService _reviewService = ReviewService();
  final NotificationService _notificationService = NotificationService();
  int _quantity = 1;
  bool _isAddingToCart = false;
  bool _isSubmittingReview = false;
  bool _isRegistering = false;
  late TabController _tabController;
  final TextEditingController _reviewController = TextEditingController();
  double _userRating = 5.0;

  List<Review> _reviews = [];
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoadingReviews = true;
    });

    try {
      final reviews = await _reviewService.getProductReviews(widget.product.id);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingReviews = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reviews: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _addToCart({bool navigateToCart = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => const AuthRequiredMessage(action: 'add items to cart'),
      );
      return;
    }

    setState(() {
      _isAddingToCart = true;
    });

    try {
      await _cartService.addToCart(
        user.uid,
        widget.product,
        quantity: _quantity,
      );

      if (!mounted) return;

      if (navigateToCart) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CartPage(
              onOrderConfirmed: () {},
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to cart'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding to cart: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });
      }
    }
  }

  Future<void> _registerForNotification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => const AuthRequiredMessage(action: 'receive notifications'),
      );
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    try {
      await _notificationService.registerForProductAvailability(
        userId: user.uid,
        productId: widget.product.id,
        userEmail: user.email ?? '',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You will be notified when this product becomes available'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error registering for notification: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => const AuthRequiredMessage(action: 'submit a review'),
      );
      return;
    }

    if (_reviewController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a review comment'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSubmittingReview = true;
    });

    try {
      await _reviewService.submitReview(
        productId: widget.product.id,
        userId: user.uid,
        userName: user.displayName ?? 'Anonymous',
        rating: _userRating,
        comment: _reviewController.text,
      );

      if (!mounted) return;

      _reviewController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review submitted successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _loadReviews();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting review: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingReview = false;
        });
      }
    }
  }

  Future<void> _markReviewHelpful(String reviewId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => const AuthRequiredMessage(action: 'mark a review as helpful'),
      );
      return;
    }

    try {
      await _reviewService.markReviewHelpful(reviewId, user.uid);
      if (!mounted) return;

      _loadReviews();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marked as helpful'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking review as helpful: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _reportReview(String reviewId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => const AuthRequiredMessage(action: 'report a review'),
      );
      return;
    }

    final reasonController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Review'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for reporting',
            hintText: 'Please explain why you are reporting this review',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(reasonController.text);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        await _reviewService.reportReview(reviewId, user.uid, result);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review reported. Thank you for helping us maintain quality content.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reporting review: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Added to favorites'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            tooltip: 'Add to favorites',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Share feature coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            tooltip: 'Share product',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Reviews'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              // DETAILS TAB
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: widget.product.imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                            imageUrl: widget.product.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) {
                              print('Image failed to load: $url, error: $error');
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.pets,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Image not available',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                              : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.pets,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No image available',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (widget.product.discountText().isNotEmpty)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(8),
                                ),
                              ),
                              child: Text(
                                widget.product.discountText(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        if (!widget.product.inStock)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withOpacity(0.5),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.error.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'OUT OF STOCK',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.product.name,
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: widget.product.inStock ? Colors.green : Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.product.inStock ? 'In Stock' : 'Out of Stock',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                    (index) {
                                  if (index < widget.product.rating.floor()) {
                                    return const Icon(Icons.star, color: Colors.amber);
                                  } else if (index == widget.product.rating.floor() &&
                                      widget.product.rating % 1 > 0) {
                                    return const Icon(Icons.star_half, color: Colors.amber);
                                  } else {
                                    return const Icon(Icons.star_border, color: Colors.amber);
                                  }
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Text(
                                  '${widget.product.rating}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              const SizedBox(width: 4),
                              TextButton(
                                onPressed: () {
                                  _tabController.animateTo(1);
                                },
                                child: Text(
                                  'See Reviews',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '\$${widget.product.price.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (widget.product.originalPrice != null &&
                                  widget.product.originalPrice! > widget.product.price)
                                Text(
                                  '\$${widget.product.originalPrice!.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Description',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.product.description,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 24),
                          if (widget.product.features != null && widget.product.features!.isNotEmpty) ...[
                            Text(
                              'Features',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: widget.product.features!.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          widget.product.features![index],
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (widget.product.inStock) ...[
                            Row(
                              children: [
                                Text(
                                  'Quantity:',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove),
                                        onPressed: _quantity > 1
                                            ? () {
                                          setState(() {
                                            _quantity--;
                                          });
                                        }
                                            : null,
                                        tooltip: 'Decrease quantity',
                                      ),
                                      Text(
                                        '$_quantity',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add),
                                        onPressed: _quantity < 10
                                            ? () {
                                          setState(() {
                                            _quantity++;
                                          });
                                        }
                                            : null,
                                        tooltip: 'Increase quantity',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (!widget.product.inStock) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.notifications_active),
                                label: Text(_isRegistering ? 'Processing...' : 'Notify Me When Available'),
                                onPressed: _isRegistering ? null : _registerForNotification,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),

              // REVIEWS TAB
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary of reviews
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Overall Rating',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Text(
                                            '${widget.product.rating}',
                                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: List.generate(
                                                  5,
                                                      (index) {
                                                    if (index < widget.product.rating.floor()) {
                                                      return const Icon(Icons.star, color: Colors.amber, size: 20);
                                                    } else if (index == widget.product.rating.floor() &&
                                                        widget.product.rating % 1 > 0) {
                                                      return const Icon(Icons.star_half, color: Colors.amber, size: 20);
                                                    } else {
                                                      return const Icon(Icons.star_border, color: Colors.amber, size: 20);
                                                    }
                                                  },
                                                ),
                                              ),
                                              Text(
                                                'Based on ${_reviews.length} reviews',
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Write a review section
                      Text(
                        'Write a Review',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Rating',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: List.generate(
                                  5,
                                      (index) => GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _userRating = index + 1.0;
                                      });
                                    },
                                    child: Icon(
                                      index < _userRating ? Icons.star : Icons.star_border,
                                      color: Colors.amber,
                                      size: 36,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Your Review',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _reviewController,
                                maxLines: 5,
                                decoration: const InputDecoration(
                                  hintText: 'Share your experience with this product...',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isSubmittingReview ? null : _submitReview,
                                  child: _isSubmittingReview
                                      ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                      : const Text('Submit Review'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Customer Reviews
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Customer Reviews',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _loadReviews,
                            tooltip: 'Refresh reviews',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Display actual reviews from Firestore
                      _isLoadingReviews
                          ? const Center(child: CircularProgressIndicator())
                          : _reviews.isEmpty
                          ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Text('No reviews yet. Be the first to review this product!'),
                        ),
                      )
                          : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _reviews.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final review = _reviews[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      review.userName,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _getFormattedDate(review.timestamp),
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: List.generate(
                                    5,
                                        (i) => Icon(
                                      i < review.rating ? Icons.star : Icons.star_border,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  review.comment,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.thumb_up,
                                            color: review.helpfulUserIds.contains(FirebaseAuth.instance.currentUser?.uid)
                                                ? Theme.of(context).colorScheme.primary
                                                : Colors.grey,
                                            size: 16,
                                          ),
                                          onPressed: () => _markReviewHelpful(review.id),
                                          tooltip: 'Mark as helpful',
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(8),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${review.helpfulUserIds.length}',
                                          style: Theme.of(context).textTheme.labelMedium,
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: () => _reportReview(review.id),
                                      child: const Text('Report'),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Bottom bar for actions
          if (widget.product.inStock)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isAddingToCart ? null : () => _addToCart(),
                        child: _isAddingToCart
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Text('Add to Cart'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isAddingToCart ? null : () => _addToCart(navigateToCart: true),
                        child: _isAddingToCart
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Text('Buy Now'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                           backgroundColor: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getFormattedDate(DateTime? timestamp) {
    if (timestamp == null) return 'Unknown date';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}