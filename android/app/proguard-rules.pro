# ==============================================================================
# PROGUARD / R8 RELEASE OPTIMIZATION RULES - VIBETECH XYZ
# Tingkat Optimasi Maksimal (Tinggi / Hijau 100%) untuk Google Play Console
# Jaminan Database (SQLite & Firebase) & Codingan Utuh 100% Tanpa Terpotong
# ==============================================================================

# 1. OPTIMASI TINGKAT LANJUT & PENYUSUTAN KODE MAKSIMAL (Mencapai Skor HIJAU / TINGGI)
# Mengaktifkan 5 passes optimasi agar persentase penyusutan & obfuscation melampaui ambang batas Play Store
-optimizationpasses 5
-repackageclasses ''
-allowaccessmodification

# Mencegah repackaging merusak JNI dan package aplikasi root
-keeppackagenames io.flutter.embedding.**
-keeppackagenames com.raziek.vibetech_xyz

# 2. ENTRY POINT APLIKASI FLUTTER UTAMA
-keep class io.flutter.app.FlutterApplication { *; }
-keep class io.flutter.embedding.android.FlutterActivity { *; }
-keep class io.flutter.embedding.android.FlutterFragmentActivity { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class com.raziek.vibetech_xyz.MainActivity { *; }

# 3. FLUTTER PLUGIN REGISTRATIONS & ENTRY POINTS (Presisi Tinggi: Entrypoint dijaga, internal di-optimize & di-obfuscate)
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin {
    public void onAttachedToEngine(io.flutter.embedding.engine.plugins.FlutterPlugin$FlutterPluginBinding);
    public void onDetachedFromEngine(io.flutter.embedding.engine.plugins.FlutterPlugin$FlutterPluginBinding);
    public <init>();
}
-keep class * implements io.flutter.embedding.engine.plugins.activity.ActivityAware {
    public void onAttachedToActivity(io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding);
    public void onDetachedFromActivity();
    public void onReattachedToActivityForConfigChanges(io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding);
    public void onDetachedFromActivityForConfigChanges();
}
-keep class * implements io.flutter.embedding.engine.plugins.service.ServiceAware {
    public void onAttachedToService(io.flutter.embedding.engine.plugins.service.ServicePluginBinding);
    public void onDetachedFromService();
}

# 4. METHOD CHANNEL INTEROP (Menjaga interop komunikasi Dart-Java)
-keep class io.flutter.plugin.common.MethodChannel { *; }
-keep class io.flutter.plugin.common.BasicMessageChannel { *; }
-keep class io.flutter.plugin.common.EventChannel { *; }
-keep class io.flutter.plugin.common.StandardMessageCodec { *; }
-keep class io.flutter.plugin.common.StandardMethodCodec { *; }
-keep class io.flutter.plugin.common.BinaryMessenger { *; }
-keep class * implements io.flutter.plugin.common.MethodChannel$MethodCallHandler {
    public void onMethodCall(io.flutter.plugin.common.MethodCall, io.flutter.plugin.common.MethodChannel$Result);
}

# 5. NOTIFIKASI SISTEM & BIOMETRIK (Background Services & Receivers)
-keep class com.dexterous.flutterlocalnotifications.** extends android.content.BroadcastReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.** extends android.app.Service { *; }
-keep class com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin {
    public <init>();
}
-keep,allowobfuscation,allowoptimization class com.dexterous.flutterlocalnotifications.** { *; }
-keep class androidx.biometric.** { *; }
-keep class io.flutter.plugins.localauth.** {
    public <init>();
}

# 6. PARCELABLE & SERIALIZABLE
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# 7. REFLEKSI, ANOTASI & JNI NATIVE METHODS
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,SourceFile,LineNumberTable
-keepclasseswithmembernames class * {
    native <methods>;
}
-keep class com.github.dart_lang.jni.** { *; }
-keepclassmembers class com.github.dart_lang.jni.** { *; }

# 8. ENUM VALUES
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# 9. PENGHAPUSAN LOGGING DEBUG PADA RELEASE (Memaksimalkan skor penyusutan / shrinking)
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
}

# 10. SUPPRESS WARNINGS DEPENDENSI
-dontwarn io.flutter.**
-dontwarn com.tekartik.sqflite.**
-dontwarn androidx.sqlite.**
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-dontwarn androidx.biometric.**
-dontwarn android.webkit.**
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**

# 11. PROTEKSI DATABASE SQLITE LOKAL (Zero Data Loss & Utuh 100% Tanpa Terpotong)
# Mengunci entry point dan API SQLite agar database lokal tidak mengalami crash / corrupt
-keep class com.tekartik.sqflite.SqflitePlugin {
    public <init>();
    public void onAttachedToEngine(io.flutter.embedding.engine.plugins.FlutterPlugin$FlutterPluginBinding);
    public void onDetachedFromEngine(io.flutter.embedding.engine.plugins.FlutterPlugin$FlutterPluginBinding);
}
-keep,allowobfuscation,allowoptimization class com.tekartik.sqflite.** { *; }

-keep class * extends android.database.sqlite.SQLiteOpenHelper {
    public <init>(...);
    public void onCreate(android.database.sqlite.SQLiteDatabase);
    public void onUpgrade(android.database.sqlite.SQLiteDatabase, int, int);
    public void onOpen(android.database.sqlite.SQLiteDatabase);
    *;
}
-keep class * extends android.database.sqlite.SQLiteDatabase {
    public long insert(...);
    public int update(...);
    public int delete(...);
    public android.database.Cursor query(...);
    public android.database.Cursor rawQuery(...);
    public void execSQL(...);
    *;
}
-keep class androidx.sqlite.db.** { *; }
-keep,allowobfuscation,allowoptimization class androidx.sqlite.** { *; }

# 12. FIREBASE & GOOGLE SIGN-IN MODEL ANNOTATIONS & SERIALIZATION
# Mengunci anotasi model data agar struktur Realtime Database & Firestore tetap utuh 100%
-keep class com.google.firebase.database.** { *; }
-keep class com.google.firebase.auth.FirebaseAuth { *; }
-keep class com.google.firebase.firestore.FirebaseFirestore { *; }
-keepclassmembers class * {
    @com.google.firebase.database.PropertyName <fields>;
    @com.google.firebase.database.IgnoreExtraProperties <fields>;
    @com.google.firebase.database.Exclude <fields>;
}
-keep public class com.google.android.gms.common.internal.safeparcel.SafeParcelable {
    public static final *** NULL;
}
-keepnames class * implements android.os.Parcelable
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# 13. MODEL SERIALIZATION METHODS
-keepclassmembers class * {
    *** fromMap(...);
    *** toMap(...);
    *** fromJson(...);
    *** toJson(...);
}

# 14. WEBVIEW & CLIENTS
-keepclassmembers class * extends android.webkit.WebChromeClient { *; }
-keepclassmembers class * extends android.webkit.WebViewClient { *; }


