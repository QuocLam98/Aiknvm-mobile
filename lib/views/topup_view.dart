import 'package:flutter/material.dart';

/// Simple top-up/pricing screen that mirrors the provided design.
/// Currently focuses on layout/UI. Hook up payment flow from the "Mua ngay" buttons later.
class TopUpView extends StatelessWidget {
  const TopUpView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Nạp tiền')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive grid: 1/2/3/4 columns based on width
          int crossAxisCount = 1;
          final w = constraints.maxWidth;
          if (w >= 1200) {
            crossAxisCount = 4;
          } else if (w >= 900) {
            crossAxisCount = 3;
          } else if (w >= 600) {
            crossAxisCount = 2;
          }

          // Define the plans once
          const plans = [
            _PricingCard(
              priceText: '50.000 vnd',
              bullets: [
                'Hỏi – đáp mọi lĩnh vực như giáo dục, tâm lí, pháp lí, bệnh lí, y học, khoa học, công nghệ, tin học, giới tính, tình yêu, hôn nhân, gia đình.',
                'Có thể gỡ được 30 câu hỏi với câu trả lời có độ chính xác cao.',
              ],
            ),
            _PricingCard(
              priceText: '100.000 vnd',
              bullets: [
                'Hỏi được tất cả các lĩnh vực như giáo dục, tâm lí, pháp lí, bệnh lí, y học, khoa học, công nghệ, tin học, giới tính, tình yêu, hôn nhân, gia đình, cách chữa bệnh, hướng dẫn dùng thuốc, viết thơ, viết bài diễn thuyết, bài phát biểu.',
                'Có thể hỏi lên tới 100 câu hỏi hay yêu cầu với câu trả lời chuẩn và chất lượng cao, vượt xa các bản miễn phí.',
              ],
            ),
            _PricingCard(
              priceText: '150.000 vnd',
              bullets: [
                'Hỏi được tất cả các lĩnh vực như giáo dục, tâm lí, pháp lí, bệnh lí, y học, khoa học, công nghệ, tin học, giới tính, tình yêu, hôn nhân, gia đình, cách chữa bệnh, hướng dẫn dùng thuốc, viết thơ, viết bài diễn thuyết, bài phát biểu, kịch bản, viết sách, truyện, tạo tranh ảnh.',
                'Có thể hỏi lên tới 150 câu hỏi hay yêu cầu với câu trả lời có độ tin cậy cao, hơn hẳn các bản miễn phí.',
              ],
            ),
            _PricingCard(
              priceText: '200.000 vnd',
              bullets: [
                'Hỏi được tất cả các lĩnh vực như giáo dục, tâm lí, pháp lí, bệnh lí, y học, khoa học, công nghệ, tin học, giới tính, tình yêu, hôn nhân, gia đình, cách chữa bệnh, hướng dẫn dùng thuốc, viết thơ, viết bài diễn thuyết, bài phát biểu, kịch bản, viết sách, truyện, nghiên cứu khoa học, tìm nguồn tài liệu chính xác, đưa ra ý tưởng, kế hoạch, viết thơ, bài hát, truyện ngắn, kịch bản video, phim tạp, tạo nhiều tranh ảnh.',
                'Có thể gõ được 200 câu hỏi hay yêu cầu dài với câu trả lời dài, chuẩn và chất lượng cao, vượt xa các bản miễn phí.',
              ],
            ),
          ];

          Widget list;
          if (crossAxisCount == 1) {
            // Use a ListView for single-column to avoid fixed-height grid overflows.
            list = ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (ctx, i) => plans[i],
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemCount: plans.length,
            );
          } else {
            double aspect = 0.8;
            if (crossAxisCount == 2) aspect = 0.65;
            if (crossAxisCount == 3) aspect = 0.55;
            if (crossAxisCount >= 4) aspect = 0.48;

            list = GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: aspect,
              ),
              itemCount: plans.length,
              itemBuilder: (ctx, i) => plans[i],
            );
          }

          return Column(
            children: [
              Expanded(child: list),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Center(
                  child: Text(
                    '(*) 1 credits = 1 USD',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final String priceText;
  final List<String> bullets;

  const _PricingCard({required this.priceText, required this.bullets});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.black.withOpacity(0.08)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              priceText,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...bullets.map((t) => _bullet(t)).toList(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF635BFF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  // TODO: Hook payment flow. For now, show a placeholder.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chức năng thanh toán sẽ sớm có.'),
                    ),
                  );
                },
                child: const Text('Mua ngay'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3.0),
            child: Icon(Icons.check_circle, color: Colors.green, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}
