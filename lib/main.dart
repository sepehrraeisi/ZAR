import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  runApp(const ZarPlusApp());
}

class ZarPlusApp extends StatelessWidget {
  const ZarPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ZAR+',
      themeMode: ThemeMode.light,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: ZarShell(),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    const warmAccent = Color(0xFFC08A3D);
    final surface = isDark ? const Color(0xFF151515) : const Color(0xFFFBFAF8);
    final card = isDark ? const Color(0xFF1D1D1D) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF4F4F4) : const Color(0xFF121212);
    final textSecondary = isDark ? const Color(0xFFA9A9A9) : const Color(0xFF707070);

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: surface,
      fontFamily: 'Vazirmatn',
      colorScheme: ColorScheme.fromSeed(
        seedColor: warmAccent,
        brightness: brightness,
        surface: card,
      ).copyWith(
        error: const Color(0xFFBD3A3A),
      ),
      textTheme: TextTheme(
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.35,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.35,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.45,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          height: 1.55,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.6,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      dividerColor: isDark ? const Color(0xFF303030) : const Color(0xFFECEAE6),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: surface,
        foregroundColor: textPrimary,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Vazirmatn',
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFE0DED8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF252525) : const Color(0xFFF6F4F1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: warmAccent, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );

    return base;
  }
}

class ZarShell extends StatefulWidget {
  const ZarShell({super.key});

  @override
  State<ZarShell> createState() => _ZarShellState();
}

class _ZarShellState extends State<ZarShell> {
  int _index = 0;

  final _pages = const [
    HomeScreen(),
    CalendarScreen(),
    SizedBox.shrink(),
    PeopleScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _index, children: _pages),
      ),
      bottomNavigationBar: _ZBottomBar(
        currentIndex: _index,
        onTap: (value) {
          if (value == 2) {
            _openQuickAddSheet();
            return;
          }
          setState(() {
            _index = value;
          });
        },
      ),
    );
  }

  Future<void> _openQuickAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const QuickAddSheet(),
    );
  }
}

class _ZBottomBar extends StatelessWidget {
  const _ZBottomBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final inactive = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    Widget item({
      required int index,
      required IconData icon,
      required String label,
    }) {
      final isActive = currentIndex == index;
      final color = isActive ? accent : inactive;
      return Expanded(
        child: InkWell(
          onTap: () => onTap(index),
          child: SizedBox(
            height: 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 21, color: color),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                children: [
                  item(index: 0, icon: CupertinoIcons.house, label: 'خانه'),
                  item(index: 1, icon: CupertinoIcons.calendar, label: 'تقویم'),
                  const SizedBox(width: 70),
                  item(index: 3, icon: CupertinoIcons.person_2, label: 'اشخاص'),
                ],
              ),
              GestureDetector(
                onTap: () => onTap(2),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.34),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(CupertinoIcons.add, size: 24, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = Jalali.now();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('ZAR+'),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(CupertinoIcons.bell),
              tooltip: 'اعلان‌ها',
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              '${weekdayName(now.weekDay)}\n${formatJalaliDate(now)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        _buildSection(context, title: 'عقب‌افتاده', items: mockOverdue, isOverdue: true),
        _buildSection(context, title: 'امروز', items: mockToday),
        _buildSection(context, title: 'فردا', items: mockTomorrow),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<SettlementItem> items,
    bool isOverdue = false,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isOverdue ? const Color(0xFF9D3636) : null,
                      ),
                ),
                const SizedBox(width: 8),
                Text(
                  toPersianDigits(items.length.toString()),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const _ZEmptyRow(label: 'موردی ثبت نشده است.')
            else
              ...items.map(
                (item) => _SettlementRow(
                  item: item,
                  showOverdueTone: isOverdue,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettlementRow extends StatelessWidget {
  const _SettlementRow({
    required this.item,
    this.showOverdueTone = false,
  });

  final SettlementItem item;
  final bool showOverdueTone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = showOverdueTone
        ? const Color(0xFF9D3636)
        : item.status == SettlementStatus.completed
            ? const Color(0xFF2F7D4C)
            : theme.textTheme.bodyMedium?.color;

    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.dividerColor),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.operationLabel} • ${item.personName}',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AmountText(item.amountDisplay),
                      Text(item.assetLabel, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.timeLabel,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  item.statusLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _ZEmptyRow extends StatelessWidget {
  const _ZEmptyRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key});

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  String? _operation;
  String? _asset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('چه کاری می‌خواهید ثبت کنید؟', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['خرید', 'فروش', 'دریافت', 'تحویل'].map((value) {
                final selected = _operation == value;
                return ChoiceChip(
                  label: Text(value),
                  selected: selected,
                  onSelected: (_) => setState(() => _operation = value),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            Text('نوع دارایی', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['طلا', 'ارز'].map((value) {
                final selected = _asset == value;
                return ChoiceChip(
                  label: Text(value),
                  selected: selected,
                  onSelected: _operation == null ? null : (_) => setState(() => _asset = value),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (_operation != null && _asset != null) ...[
              TextField(decoration: const InputDecoration(labelText: 'شخص')),
              const SizedBox(height: 10),
              TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: _asset == 'طلا' ? 'مقدار' : 'مبلغ'),
              ),
              const SizedBox(height: 10),
              if (_asset == 'طلا')
                TextField(
                  decoration: const InputDecoration(labelText: 'عیار (اختیاری)'),
                ),
              if (_asset == 'طلا') const SizedBox(height: 10),
              TextField(decoration: const InputDecoration(labelText: 'تاریخ')),
              const SizedBox(height: 10),
              TextField(decoration: const InputDecoration(labelText: 'ساعت (اختیاری)')),
              const SizedBox(height: 10),
              TextField(decoration: const InputDecoration(labelText: 'یادآوری')),
              const SizedBox(height: 10),
              TextField(decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)')),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ثبت'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  Jalali _month = Jalali.now().withDay(1);
  Jalali _selectedDay = Jalali.now();

  @override
  Widget build(BuildContext context) {
    final events = mockCalendarEvents;
    final selectedEvents = events.where((e) => isSameJalali(e.date, _selectedDay)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('تقویم')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _month = _month.addMonths(-1)),
                  icon: const Icon(CupertinoIcons.chevron_right),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${monthName(_month.month)} ${toPersianDigits(_month.year.toString())}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _month = _month.addMonths(1)),
                  icon: const Icon(CupertinoIcons.chevron_left),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _CalendarMonthGrid(
              month: _month,
              selected: _selectedDay,
              eventDays: events.map((e) => e.date).toList(),
              onDayTap: (date) => setState(() => _selectedDay = date),
            ),
            const SizedBox(height: 16),
            Text(
              'برنامه روز ${formatJalaliDate(_selectedDay)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: selectedEvents.isEmpty
                  ? const Center(child: Text('برای این روز موردی ثبت نشده است.'))
                  : ListView.separated(
                      itemBuilder: (context, index) => _SettlementRow(item: selectedEvents[index]),
                      separatorBuilder: (_, __) => const SizedBox(height: 0),
                      itemCount: selectedEvents.length,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarMonthGrid extends StatelessWidget {
  const _CalendarMonthGrid({
    required this.month,
    required this.selected,
    required this.eventDays,
    required this.onDayTap,
  });

  final Jalali month;
  final Jalali selected;
  final List<Jalali> eventDays;
  final ValueChanged<Jalali> onDayTap;

  @override
  Widget build(BuildContext context) {
    const weekTitles = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

    final firstWeekday = ((month.toDateTime().weekday + 1) % 7);
    final daysInMonth = month.monthLength;

    final cells = <Widget>[];
    for (final title in weekTitles) {
      cells.add(
        Center(
          child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }

    for (int i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = month.withDay(day);
      final hasEvent = eventDays.any((eventDate) => isSameJalali(eventDate, date));
      final isSelected = isSameJalali(selected, date);

      cells.add(
        GestureDetector(
          onTap: () => onDayTap(date),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  toPersianDigits(day.toString()),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 2),
                if (hasEvent)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(height: 5),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 7,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.9,
        children: cells,
      ),
    );
  }
}

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = mockPeople
        .where((person) => person.name.contains(query.trim()))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('اشخاص')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'جستجو در اشخاص',
                prefixIcon: Icon(CupertinoIcons.search),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemBuilder: (context, index) {
                  final person = filtered[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
                      child: Text(
                        person.name.trim().isEmpty ? '-' : person.name.trim()[0],
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    title: Text(
                      person.name,
                      style: Theme.of(context).textTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${toPersianDigits(person.openCount.toString())} تعهد باز',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    trailing: const Icon(CupertinoIcons.chevron_left, size: 18),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PersonDetailScreen(person: person),
                        ),
                      );
                    },
                  );
                },
                separatorBuilder: (_, __) => Divider(color: Theme.of(context).dividerColor),
                itemCount: filtered.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PersonDetailScreen extends StatelessWidget {
  const PersonDetailScreen({super.key, required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final personItems = mockAllItems.where((item) => item.personName == person.name).toList();
    final openItems = personItems.where((item) => item.status == SettlementStatus.open).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('جزئیات شخص')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          children: [
            Text(person.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(person.phone ?? 'شماره تماس ثبت نشده است.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 14),
            Text(
              '${toPersianDigits(openItems.length.toString())} تعهد باز',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            ...openItems.map((item) => _SettlementRow(item: item)),
            const SizedBox(height: 18),
            Text('سوابق', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...personItems.map((item) => _SettlementRow(item: item)),
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سوابق')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text('امروز', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...mockHistory.map((item) => _SettlementRow(item: item)),
        ],
      ),
    );
  }
}

class AmountText extends StatelessWidget {
  const AmountText(this.amount, {super.key});

  final String amount;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        amount,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

enum SettlementStatus { open, completed, cancelled }

class SettlementItem {
  SettlementItem({
    required this.operationLabel,
    required this.personName,
    required this.amountDisplay,
    required this.assetLabel,
    required this.timeLabel,
    required this.status,
    required this.date,
  });

  final String operationLabel;
  final String personName;
  final String amountDisplay;
  final String assetLabel;
  final String timeLabel;
  final SettlementStatus status;
  final Jalali date;

  String get statusLabel {
    switch (status) {
      case SettlementStatus.open:
        return 'در انتظار';
      case SettlementStatus.completed:
        return 'انجام شد';
      case SettlementStatus.cancelled:
        return 'لغو شد';
    }
  }
}

class Person {
  Person({
    required this.name,
    required this.openCount,
    this.phone,
  });

  final String name;
  final int openCount;
  final String? phone;
}

final mockOverdue = [
  SettlementItem(
    operationLabel: 'تحویل',
    personName: 'رضا محمدی',
    amountDisplay: '\$10,000',
    assetLabel: 'ارز',
    timeLabel: 'دیروز ۱۱:۰۰',
    status: SettlementStatus.open,
    date: Jalali.now().addDays(-1),
  ),
];

final mockToday = [
  SettlementItem(
    operationLabel: 'دریافت',
    personName: 'علی رضایی',
    amountDisplay: '۲۵۰',
    assetLabel: 'گرم طلا',
    timeLabel: '۱۰:۳۰',
    status: SettlementStatus.open,
    date: Jalali.now(),
  ),
  SettlementItem(
    operationLabel: 'تحویل',
    personName: 'حسن کریمی',
    amountDisplay: '€5,000',
    assetLabel: 'ارز',
    timeLabel: '۱۴:۴۵',
    status: SettlementStatus.open,
    date: Jalali.now(),
  ),
];

final mockTomorrow = [
  SettlementItem(
    operationLabel: 'دریافت',
    personName: 'مهدی احمدی',
    amountDisplay: '۴۰۰',
    assetLabel: 'گرم طلا',
    timeLabel: 'بدون ساعت',
    status: SettlementStatus.open,
    date: Jalali.now().addDays(1),
  ),
];

final mockHistory = [
  SettlementItem(
    operationLabel: 'دریافت',
    personName: 'علی رضایی',
    amountDisplay: '۳۰۰',
    assetLabel: 'گرم طلا',
    timeLabel: '۰۹:۱۰',
    status: SettlementStatus.completed,
    date: Jalali.now(),
  ),
  SettlementItem(
    operationLabel: 'تحویل',
    personName: 'رضا محمدی',
    amountDisplay: '\$8,000',
    assetLabel: 'ارز',
    timeLabel: '۱۲:۲۰',
    status: SettlementStatus.completed,
    date: Jalali.now(),
  ),
];

final mockPeople = [
  Person(name: 'علی رضایی', openCount: 2, phone: '۰۹۱۲۱۲۳۴۵۶۷'),
  Person(name: 'رضا محمدی', openCount: 1, phone: '۰۹۱۲۴۴۴۵۵۶۶'),
  Person(name: 'حسن کریمی', openCount: 1, phone: '۰۹۱۲۳۳۳۴۴۵۵'),
  Person(name: 'مهدی احمدی با نام خانوادگی طولانی', openCount: 0),
];

List<SettlementItem> get mockAllItems => [...mockOverdue, ...mockToday, ...mockTomorrow, ...mockHistory];

List<SettlementItem> get mockCalendarEvents => mockAllItems;

String formatJalaliDate(Jalali date) {
  return '${toPersianDigits(date.day.toString())} ${monthName(date.month)} ${toPersianDigits(date.year.toString())}';
}

String weekdayName(int weekday) {
  switch (weekday) {
    case 1:
      return 'دوشنبه';
    case 2:
      return 'سه‌شنبه';
    case 3:
      return 'چهارشنبه';
    case 4:
      return 'پنج‌شنبه';
    case 5:
      return 'جمعه';
    case 6:
      return 'شنبه';
    case 7:
      return 'یکشنبه';
    default:
      return '';
  }
}

String monthName(int month) {
  const months = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];
  return months[month - 1];
}

String toPersianDigits(String input) {
  const latin = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

  var output = input;
  for (int i = 0; i < latin.length; i++) {
    output = output.replaceAll(latin[i], persian[i]);
  }
  return output;
}

bool isSameJalali(Jalali a, Jalali b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String formatAmountWithGrouping(int amount) {
  final formatter = NumberFormat('#,###');
  return toPersianDigits(formatter.format(amount));
}
