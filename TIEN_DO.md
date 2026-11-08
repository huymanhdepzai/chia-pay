9# 📋 TIẾN ĐỘ DỰ ÁN CHIAPAY

> Bảng theo dõi tiến độ chi tiết được đối chiếu trực tiếp với tài liệu đặc tả yêu cầu **[ChiaPay.pdf](file:///C:/ChiaPay/chia_pay/ChiaPay.pdf)**.  
> Cập nhật lần cuối: 08/11/2026.

---

## 📊 Tổng quan tiến độ

| Phạm vi | Trạng thái | Đánh giá |
| :--- | :---: | :--- |
| **MVP (Phạm vi bắt buộc hoàn thành)** | 🟢 **100% Hoàn thành** | Đã hoàn thành toàn bộ 4 phân hệ cốt lõi, cơ sở dữ liệu Drift/SQLite, thuật toán cân bằng và bộ Unit Test. |
| **Phân hệ mở rộng (Phân hệ 5 & 6)** | 🟢 **100% Hoàn thành** | Đã hoàn thiện toàn bộ Thống kê biểu đồ, xuất CSV, Sao lưu/Khôi phục JSON, Khóa mã PIN, Chế độ Sáng/Tối. |
| **Tính năng Nâng cao (Nếu còn thời gian)** | 🟡 **40% Hoàn thành** | Đã làm: Thống kê biểu đồ, Sao lưu & Khôi phục, Xuất CSV. Chưa làm: OCR hóa đơn, Xuất PDF, Thuật toán tối ưu Subset-Sum. |

---

## ✅ CÁC MỤC ĐÃ HOÀN THÀNH

### 1. Phân hệ 1 – Quản lý nhóm (Mục 3.1)
- [x] **Tạo nhóm đa dạng**: Hỗ trợ phân loại nhóm theo chủ đề (Du lịch, Ăn uống, Ở ghép, Sinh hoạt gia đình...) kèm icon/màu sắc trực quan ([`group_list_page.dart`](file:///C:/ChiaPay/chia_pay/lib/presentation/pages/group_list_page.dart)).
- [x] **Thêm, sửa, xóa thành viên**: Thêm mới thành viên, sửa tên, xóa thành viên an toàn (ngăn chặn xóa thành viên đã phát sinh khoản chi tiêu) ([`group_detail_page.dart`](file:///C:/ChiaPay/chia_pay/lib/presentation/pages/group_detail_page.dart)).
- [x] **Thông tin chi tiết nhóm**: Nhập và lưu trữ tên nhóm, mô tả, đơn vị tiền tệ riêng (VND, USD, EUR...), ngày bắt đầu và kết thúc chuyến đi.
- [x] **Tổng quan nhóm**: Hiển thị tổng tiền đã chi của toàn nhóm và số dư (đã ứng / phải chịu) của từng thành viên.

### 2. Phân hệ 2 – Quản lý khoản chi (Mục 3.2)
- [x] **Thêm khoản chi**: Nhập tên khoản chi, số tiền, ngày chi, danh mục phân loại và ghi chú chi tiết ([`add_expense_page.dart`](file:///C:/ChiaPay/chia_pay/lib/presentation/pages/add_expense_page.dart)).
- [x] **Người thanh toán**: Chọn người thực tế đã bỏ tiền thanh toán (hỗ trợ trường hợp người trả không thuộc nhóm cùng chịu tiền).
- [x] **Thành viên tham gia**: Tùy chọn danh sách những người cùng chịu khoản chi (multi-select).
- [x] **3 Chế độ chia tiền linh hoạt**:
  - [x] **Chia đều (Equal)**: Tự động chia đều cho những người tham gia, tự động phân bổ phần dư lẻ để tổng tiền khớp 100% không lệch 1 xu/đồng.
  - [x] **Chia theo số tiền tùy chỉnh (Exact)**: Cho phép nhập số tiền cụ thể của từng người, kiểm tra tổng khớp tuyệt đối.
  - [x] **Chia theo tỷ lệ phần trăm (Percent)**: Nhập phần trăm từng người (tổng 100%), tính ra số tiền nguyên vẹn không sai số số thực.
- [x] **Sửa và xóa khoản chi**: Cho phép cập nhật thông tin khoản chi hoặc xóa, tự động tính toán lại số dư toàn nhóm từ dữ liệu gốc trong SQLite transaction ([`expense_repository_impl.dart`](file:///C:/ChiaPay/chia_pay/lib/data/repositories/expense_repository_impl.dart)).

### 3. Phân hệ 3 – Số dư và quyết toán (Mục 3.3 & Mục 4)
- [x] **Tổng hợp số tiền mỗi người đã ứng**: Tính tổng số tiền đã bỏ ra thanh toán của từng thành viên.
- [x] **Tổng hợp chi phí mỗi người phải chịu**: Tính tổng trách nhiệm chi phí thực tế mà từng thành viên phải gánh.
- [x] **Xác định trạng thái nợ/nhận**: Phân tách rõ ràng thành viên cần nhận (số dư dương) và người cần trả (số dư âm).
- [x] **Đề xuất giao dịch hoàn tiền tối ưu**:
  - Áp dụng thuật toán ghép nợ giảm số lần chuyển tiền so với việc quyết toán từng hóa đơn đơn lẻ ([`balance_usecases.dart`](file:///C:/ChiaPay/chia_pay/lib/domain/usecases/balance_usecases.dart#L48-L93)).
  - Đảm bảo với $N$ người có số dư khác 0 thì số giao dịch đề xuất tối đa chỉ là $N - 1$.
- [x] **Tiến độ quyết toán**: Tính toán và hiển thị thanh % tiến độ giải quyết công nợ của nhóm (dựa trên tỷ lệ số tiền đã thanh toán) ([`settlement_page.dart`](file:///C:/ChiaPay/chia_pay/lib/presentation/pages/settlement_page.dart)).

### 4. Phân hệ 4 – Theo dõi hoàn tiền (Mục 3.4)
- [x] **Đánh dấu đã thanh toán**: Ghi nhận một giao dịch nợ đã được chuyển khoản hoặc thanh toán xong.
- [x] **Lưu thông tin giao dịch**: Ghi nhận ngày giờ thanh toán, số tiền thực trả và ghi chú giao dịch.
- [x] **Hỗ trợ hoàn tác (Undo)**: Cho phép xóa hoặc hủy trạng thái đã thanh toán khi người dùng lỡ tay bấm nhầm.
- [x] **Phân biệt 2 loại số dư**:
  - `theoreticalBalance` (Số dư lý thuyết): Dựa trên tổng chi tiêu ban đầu.
  - `remainingBalance` (Số tiền thực tế còn chưa quyết toán): Đã trừ đi các giao dịch đã chuyển khoản thành công.
- [x] **Hoạt động hoàn toàn Offline**: Dữ liệu lưu cục bộ trên máy, người dùng tự chuyển khoản ngoài đời thực mà không cần kết nối máy chủ/Internet.

### 5. Phân hệ 5 – Thống kê và báo cáo (Mục 3.5 & Mục 6)
- [x] **Thống kê chi tiêu đa chiều**: Thống kê theo danh mục chi tiêu, theo từng thành viên và theo mốc thời gian ([`statistics_page.dart`](file:///C:/ChiaPay/chia_pay/lib/presentation/pages/statistics_page.dart)).
- [x] **Biểu đồ chi tiêu**: Tích hợp thư viện `fl_chart` vẽ biểu đồ phân tích cơ cấu chi tiêu trực quan.
- [x] **Bộ lọc**: Lọc danh sách các khoản chi tiêu theo từng người thanh toán.
- [x] **Xuất CSV & Tin nhắn tổng kết**:
  - Xuất bảng chi tiêu ra file CSV (có hỗ trợ BOM UTF-8 để mở tiếng Việt trên Microsoft Excel) ([`report_builder.dart`](file:///C:/ChiaPay/chia_pay/lib/core/utils/report_builder.dart)).
  - Tạo định dạng văn bản bảng quyết toán đẹp mắt để gửi nhanh qua Zalo, Messenger, SMS ([`share_helper.dart`](file:///C:/ChiaPay/chia_pay/lib/core/utils/share_helper.dart)).

### 6. Phân hệ 6 – Cài đặt và dữ liệu (Mục 3.6)
- [x] **Giao diện Sáng / Tối (Dark Mode)**: Hỗ trợ 3 tùy chọn: Theo hệ thống, Sáng (Light), Tối (Dark) ([`settings_page.dart`](file:///C:/ChiaPay/chia_pay/lib/presentation/pages/settings_page.dart)).
- [x] **Đơn vị tiền tệ mặc định**: Thiết lập tiền tệ mặc định cho ứng dụng (VND, USD, EUR, JPY...).
- [x] **Khóa ứng dụng bằng mã PIN**: Bảo mật bằng mã PIN 4 số khi mở lại ứng dụng ([`lock_page.dart`](file:///C:/ChiaPay/chia_pay/lib/presentation/pages/lock_page.dart)).
- [x] **Sao lưu và khôi phục dữ liệu**: Xuất toàn bộ dữ liệu ra file `.json` và khôi phục khi cần bằng bộ chọn file (`file_picker`).
- [x] **Quản lý nhóm đã lưu trữ (Archived)**: Lưu trữ các nhóm đã hoàn thành chuyến đi và phục hồi lại khi muốn tra cứu ([`archived_groups_page.dart`](file:///C:/ChiaPay/chia_pay/lib/presentation/pages/archived_groups_page.dart)).

### 7. Kiến trúc kỹ thuật & Database (Mục 5 & Mục 7)
- [x] **Clean Architecture + BLoC/Cubit**: Tách biệt rõ ràng tầng Presentation, Domain, Data; quản lý trạng thái bằng Cubit và điều hướng bằng `GoRouter` ([`app_router.dart`](file:///C:/ChiaPay/chia_pay/lib/routes/app_router.dart)).
- [x] **Độc lập UseCase**: Tách riêng `CalculateBalancesUseCase` và `GenerateSettlementUseCase` không phụ thuộc Flutter UI hay SQLite, phục vụ viết Unit Test độc lập.
- [x] **Cơ sở dữ liệu SQLite qua Drift**:
  - Sử dụng số nguyên (`int`) đại diện cho tiền tệ, loại trừ hoàn toàn sai số số thực (`double`).
  - Lưu bảng `expense_shares` lưu tiền chi tiết của từng người.
  - Bật cấu hình `PRAGMA foreign_keys = ON` và thực thi transaction đồng bộ.
  - Cơ chế Migration DB hỗ trợ nâng cấp phiên bản schema an toàn ([`database.dart`](file:///C:/ChiaPay/chia_pay/lib/core/database/database.dart)).

### 8. Đã vượt qua toàn bộ 37/37 Unit Test (Mục 9)
Tất cả 8 trường hợp kiểm thử đặc biệt yêu cầu trong đề cương đều đã được viết test và chạy pass 100% (`flutter test`):
- [x] Chia đều khoản tiền không chia hết (ví dụ 100.000đ cho 3 người): Phân bổ phần dư, tổng khớp 100.000đ.
- [x] Một người thanh toán nhưng không tham gia vào khoản chi đó.
- [x] Thành viên mới được thêm vào sau khi nhóm đã phát sinh hóa đơn.
- [x] Sửa hoặc xóa khoản chi và cập nhật tính toán lại số dư từ dữ liệu gốc.
- [x] Một người vừa là người nhận ở khoản này, vừa là người trả ở khoản khác.
- [x] Đánh dấu giao dịch đã thanh toán rồi hoàn tác lại.
- [x] Đóng và mở lại ứng dụng (kiểm tra sao lưu - khôi phục), dữ liệu toàn vẹn.
- [x] Tổng số dư toàn bộ nhóm luôn bằng 0, sai số tối đa bằng 0 đồng.

---

## ❌ CÁC MỤC CHƯA LÀM (Phạm vi nâng cao & Mở rộng)

Dựa theo **Mục 10 (Nâng cao – Nếu còn thời gian)** và yêu cầu hoàn thiện đồ án:

### 1. OCR Hóa đơn (Chưa làm)
- [ ] Tích hợp camera / thư viện chụp ảnh hoặc chọn ảnh hóa đơn (ví dụ `google_mlkit_text_recognition` hoặc AI API).
- [ ] Tự động bóc tách tổng tiền, ngày thanh toán và tên hàng quán từ ảnh chụp để điền tự động vào màn hình Thêm chi tiêu.

### 2. Xuất báo cáo định dạng PDF (Chưa làm)
- [ ] Hiện tại ứng dụng mới hỗ trợ xuất file **CSV** và chia sẻ văn bản dạng **Text**.
- [ ] Chưa tích hợp thư viện tạo file **PDF** (ví dụ gói `pdf` / `printing`) để xuất hóa đơn/báo cáo quyết toán có định dạng in ấn chuyên nghiệp (gồm logo, bảng biểu, chữ ký chốt tiền).

### 3. Thuật toán tối ưu số giao dịch tối thiểu tuyệt đối (Chưa hoàn thiện dạng Subset-Sum)
- [ ] Hiện tại thuật toán đề xuất đang dùng giải thuật **Greedy (Tham lam - ghép cặp nợ lớn nhất với có lớn nhất)**. Thuật toán này đảm bảo tối đa $N - 1$ giao dịch.
- [ ] Chưa triển khai thuật toán giải bài toán **Subset Sum / NP-hard** (cho nhóm nhỏ $N \le 10$) để tìm tập hợp triệt tiêu nợ cục bộ nhằm đưa số lượng giao dịch về mức tối thiểu tuyệt đối (ít hơn $N - 1$ khi có các nhóm con tổng bằng 0).

### 4. Tài liệu báo cáo & Thuyết trình môn học (Đề cương mục 8 & 10)
- [ ] Viết tài liệu báo cáo kỹ thuật môn học (Word / PDF) theo tên đề tài gợi ý: *“Xây dựng ứng dụng di động ChiaPay hỗ trợ quản lý và quyết toán chi phí nhóm trên nền tảng Flutter”*.
- [ ] Thiết kế Slide thuyết trình demo luồng chuẩn: *Tạo nhóm → Thêm thành viên → Nhập 3 hóa đơn mẫu → Xem số dư tự động → Tạo phương án quyết toán → Đánh dấu đã trả → Kiểm tra số tiền còn lại*.

---

## 🎯 Đề xuất kế hoạch tiếp theo (Nếu muốn mở rộng thêm)

1. **Ưu tiên 1**: Tạo tính năng **Xuất báo cáo PDF** (dễ làm hơn OCR, tạo ấn tượng rất tốt khi báo cáo môn học).
2. **Ưu tiên 2**: Nâng cấp thuật toán quyết toán sang **Exact Minimum Cash Flow (Dynamic Programming / Subset Sum)** cho nhóm dưới 10 người.
3. **Ưu tiên 3**: Tích hợp **OCR quét hóa đơn** bằng Google ML Kit Text Recognition nếu môi trường chạy trên điện thoại thật có camera.
