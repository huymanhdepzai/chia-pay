import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/utils/app_format.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/expense.dart';
import '../../domain/services/split_calculator.dart';
import '../../domain/usecases/expense_usecases.dart';
import '../../injection.dart';

class AddExpensePage extends StatefulWidget {
  final Group group;
  final List<Member> members;
  final ExpenseWithDetails? expenseToEdit;

  const AddExpensePage({super.key, required this.group, required this.members, this.expenseToEdit});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  /// Ô nhập số tiền / phần trăm của từng thành viên khi chia tùy chỉnh.
  final Map<int, TextEditingController> _customControllers = {};

  Member? _selectedPayer;
  List<Member> _selectedParticipants = [];
  String _category = 'Ăn uống';
  DateTime _date = DateTime.now();
  SplitType _splitType = SplitType.equal;
  bool _saving = false;

  bool get _isEditing => widget.expenseToEdit != null;

  @override
  void initState() {
    super.initState();
    for (final m in widget.members) {
      _customControllers[m.id] = TextEditingController()..addListener(_refresh);
    }
    _amountController.addListener(_refresh);

    if (widget.expenseToEdit != null) {
      final e = widget.expenseToEdit!;
      _nameController.text = e.expense.name;
      _amountController.text = formatNumber(e.expense.amount);
      _noteController.text = e.expense.note ?? '';
      _category = e.expense.category;
      _date = e.expense.date;
      _splitType = SplitType.fromValue(e.expense.splitType);

      try {
        _selectedPayer = widget.members.firstWhere((m) => m.id == e.payer.id);
      } catch (_) {
        _selectedPayer = widget.members.isNotEmpty ? widget.members.first : null;
      }

      _selectedParticipants = widget.members.where((m) {
        return e.shares.any((s) => s.member.id == m.id && s.share.amount > 0);
      }).toList();

      for (final s in e.shares) {
        final controller = _customControllers[s.member.id];
        if (controller == null) continue;
        if (_splitType == SplitType.exact) {
          controller.text = formatNumber(s.share.amount);
        } else if (_splitType == SplitType.percent) {
          final bp = s.share.percentBp ?? (s.share.amount * SplitCalculator.fullPercentBp / e.expense.amount).round();
          controller.text = SplitCalculator.formatPercent(bp);
        }
      }
    } else if (widget.members.isNotEmpty) {
      _selectedPayer = widget.members.first;
      _selectedParticipants = List.from(widget.members);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    for (final c in _customControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _refresh() => setState(() {});

  int? get _amount => parseAmount(_amountController.text);

  /// Phần tiền của từng người theo cách chia đang chọn. Ném [SplitException] nếu chưa hợp lệ.
  Map<int, int> _computeShares() {
    final amount = _amount ?? 0;
    switch (_splitType) {
      case SplitType.equal:
        // Giữ thứ tự thành viên trong nhóm để phần dư luôn rơi vào cùng một người.
        final ids = widget.members.where(_selectedParticipants.contains).map((m) => m.id).toList();
        return SplitCalculator.equal(amount, ids);
      case SplitType.exact:
        return SplitCalculator.exact(amount, {
          for (final m in widget.members) m.id: parseAmount(_customControllers[m.id]!.text) ?? 0,
        });
      case SplitType.percent:
        final bps = <int, int>{};
        for (final m in widget.members) {
          final text = _customControllers[m.id]!.text;
          if (text.trim().isEmpty) continue;
          final bp = SplitCalculator.parsePercent(text);
          if (bp == null) throw SplitException('Tỷ lệ của ${m.name} không hợp lệ');
          bps[m.id] = bp;
        }
        return SplitCalculator.percent(amount, bps);
    }
  }

  ({Map<int, int>? shares, String? error}) _preview() {
    try {
      return (shares: _computeShares(), error: null);
    } on SplitException catch (e) {
      return (shares: null, error: e.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute));
    }
  }

  void _saveExpense() async {
    if (_saving) return;
    if (_nameController.text.trim().isEmpty || _selectedPayer == null) {
      _showError('Vui lòng nhập tên khoản chi và chọn người thanh toán');
      return;
    }
    final amount = _amount;
    if (amount == null || amount <= 0) {
      _showError('Số tiền phải lớn hơn 0');
      return;
    }

    final preview = _preview();
    if (preview.shares == null) {
      _showError(preview.error!);
      return;
    }

    final expense = Expense(
      id: _isEditing ? widget.expenseToEdit!.expense.id : 0,
      groupId: widget.group.id,
      payerId: _selectedPayer!.id,
      name: _nameController.text.trim(),
      amount: amount,
      date: _date,
      category: _category,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      splitType: _splitType.value,
      createdAt: _isEditing ? widget.expenseToEdit!.expense.createdAt : DateTime.now(),
    );

    final shares = preview.shares!.entries
        .map((entry) => ExpenseShare(
              id: 0,
              expenseId: expense.id,
              memberId: entry.key,
              amount: entry.value,
              percentBp: _splitType == SplitType.percent
                  ? SplitCalculator.parsePercent(_customControllers[entry.key]!.text)
                  : null,
            ))
        .toList();

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await sl<UpdateExpense>().call(expense, shares);
      } else {
        await sl<AddExpense>().call(expense, shares);
      }
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa khoản chi' : 'Thêm khoản chi', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
      ),
      body: widget.members.isEmpty ? _buildNoMemberState() : _buildForm(),
      bottomNavigationBar: widget.members.isEmpty ? null : _buildBottomBar(),
    );
  }

  Widget _buildNoMemberState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[300]).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 16),
          Text(
            'Chưa có thành viên',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.5),
          const SizedBox(height: 8),
          Text(
            'Hãy thêm thành viên để ghi chép',
            style: TextStyle(color: Colors.grey[500]),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.5),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAmountInput().animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
          const SizedBox(height: 32),
          _buildSectionTitle('Tên khoản chi').animate().fadeIn(delay: 100.ms).slideX(begin: 0.1),
          const SizedBox(height: 12),
          _buildNameInput().animate().fadeIn(delay: 150.ms).slideX(begin: 0.1),
          const SizedBox(height: 16),
          _buildDateAndNote().animate().fadeIn(delay: 180.ms).slideX(begin: 0.1),
          const SizedBox(height: 32),
          _buildSectionTitle('Danh mục').animate().fadeIn(delay: 200.ms).slideX(begin: 0.1),
          const SizedBox(height: 12),
          _buildCategorySelector().animate().fadeIn(delay: 250.ms).slideX(begin: 0.1),
          const SizedBox(height: 32),
          _buildSectionTitle('Người thanh toán (Đã trả tiền)').animate().fadeIn(delay: 300.ms).slideX(begin: 0.1),
          const SizedBox(height: 12),
          _buildPayerSelector().animate().fadeIn(delay: 350.ms).slideX(begin: 0.1),
          const SizedBox(height: 32),
          _buildSectionTitle('Cách chia').animate().fadeIn(delay: 380.ms).slideX(begin: 0.1),
          const SizedBox(height: 12),
          _buildSplitTypeSelector().animate().fadeIn(delay: 400.ms).slideX(begin: 0.1),
          const SizedBox(height: 20),
          if (_splitType == SplitType.equal) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('Người dùng chung'),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedParticipants.length == widget.members.length) {
                        _selectedParticipants.clear();
                      } else {
                        _selectedParticipants = List.from(widget.members);
                      }
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).primaryColor,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  child: Text(_selectedParticipants.length == widget.members.length ? 'Bỏ chọn tất cả' : 'Chọn tất cả'),
                )
              ],
            ),
            _buildParticipantsSelector(),
          ] else
            _buildCustomSplitInputs(),
          const SizedBox(height: 24),
          _buildSharePreview(),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('SỐ TIỀN', style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IntrinsicWidth(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: context.textPrimary, height: 1.0),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: '0',
                    hintStyle: TextStyle(color: context.textPrimary.withValues(alpha: 0.26)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Text(
                  widget.group.currency,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary.withValues(alpha: 0.45)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400]),
      filled: true,
      fillColor: context.cardColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      prefixIcon: Icon(icon, color: Colors.grey[400]),
    );
  }

  Widget _buildNameInput() {
    return TextField(
      controller: _nameController,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      decoration: _fieldDecoration(hint: 'VD: Ăn tối tại nhà hàng...', icon: Icons.edit_note),
    );
  }

  Widget _buildDateAndNote() {
    return Column(
      children: [
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: Colors.grey[400], size: 20),
                const SizedBox(width: 14),
                Text('Ngày chi', style: TextStyle(color: context.textSecondary)),
                const Spacer(),
                Text(formatDate(_date), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _noteController,
          maxLines: 2,
          minLines: 1,
          decoration: _fieldDecoration(hint: 'Ghi chú (không bắt buộc)', icon: Icons.sticky_note_2_outlined),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      child: Row(
        children: expenseCategories.entries.map((entry) {
          final isSelected = _category == entry.key;
          return GestureDetector(
            onTap: () => setState(() => _category = entry.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).primaryColor : context.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSelected
                    ? [BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 5, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Icon(entry.value, color: isSelected ? Colors.white : Colors.grey[500], size: 20),
                  const SizedBox(width: 10),
                  Text(
                    entry.key,
                    style: TextStyle(
                      color: isSelected ? Colors.white : context.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPayerSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      child: Row(
        children: widget.members.map((m) {
          final isSelected = _selectedPayer == m;
          return GestureDetector(
            onTap: () => setState(() => _selectedPayer = m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 20),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.all(isSelected ? 3 : 0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : context.cardColor,
                      child: Text(
                        m.name.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    m.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Theme.of(context).primaryColor : context.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSplitTypeSelector() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<SplitType>(
        segments: const [
          ButtonSegment(value: SplitType.equal, label: Text('Chia đều'), icon: Icon(Icons.drag_handle_rounded)),
          ButtonSegment(value: SplitType.exact, label: Text('Số tiền'), icon: Icon(Icons.payments_outlined)),
          ButtonSegment(value: SplitType.percent, label: Text('%'), icon: Icon(Icons.percent_rounded)),
        ],
        selected: {_splitType},
        showSelectedIcon: false,
        onSelectionChanged: (s) {
          // Số tiền và tỷ lệ không dùng chung được nên xóa ô nhập khi đổi cách chia.
          for (final c in _customControllers.values) {
            c.clear();
          }
          setState(() => _splitType = s.first);
        },
      ),
    );
  }

  Widget _buildParticipantsSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: widget.members.map((m) {
        final isSelected = _selectedParticipants.contains(m);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedParticipants.remove(m);
              } else {
                _selectedParticipants.add(m);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.08) : context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.5) : Colors.transparent),
              boxShadow: !isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))] : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  m.name,
                  style: TextStyle(
                    color: isSelected ? Theme.of(context).primaryColor : context.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Ô nhập số tiền hoặc tỷ lệ cho từng thành viên. Để trống = không tham gia.
  Widget _buildCustomSplitInputs() {
    final isPercent = _splitType == SplitType.percent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isPercent ? 'Nhập tỷ lệ % cho từng người (để trống nếu không tham gia)' : 'Nhập số tiền cho từng người (để trống nếu không tham gia)',
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        ...widget.members.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    child: Text(m.name.substring(0, 1).toUpperCase(),
                        style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _customControllers[m.id],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '0',
                        suffixText: isPercent ? '%' : widget.group.currency,
                        filled: true,
                        fillColor: context.cardColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
            )),
        if (!isPercent && _amount != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
              label: const Text('Điền đều cho mọi người'),
              onPressed: () {
                final shares = SplitCalculator.equal(_amount!, widget.members.map((m) => m.id).toList());
                for (final m in widget.members) {
                  _customControllers[m.id]!.text = formatNumber(shares[m.id]!);
                }
              },
            ),
          ),
      ],
    );
  }

  /// Hiển thị ngay số tiền mỗi người phải chịu trước khi lưu.
  Widget _buildSharePreview() {
    final amount = _amount;
    if (amount == null || amount <= 0) return const SizedBox.shrink();
    final preview = _preview();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: preview.error != null ? Colors.redAccent.withValues(alpha: 0.06) : Theme.of(context).primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: preview.error != null ? Colors.redAccent.withValues(alpha: 0.3) : Theme.of(context).primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(preview.error != null ? Icons.error_outline_rounded : Icons.pie_chart_outline_rounded,
                  size: 20, color: preview.error != null ? Colors.redAccent : Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              const Text('Mỗi người phải chịu', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          if (preview.error != null)
            Text(preview.error!, style: const TextStyle(color: Colors.redAccent))
          else
            ...widget.members.where((m) => preview.shares!.containsKey(m.id)).map((m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(m.name)),
                      Text(formatMoney(preview.shares![m.id]!, widget.group.currency),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: context.cardColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, -10)),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
          ),
          onPressed: _saving ? null : _saveExpense,
          child: Text(
            _isEditing ? 'Cập nhật khoản chi' : 'Xác nhận khoản chi',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ),
      ),
    ).animate().slideY(begin: 1.0, duration: 400.ms, curve: Curves.easeOutCubic);
  }
}
