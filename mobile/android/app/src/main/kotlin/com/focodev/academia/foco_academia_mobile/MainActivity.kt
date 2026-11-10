package com.focodev.academia.foco_academia_mobile

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val energyChannelName = "com.focodev.academia/energy_settings"
    private val audioRouteChannelName = "com.focodev.academia/audio_route"
    private val deviceChannelName = "com.focodev.academia/device"
    private val inviteChannelName = "com.focodev.academia/invite_link"
    private var inviteChannel: MethodChannel? = null

    /** Link de convite (focoacademia://convite/CODIGO) ainda não lido pelo Flutter. */
    private var pendingInviteLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingInviteLink = inviteLinkFrom(intent)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Continua igual se o app for desinstalado e instalado de novo no mesmo celular.
                    "stableDeviceId" -> result.success(
                        try {
                            Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                        } catch (_: Exception) {
                            null
                        },
                    )
                    else -> result.notImplemented()
                }
            }
        inviteChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, inviteChannelName).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeInviteLink" -> {
                        result.success(pendingInviteLink)
                        pendingInviteLink = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, energyChannelName)
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, audioRouteChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "prepareMediaPlaybackRoute" -> {
                        result.success(prepareMediaPlaybackRoute())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val link = inviteLinkFrom(intent) ?: return
        setIntent(intent)
        // App já aberto: avisa o Flutter na hora.
        inviteChannel?.invokeMethod("inviteLink", link)
    }

    private fun inviteLinkFrom(intent: Intent?): String? {
        val data = intent?.data ?: return null
        return if (data.scheme == "focoacademia" || data.path?.startsWith("/convite/") == true) data.toString() else null
    }

    /**
     * Garante que voz/toques do outdoor usem a rota de mídia atual
     * (fone BT/cabo quando conectado), e não o alto-falante do aparelho.
     */
    private fun prepareMediaPlaybackRoute(): Boolean {
        return try {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            am.mode = AudioManager.MODE_NORMAL
            @Suppress("DEPRECATION")
            am.isSpeakerphoneOn = false
            true
        } catch (_: Exception) {
            false
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
