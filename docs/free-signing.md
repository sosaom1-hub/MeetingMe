# การใช้แอปบนเครื่องจริงแบบฟรี (ไม่สมัคร Apple Developer Program)

## ข้อจำกัดของ Apple ID ฟรี (Personal Team)

- โปรไฟล์ที่ใช้เซ็นแอปมีอายุ **7 วัน** หลังจากนั้นแอปบน iPhone/Watch จะเปิดไม่ขึ้น จนกว่าจะติดตั้งทับใหม่
- ติดตั้งแอปที่เซ็นแบบนี้ได้สูงสุด **3 แอปต่อเครื่อง**
- สร้าง App ID ได้สูงสุด **10 อันต่อ 7 วัน** โปรเจกต์นี้ใช้ 2 อัน คือแอป iPhone และแอป Watch และจะใช้ 3 อันเมื่อเพิ่ม widget
  ห้ามเปลี่ยน `BUNDLE_PREFIX` บ่อยๆ
- ไม่มี iCloud/CloudKit, Push Notification และ TestFlight
  แอปนี้ไม่ได้ใช้ของพวกนี้: Watch กับ iPhone คุยกันผ่าน WatchConnectivity ส่วน iPhone กับ Mac คุยกันผ่าน Tailscale
- **แอป Mac ไม่หมดอายุ** เพราะเซ็นแบบ "Sign to Run Locally" สำหรับใช้บนเครื่องตัวเอง

## ข้อมูลไม่หาย

แอปที่หมดอายุแล้ว **ข้อมูลยังอยู่ครบ** ติดตั้งทับด้วย bundle ID เดิมและ Apple ID เดิม แล้วทุกอย่างกลับมาเหมือนเดิม
**ห้ามลบแอปออกจาก iPhone** เพราะการลบแอปจะลบไฟล์เสียงและ transcript ทั้งหมดไปด้วย

## วิธีแก้: ให้ Mac ต่ออายุให้อัตโนมัติ

`scripts/renew-devices.sh` จะ build และเซ็นแอปใหม่ แล้วติดตั้งทับลง iPhone ผ่าน Wi-Fi ด้วย `devicectl`
แอป Watch ฝังอยู่ในแอป iPhone จึงได้รับการต่ออายุไปพร้อมกัน
launchd จะรันสคริปต์ทุกวันเวลา 09:30 และทุกครั้งที่ล็อกอิน แต่จะติดตั้งใหม่เฉพาะเมื่อติดตั้งครั้งล่าสุดผ่านมา 5 วันขึ้นไป
ถ้าวันไหนหา iPhone ไม่เจอ วันรุ่งขึ้นจะลองใหม่ จึงมีวันสำรองอีก 2 วัน และทุกครั้งที่ทำไม่สำเร็จ Mac จะแสดงการแจ้งเตือน

### ตั้งค่าครั้งเดียว

1. **เพิ่ม Apple ID ใน Xcode:** Xcode > Settings > Accounts > + > Apple ID แล้วล็อกอิน
2. **หา Team ID:** ในหน้า Accounts เดิม เลือก Personal Team ของคุณ จะเห็นรหัส 10 ตัวอักษร
3. **สร้าง `scripts/signing.env`** (ไฟล์นี้ไม่ถูก commit ขึ้น git):
   ```sh
   TEAM_ID=ABCDE12345
   DEVICE=Send_Doggo        # ชื่อ iPhone จากคำสั่ง: xcrun devicectl list devices
   ```
4. **ติดตั้งครั้งแรกด้วยมือ** iPhone ต้องปลดล็อกอยู่:
   ```sh
   scripts/renew-devices.sh --force
   ```
   - ครั้งแรก iPhone จะถามให้เชื่อถือนักพัฒนา ไปที่ การตั้งค่า > ทั่วไป > VPN และการจัดการอุปกรณ์ แล้วกดเชื่อถือ Apple ID ของคุณ
   - เปิด **Developer Mode** บน iPhone และ Watch: การตั้งค่า > ความเป็นส่วนตัวและความปลอดภัย > Developer Mode
   - ถ้าแอปไม่ขึ้นบน Watch เอง ให้เปิดแอป Watch บน iPhone แล้วกดติดตั้ง "บันทึกประชุม"
5. **เปิดการต่ออายุอัตโนมัติ:**
   ```sh
   sed "s|REPO_PATH|$PWD|" scripts/com.meetingrecorder.renew.plist > ~/Library/LaunchAgents/com.meetingrecorder.renew.plist
   launchctl load ~/Library/LaunchAgents/com.meetingrecorder.renew.plist
   ```

### ตรวจสถานะ

```sh
cat /tmp/meetingrecorder-renew.log                   # ผลการรันแต่ละครั้ง
ls ~/Library/Logs/MeetingRecorderRenew/              # log ของการ build
```

ถ้า Mac เปิดอยู่และ iPhone อยู่ Wi-Fi เดียวกันอย่างน้อยหนึ่งครั้งทุก 5–7 วัน แอปจะไม่หมดอายุ
Task 10 จะเพิ่มบรรทัด "แอปบน iPhone ใช้ได้อีก N วัน" และปุ่ม "ต่ออายุเดี๋ยวนี้" ลงในแอป Mac บนแถบเมนู
