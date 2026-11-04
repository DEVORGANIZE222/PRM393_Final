# Kế hoạch & Báo cáo kiểm thử E2E với ARTEMIS — PRM393 Lab 3

Kiểm thử đầu cuối cho ứng dụng **EXEMatching** (Flutter + Firebase), do **ARTEMIS** điều khiển trên máy ảo Android `Pixel_API_36` (Android 16, `emulator-5556`). Mã kiểm thử: [`e2e_test/`](../e2e_test). Bằng chứng từng lần chạy: `e2e_test/evidence*/<test>/run{1,2,3}/` gồm `result.json` (goal, output JSON của agent, `trace_id`, thời gian), `screen.txt` (cây accessibility sau khi agent dừng), `analytics.txt` (sự kiện Analytics trong Logcat) và `final.png`.

---

## 1. Phương pháp

- **ARTEMIS làm các bước, pytest kiểm tra kết quả.** Mỗi ca giao cho agent một mục tiêu bằng ngôn ngữ tự nhiên (góc nhìn sinh viên) và yêu cầu trả về JSON có cấu trúc. Agent không được biết giá trị mong đợi.
- **Không tin cờ `SUCCESS` của agent.** Sau mỗi lần chạy, bài test đọc lại thiết bị và backend:
  - cây accessibility (`Semantics.identifier` → `resource-id` Android) qua `uiautomator dump`;
  - sự kiện `analytics_event <tên>` mà `FirebaseAnalyticsService` in ra Logcat;
  - tài liệu Firestore và object Cloud Storage qua REST API (`backend.py`).
- **Điều kiện đầu lặp lại được.** `backend.reset()` khôi phục dữ liệu seed Lab 3 (`tool/seed_firestore_lab3.py`) rồi đặt tài khoản test (`megalit2578@gmail.com`, một tài khoản Google thật trên máy ảo) vào vai cần thiết: thay ghế của Minh Le trong Team AI-04 (có thể là leader), hoặc là sinh viên chưa có nhóm. `device.sign_in()` xoá dữ liệu app (`pm clear`), cấp lại quyền thông báo và đăng nhập Google thật.
- **3 lần chạy độc lập mỗi ca** (`E2E_RUNS=3`), mỗi lần reset lại từ đầu; có `E2E_COOLDOWN` giữa các tác vụ để không vượt hạn mức Gemini miễn phí.
- **Mô hình:** profile `flash` của ARTEMIS dùng `gemini-3.5-flash-lite` (tầng miễn phí, 15 RPM / 500 RPD); tắt step summarizer để tiết kiệm request.

---

## 2. Đặc tả 13 ca kiểm thử

| Ca | Luồng | Điều kiện đầu (do harness tạo) | Mục tiêu giao cho ARTEMIS | Kiểm tra (ground truth) |
|---|---|---|---|---|
| **TC-01** | Auth · lỗi | Tài khoản bị tắt trong `allowedEmails` (`enabled=false`), app ở Sign In | Bấm *Continue with Google*, chọn tài khoản, đọc tiêu đề lỗi | `signed_in=false`; màn hình còn `[btn_google_sign_in]`; banner `[sign_in_message] This account is not on the class roster…` có email đã chọn |
| **TC-02** | Auth · chuẩn | Tài khoản ở Team AI-04, app ở Sign In | Đăng nhập Google, đọc lời chào, hạn chót, tên nhóm | Lời chào `Hi, <tên>`; hạn chót chứa "left"; tên nhóm chứa AI-04; có `[nav_home]`, `[card_deadline]`; Logcat có `login`; `students/{uid}.email` đúng |
| **TC-03** | Flow 1 · tìm & lọc | Sinh viên chưa có nhóm, đã đăng nhập | Tab Browse, bật chip `AI/ML`, giữ `Open Slots`, tìm "drone" | `result_count=1`, có AI-04; màn hình `[browse_result_count] 1 team with open slots`; Logcat có `search_teams` |
| **TC-04** | Flow 1 · rỗng | Như TC-03 | Tìm "quantum", đọc thông báo rỗng, bấm nút xoá bộ lọc, đếm nhóm | Tiêu đề `No teams match your search`; số nhóm sau khi xoá = số nhóm còn chỗ đếm từ Firestore; dòng `[browse_result_count] N teams with open slots` |
| **TC-05** | Flow 1 · mất mạng | Như TC-03, tắt wifi + data qua ADB | (1) Mở Browse khi offline, đọc lỗi. (2) Mạng bật lại, bấm *Try Again*, đếm nhóm | (1) `Can't connect right now`, có nút Try Again, `[state_error]`. (2) Số nhóm = Firestore, không còn `[state_error]` |
| **TC-06** | Flow 1 · tham gia | Như TC-03 (FinTech Guard 2/5) | Tìm FinTech Guard, mở chi tiết, Join và xác nhận, đọc My Team | `joined=true`, My Team = FinTech Guard "3 of 5"; `[card_my_team_header]`; Logcat `join_team`; Firestore `teams/team_fin02.memberIds` có uid, đủ 3 người |
| **TC-07** | Flow 1 · nhóm vừa đầy | Như TC-03 (EduSmart 4/5). Khi agent mở hộp xác nhận, harness ghi thêm 1 sinh viên vào nhóm | Xác nhận tham gia, đọc thông báo và trạng thái nút Join | `joined=false`, tiêu đề chứa "just filled up"; `[banner_team_filled]`, `[join_blocked_reason] This team is full (5/5).`; uid không có trong `memberIds` |
| **TC-08** | Flow 2 · giấu kết quả | Tài khoản ở AI-04, chưa bỏ phiếu | Mở *Vote for Leader*, không bỏ phiếu, đọc hộp thông tin | Không thấy số phiếu, `Results appear after you vote`, nút Submit tắt; không có chuỗi "/3" trên màn hình; `votes` không có uid |
| **TC-09** | Flow 2 · bầu leader | Như TC-08 | Bỏ phiếu cho chính mình, đọc leader và số phiếu | Leader = tên tài khoản, 2 phiếu; `[banner_leader_elected] … is your team leader`; Logcat `cast_vote`; Firestore `votes[uid]=uid`, `leaderId=uid` |
| **TC-10** | Flow 3 · lỗi → phục hồi | Tài khoản là leader AI-04 (3/5, cần ≥4 để khoá) | Mở *Review & Lock*, ghi lỗi đầu tiên, mời từ Waiting Pool, chờ người vào, khoá roster | Lỗi bắt đầu `Can't lock yet`; người vào là `Khanh Vo`; mã `CM-AI04-XXXX` có trên màn hình; `[state_locked]`; Logcat `invite_pool`, `lock_roster`; Firestore `locked=true`, `lockCode` khớp, `waitingPool/s_khanh.assigned=true` |
| **TC-11** | Flow 3 · Android native | Như TC-10 | Bấm *Share Team Link*, dừng ở share sheet | Agent thấy share sheet có tên nhóm; activity trên cùng là `com.android.intentresolver` |
| **TC-12** | Alerts | Sinh viên chưa có nhóm, có 1 lời mời từ FinTech Guard trong `students/{uid}/notifications` | Mở Alerts (chuông), lọc Invites, Decline, bấm Undo trên snackbar | Sau Decline 0, sau Undo 1; màn hình `Invites (1)`; tài liệu notification tồn tại lại trên Firestore |
| **TC-13** | Profile · Storage | Tài khoản ở AI-04 | Mở Profile, *Export & Upload PDF*, chờ xong, đọc tên và kích thước tệp | Tên `team-ai-04-YYYYMMDD-HHMM.pdf`, size > 0; banner `[export_done] Uploaded…` chứa URL `firebasestorage.googleapis.com` với `reports%2F{uid}%2F<tệp>`; Logcat `export_report`; object mới xuất hiện trong bucket dưới `reports/{uid}/` |

---

## 3. Kết quả thực thi

Kết quả dưới đây được sinh trực tiếp từ `junit.xml` và `result.json` của từng thư mục bằng chứng. "TB thời gian ARTEMIS" là thời gian agent chạy (`result.json.seconds`); "TB tổng" tính cả reset dữ liệu, xoá app và đăng nhập Google. Trace ID mở được bằng `mobile_inspect_trace` của ARTEMIS.

### 3.1. Lần chạy 1 — `e2e_test/evidence-attempt1/` (2026-11-02, 6/39)

Môi trường: `emulator-5554`, app trên nhánh `feat/lab3-firebase-fixes` tại `a3763f6`.

| Ca | Run 1 | Run 2 | Run 3 | Đạt | TB ARTEMIS | TB tổng | Nguyên nhân thất bại |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|---|
| TC-01 | PASS | PASS | PASS | 3/3 | 41.1s | 45.6s | — |
| TC-02 | PASS | PASS | PASS | 3/3 | 41.4s | 46.8s | — |
| TC-03 | FAIL | FAIL | FAIL | 0/3 | 73.7s | 79.1s | Danh sách trả về 2 nhóm thay vì 1 (lỗi app, xem TC-03 ở 3.2); run 3 không thấy nút đăng nhập |
| TC-04 | FAIL | FAIL | FAIL | 0/3 | 220.2s | 422.9s | Agent không gõ được vào ô tìm kiếm (ô nhập lộ 2 `EditText`), run 2 hết 900s |
| TC-05 | FAIL | FAIL | FAIL | 0/3 | 274.9s | 299.9s | Agent báo thất bại: cùng lỗi không gõ được + hết quota Gemini 15 RPM |
| TC-06 | FAIL | FAIL | FAIL | 0/3 | 193.4s | 215.9s | Như TC-05 |
| TC-07…TC-11 | FAIL | FAIL | FAIL | 0/15 | — | 0.2s | Token Firebase CLI hết hạn sau ~60 phút: `backend.reset()` nhận HTTP 401, ARTEMIS chưa chạy |
| TC-12 | FAIL | FAIL | FAIL | 0/3 | 76.6s | 81.4s | Hộp thoại quyền thông báo Android 13+ che Home; Undo không hiện |
| TC-13 | FAIL | FAIL | FAIL | 0/3 | 29.1s | 48.4s | Upload thành công nhưng bài test so sai nhãn banner |

Sửa sau lần 1 (harness): làm mới token khi gặp 401 (`backend.py`), cấp `POST_NOTIFICATIONS` sau `pm clear` (`device.py`), thêm `E2E_COOLDOWN` — commit `9652bb4`, `72a8a0a`. Sửa app: ô nhập chỉ còn 1 `EditText` (`84fdaa0`), hỗ trợ phím Paste mà ARTEMIS dùng để gõ (`87e076e`).

### 3.2. Lần chạy 2 — `e2e_test/evidence-attempt2/` (2026-11-03, build `e2f873a`, 23/39)

| Ca | Run 1 | Run 2 | Run 3 | Đạt | TB ARTEMIS | TB tổng | Trace ID (run 1 / 2 / 3) |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|---|
| TC-01 | PASS | PASS | PASS | 3/3 | 41.3s | 65.7s | `2bd9cd69` / `dc3c1857` / `f7039a84` |
| TC-02 | PASS | PASS | PASS | 3/3 | 52.1s | 78.3s | `f322b756` / `4feb9567` / `c505dc8e` |
| TC-03 | FAIL | FAIL | FAIL | 0/3 | 41.1s | 83.0s | `c0c435b7` / `db7a4720` / `c9486611` |
| TC-04 | PASS | PASS | FAIL | 2/3 | 39.5s | 82.5s | `74959f30` / `11b17b43` / `acfcd0f0` |
| TC-05 | FAIL | FAIL | FAIL | 0/3 | 23.8s | 65.2s | `85562f2a` / `cc3ae16e` / `3d05e65b` |
| TC-06 | FAIL | FAIL | FAIL | 0/3 | 46.4s | 87.7s | `d9541679` / `8bedd5a6` / `502352bb` |
| TC-07 | PASS | PASS | PASS | 3/3 | 30.1s | 150.1s | `fbf86a20` / `5c6d9da6` / `f914e56a` |
| TC-08 | PASS | PASS | PASS | 3/3 | 22.5s | 65.7s | `23744ef2` / `7b18e3d0` / `6f0d241d` |
| TC-09 | PASS | PASS | PASS | 3/3 | 32.8s | 79.3s | `e4ebdd30` / `38d59a90` / `8077aef8` |
| TC-10 | FAIL | PASS | FAIL | 1/3 | 62.9s | 108.4s | `a50bd4bb` / `d4f4a5a8` / `daf8cba6` |
| TC-11 | PASS | PASS | FAIL | 2/3 | 83.0s | 130.3s | `537db468` / `49e4a0be` / `7116c59a` |
| TC-12 | PASS | PASS | PASS | 3/3 | 33.4s | 76.4s | `f5f05ac5` / `7751b3cc` / `72d69093` |
| TC-13 | FAIL | FAIL | FAIL | 0/3 | 30.7s | 75.0s | `1408b201` / `6120e9d8` / `00e59187` |

Phân tích từng thất bại (đọc `result.json`, `screen.txt` và trace):

| Ca | Quan sát | Phân loại | Cách xử lý |
|---|---|---|---|
| TC-03 (3/3) | `screen.txt`: ô tìm kiếm hiện "drone" nhưng `[browse_result_count] 2 teams with open slots` (AI-04 + EduSmart). App chỉ áp dụng từ khoá khi submit; lần tìm cuối là do bấm chip với từ khoá rỗng | **Lỗi app** — ô tìm kiếm không khớp kết quả | Tìm kiếm theo từng ký tự với debounce 400ms — `0f09c6d` |
| TC-05 (3/3) | Offline nhưng màn hình báo "No teams match your search / Every team is full" vì Firestore trả cache rỗng | **Lỗi app** — sai trạng thái lỗi | `Source.server` + ánh xạ `unavailable` → `AppFailure.offline` — `12ef1b3` |
| TC-06 (3/3) | Tham gia thành công (Firestore đúng 3 thành viên) nhưng thẻ `[member_<uid>]` nằm dưới màn hình nên `uiautomator` không thấy | Lỗi bài test | Kiểm tra thành viên trên Firestore thay vì thẻ ngoài màn hình — `83f3136` |
| TC-10 (run 1, 3) | Agent báo dòng gợi ý "Needs 1 more member to lock" dưới nút Lock thay vì tiêu đề banner đỏ; phần phục hồi và khoá vẫn đúng (`CM-AI04-3339`) | Mục tiêu mơ hồ | Nói rõ phải đọc tiêu đề in đậm của hộp đỏ (không tiết lộ nội dung mong đợi) — `e634fb0` |
| TC-04 (run 3) | Agent đã cuộn xuống khi đếm nhóm nên dòng `[browse_result_count]` ra khỏi màn hình | Lỗi bài test | Cuộn về đầu trước khi đọc màn hình — `81695c7` |
| TC-11 (run 3) | Share sheet đã mở trong lúc agent chạy (agent báo đúng), nhưng khi harness kiểm tra (lần chạy dài 179s) activity trên cùng đã là `MainActivity` của app | **Không ổn định (flaky)** — thời gian | Ghi nhận; không sửa app |
| TC-13 (3/3) | Upload thành công, object có trong bucket, nhưng banner đổi nội dung thành "Uploaded …" + URL sau đợt restyle UI | Lỗi bài test | So khớp nội dung banner hiện tại — `f78369b` |

Các lỗi khác tìm thấy trong khi điều tra (không làm fail test nhưng đã sửa): bộ mời Waiting Pool bị `PERMISSION_DENIED` vì rules không cho leader đọc pool (`68e0656`, đã deploy), seed thiếu sinh viên trong pool (`db89247`), `cast_vote` gửi tham số bool khiến Analytics ném lỗi và app hiện "Something went wrong" (`deb3215`), snackbar Undo không hiện vì dùng `context` sau khi widget bị huỷ (`e2f873a`), stream Firestore lỗi không được xử lý gây crash ghi trên Crashlytics (`8594b26`).

### 3.3. Lần chạy cuối — `e2e_test/evidence/` (build `81695c7`)

Lần chạy cuối gồm hai phiên trên cùng một build và cùng máy ảo.

**Phiên 1** — 2026-11-03 18:40–20:19, `e2e_test/evidence-final-session1/` (24/39):

| Ca | Run 1 | Run 2 | Run 3 | Đạt | TB ARTEMIS | TB tổng | Trace ID (run 1 / 2 / 3) |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|---|
| TC-01 | PASS | PASS | PASS | 3/3 | 62.9s | 88.3s | `4078233d` / `8f8ec5be` / `7aefd229` |
| TC-02 | PASS | PASS | PASS | 3/3 | 42.8s | 69.5s | `cdc86073` / `39d3bf7f` / `7cd41b3d` |
| TC-03 | PASS | PASS | PASS | 3/3 | 45.4s | 89.5s | `91b509f2` / `dc800ec9` / `9c4f292d` |
| TC-04 | PASS | PASS | PASS | 3/3 | 94.1s | 142.6s | `15f2da3d` / `c1efc34a` / `95238313` |
| TC-05 | PASS | PASS | PASS | 3/3 | 21.8s | 104.8s | `bf1a0bae` / `97598caa` / `d29e21f5` |
| TC-06 | PASS | PASS | PASS | 3/3 | 45.3s | 89.0s | `cb932c72` / `4b85d365` / `4b1b0b04` |
| TC-07 | FAIL | FAIL | FAIL | 0/3 | 198.1s | 240.6s | `a6e454c9` / `e2cd65e2` / `55734f81` |
| TC-08 | FAIL | FAIL | FAIL | 0/3 | 192.2s | 234.9s | `77b5c214` / `f77a99e6` / `3d23cd01` |
| TC-09 | FAIL | FAIL | FAIL | 0/3 | 192.7s | 239.1s | `0f9d3b02` / `149477a3` / `a9bd3620` |
| TC-10 | FAIL | FAIL | FAIL | 0/3 | 239.4s | 284.9s | `2991b43a` / `5bfc3ad6` / `46ed32cd` |
| TC-11 | FAIL | FAIL | FAIL | 0/3 | 194.8s | 239.5s | `859356ab` / `07f0300a` / `469bbc0f` |
| TC-12 | PASS | PASS | PASS | 3/3 | 42.2s | 86.3s | `94b83370` / `43278301` / `be79055b` |
| TC-13 | PASS | PASS | PASS | 3/3 | 30.1s | 73.8s | `fbc83c2b` / `506a0dd2` / `1e17ec6a` |

Cả 15 lần chạy thất bại (từ 19:17) đều có cùng nguyên nhân hạ tầng, không phải lỗi app: `stdout.log` của trace cho thấy mọi lời gọi Gemini nhận `429 RESOURCE_EXHAUSTED` — hết hạn mức miễn phí theo ngày của `gemini-3.5-flash-lite` (`limit: 500`, metric `generate_content_free_tier_requests`) sau các lần chạy trong ngày — và agent dừng với "LLM call timed out after 180 seconds" trước khi thực hiện bước nào (`steps` rỗng). Không có kiểm tra nào của app được đánh giá trong các lần này.

Trong suốt phiên 1, Logcat của Flutter (590 dòng) không có `EXCEPTION CAUGHT`, `RenderFlex overflowed` hay lỗi layout nào trên build `81695c7`.

<!-- SESSION2 -->
**Lần thử phiên 2 bị hủy (2026-11-03 22:04):** lúc 22:03 một lệnh gọi thử `gemini-3.5-flash-lite` vẫn trả lời, nên TC-07…TC-11 được chạy lại. Lần chạy đầu tiên (TC-07 run1, trace `c800b1b5`) lại nhận `429 RESOURCE_EXHAUSTED`: hạn mức ngày của flash-lite (`limit: 500`) và flash (`limit: 20`) đều đã hết. Sau đó emulator-5556 treo hẳn: `adb shell echo` cũng không trả lời, nên pytest đứng chờ cả đêm. Sáng 2026-11-04 tiến trình được dừng và emulator được khởi động lại (cold boot). Bản ghi của lần thử này nằm ở `e2e_test/evidence-session2-aborted/`; nó không được tính vào kết quả.

**Phiên 2** — chạy lại TC-07…TC-11 (3 lần mỗi ca) sau khi hạn mức ngày được đặt lại (0:00 giờ Thái Bình Dương = 15:00 giờ Việt Nam): _chưa chạy_.

---

## 4. Phiên kiểm thử khám phá (Exploratory)

<!-- EXPLORATORY -->
_Chưa thực hiện — sẽ ghi sau phiên chạy thật với ARTEMIS (profile Pro), kèm trace ID._
