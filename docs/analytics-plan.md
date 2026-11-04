# Kế hoạch đo lường Google Analytics for Firebase (PRM393 Lab 3)

## 1. Nguyên tắc tuân thủ quyền riêng tư (Privacy-by-Design)

Hệ thống ghi nhận sự kiện tương tác người dùng theo cấu trúc chuẩn của Google Analytics for Firebase. Tuyệt đối không gửi dữ liệu định danh cá nhân (PII) như họ tên, email, mã số sinh viên, nội dung thông báo hay đường dẫn tải tệp trực tiếp trong tham số sự kiện. Danh tính người dùng được gán qua `FirebaseAnalytics.instance.setUserId(id)` sau khi xác thực thành công.

---

## 2. Bảng đặc tả chi tiết 9 sự kiện Analytics

| Sự kiện (Event) | Luồng Lab 2 | Thời điểm kích hoạt (Trigger Moment) | Tham số & Kiểu dữ liệu | Câu hỏi sản phẩm (Product Question) | Tiêu chí thành công |
|---|---|---|---|---|---|
| `login` | Khởi tạo / SCR_01 | Người dùng hoàn tất đăng nhập Google SSO FPT thành công | `login_method` (String: `"google"`) | Kênh đăng nhập nào hoạt động ổn định và tỷ lệ đăng nhập thành công là bao nhiêu? | Người dùng được điều hướng vào Home Dashboard |
| `logout` | Profile / SCR_10 | Người dùng bấm nút "Sign Out" và xác nhận đăng xuất | Không tham số | Bao nhiêu sinh viên chủ động kết thúc phiên làm việc sau mỗi đợt chốt nhóm? | Phiên đăng nhập xóa sạch, quay lại SCR_01 |
| `search_teams` | Flow 1 / SCR_03 | Người dùng gõ từ khóa tìm kiếm hoặc bấm chọn chip lọc nhóm | `query_length` (int), `result_count` (int), `filter_count` (int) | Sinh viên tìm kiếm theo chủ đề gì nhiều nhất (AI/ML, Web, Mobile) và có gặp tình trạng 0 kết quả không? | Danh sách kết quả cập nhật mượt mà không reload |
| `view_team` | Flow 1 / SCR_04 | Người dùng bấm vào một thẻ nhóm từ màn hình Browse hoặc Alert | `team_id` (String), `team_code` (String) | Nhóm nào nhận được nhiều lượt xem chi tiết nhất trong học kỳ? | Màn hình chi tiết hiển thị đầy đủ slot và thông tin đề tài |
| `join_team` | Flow 1 / SCR_04 | Người dùng chọn vị trí còn trống và xác nhận tham gia nhóm thành công | `team_id` (String), `member_count` (int) | Tốc độ lấp đầy thành viên của các nhóm diễn ra nhanh hay chậm? | Sinh viên được đưa vào danh sách thành viên của nhóm trên Firestore |
| `cast_vote` | Flow 2 / SCR_06 | Thành viên nhóm chọn ứng viên và gửi phiếu bầu chọn nhóm trưởng | `team_id` (String), `changed` (int: 1 = đổi phiếu, 0 = phiếu đầu; Analytics chỉ nhận String/number) | Tỷ lệ đồng thuận bầu nhóm trưởng đạt bao nhiêu % và sinh viên có thường xuyên đổi phiếu bầu không? | Cập nhật phiếu bầu trong Firestore transaction, hiển thị nhóm trưởng khi đủ đa số |
| `invite_pool` | Flow 3 / SCR_07 | Nhóm trưởng bấm "Invite from Waiting Pool" khi nhóm thiếu thành viên (< 4) | `team_id` (String), `invited_count` (int) | Tính năng tự động ghép sinh viên từ Waiting Pool giúp cứu được bao nhiêu nhóm trước hạn chót? | Ghép thành công 1 ứng viên phù hợp từ waitingPool sang nhóm |
| `lock_roster` | Flow 3 / SCR_07 | Nhóm trưởng bấm "Lock Roster" sau khi nhóm đủ 4–5 thành viên và có trưởng nhóm | `team_id` (String), `member_count` (int) | Bao nhiêu nhóm hoàn thành chốt danh sách chính thức trước deadline? | Trạng thái nhóm chuyển sang `locked: true` kèm mã xác nhận `lockCode` |
| `export_report` | Profile / SCR_10 | Người dùng bấm "Export & Upload Team PDF" lên Cloud Storage | `team_id` (String), `file_size_kb` (int) | Sinh viên có thường xuyên sao lưu báo cáo xác nhận nhóm về máy/đám mây không? | Tệp PDF tải lên `reports/{uid}/...` thành công và trả về URL tải |

---

## 3. Hướng dẫn kiểm chứng sự kiện trên Firebase Analytics DebugView

1. **Bật chế độ gỡ lỗi (DebugView mode) trên thiết bị Android qua ADB:**
   ```powershell
   adb shell setprop debug.firebase.analytics.app com.devorganize222.exematching
   ```
2. **Theo dõi sự kiện:** Mở Firebase Console → **Analytics** → **DebugView**.
3. **Thao tác trên ứng dụng:** Lần lượt thực hiện các bước trong 3 flow chính:
   - Đăng nhập tài khoản FPT (`login`).
   - Tìm kiếm nhóm AI/ML (`search_teams`) và xem chi tiết nhóm (`view_team`).
   - Tham gia nhóm còn chỗ (`join_team`).
   - Vào My Team, bình chọn leader (`cast_vote`).
   - Mời thành viên từ Waiting Pool (`invite_pool`) và Khóa nhóm (`lock_roster`).
   - Vào Profile xuất báo cáo PDF (`export_report`), sau đó Đăng xuất (`logout`).
4. **Tắt chế độ gỡ lỗi sau khi hoàn tất kiểm tra:**
   ```powershell
   adb shell setprop debug.firebase.analytics.app .none.
   ```
