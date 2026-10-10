<!-- PANDA-OS:START — Vùng này do panda-sync quản lý. ĐỪNG sửa tay, sẽ bị ghi đè. -->
# AGENTS — clmca-ea

> Bạn đang làm trong project **clmca-ea** thuộc hệ thống Panda OS.
> Nguồn luật chung: `/Users/panda/Dev/panda-os/`

## Đọc trước khi làm
1. `/Users/panda/Dev/panda-os/START_HERE.md` — cách hệ thống hoạt động.
2. `/Users/panda/Dev/panda-os/RULES.md` — luật cứng. **Luật thắng chat.**
3. `./.ai/CONTEXT.md` — project này là gì, stack, đang làm gì.

## Profile của project này: **code,trading**
Các block luật đang bật: CORE + CODE + TRADING

## Nhắc nhanh (chi tiết trong RULES.md)
- 🧭 **North Star:** việc này có giải nỗi đau khách thật / mang thu nhập về gia đình không, hay chỉ xây hệ thống cho vui? Chạm ranh giới đỏ (data khách · over-promise · thao túng review · bất công nhân viên · sức khỏe/gia đình) → **DỪNG.** (vault: `Panda — North Star`)
- File là source of truth, không phải chat.
- Một task = một scope. Không refactor lan man.
- Checkpoint: chỉ ở `.ai/CHECKPOINT-YYYY-MM-DD.md`, commit + push `origin/main`; bàn giao kèm lệnh `git show origin/main:…` đã tự chạy thử (RULES §C1c).
- Rủi ro 🔴 (production / schema / tiền / auth / xóa data / deploy) → **DỪNG, xin Panda duyệt.**

- Code: No spec → no code. Trước merge chạy lint/typecheck/build/test.
- Trading: Mặc định DRY_RUN/PAPER trước khi LIVE; bắt buộc có Stop-Loss, Max Daily Loss, Kill Switch; API Key cấm quyền rút tiền.

<!-- PANDA-OS:END -->

# PROJECT-SPECIFIC — clmca-ea
> Vùng dưới đây là của riêng project. panda-sync KHÔNG đụng vào. Ghi context/luật đặc thù ở đây.

(để trống — điền context riêng, hoặc trỏ tới .ai/CONTEXT.md)
