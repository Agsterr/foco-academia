package com.focodev.academia.foco_academia_mobile

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.focodev.academia/energy_settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openBatterySaverSettings" -> {
                        result.success(openBatterySaverSettings())
                    }
                    "openIgnoreBatteryOptimizations" -> {
                        result.success(openIgnoreBatteryOptimizations())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Abre a tela do sistema com o interruptor de Economia de energia. */
    private fun openBatterySaverSettings(): Boolean {
        return try {
            val candidates = ArrayList<Intent>()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                candidates.add(Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS))
            }
            // Fallbacks: lista de otimização / tela geral de bateria / settings.
            candidates.add(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                candidates.add(Intent(Intent.ACTION_POWER_USAGE_SUMMARY))
            }
            candidates.add(Intent(Settings.ACTION_SETTINGS))

            for (intent in candidates) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    return true
                }
            }
            false
        } catch (_: Exception) {
            false
        }
    }

    /** Pede isenção de otimização só deste app (não é a Economia do sistema). */
    private fun openIgnoreBatteryOptimizations(): Boolean {
        return try {
            val request = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (request.resolveActivity(packageManager) != null) {
                startActivity(request)
                return true
            }
            val list = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(list)
            true
        } catch (_: Exception) {
            false
        }
    }
}
