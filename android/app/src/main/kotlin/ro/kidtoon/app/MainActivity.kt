package ro.kidtoon.app

import android.app.UiModeManager
import android.content.Intent
import android.content.res.Configuration
import android.content.pm.PackageManager
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity (din audio_service) leaga activitatea de serviciul media,
// ca radioul sa mearga mai departe in fundal.
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        // Scutirea de la economisirea bateriei: altfel unele telefoane opresc radioul cu ecranul stins.
        MethodChannel(messenger, "kidtoon/battery").setMethodCallHandler { call, result ->
            val pm = getSystemService(PowerManager::class.java)
            when (call.method) {
                "isIgnoring" -> result.success(pm?.isIgnoringBatteryOptimizations(packageName) ?: true)
                "request" -> {
                    val direct = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName"))
                    runCatching { startActivity(direct) }
                        .recoverCatching { startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        // Televizor sau telefon: pe TV aplicatia se foloseste cu telecomanda (sageti si OK).
        MethodChannel(messenger, "kidtoon/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "isTv" -> {
                    val ui = getSystemService(UiModeManager::class.java)
                    val tv = ui?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
                        packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
                    result.success(tv)
                }
                else -> result.notImplemented()
            }
        }
    }
}
