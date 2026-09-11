# ==============================================================================
# PROGUARD / R8 RELEASE OPTIMIZATION RULES - VIBETECH XYZ
# Tingkat Optimasi Maksimal (Tinggi / 100% Hijau) untuk Google Play Console
# ==============================================================================

# 1. OPTIMASI TINGKAT LANJUT & KEMAS ULANG KELAS (CLASS REPACKAGING)
# Mengaktifkan fitur "Kemas Ulang Kelas" (Class Repackaging) agar checklist hijau di Play Console
# Menghindari -overloadaggressively karena menyebabkan ART runtime de-optimasi / lagging pada HP
-optimizationpasses 2
-repackageclasses ''
-allowaccessmodification

# Mencegah repackageclasses merusak paket Google, Firebase, Flutter, SQLite, Notifikasi, dan AndroidX (Mencegah runtime break & IPC break)
-keeppackagenames com.google.**
-keeppackagenames io.flutter.**
-keeppackagenames androidx.**
-keeppackagenames com.tekartik.**
-keeppackagenames com.dexterous.**
-keeppackagenames io.requery.**

# 2. ENTRY POINT APLIKASI FLUTTER UTAMA
-keep class io.flutter.app.FlutterApplication { *; }
-keep class io.flutter.embedding.android.FlutterActivity { *; }
-keep class io.flutter.embedding.android.FlutterFragmentActivity { *; }
-keep class androidx.fragment.app.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class com.raziek.vibetech_xyz.MainActivity { *; }

# 3. FLUTTER PLUGIN REGISTRATIONS (Presisi: Hanya keep entry point plugin, bukan seluruh package)
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin {
    public void onAttachedToEngine(io.flutter.embedding.engine.plugins.FlutterPlugin$FlutterPluginBinding);
    public void onDetachedFromEngine(io.flutter.embedding.engine.plugins.FlutterPlugin$FlutterPluginBinding);
}
-keep class * implements io.flutter.embedding.engine.plugins.activity.ActivityAware {
    public void onAttachedToActivity(io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding);
    public void onDetachedFromActivity();
    public void onReattachedToActivityForConfigChanges(io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding);
    public void onDetachedFromActivityForConfigChanges();
}

# 4. METHOD CHANNEL INTEROP (Mencegah nama method channel terpotong)
-keep class io.flutter.plugin.common.MethodChannel { *; }
-keep class io.flutter.plugin.common.BasicMessageChannel { *; }
-keep class io.flutter.plugin.common.EventChannel { *; }

# 5. NOTIFIKASI SISTEM (BroadcastReceiver & Service untuk background notifications)
-keep class com.dexterous.flutterlocalnotifications.** extends android.content.BroadcastReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.** extends android.app.Service { *; }

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

# 11. PROTEKSI KELAS NATIVE & JNI DATABASE SQLITE DAN GOOGLE FIREBASE (PLAY STORE RELEASE HARDENING)
-keep class com.tekartik.sqflite.** { *; }
-keep class com.tekartik.** { *; }
-keep class androidx.sqlite.** { *; }
-keep class androidx.sqlite.db.** { *; }
-keep class androidx.sqlite.db.framework.** { *; }
-keep class io.requery.android.database.sqlite.** { *; }
-keep class android.database.sqlite.** { *; }
-keep class android.database.** { *; }
-keepclassmembers class * extends android.database.sqlite.SQLiteOpenHelper {
    public <init>(...);
    public void onCreate(android.database.sqlite.SQLiteDatabase);
    public void onUpgrade(android.database.sqlite.SQLiteDatabase, int, int);
    public void onOpen(android.database.sqlite.SQLiteDatabase);
}
-keep class com.google.firebase.** { *; }
-keep class com.google.firebase.database.** { *; }
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.android.gms.** { *; }
-keepclassmembers class * {
    @com.google.firebase.database.PropertyName <fields>;
    @com.google.firebase.database.IgnoreExtraProperties <fields>;
    @com.google.firebase.database.Exclude <fields>;
}

# 12. PROTEKSI LENGKAP GOOGLE PLAY SERVICES & GOOGLE SIGN-IN (MENCEGAH ERROR APIEXCEPTION 10)
-keep class io.flutter.plugins.googlesignin.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.auth.api.** { *; }
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.common.api.** { *; }
-keep class com.google.android.gms.common.internal.** { *; }
-keep class com.google.android.gms.common.internal.safeparcel.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep interface com.google.android.gms.** { *; }
-keep public class com.google.android.gms.common.internal.safeparcel.SafeParcelable {
    public static final *** NULL;
}
-keepnames class * implements android.os.Parcelable
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
-keep class androidx.credentials.** { *; }
-keep class androidx.credentials.playservices.** { *; }

# 13. MODEL SERIALIZATION & DART/JNI DATA ENTITIES & PLUGINS
-keepclassmembers class * {
    *** fromMap(...);
    *** toMap(...);
    *** fromJson(...);
    *** toJson(...);
}
-keep class io.requery.android.database.sqlite.** { *; }
-keep class com.google.android.play.core.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class io.flutter.plugins.webviewflutter.** { *; }
-keep class com.airbnb.lottie.** { *; }

