# راهنمای رفع مشکل اکانت رایگان Apple Developer

## 🚨 تشخیص مشکل

خطاهای شما نشان می‌دهد که از **اکانت رایگان Apple Developer** استفاده می‌کنید که محدودیت‌هایی دارد:

### خطاهای رایج اکانت رایگان:
- ❌ `Associated Domains capability` پشتیبانی نمی‌شود
- ❌ `App Groups` نیاز به اکانت پولی دارد  
- ❌ `Custom Network Protocol` محدود است
- ❌ `Background Downloads` کاملاً پشتیبانی نمی‌شود

## ✅ راه‌حل‌های ارائه شده

### 1. Entitlements سازگار با اکانت رایگان
فایل `Feather.entitlements` به‌روزرسانی شده و شامل:
- ✅ دسترسی پایه به فایل‌ها
- ✅ دسترسی شبکه 
- ✅ Background Processing محدود
- ❌ حذف قابلیت‌های پولی

### 2. اسکریپت‌های ویژه اکانت رایگان
- 📜 `build_ipa_free_account.sh` (macOS/Linux)
- 📜 `build_ipa_free_account.ps1` (Windows)

## 🛠️ مراحل رفع مشکل

### مرحله 1: استفاده از اسکریپت رایگان

**برای macOS/Linux:**
```bash
cd "Baba App IOS app"
chmod +x build_ipa_free_account.sh
./build_ipa_free_account.sh
```

**برای Windows:**
```powershell
cd "Baba App IOS app"
.\build_ipa_free_account.ps1
```

### مرحله 2: تنظیمات Xcode (اختیاری)

اگر می‌خواهید manually از Xcode build کنید:

1. **Project Settings** را باز کنید
2. **Target → Feather** را انتخاب کنید
3. **Signing & Capabilities** تب:
   - ✅ `Automatically manage signing` را فعال کنید
   - ✅ Team خود را انتخاب کنید
   - ✅ Bundle ID را `BabaApp.Babaman.baba` تغییر دهید

4. **Capabilities حذف کنید:**
   - ❌ Associated Domains
   - ❌ App Groups  
   - ❌ Push Notifications (اگر دارید)
   - ❌ Background App Refresh (advanced)

## 🔧 تنظیمات دستی Entitlements

اگر خطا ادامه داشت، entitlements را کاملاً minimal کنید:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>get-task-allow</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

## 📋 محدودیت‌های اکانت رایگان

### ❌ چه چیزهایی کار نمی‌کند:
- Associated Domains (deep linking محدود)
- App Groups (sharing data between apps)
- Push Notifications
- Background App Refresh کامل
- Custom URL Schemes پیچیده
- Enterprise features

### ✅ چه چیزهایی کار می‌کند:
- Basic file downloads
- Network requests
- Local storage
- Basic background processing
- Core app functionality

## 🚀 آپگرید به اکانت پولی

برای رفع کامل محدودیت‌ها:

1. **Apple Developer Program** بخرید ($99/سال)
2. **تمام entitlements** فعال می‌شوند
3. **App Store distribution** امکان‌پذیر می‌شود
4. **7-day limit** برداشته می‌شود

## 🛡️ نکات امنیتی

### اکانت رایگان:
- ✅ Apps فقط 7 روز کار می‌کنند
- ✅ فقط 3 app همزمان
- ✅ فقط روی دستگاه خودتان

### اکانت پولی:
- ✅ Apps یک سال کار می‌کنند  
- ✅ Distribution برای 100 device
- ✅ TestFlight access

## 🎯 تست نهایی

بعد از build کردن با اسکریپت جدید:

1. **نصب IPA** روی دستگاه
2. **تست download** - خطای "Cannot create file" باید حل شود
3. **محدودیت‌ها** را در نظر بگیرید:
   - بعضی network features ممکن است محدود باشند
   - Deep linking کار نکند

## 📞 پشتیبانی

اگر مشکل ادامه داشت:

1. **Clean Build Folder** در Xcode
2. **Delete Derived Data**
3. **Restart Xcode**
4. **Team و Certificate** را دوباره انتخاب کنید

## 🔍 خطایابی

### خطاهای شایع بعد از تغییرات:

```bash
# Check signing
codesign -vv -d ./dist/Feather-FreeBuild.ipa

# Check entitlements  
codesign -d --entitlements - ./Payload/Feather.app

# Check bundle ID
plutil -p ./Payload/Feather.app/Info.plist | grep BundleId
```

---

**⚠️ نکته مهم**: این راه‌حل برای اکانت‌های رایگان بهینه شده و بعضی از قابلیت‌های پیشرفته را حذف می‌کند. برای تجربه کامل، آپگرید به Apple Developer Program توصیه می‌شود.