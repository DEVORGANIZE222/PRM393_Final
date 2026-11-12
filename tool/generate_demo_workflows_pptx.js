/**
 * Generator script for PRM393 Demo Workflow slides (Slide 18, 19, 20)
 * Uses pptxgenjs to create an exact replica of the provided presentation template.
 */
const pptxgen = require('./node_modules/pptxgenjs');
const path = require('path');

const pres = new pptxgen();
pres.layout = 'LAYOUT_16x9'; // 10 x 5.625 inches

// Slide data definitions
const slidesData = [
  {
    slideNum: 18,
    wfCode: 'DEMO WF-01',
    roleTag: 'WF-01 · SINH VIÊN',
    roleColor: '2563EB',
    roleBg: 'DBEAFE',
    themeColor: '2563EB',
    themeBgLight: 'EFF6FF',
    themeBorderLight: 'BFDBFE',
    title: 'Slide 18 Demo WF-01 — Gửi yêu cầu (khởi tạo nghiệp vụ)',
    question: 'WF-01 có chạy thật, đúng nghiệp vụ, và xử lý lỗi đúng không?',
    scenario: 'Nhóm sinh viên cần tạo nhóm Capstone, dùng Gemini AI gợi ý đề tài, chốt đủ 4 thành viên, bầu trưởng nhóm và gửi hồ sơ nộp.',
    happyPath: 'Mở app Mobile ➔ Tạo nhóm & Gợi ý đề tài với Gemini AI ➔ Bầu trưởng nhóm (BR-01) ➔ Lock Review ➔ Bấm nộp hồ sơ.',
    exceptionPath: 'Cố ý nộp khi nhóm mới có 2 SV hoặc chưa bầu leader ➔ Bị chặn bởi BR-01 (tối thiểu 4 thành viên) & Security Rule R-01.',
    evidence: 'Mã Record #SUB-AI04 • Trạng thái PENDING • Log Firestore lúc 21:30:15 • Khớp TC01–04 (ARTEMIS)',
    flow: [
      { top: 'Trigger', sub: 'Đợt mở', isPrimary: true },
      { top: 'Tạo nhóm', sub: 'UI-01' },
      { top: 'Sĩ số & Vote', sub: 'BR-01' },
      { top: 'Lock Review', sub: 'UI-02' },
      { top: 'Kết quả', sub: 'PENDING', isPrimary: true }
    ],
    statusText: 'TRẠNG THÁI  FORMING ➔ LOCKED ➔ PENDING',
    exceptionText: 'EXCEPTION  Gửi khi nhóm chưa đủ 4 SV ➔ Báo lỗi BR-01, Security Rule R-01 chặn tạo submission'
  },
  {
    slideNum: 19,
    wfCode: 'DEMO WF-02',
    roleTag: 'WF-02 · CÁN BỘ / QUẢN LÝ',
    roleColor: '0D9488',
    roleBg: 'CCFBF1',
    themeColor: '0D9488',
    themeBgLight: 'F0FDFA',
    themeBorderLight: '99F6E4',
    title: 'Slide 19 Demo WF-02 — Duyệt yêu cầu (xử lý nghiệp vụ)',
    question: 'WF-02 có chạy thật, đúng nghiệp vụ, và xử lý lỗi đúng không?',
    scenario: 'Cán bộ mở Web Admin, nhận snapshot hồ sơ #SUB-AI04 vừa nộp từ WF-01 trên Review Queue, thẩm định đề tài và phê duyệt.',
    happyPath: 'Nhận realtime snapshot (~180ms) ➔ Xem Review Queue ➔ Xem chi tiết đề tài & thành viên ➔ Nhập ghi chú ➔ Bấm Approve.',
    exceptionPath: 'Bấm Từ chối mà bỏ trống lý do ➔ Form chặn bắt buộc nhập reason; Sinh viên gọi sửa status ➔ Bị chặn bởi Security Rule R-03.',
    evidence: '#SUB-AI04 chuyển APPROVED • Mobile nhận thông báo tức thì (~210ms) • Khớp TC05–08 (ARTEMIS)',
    flow: [
      { top: 'Trigger', sub: 'Hồ sơ chờ', isPrimary: true },
      { top: 'Review Queue', sub: 'UI-03' },
      { top: 'Hồ sơ nhóm', sub: 'UI-04' },
      { top: 'Định mức?', sub: 'BR-02' },
      { top: 'Kết quả', sub: 'APPROVED', isPrimary: true }
    ],
    statusText: 'TRẠNG THÁI  PENDING ➔ APPROVED / REJECTED',
    exceptionText: 'EXCEPTION  Từ chối không lý do ➔ Bị chặn (BR-02); Sinh viên tự duyệt ➔ Bị chặn bởi Rule R-03 (403)'
  },
  {
    slideNum: 20,
    wfCode: 'DEMO WF-03',
    roleTag: 'WF-03 · QUẢN TRỊ / HỘI ĐỒNG',
    roleColor: 'EA580C',
    roleBg: 'FFEDD5',
    themeColor: 'EA580C',
    themeBgLight: 'FFF7ED',
    themeBorderLight: 'FED7AA',
    title: 'Slide 20 Demo WF-03 — Xem báo cáo (tổng hợp kết quả)',
    question: 'WF-03 có chạy thật, đúng nghiệp vụ, và xử lý lỗi đúng không?',
    scenario: 'Quản trị viên/Hội đồng xem báo cáo tổng kết đợt đăng ký Capstone trên Dashboard, kiểm tra nhóm #SUB-AI04 và xuất file PDF.',
    happyPath: 'Mở Dashboard Web ➔ Kiểm tra 3 con số tổng hợp & chart ➔ Lọc nhóm Approved ➔ Xuất file báo cáo đồ án gửi Hội đồng.',
    exceptionPath: 'Lọc kỳ học chưa có dữ liệu ➔ Hiển thị Empty State; Tài khoản sinh viên cố truy cập /admin/dashboard ➔ Bị chặn chuyển hướng login.',
    evidence: '#SUB-AI04 có mặt trong báo cáo chính thức • Số tổng Dashboard khớp DB 100% • Khớp TC09–10',
    flow: [
      { top: 'Trigger', sub: 'Chốt đợt', isPrimary: true },
      { top: 'Bộ lọc kỳ', sub: 'UI-05' },
      { top: 'Aggregation', sub: 'Server' },
      { top: 'Dashboard', sub: 'UI-06' },
      { top: 'Kết quả', sub: 'File PDF', isPrimary: true }
    ],
    statusText: 'TRẠNG THÁI  APPROVED (Chính thức, chỉ đọc - Read-only)',
    exceptionText: 'EXCEPTION  Không có dữ liệu trong kỳ ➔ Trạng thái empty; Sinh viên vào link admin ➔ Bị đá về login'
  }
];

slidesData.forEach((data) => {
  const slide = pres.addSlide();

  // Background
  slide.background = { color: 'FFFFFF' };

  // --- TOP HEADER ---
  // Pill Left: P3 · DEMO
  slide.addShape(pres.ShapeType.roundRect, {
    x: 0.4, y: 0.18, w: 1.15, h: 0.26,
    fill: { color: 'FEE2E2' },
    line: { color: 'FCA5A5', width: 0.75 },
    rectRadius: 0.13
  });
  slide.addText('P3 · DEMO', {
    x: 0.4, y: 0.18, w: 1.15, h: 0.26,
    fontSize: 8.5, fontFace: 'Segoe UI', bold: true, color: 'EA580C',
    align: 'center', valign: 'middle'
  });

  // Center Slide Code
  slide.addText(`${data.slideNum}  /  ${data.wfCode}`, {
    x: 1.65, y: 0.18, w: 2.2, h: 0.26,
    fontSize: 8.5, fontFace: 'Segoe UI', bold: true, color: '64748B',
    align: 'left', valign: 'middle'
  });

  // Pill Right: Role Tag
  slide.addShape(pres.ShapeType.roundRect, {
    x: 7.7, y: 0.18, w: 1.9, h: 0.26,
    fill: { color: data.roleBg },
    line: { color: data.roleColor, width: 0.75 },
    rectRadius: 0.13
  });
  slide.addText(data.roleTag, {
    x: 7.7, y: 0.18, w: 1.9, h: 0.26,
    fontSize: 8.5, fontFace: 'Segoe UI', bold: true, color: data.roleColor,
    align: 'center', valign: 'middle'
  });

  // --- TITLE & SUBTITLE ---
  slide.addText(data.title, {
    x: 0.4, y: 0.52, w: 9.2, h: 0.36,
    fontSize: 15.5, fontFace: 'Segoe UI', bold: true, color: '1E293B',
    valign: 'top'
  });
  slide.addText('Cùng một layout cho mọi workflow để người xem dễ theo dõi.', {
    x: 0.4, y: 0.88, w: 9.2, h: 0.22,
    fontSize: 9, fontFace: 'Segoe UI', color: '64748B',
    valign: 'top'
  });

  // --- 3 TOP META BOXES ---
  const boxY = 1.18;
  const boxH = 0.62;

  // Box 1: CÂU HỎI HỘI ĐỒNG
  slide.addShape(pres.ShapeType.roundRect, {
    x: 0.4, y: boxY, w: 4.8, h: boxH,
    fill: { color: 'FFF7ED' },
    line: { color: 'FED7AA', width: 0.75 },
    rectRadius: 0.08
  });
  slide.addText([
    { text: 'CÂU HỎI HỘI ĐỒNG\n', options: { fontSize: 7, bold: true, color: 'C2410C' } },
    { text: data.question, options: { fontSize: 8.5, italic: true, color: '1E293B' } }
  ], {
    x: 0.5, y: boxY + 0.05, w: 4.6, h: boxH - 0.1,
    fontFace: 'Segoe UI', valign: 'top'
  });

  // Box 2: THỜI LƯỢNG
  slide.addShape(pres.ShapeType.roundRect, {
    x: 5.3, y: boxY, w: 1.2, h: boxH,
    fill: { color: 'FFF7ED' },
    line: { color: 'FED7AA', width: 0.75 },
    rectRadius: 0.08
  });
  slide.addText([
    { text: 'THỜI LƯỢNG\n', options: { fontSize: 7, bold: true, color: 'C2410C' } },
    { text: '≈ 2\'', options: { fontSize: 13, bold: true, color: 'C2410C' } }
  ], {
    x: 5.3, y: boxY + 0.05, w: 1.2, h: boxH - 0.1,
    fontFace: 'Segoe UI', align: 'center', valign: 'top'
  });

  // Box 3: MINH CHỨNG BẮT BUỘC
  slide.addShape(pres.ShapeType.roundRect, {
    x: 6.6, y: boxY, w: 3.0, h: boxH,
    fill: { color: 'FFF7ED' },
    line: { color: 'FED7AA', width: 0.75 },
    rectRadius: 0.08
  });
  slide.addText([
    { text: 'MINH CHỨNG BẮT BUỘC\n', options: { fontSize: 7, bold: true, color: 'C2410C' } },
    { text: 'Chạy trực tiếp; record ID, trạng thái, log / email', options: { fontSize: 8.5, color: '1E293B' } }
  ], {
    x: 6.7, y: boxY + 0.05, w: 2.8, h: boxH - 0.1,
    fontFace: 'Segoe UI', valign: 'top'
  });

  // --- LEFT COLUMN: NỘI DUNG CẦN TRÌNH BÀY ---
  slide.addText('NỘI DUNG CẦN TRÌNH BÀY', {
    x: 0.4, y: 1.92, w: 3.6, h: 0.22,
    fontSize: 7.5, fontFace: 'Segoe UI', bold: true, color: 'EA580C'
  });

  const listItems = [
    { num: '1', label: 'Scenario: ', desc: data.scenario },
    { num: '2', label: 'Happy path: ', desc: data.happyPath },
    { num: '3', label: 'Exception path: ', desc: data.exceptionPath },
    { num: '4', label: 'Minh chứng: ', desc: data.evidence }
  ];

  let currentY = 2.16;
  listItems.forEach((item, idx) => {
    // Number circle
    slide.addShape(pres.ShapeType.ellipse, {
      x: 0.4, y: currentY + 0.02, w: 0.24, h: 0.24,
      fill: { color: 'FFEDD5' },
      line: { color: 'EA580C', width: 0.75 }
    });
    slide.addText(item.num, {
      x: 0.4, y: currentY + 0.02, w: 0.24, h: 0.24,
      fontSize: 8, fontFace: 'Segoe UI', bold: true, color: 'EA580C',
      align: 'center', valign: 'middle'
    });

    // Content text
    const textH = idx === 0 ? 0.52 : idx === 1 ? 0.44 : idx === 2 ? 0.48 : 0.44;
    slide.addText([
      { text: item.label, options: { bold: true, color: '334155' } },
      { text: item.desc, options: { color: '475569' } }
    ], {
      x: 0.7, y: currentY, w: 3.3, h: textH,
      fontSize: 8, fontFace: 'Segoe UI', valign: 'top'
    });

    currentY += textH + 0.06;
  });

  // Warning card at bottom left
  slide.addShape(pres.ShapeType.roundRect, {
    x: 0.4, y: 4.45, w: 3.6, h: 0.85,
    fill: { color: 'FFF1F2' },
    line: { color: 'FECDD3', width: 0.75 },
    rectRadius: 0.08
  });
  slide.addText([
    { text: 'TRÁNH\n', options: { fontSize: 7, bold: true, color: 'BE123C' } },
    { text: 'Chiếu video thay cho chạy thật; video chỉ là phương án dự phòng.', options: { fontSize: 8, color: '475569' } }
  ], {
    x: 0.5, y: 4.52, w: 3.4, h: 0.72,
    fontFace: 'Segoe UI', valign: 'top'
  });

  // --- RIGHT COLUMN: MẪU BỐ CỤC ---
  slide.addText('MẪU BỐ CỤC', {
    x: 4.3, y: 1.92, w: 5.3, h: 0.22,
    fontSize: 7.5, fontFace: 'Segoe UI', bold: true, color: '64748B'
  });

  // 5 Flow Boxes
  const flowStartX = 4.3;
  const flowY = 2.22;
  const boxW = 0.88;
  const boxHFlow = 0.68;
  const gap = 0.22;

  data.flow.forEach((f, idx) => {
    const fX = flowStartX + idx * (boxW + gap);
    const isPri = f.isPrimary;

    slide.addShape(pres.ShapeType.roundRect, {
      x: fX, y: flowY, w: boxW, h: boxHFlow,
      fill: { color: isPri ? data.themeColor : data.themeBgLight },
      line: { color: isPri ? data.themeColor : data.themeBorderLight, width: 1 },
      rectRadius: 0.06
    });

    slide.addText([
      { text: f.top + '\n', options: { fontSize: 8, bold: true, color: isPri ? 'FFFFFF' : '1E293B' } },
      { text: f.sub, options: { fontSize: 7, color: isPri ? 'E2E8F0' : '64748B' } }
    ], {
      x: fX, y: flowY, w: boxW, h: boxHFlow,
      fontFace: 'Segoe UI', align: 'center', valign: 'middle'
    });

    // Arrow to next box
    if (idx < 4) {
      slide.addText('➔', {
        x: fX + boxW, y: flowY, w: gap, h: boxHFlow,
        fontSize: 10, fontFace: 'Segoe UI', color: '94A3B8',
        align: 'center', valign: 'middle'
      });
    }
  });

  // Status Banner
  slide.addShape(pres.ShapeType.roundRect, {
    x: 4.3, y: 3.05, w: 5.3, h: 0.42,
    fill: { color: 'F1F5F9' },
    line: { color: 'E2E8F0', width: 0.5 },
    rectRadius: 0.06
  });
  slide.addText(data.statusText, {
    x: 4.45, y: 3.05, w: 5.0, h: 0.42,
    fontSize: 8, fontFace: 'Segoe UI', bold: true, color: '334155',
    valign: 'middle'
  });

  // Exception Banner
  slide.addShape(pres.ShapeType.roundRect, {
    x: 4.3, y: 3.58, w: 5.3, h: 0.52,
    fill: { color: 'FFF1F2' },
    line: { color: 'FECDD3', width: 0.75 },
    rectRadius: 0.06
  });
  slide.addText(data.exceptionText, {
    x: 4.45, y: 3.58, w: 5.0, h: 0.52,
    fontSize: 7.8, fontFace: 'Segoe UI', color: 'BE123C',
    valign: 'middle'
  });

  // Evidence Banner
  slide.addShape(pres.ShapeType.roundRect, {
    x: 4.3, y: 4.22, w: 5.3, h: 0.52,
    fill: { color: 'F0FDF4' },
    line: { color: 'BBF7D0', width: 0.75 },
    rectRadius: 0.06
  });
  slide.addText(data.evidence, {
    x: 4.45, y: 4.22, w: 5.0, h: 0.52,
    fontSize: 7.8, fontFace: 'Segoe UI', bold: true, color: '15803D',
    valign: 'middle'
  });

  // Footnote
  slide.addText('Thay nội dung ví dụ bằng dữ liệu demo cụ thể của nhóm.', {
    x: 4.3, y: 4.88, w: 5.3, h: 0.25,
    fontSize: 7.5, fontFace: 'Segoe UI', italic: true, color: '94A3B8'
  });
});

// Save to slides folder
const outPath = path.resolve(__dirname, '..', 'slides', 'Demo_Workflows_Slides.pptx');
pres.writeFile({ fileName: outPath }).then(() => {
  console.log('Successfully generated PPTX file at: ' + outPath);
}).catch(err => {
  console.error('Error generating PPTX:', err);
});
